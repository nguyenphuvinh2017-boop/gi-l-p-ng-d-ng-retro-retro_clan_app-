import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/lan_message.dart';

class ClanNetplayService {
  static const int defaultWsPort = 8989;
  static const int defaultUdpPort = 8988;

  HttpServer? _wsServer;
  WebSocket? _p2Socket;
  RawDatagramSocket? _udpSocket;
  Timer? _beaconTimer;

  // Client connection
  WebSocket? _clientSocket;

  // Callbacks
  Function(String btn, bool isDown)? onPlayer2InputReceived;
  Function(bool connected)? onP2ConnectionChanged;
  Function(List<ClanRoomInfo> rooms)? onRoomsDiscovered;

  final Map<String, ClanRoomInfo> _discoveredRooms = {};
  Timer? _cleanupTimer;

  bool get isHosting => _wsServer != null;
  bool get isP2Connected => _p2Socket != null && _p2Socket?.readyState == WebSocket.open;
  bool get isClientConnected => _clientSocket != null && _clientSocket?.readyState == WebSocket.open;

  /// Lấy địa chỉ IP mạng Wi-Fi nội bộ chính xác (ưu tiên card Wi-Fi en0/wlan0, loại bỏ 4G di động)
  Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // 1. Ưu tiên cao nhất: Interface Wi-Fi thực thụ (en0 trên iOS, wlan0 trên Android, Wi-Fi trên Windows)
      for (var iface in interfaces) {
        final name = iface.name.toLowerCase();
        final isWifi = name.contains('wlan') || name.contains('en0') || name.contains('wi-fi') || name.contains('wifi') || name.contains('eth');
        if (isWifi) {
          for (var addr in iface.addresses) {
            if (!addr.isLoopback && (addr.address.startsWith('192.168.') || addr.address.startsWith('10.') || addr.address.startsWith('172.'))) {
              return addr.address;
            }
          }
        }
      }

      // 2. Ưu tiên dải mạng Wi-Fi gia đình thông dụng 192.168.x.x
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }

      // 3. Các dải private LAN khác (loại bỏ mạng di động nếu có thể)
      for (var iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (!name.contains('pdp_ip') && !name.contains('rmnet') && !name.contains('cellular')) {
          for (var addr in iface.addresses) {
            if (!addr.isLoopback && !addr.address.startsWith('127.')) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      print('Local IP fetch error: $e');
    }
    return '127.0.0.1';
  }

  // ==========================================
  // HOST MODE
  // ==========================================

  /// Start Clan Room as Host
  Future<bool> startClanRoom({
    required String roomName,
    required String gameTitle,
    int port = defaultWsPort,
  }) async {
    await stopAll();

    try {
      final localIp = await getLocalIp();

      // 1. Start WebSocket server for controller sync
      _wsServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Clan Host WS server listening on $localIp:$port');

      _wsServer!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleP2Connection(socket, gameTitle);
        } else if (request.uri.path == '/status' || request.uri.path == '/info') {
          request.response.headers.contentType = ContentType.json;
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.write(jsonEncode({
            'status': 'ok',
            'roomName': roomName,
            'gameTitle': gameTitle,
            'hostIp': localIp,
            'port': port,
            'p2Connected': isP2Connected,
          }));
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.write('RetroClan Host Active');
          await request.response.close();
        }
      });

      // 2. Start UDP Beacon broadcaster for zero-config LAN discovery
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket!.broadcastEnabled = true;

      _beaconTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        try {
          final beaconMsg = LanMessage(
            type: LanMessageType.beacon,
            payload: {
              'roomName': roomName,
              'gameTitle': gameTitle,
              'hostIp': localIp,
              'port': port,
            },
          ).serialize();

          final bytes = utf8.encode(beaconMsg);
          _udpSocket?.send(
            bytes,
            InternetAddress('255.255.255.255'),
            defaultUdpPort,
          );
        } catch (_) {}
      });

      return true;
    } catch (e) {
      print('Failed to start clan room: $e');
      await stopAll();
      return false;
    }
  }

  void _handleP2Connection(WebSocket socket, String gameTitle) {
    if (_p2Socket != null) {
      socket.close(WebSocketStatus.normalClosure, 'Room Full');
      return;
    }

    _p2Socket = socket;
    onP2ConnectionChanged?.call(true);

    // Send welcome payload
    final welcome = LanMessage(
      type: LanMessageType.joined,
      payload: {
        'player': 2,
        'gameTitle': gameTitle,
        'status': 'connected',
      },
    ).serialize();
    _p2Socket?.add(welcome);

    _p2Socket?.listen(
      (data) {
        final msg = LanMessage.deserialize(data.toString());
        if (msg == null) return;

        if (msg.type == LanMessageType.input) {
          final btn = msg.payload['btn'] as String? ?? '';
          final isDown = msg.payload['down'] as bool? ?? false;
          onPlayer2InputReceived?.call(btn, isDown);
        }
      },
      onDone: () {
        _p2Socket = null;
        onP2ConnectionChanged?.call(false);
      },
      onError: (_) {
        _p2Socket = null;
        onP2ConnectionChanged?.call(false);
      },
    );
  }

  // ==========================================
  // CLIENT / CLAN MEMBER MODE
  // ==========================================

  /// Start discovering Clan Rooms on local Wi-Fi
  Future<void> startDiscovery() async {
    _discoveredRooms.clear();
    // 1. Quét song song bằng UDP Broadcast
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        defaultUdpPort,
        reuseAddress: true,
      );
      _udpSocket?.broadcastEnabled = true;

      _udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            final raw = utf8.decode(datagram.data);
            final msg = LanMessage.deserialize(raw);
            if (msg != null && msg.type == LanMessageType.beacon) {
              final hostIp = msg.payload['hostIp'] as String? ?? datagram.address.address;
              final port = msg.payload['port'] as int? ?? defaultWsPort;
              final roomName = msg.payload['roomName'] as String? ?? 'Clan Room';
              final gameTitle = msg.payload['gameTitle'] as String? ?? 'Retro Game';

              _discoveredRooms[hostIp] = ClanRoomInfo(
                roomName: roomName,
                gameTitle: gameTitle,
                hostIp: hostIp,
                port: port,
                lastSeen: DateTime.now(),
              );

              onRoomsDiscovered?.call(_discoveredRooms.values.toList());
            }
          }
        }
      });

      // Cleanup stale rooms
      _cleanupTimer?.cancel();
      _cleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        final now = DateTime.now();
        _discoveredRooms.removeWhere((_, room) => now.difference(room.lastSeen).inSeconds > 10);
        onRoomsDiscovered?.call(_discoveredRooms.values.toList());
      });
    } catch (e) {
      print('Discovery error: $e');
    }

    // 2. Quét song song bằng HTTP subnet probe (Đảm bảo 100% tìm thấy trên iOS và Router chặn UDP)
    scanSubnet();
  }

  /// Quét nhanh dải mạng nội bộ qua HTTP (dành cho iOS và bộ định tuyến chặn UDP Broadcast)
  Future<void> scanSubnet() async {
    try {
      final localIp = await getLocalIp();
      if (!localIp.contains('.')) return;
      final parts = localIp.split('.');
      if (parts.length != 4) return;
      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      final currentHostNum = int.tryParse(parts[3]) ?? 0;

      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);

      // Quét các IP lân cận trước
      final List<int> ipSuffixes = [];
      for (int delta = 1; delta <= 30; delta++) {
        if (currentHostNum - delta >= 1) ipSuffixes.add(currentHostNum - delta);
        if (currentHostNum + delta <= 254) ipSuffixes.add(currentHostNum + delta);
      }
      for (int i = 1; i <= 254; i++) {
        if (!ipSuffixes.contains(i) && i != currentHostNum) {
          ipSuffixes.add(i);
        }
      }

      const batchSize = 30;
      for (int i = 0; i < ipSuffixes.length; i += batchSize) {
        final batch = ipSuffixes.skip(i).take(batchSize);
        await Future.wait(batch.map((suffix) async {
          final targetIp = '$prefix.$suffix';
          try {
            final uri = Uri.parse('http://$targetIp:$defaultWsPort/status');
            final req = await client.getUrl(uri);
            final res = await req.close();
            if (res.statusCode == HttpStatus.ok) {
              final body = await res.transform(utf8.decoder).join();
              final json = jsonDecode(body) as Map<String, dynamic>;
              final hostIp = json['hostIp'] as String? ?? targetIp;
              final roomName = json['roomName'] as String? ?? 'Phòng Clan';
              final gameTitle = json['gameTitle'] as String? ?? 'Game';
              final port = json['port'] as int? ?? defaultWsPort;

              _discoveredRooms[hostIp] = ClanRoomInfo(
                roomName: roomName,
                gameTitle: gameTitle,
                hostIp: hostIp,
                port: port,
                lastSeen: DateTime.now(),
              );
              onRoomsDiscovered?.call(_discoveredRooms.values.toList());
            }
          } catch (_) {}
        }));
      }
      client.close();
    } catch (_) {}
  }

  /// Connect to Host as Player 2
  Future<bool> joinClanRoom({
    required String hostIp,
    int port = defaultWsPort,
    required Function(String gameTitle) onJoined,
  }) async {
    try {
      final cleanIp = hostIp.trim();
      final wsUrl = 'ws://$cleanIp:$port';
      print('Connecting to $wsUrl');
      _clientSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 8));

      _clientSocket?.listen(
        (data) {
          final msg = LanMessage.deserialize(data.toString());
          if (msg != null && msg.type == LanMessageType.joined) {
            final title = msg.payload['gameTitle'] as String? ?? 'Game';
            onJoined(title);
          }
        },
        onDone: () {
          _clientSocket = null;
        },
        onError: (_) {
          _clientSocket = null;
        },
      );

      return true;
    } catch (e) {
      print('Failed to join clan room: $e');
      _clientSocket = null;
      return false;
    }
  }

  /// Send button input from Client (Player 2) to Host
  void sendClientInput(String button, bool isDown) {
    if (_clientSocket != null && _clientSocket?.readyState == WebSocket.open) {
      final msg = LanMessage(
        type: LanMessageType.input,
        payload: {
          'player': 2,
          'btn': button,
          'down': isDown,
        },
      ).serialize();
      _clientSocket?.add(msg);
    }
  }

  /// Shutdown all servers and sockets
  Future<void> stopAll() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    try {
      await _p2Socket?.close();
    } catch (_) {}
    _p2Socket = null;

    try {
      await _clientSocket?.close();
    } catch (_) {}
    _clientSocket = null;

    try {
      await _wsServer?.close(force: true);
    } catch (_) {}
    _wsServer = null;

    try {
      _udpSocket?.close();
    } catch (_) {}
    _udpSocket = null;
  }
}

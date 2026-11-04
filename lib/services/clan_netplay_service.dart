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

  /// Get Local Wi-Fi IPv4 address
  Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && (addr.address.startsWith('192.168.') || addr.address.startsWith('10.') || addr.address.startsWith('172.'))) {
            return addr.address;
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
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
        } else {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.close();
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
        _discoveredRooms.removeWhere((_, room) => now.difference(room.lastSeen).inSeconds > 5);
        onRoomsDiscovered?.call(_discoveredRooms.values.toList());
      });
    } catch (e) {
      print('Discovery error: $e');
    }
  }

  /// Connect to Host as Player 2
  Future<bool> joinClanRoom({
    required String hostIp,
    int port = defaultWsPort,
    required Function(String gameTitle) onJoined,
  }) async {
    try {
      final wsUrl = 'ws://$hostIp:$port';
      print('Connecting to $wsUrl');
      _clientSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 4));

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

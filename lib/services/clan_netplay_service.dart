import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/lan_message.dart';

class ClanNetplayService {
  static const int defaultWsPort = 8989;
  WebSocket? _audioSourceSocket;
  final List<WebSocket> _audioClientSockets = [];

  static const String _p2ScreenHtml = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; user-select:none; -webkit-user-select:none; }
    html, body { width:100%; height:100%; background:#000; overflow:hidden; display:flex; align-items:center; justify-content:center; }
    #canvas { width:100%; height:100%; object-fit:contain; image-rendering:pixelated; image-rendering:crisp-edges; }
    #tapPrompt {
      position:absolute; top:8px; left:50%; transform:translateX(-50%);
      background:rgba(19, 28, 49, 0.94); border:1.5px solid #00E5FF; color:#00E5FF;
      padding:6px 14px; border-radius:20px; font-size:11px; font-weight:bold;
      font-family:system-ui, -apple-system, sans-serif; pointer-events:auto; cursor:pointer; z-index:10;
      display:flex; align-items:center; gap:6px; box-shadow:0 4px 14px rgba(0,0,0,0.8);
    }
  </style>
</head>
<body>
  <div id="tapPrompt" onclick="unlockAudio()">🔊 Bấm để mở âm thanh</div>
  <canvas id="canvas" width="640" height="480"></canvas>
  <script>
    const canvas = document.getElementById('canvas');
    const ctx = canvas.getContext('2d', { alpha: false });
    ctx.imageSmoothingEnabled = false;
    const prompt = document.getElementById('tapPrompt');

    let actx = null;
    let nextAudioTime = 0;

    function unlockAudio() {
      try {
        if (!actx) {
          const AC = window.AudioContext || window.webkitAudioContext;
          actx = new AC({ sampleRate: 44100 });
        }
        if (actx && actx.state === 'suspended') {
          actx.resume();
        }
        if (actx && actx.state === 'running' && prompt) {
          prompt.style.display = 'none';
        }
      } catch(e) {}
    }

    window.unlockAudio = unlockAudio;
    document.addEventListener('touchstart', unlockAudio, { passive: true });
    document.addEventListener('pointerdown', unlockAudio, { passive: true });
    document.addEventListener('click', unlockAudio, { passive: true });

    const urlParams = new URLSearchParams(window.location.search);
    const host = urlParams.get('host') || window.location.hostname || '127.0.0.1';

    // 1. Nhận luồng Video Full HD 640x480 và giải mã trực tiếp bằng GPU
    function connectVideo() {
      const ws = new WebSocket('ws://' + host + ':8989/screen_feed_client');
      ws.binaryType = 'blob';
      ws.onmessage = function(e) {
        if (window.createImageBitmap) {
          createImageBitmap(e.data).then(bmp => {
            ctx.drawImage(bmp, 0, 0, canvas.width, canvas.height);
            bmp.close();
          }).catch(() => {});
        } else {
          const img = new Image();
          img.src = URL.createObjectURL(e.data);
          img.onload = () => {
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            URL.revokeObjectURL(img.src);
          };
        }
      };
      ws.onclose = () => setTimeout(connectVideo, 1000);
    }
    connectVideo();

    // 2. Nhận luồng Âm thanh PCM 16-bit và phát mượt mà
    function connectAudio() {
      const host = window.location.hostname || '127.0.0.1';
      const ws = new WebSocket('ws://' + host + ':8989/audio_feed');
      ws.binaryType = 'arraybuffer';
      ws.onmessage = function(e) {
        if (!actx) unlockAudio();
        if (actx && actx.state === 'suspended') actx.resume();
        if (!actx || actx.state !== 'running') return;

        const i16 = new Int16Array(e.data);
        const len = i16.length;
        if (len === 0) return;

        const f32 = new Float32Array(len);
        for (let i = 0; i < len; i++) {
          f32[i] = i16[i] / (i16[i] < 0 ? 32768 : 32767);
        }

        const buf = actx.createBuffer(1, len, actx.sampleRate || 44100);
        buf.getChannelData(0).set(f32);

        const src = actx.createBufferSource();
        src.buffer = buf;
        src.connect(actx.destination);

        const now = actx.currentTime;
        if (nextAudioTime < now || nextAudioTime > now + 0.25) {
          nextAudioTime = now + 0.02;
        }
        src.start(nextAudioTime);
        nextAudioTime += buf.duration;
      };
      ws.onclose = () => setTimeout(connectAudio, 1000);
    }
    connectAudio();
  </script>
</body>
</html>''';


  void _handleAudioFeedSource(WebSocket socket) {
    _audioSourceSocket?.close();
    _audioSourceSocket = socket;
    socket.listen(
      (data) {
        for (var client in List<WebSocket>.from(_audioClientSockets)) {
          try {
            if (client.readyState == WebSocket.open) {
              client.add(data);
            }
          } catch (_) {}
        }
      },
      onDone: () => _audioSourceSocket = null,
      onError: (_) => _audioSourceSocket = null,
    );
  }

  void _handleAudioFeedClient(WebSocket socket) {
    _audioClientSockets.add(socket);
    socket.listen(
      (_) {},
      onDone: () => _audioClientSockets.remove(socket),
      onError: (_) => _audioClientSockets.remove(socket),
    );
  }

  static const int defaultUdpPort = 8988;

  HttpServer? _wsServer;
  WebSocket? _p2Socket;
  RawDatagramSocket? _udpSocket;
  Timer? _beaconTimer;

  // Client connection
  WebSocket? _clientSocket;
  String? lastJoinError;

  // Callbacks
  Function(String btn, bool isDown)? onPlayer2InputReceived;
  Function(bool connected)? onP2ConnectionChanged;
  Function(List<ClanRoomInfo> rooms)? onRoomsDiscovered;
  void Function()? onClientDisconnected;
  Function(Uint8List frame)? onScreenFrameReceived;

  WebSocket? _screenFeedSocket;
  Timer? _subnetScanTimer;

  final Map<String, ClanRoomInfo> _discoveredRooms = {};
  Timer? _cleanupTimer;

  String _currentRoomName = '';
  String _currentGameTitle = '';

  String get currentGameTitle => _currentGameTitle;
  String get currentRoomName => _currentRoomName;

  void updateHostedGame(String gameTitle, {String? roomName}) {
    _currentGameTitle = gameTitle;
    _currentRoomName = roomName ?? 'Phòng $gameTitle';
    if (_p2Socket != null && _p2Socket?.readyState == WebSocket.open) {
      try {
        final updateMsg = LanMessage(
          type: LanMessageType.joined,
          payload: {
            'player': 2,
            'gameTitle': _currentGameTitle,
            'status': 'game_switched',
          },
        ).serialize();
        _p2Socket?.add(updateMsg);
      } catch (_) {}
    }
  }

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
      _currentRoomName = roomName;
      _currentGameTitle = gameTitle;

      // 1. Start WebSocket server for controller sync
      _wsServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Clan Host WS server listening on $localIp:$port');

      _wsServer!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final path = request.uri.path;
          final socket = await WebSocketTransformer.upgrade(request);
          if (path.contains('screen_feed_client')) {
            _handleScreenFeedClient(socket);
          } else if (path.contains('screen_feed')) {
            _handleScreenFeedSource(socket);
          } else if (path.contains('audio_feed_source')) {
            _handleAudioFeedSource(socket);
          } else if (path.contains('audio_feed')) {
            _handleAudioFeedClient(socket);
          } else {
            _handleP2Connection(socket, _currentGameTitle);
          }
        } else if (request.uri.path.contains('p2_screen') || request.uri.path.contains('audio_receiver')) {
          request.response.headers.contentType = ContentType.html;
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.write(_p2ScreenHtml);
          await request.response.close();
        } else if (request.uri.path.startsWith('/status') || request.uri.path.startsWith('/info')) {
          request.response.headers.contentType = ContentType.json;
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.write(jsonEncode({
            'status': 'ok',
            'roomName': _currentRoomName,
            'gameTitle': _currentGameTitle,
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

      final parts = localIp.split('.');
      String subnetBroadcast = '255.255.255.255';
      if (parts.length == 4) {
        subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
      }

      _beaconTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
        try {
          final beaconMsg = LanMessage(
            type: LanMessageType.beacon,
            payload: {
              'roomName': _currentRoomName,
              'gameTitle': _currentGameTitle,
              'hostIp': localIp,
              'port': port,
            },
          ).serialize();

          final bytes = utf8.encode(beaconMsg);
          _udpSocket?.send(bytes, InternetAddress('255.255.255.255'), defaultUdpPort);
          if (subnetBroadcast != '255.255.255.255') {
            try {
              _udpSocket?.send(bytes, InternetAddress(subnetBroadcast), defaultUdpPort);
            } catch (_) {}
          }
          try {
            _udpSocket?.send(bytes, InternetAddress('127.0.0.1'), defaultUdpPort);
          } catch (_) {}
        } catch (_) {}
      });

      return true;
    } catch (e) {
      print('Failed to start clan room: $e');
      await stopAll();
      return false;
    }
  }

  final List<WebSocket> _screenClientSockets = [];

  void _handleScreenFeedClient(WebSocket socket) {
    _screenClientSockets.add(socket);
    socket.listen(
      (_) {},
      onDone: () => _screenClientSockets.remove(socket),
      onError: (_) => _screenClientSockets.remove(socket),
    );
  }

  void _handleScreenFeedSource(WebSocket socket) {
    try {
      _screenFeedSocket?.close();
    } catch (_) {}
    _screenFeedSocket = socket;
    _screenFeedSocket?.listen(
      (data) {
        if (_p2Socket != null && _p2Socket?.readyState == WebSocket.open) {
          try {
            _p2Socket?.add(data);
          } catch (_) {}
        }
        for (var client in List<WebSocket>.from(_screenClientSockets)) {
          try {
            if (client.readyState == WebSocket.open) {
              client.add(data);
            }
          } catch (_) {}
        }
      },
      onDone: () => _screenFeedSocket = null,
      onError: (_) => _screenFeedSocket = null,
    );
  }

  void _handleP2Connection(WebSocket socket, String gameTitle) {
    if (_p2Socket != null) {
      try {
        _p2Socket?.close(WebSocketStatus.normalClosure, 'Replaced by new connection');
      } catch (_) {}
      _p2Socket = null;
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
              final senderIp = datagram.address.address;
              String hostIp = senderIp;
              if (senderIp == '127.0.0.1' || senderIp == '0.0.0.0') {
                hostIp = msg.payload['hostIp'] as String? ?? senderIp;
              }
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

    // 2. Quét song song định kỳ bằng HTTP subnet probe (Tìm thấy phòng 100% không lo router chặn UDP)
    _subnetScanTimer?.cancel();
    scanSubnet();
    _subnetScanTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      scanSubnet();
    });
  }

  bool _isSubnetScanning = false;
  String? lastKnownHostIp;

  /// Đặt lại cờ quét khi người dùng bấm nút làm mới
  void forceScan([String? priorityIp]) {
    _isSubnetScanning = false;
    scanSubnet(priorityIp);
  }

  /// Quét nhanh dải mạng nội bộ qua HTTP (Giai đoạn 1: Ưu tiên siêu tốc 200ms, Giai đoạn 2: Quét toàn dải)
  Future<void> scanSubnet([String? priorityIp]) async {
    if (_isSubnetScanning) return;
    _isSubnetScanning = true;
    try {
      final localIp = await getLocalIp();

      final List<String> priorityList = [];
      if (priorityIp != null && priorityIp.isNotEmpty && !priorityList.contains(priorityIp)) {
        priorityList.add(priorityIp);
      }
      if (lastKnownHostIp != null && !priorityList.contains(lastKnownHostIp)) {
        priorityList.add(lastKnownHostIp!);
      }
      if (!priorityList.contains('127.0.0.1')) priorityList.add('127.0.0.1');
      if (!priorityList.contains(localIp)) priorityList.add(localIp);

      final List<String> remainingList = [];
      if (localIp.contains('.')) {
        final parts = localIp.split('.');
        if (parts.length == 4) {
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
          final hostNum = int.tryParse(parts[3]) ?? 0;
          // Thêm các máy lân cận (+-6) vào nhóm ưu tiên
          for (int delta = 1; delta <= 6; delta++) {
            if (hostNum + delta <= 254) {
              final ip = '$prefix.${hostNum + delta}';
              if (!priorityList.contains(ip)) priorityList.add(ip);
            }
            if (hostNum - delta >= 1) {
              final ip = '$prefix.${hostNum - delta}';
              if (!priorityList.contains(ip)) priorityList.add(ip);
            }
          }
          // Toàn bộ các máy còn lại trong dải subnet
          for (int i = 1; i <= 254; i++) {
            final ip = '$prefix.$i';
            if (!priorityList.contains(ip)) remainingList.add(ip);
          }
        }
      }

      // --- GIAI ĐOẠN 1: Quét song song toàn bộ nhóm ưu tiên lân cận (SIÊU TỐC ~200ms) ---
      final fastClient = HttpClient()..connectionTimeout = const Duration(milliseconds: 250);
      await Future.wait(priorityList.map((targetIp) async {
        try {
          final uri = Uri.parse('http://$targetIp:$defaultWsPort/status');
          final req = await fastClient.getUrl(uri);
          final res = await req.close();
          if (res.statusCode == HttpStatus.ok) {
            final body = await res.transform(utf8.decoder).join();
            final json = jsonDecode(body) as Map<String, dynamic>;
            final hostIp = targetIp;
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
      fastClient.close();

      // --- GIAI ĐOẠN 2: Quét nhanh các máy còn lại theo batch 15 máy (~1.5 giây) ---
      if (remainingList.isNotEmpty) {
        final broadClient = HttpClient()..connectionTimeout = const Duration(milliseconds: 180);
        const batchSize = 15;
        for (int i = 0; i < remainingList.length; i += batchSize) {
          final batch = remainingList.skip(i).take(batchSize);
          await Future.wait(batch.map((targetIp) async {
            try {
              final uri = Uri.parse('http://$targetIp:$defaultWsPort/status');
              final req = await broadClient.getUrl(uri);
              final res = await req.close();
              if (res.statusCode == HttpStatus.ok) {
                final body = await res.transform(utf8.decoder).join();
                final json = jsonDecode(body) as Map<String, dynamic>;
                final hostIp = targetIp;
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
        broadClient.close();
      }
    } catch (_) {} finally {
      _isSubnetScanning = false;
    }
  }

  /// Connect to Host as Player 2
  Future<bool> joinClanRoom({
    required String hostIp,
    int port = defaultWsPort,
    required Function(String gameTitle) onJoined,
  }) async {
    lastJoinError = null;
    try {
      String cleanIp = hostIp.trim();
      int targetPort = port;
      if (cleanIp.contains(':')) {
        final parts = cleanIp.split(':');
        cleanIp = parts[0].trim();
        targetPort = int.tryParse(parts[1].trim()) ?? port;
      }

      // Đóng kết nối cũ nếu có
      try {
        await _clientSocket?.close();
      } catch (_) {}
      _clientSocket = null;

      final wsUrl = 'ws://$cleanIp:$targetPort';
      print('Connecting to $wsUrl');
      _clientSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 6));

      _clientSocket?.listen(
        (data) {
          if (data is List<int>) {
            // Live game screen frame from Host
            onScreenFrameReceived?.call(Uint8List.fromList(data));
          } else {
            final msg = LanMessage.deserialize(data.toString());
            if (msg != null) {
              if (msg.type == LanMessageType.joined) {
                final title = msg.payload['gameTitle'] as String? ?? 'Game';
                onJoined(title);
              } else if (msg.type == LanMessageType.disconnect || msg.payload['status'] == 'host_exited') {
                onClientDisconnected?.call();
              }
            }
          }
        },
        onDone: () {
          _clientSocket = null;
          onClientDisconnected?.call();
        },
        onError: (err) {
          print('Client socket error: $err');
          _clientSocket = null;
          onClientDisconnected?.call();
        },
      );

      return true;
    } catch (e) {
      print('Failed to join clan room: $e');
      lastJoinError = e.toString();
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

  /// Thông báo cho P2 rằng Host đã thoát và ngắt các luồng stream
  Future<void> notifyHostExited() async {
    if (_p2Socket != null && _p2Socket?.readyState == WebSocket.open) {
      try {
        final exitMsg = LanMessage(
          type: LanMessageType.disconnect,
          payload: {
            'player': 1,
            'status': 'host_exited',
            'message': 'Chủ phòng đã thoát game.',
          },
        ).serialize();
        _p2Socket?.add(exitMsg);
        await Future.delayed(const Duration(milliseconds: 80));
        await _p2Socket?.close();
      } catch (_) {}
      _p2Socket = null;
    }

    try {
      await _screenFeedSocket?.close();
    } catch (_) {}
    _screenFeedSocket = null;

    try {
      await _audioSourceSocket?.close();
    } catch (_) {}
    _audioSourceSocket = null;

    for (var client in List<WebSocket>.from(_audioClientSockets)) {
      try { client.close(); } catch (_) {}
    }
    _audioClientSockets.clear();

    for (var client in List<WebSocket>.from(_screenClientSockets)) {
      try { client.close(); } catch (_) {}
    }
    _screenClientSockets.clear();
  }

  /// Shutdown all servers and sockets
  Future<void> stopAll() async {
    await notifyHostExited();

    _beaconTimer?.cancel();
    _beaconTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _subnetScanTimer?.cancel();
    _subnetScanTimer = null;

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

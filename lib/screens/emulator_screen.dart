import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:webview_windows/webview_windows.dart';
import '../models/game_item.dart';
import '../services/clan_netplay_service.dart';
import '../services/app_language.dart';
import '../widgets/arcade_gamepad.dart';
import '../widgets/arcade_settings_dialog.dart';
import '../widgets/cheat_manager_dialog.dart';

class EmulatorScreen extends StatefulWidget {
  final GameItem game;
  final ClanNetplayService clanService;
  final bool isHost;

  const EmulatorScreen({
    super.key,
    required this.game,
    required this.clanService,
    this.isHost = false,
  });

  @override
  State<EmulatorScreen> createState() => _EmulatorScreenState();
}

class _EmulatorScreenState extends State<EmulatorScreen> with WidgetsBindingObserver {
  HttpServer? _localServer;
  int _localPort = 0;
  HttpClient? _proxyHttpClient;

  WebviewController? _winController;
  WebViewController? _mobileController;

  bool _isEngineReady = false;
  bool _p2Connected = false;
  String _hostIp = '127.0.0.1';

  // Điều khiển hiển thị
  bool _isLandscape = false;
  int _speedMultiplier = 1;

  // Cấu hình Nút & Cần gạt
  double _buttonScale = 1.0;
  double _buttonPercent = 75.0;
  String _buttonLayout = 'arcade6';
  String _joystickType = 'analog360';
  String _joystickSensitivity = 'normal';

  // Tọa độ tùy chỉnh lưu cho TỪNG NÚT riêng biệt
  Map<String, Offset>? _customButtonsLand;
  Map<String, Offset>? _customButtonsPort;

  // Chế độ kéo thả chỉnh nút trực quan
  bool _isCustomizingLayout = false;

  // Tính năng nâng cao tương tự Retrofun
  bool _isAutoGrindActive = false;
  Timer? _autoGrindTimer;
  bool _isCrtFilterActive = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) {
      _isLandscape = true;
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _loadGamepadSettings();
    _startLocalServerAndEngine();

  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !Platform.isWindows) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.isHost) {
      widget.clanService.notifyHostExited();
    }
    _localServer?.close(force: true);
    _proxyHttpClient?.close(force: true);
    _autoGrindTimer?.cancel();

    try {
      _winController?.dispose();
    } catch (_) {}
    if (!Platform.isWindows) {
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _startLocalServerAndEngine() async {
    _hostIp = await widget.clanService.getLocalIp();

    final romFileName = widget.game.localRomPath != null
        ? File(widget.game.localRomPath!).uri.pathSegments.last
        : 'rom.zip';

    // 1. Tải trước nội dung assets
    String indexHtml = '';
    ByteData? jsnesData;
    ByteData? neogeoData;
    try {
      indexHtml = await rootBundle.loadString('assets/emulator/index.html');
      jsnesData = await rootBundle.load('assets/emulator/jsnes.min.js');
      neogeoData = await rootBundle.load('assets/emulator/neogeo.zip');
    } catch (e) {
      debugPrint('Lỗi nạp assets emulator: $e');
    }

    // Bổ sung nạp trực tiếp từ thư mục ROM nếu có file cập nhật cục bộ
    if (widget.game.localRomPath != null) {
      try {
        final romParent = File(widget.game.localRomPath!).parent;
        final localIndexFile = File('${romParent.path}/index.html');
        if (await localIndexFile.exists()) {
          final customHtml = await localIndexFile.readAsString();
          if (customHtml.isNotEmpty) {
            indexHtml = customHtml;
          }
        }
        final localBiosFile = File('${romParent.path}/neogeo.zip');
        if (await localBiosFile.exists()) {
          final bytes = await localBiosFile.readAsBytes();
          neogeoData = ByteData.sublistView(bytes);
        }
      } catch (e) {
        debugPrint('Lỗi nạp file cục bộ romParent: $e');
      }
    }

    // 2. Khởi chạy máy chủ HTTP nội bộ 127.0.0.1
    try {
      _proxyHttpClient = HttpClient();
      _localServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _localPort = _localServer!.port;

      _localServer!.listen((HttpRequest req) async {
        final path = req.uri.path;
        debugPrint('--> HTTP [${req.method}] $path');
        req.response.headers.add('Access-Control-Allow-Origin', '*');
        req.response.headers.add('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
        req.response.headers.add('Access-Control-Allow-Headers', '*');
        req.response.headers.add('Access-Control-Expose-Headers', '*');
        req.response.headers.add('Cross-Origin-Resource-Policy', 'cross-origin');

        if (req.method == 'OPTIONS') {
          req.response.statusCode = HttpStatus.ok;
          await req.response.close();
          return;
        }

        if (path == '/' || path == '/index.html') {
          req.response.headers.contentType = ContentType.html;
          req.response.write(indexHtml);
          await req.response.close();
        } else if (path == '/jsnes.min.js') {
          req.response.headers.add('Content-Type', 'application/javascript');
          if (jsnesData != null) {
            req.response.add(jsnesData.buffer.asUint8List());
          }
          await req.response.close();
        } else if (path == '/neogeo.zip') {
          // Cung cấp file BIOS Neo Geo bắt buộc cho FBNeo
          req.response.headers.contentType = ContentType.binary;
          req.response.headers.add('Accept-Ranges', 'bytes');
          req.response.headers.add('Content-Disposition', 'inline; filename="neogeo.zip"');

          if (neogeoData != null) {
            req.response.headers.contentLength = neogeoData.lengthInBytes;
            if (req.method == 'HEAD') {
              req.response.statusCode = HttpStatus.ok;
              await req.response.close();
              return;
            }
            req.response.add(neogeoData.buffer.asUint8List());
          } else if (widget.game.localRomPath != null) {
            final localBios = File('${File(widget.game.localRomPath!).parent.path}/neogeo.zip');
            if (await localBios.exists()) {
              final len = await localBios.length();
              req.response.headers.contentLength = len;
              if (req.method == 'HEAD') {
                req.response.statusCode = HttpStatus.ok;
                await req.response.close();
                return;
              }
              await req.response.addStream(localBios.openRead());
            }
          }
          await req.response.close();
        } else if (path == '/$romFileName' || path == '/rom.data' || path.endsWith('.zip') || path.endsWith('.nes') || path.endsWith('.bin')) {
          bool served = false;
          if (widget.game.localRomPath != null) {
            final file = File(widget.game.localRomPath!);
            if (await file.exists()) {
              final length = await file.length();
              req.response.headers.contentType = ContentType.binary;
              req.response.headers.contentLength = length;
              req.response.headers.add('Accept-Ranges', 'bytes');
              req.response.headers.add('Content-Disposition', 'inline; filename="$romFileName"');

              if (req.method == 'HEAD') {
                req.response.statusCode = HttpStatus.ok;
                await req.response.close();
                return;
              }

              await req.response.addStream(file.openRead());
              served = true;
            }
          }

          if (!served) {
            // Nạp từ asset neobombe.zip làm cứu cánh dự phòng
            try {
              final fallbackData = await rootBundle.load('assets/emulator/neobombe.zip');
              req.response.headers.contentType = ContentType.binary;
              req.response.headers.contentLength = fallbackData.lengthInBytes;
              req.response.headers.add('Accept-Ranges', 'bytes');
              req.response.headers.add('Content-Disposition', 'inline; filename="neobombe.zip"');
              if (req.method != 'HEAD') {
                req.response.add(fallbackData.buffer.asUint8List());
              }
              served = true;
            } catch (_) {}
          }

          if (!served) {
            req.response.statusCode = HttpStatus.notFound;
          }
          await req.response.close();
        } else if (path.startsWith('/data/')) {
          // Same-Origin Proxy cho EmulatorJS assets trên iOS và Android
          try {
            final subPath = path.substring(6); // Bỏ tiền tố '/data/'
            final remoteUri = Uri.parse('https://cdn.emulatorjs.org/4.2.3/data/$subPath');
            final remoteReq = await (_proxyHttpClient ?? HttpClient()).getUrl(remoteUri);
            final remoteRes = await remoteReq.close();
            req.response.statusCode = remoteRes.statusCode;
            if (remoteRes.headers.contentType != null) {
              req.response.headers.contentType = remoteRes.headers.contentType;
            }
            if (remoteRes.contentLength > 0) {
              req.response.headers.contentLength = remoteRes.contentLength;
            }
            if (req.method != 'HEAD') {
              await req.response.addStream(remoteRes);
            }
          } catch (e) {
            req.response.statusCode = HttpStatus.notFound;
          }
          await req.response.close();
        } else if (path.startsWith('/cheats/')) {
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'Neo Bomberman': [
              { 'desc': 'Tối đa số lượng bom (Max Bombs)', 'code': '010900C0' },
              { 'desc': 'Tối đa tầm nổ (Max Fire Range)', 'code': '010901C0' },
              { 'desc': 'Bất tử (Invincible)', 'code': '010105C0' }
            ],
            'neobombe': [
              { 'desc': 'Tối đa số lượng bom (Max Bombs)', 'code': '010900C0' },
              { 'desc': 'Tối đa tầm nổ (Max Fire Range)', 'code': '010901C0' },
              { 'desc': 'Bất tử (Invincible)', 'code': '010105C0' }
            ],
            'Metal Slug 5': [
              { 'desc': 'Bất tử mạng (Infinite Lives)', 'code': '010900C0' },
              { 'desc': 'Vô hạn đạn súng (Infinite Ammo)', 'code': '010901C0' }
            ],
            'mslug5': [
              { 'desc': 'Bất tử mạng (Infinite Lives)', 'code': '010900C0' },
              { 'desc': 'Vô hạn đạn súng (Infinite Ammo)', 'code': '010901C0' }
            ]
          }));
          await req.response.close();
        } else {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
      });
    } catch (e) {
      debugPrint('Lỗi khởi động máy chủ local: $e');
    }

    final targetUrl = 'http://127.0.0.1:$_localPort/index.html?core=${widget.game.console}&title=${Uri.encodeComponent(widget.game.title)}&file=${Uri.encodeComponent(romFileName)}';

    // 3. Khởi tạo WebView
    if (Platform.isWindows) {
      _winController = WebviewController();
      try {
        await _winController!.initialize();
        await _winController!.setBackgroundColor(Colors.transparent);
        await _winController!.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
        await _winController!.loadUrl(targetUrl);
        if (mounted) {
          setState(() {
            _isEngineReady = true;
          });
          if (widget.isHost && widget.clanService.isP2Connected) {
            for (var delay in [1000, 2500, 4500]) {
              Future.delayed(Duration(milliseconds: delay), () {
                _runJs("window.setP2Status(true);");
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Lỗi khởi tạo Windows Webview: $e');
      }
    } else {
      late final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      _mobileController = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) => NavigationDecision.navigate,
            onWebResourceError: (err) {
              debugPrint('WebView Error: ${err.description} (${err.errorCode})');
            },
            onPageFinished: (_) {
              if (mounted) {
                setState(() {
                  _isEngineReady = true;
                });
                if (widget.isHost && widget.clanService.isP2Connected) {
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    _runJs("window.setP2Status(true);");
                  });
                }
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(targetUrl));

      if (_mobileController?.platform is AndroidWebViewController) {
        final androidCtrl = _mobileController!.platform as AndroidWebViewController;
        androidCtrl.setMediaPlaybackRequiresUserGesture(false);
      }

      if (mounted) {
        setState(() {
          _isEngineReady = true;
        });
      }
    }

    // 4. Lắng nghe người chơi 2 qua LAN
    if (widget.isHost) {
      widget.clanService.onPlayer2InputReceived = (button, isDown) {
        _sendInput(2, button, isDown);
      };

      widget.clanService.onP2ConnectionChanged = (connected) {
        if (mounted) {
          setState(() {
            _p2Connected = connected;
          });
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: connected ? const Color(0xFF00C853) : Colors.orangeAccent,
              duration: const Duration(seconds: 3),
              content: Row(
                children: [
                  Icon(connected ? Icons.sports_esports : Icons.link_off, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    connected
                        ? '🎮 Người chơi 2 (Clan LAN) đã kết nối thành công!'
                        : '⚠️ Người chơi 2 đã ngắt kết nối.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }
        _runJs("window.setP2Status($connected);");
        if (connected) {
          for (var delay in [800, 2000, 3500]) {
            Future.delayed(Duration(milliseconds: delay), () {
              if (mounted && _p2Connected) {
                _runJs("window.setP2Status(true);");
              }
            });
          }
        }
      };

      if (widget.clanService.isP2Connected) {
        _p2Connected = true;
        for (var delay in [800, 2000, 3500, 5000]) {
          Future.delayed(Duration(milliseconds: delay), () {
            if (mounted && _p2Connected) {
              _runJs("window.setP2Status(true);");
            }
          });
        }
      }
    }
  }

  void _sendInput(int player, String button, bool isDown) {
    _runJs("window.playerInput($player, '$button', $isDown);");
  }

  void _runJs(String jsCode) {
    try {
      if (Platform.isWindows && _winController != null) {
        _winController!.executeScript(jsCode);
      } else if (_mobileController != null) {
        _mobileController!.runJavaScript(jsCode);
      }
    } catch (_) {}
  }

  void _toggleSpeed() {
    setState(() {
      _speedMultiplier = _speedMultiplier == 1 ? 2 : (_speedMultiplier == 2 ? 4 : (_speedMultiplier == 4 ? 8 : 1));
    });
    _runJs("window.setSpeed($_speedMultiplier);");
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131C31),
        duration: const Duration(milliseconds: 900),
        content: Row(
          children: [
            const Icon(Icons.speed, color: Color(0xFF00E5FF), size: 18),
            const SizedBox(width: 8),
            Text(
              'Tốc độ: ${_speedMultiplier}x ${_speedMultiplier == 1 ? "(Bình thường)" : (_speedMultiplier == 2 ? "(Tua x2)" : (_speedMultiplier == 4 ? "(Tua x4)" : "(Tua x8)"))}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCrtFilter() async {
    setState(() {
      _isCrtFilterActive = !_isCrtFilterActive;
    });
    _runJs("window.toggleCrtFilter($_isCrtFilterActive);");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('arcade_crt_filter', _isCrtFilterActive);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131C31),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        content: Text(_isCrtFilterActive ? '📺 Đã BẬT Bộ lọc tivi CRT Scanlines cổ điển' : '📺 Đã TẮT Bộ lọc CRT'),
      ),
    );
  }

  void _toggleAutoGrind() {
    setState(() {
      _isAutoGrindActive = !_isAutoGrindActive;
    });
    _autoGrindTimer?.cancel();
    if (_isAutoGrindActive) {
      bool st = false;
      _autoGrindTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
        st = !st;
        _sendInput(1, 'A', st);
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF131C31),
          duration: const Duration(milliseconds: 1600),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF00FF88)),
          ),
          content: const Row(
            children: [
              Icon(Icons.smart_toy, color: Color(0xFF00FF88), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('🤖 Auto-Grind: Đang tự động nhấp phím A (Cày cấp & thoại)!'),
              ),
            ],
          ),
        ),
      );
    } else {
      _sendInput(1, 'A', false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF131C31),
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          content: Text('🛑 Đã TẮT Auto-Grind'),
        ),
      );
    }
  }

  void _triggerRewind() {
    _runJs("""
      if (typeof window.rewindGame === 'function') {
        window.rewindGame();
      } else if (window.EJS_emulator && typeof window.EJS_emulator.loadState === 'function') {
        window.EJS_emulator.loadState(9);
      }
    """);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131C31),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF00E5FF)),
        ),
        content: const Row(
          children: [
            Icon(Icons.fast_rewind, color: Color(0xFF00E5FF), size: 20),
            SizedBox(width: 8),
            Text('⏪ Đã tua ngược thời gian 10 giây (Rewind)!'),
          ],
        ),
      ),
    );
  }

  void _openCheatDialog() {
    showDialog(
      context: context,
      builder: (_) => CheatManagerDialog(
        gameTitle: widget.game.title,
        console: widget.game.console,
        onApplyCheat: (code, enabled) {
          _runJs("if(typeof window.applyCheatCode === 'function') window.applyCheatCode('$code', $enabled);");
        },
      ),
    );
  }

  void _toggleRotation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (!Platform.isWindows) {
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        if (_isLandscape) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        }
      } catch (_) {}
    }
  }

  void _toggleJoystickType() {
    setState(() {
      if (_joystickType == 'analog360') {
        _joystickType = 'dpadSquare4';
      } else if (_joystickType == 'dpadSquare4') {
        _joystickType = 'dpad4';
      } else {
        _joystickType = 'analog360';
      }
    });
    _saveGamepadSettings();
    if (!Platform.isWindows) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }

    String modeName = 'Phím Ô Vuông 4 hướng (Lên - Xuống - Trái - Phải)';
    if (_joystickType == 'analog360') {
      modeName = 'Cần gạt xoay tròn 360°';
    } else if (_joystickType == 'dpad4') {
      modeName = 'Cụm phím chữ thập D-Pad';
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131C31),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 70, left: 20, right: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
        ),
        content: Row(
          children: [
            const Icon(Icons.swap_horiz, color: Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã đổi: $modeName',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadGamepadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final layoutVer = prefs.getInt('arcade_layout_version') ?? 1;
      if (layoutVer < 3) {
        // Tự động dọn dẹp các vị trí cũ bị đè/lập nút
        await prefs.remove('arcade_btn_positions_land');
        await prefs.remove('arcade_btn_positions_port');
        await prefs.setInt('arcade_layout_version', 3);
        _customButtonsLand = null;
        _customButtonsPort = null;
      }

      setState(() {
        _buttonScale = prefs.getDouble('arcade_btn_scale') ?? 1.0;
        _buttonPercent = prefs.getDouble('arcade_btn_percent') ?? ((_buttonScale - 0.4) / 0.8 * 100.0).clamp(1.0, 100.0);
        _buttonLayout = prefs.getString('arcade_btn_layout') ?? 'arcade6';
        _joystickType = prefs.getString('arcade_joy_type') ?? 'dpadSquare4';
        _joystickSensitivity = prefs.getString('arcade_joy_sens') ?? 'normal';
        _isCrtFilterActive = prefs.getBool('arcade_crt_filter') ?? false;
        if (_isCrtFilterActive) {
          _runJs("window.toggleCrtFilter(true);");
        }

        if (layoutVer >= 3) {
          final landJson = prefs.getString('arcade_btn_positions_land');
          if (landJson != null) {
            try {
              final map = jsonDecode(landJson) as Map<String, dynamic>;
              _customButtonsLand = map.map(
                (k, v) => MapEntry(k, Offset((v[0] as num).toDouble(), (v[1] as num).toDouble())),
              );
            } catch (_) {}
          }

          final portJson = prefs.getString('arcade_btn_positions_port');
          if (portJson != null) {
            try {
              final map = jsonDecode(portJson) as Map<String, dynamic>;
              _customButtonsPort = map.map(
                (k, v) => MapEntry(k, Offset((v[0] as num).toDouble(), (v[1] as num).toDouble())),
              );
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading gamepad settings: $e');
    }
  }

  Future<void> _saveGamepadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('arcade_btn_scale', _buttonScale);
      await prefs.setDouble('arcade_btn_percent', _buttonPercent);
      await prefs.setString('arcade_btn_layout', _buttonLayout);
      await prefs.setString('arcade_joy_type', _joystickType);
      await prefs.setString('arcade_joy_sens', _joystickSensitivity);

      if (_customButtonsLand != null) {
        final map = _customButtonsLand!.map((k, v) => MapEntry(k, [v.dx, v.dy]));
        await prefs.setString('arcade_btn_positions_land', jsonEncode(map));
      }
      if (_customButtonsPort != null) {
        final map = _customButtonsPort!.map((k, v) => MapEntry(k, [v.dx, v.dy]));
        await prefs.setString('arcade_btn_positions_port', jsonEncode(map));
      }
    } catch (e) {
      debugPrint('Error saving gamepad settings: $e');
    }
  }

  Future<void> _resetLayoutPositions() async {
    setState(() {
      _customButtonsLand = null;
      _customButtonsPort = null;
      _buttonScale = 1.0;
      _buttonPercent = 75.0;
      _buttonLayout = 'arcade6';
      _joystickType = 'analog360';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('arcade_btn_positions_land');
      await prefs.remove('arcade_btn_positions_port');
      await prefs.remove('arcade_joy_x_land');
      await prefs.remove('arcade_joy_y_land');
      await prefs.remove('arcade_btn_x_land');
      await prefs.remove('arcade_btn_y_land');
      await prefs.remove('arcade_sys_x_land');
      await prefs.remove('arcade_sys_y_land');
      await prefs.setDouble('arcade_btn_scale', 1.0);
      await prefs.setString('arcade_btn_layout', 'arcade6');
      await prefs.setString('arcade_joy_type', 'analog360');
    } catch (_) {}
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => ArcadeSettingsDialog(
        currentButtonScale: _buttonScale,
        currentButtonLayout: _buttonLayout,
        currentJoystickType: _joystickType,
        currentJoystickSensitivity: _joystickSensitivity,
        onLayoutChanged: (scale, layout) {
          setState(() {
            _buttonScale = scale;
            _buttonPercent = ((scale - 0.4) / 0.8 * 100.0).clamp(1.0, 100.0);
            _buttonLayout = layout;
          });
          _saveGamepadSettings();
        },
        onJoystickChanged: (type, sens) {
          setState(() {
            _joystickType = type;
            _joystickSensitivity = sens;
          });
          _saveGamepadSettings();
        },
        onStartCustomizingLayout: () {
          setState(() => _isCustomizingLayout = true);
        },
        onExit: () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
        onReset: () => _runJs("window.resetGame();"),
        onSave: () {
          _runJs("if(typeof window.saveGameState === 'function') { window.saveGameState(); } else if(window.EJS_emulator) { window.EJS_emulator.saveState(1); }");
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF00C853),
              duration: const Duration(seconds: 2),
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(AppLanguage.tr('game_saved'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
        onLoad: () {
          _runJs("if(typeof window.loadGameState === 'function') { window.loadGameState(); } else if(window.EJS_emulator) { window.EJS_emulator.loadState(1); }");
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF29A3FF),
              duration: const Duration(seconds: 2),
              content: Row(
                children: [
                  const Icon(Icons.history, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(AppLanguage.tr('game_reloaded'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
        onRotate: _toggleRotation,
        onOpenLan: _showClanRoomDialog,
        onVolumeChanged: (vol) => _runJs("if(window.EJS_emulator) window.EJS_emulator.setVolume($vol);"),
        isCrtFilterActive: _isCrtFilterActive,
        onToggleCrtFilter: (val) => _toggleCrtFilter(),
        isAutoGrindActive: _isAutoGrindActive,
        onToggleAutoGrind: (val) => _toggleAutoGrind(),
        onRewind: _triggerRewind,
        onOpenCheat: _openCheatDialog,
      ),
    );
  }

  void _showClanRoomDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131C31),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_tethering, color: Colors.greenAccent, size: 28),
                const SizedBox(width: 12),
                Text(
                  widget.isHost ? 'Phòng Clan LAN (Chủ phòng)' : 'Trạng thái Clan',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('IP Mạng Wi-Fi:', style: TextStyle(color: Colors.white70)),
                      Text(_hostIp, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cổng kết nối LAN:', style: TextStyle(color: Colors.white70)),
                      Text('8989', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Người chơi 2 (LAN):', style: TextStyle(color: Colors.white70)),
                      Row(
                        children: [
                          Icon(
                            _p2Connected ? Icons.check_circle : Icons.hourglass_empty,
                            color: _p2Connected ? Colors.greenAccent : Colors.orangeAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _p2Connected ? 'Đã kết nối' : 'Đang đợi bạn vào...',
                            style: TextStyle(
                              color: _p2Connected ? Colors.greenAccent : Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Người chơi cùng mạng Wi-Fi chỉ cần mở ứng dụng và chọn "VÀO PHÒNG" để tham gia làm Player 2!',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tiếp tục chơi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (widget.isHost) {
          widget.clanService.notifyHostExited();
        }
      },
      child: _isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
    );
  }

  /// Giao diện Dọc (Portrait)
  Widget _buildPortraitLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131826),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Quay lại',
          onPressed: () {
            if (widget.isHost) {
              widget.clanService.notifyHostExited();
            }
            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.game.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _p2Connected ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _p2Connected ? 'Clan P2: Trực tuyến' : (widget.isHost ? 'Clan: Đang mở trên Wi-Fi' : 'Chơi đơn'),
                  style: TextStyle(fontSize: 11, color: _p2Connected ? Colors.greenAccent : Colors.white60),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: Color(0xFFFFD700)),
            tooltip: 'Mã Cheat (Cheat Engine)',
            onPressed: _openCheatDialog,
          ),
          IconButton(
            icon: const Icon(Icons.screen_rotation, color: Colors.white70),
            tooltip: 'Xoay màn hình (Ngang)',
            onPressed: _toggleRotation,
          ),
          IconButton(
            icon: Icon(
              Icons.wifi_tethering,
              color: _p2Connected ? const Color(0xFF00E676) : Colors.white70,
            ),
            tooltip: 'Phòng LAN',
            onPressed: _showClanRoomDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Tùy chọn mở rộng',
            color: const Color(0xFF131C31),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              switch (value) {
                case 'rewind':
                  _triggerRewind();
                  break;
                case 'crt':
                  _toggleCrtFilter();
                  break;
                case 'grind':
                  _toggleAutoGrind();
                  break;
                case 'rotate':
                  _toggleRotation();
                  break;
                case 'reload':
                  _runJs("window.location.reload();");
                  break;
                case 'settings':
                  _openSettingsDialog();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'rewind',
                child: const Row(
                  children: [
                    Icon(Icons.fast_rewind, color: Color(0xFF00E5FF), size: 20),
                    SizedBox(width: 10),
                    Text('Tua ngược 10 giây (Rewind)', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'crt',
                child: Row(
                  children: [
                    Icon(Icons.tv, color: _isCrtFilterActive ? const Color(0xFF00FF88) : Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _isCrtFilterActive ? 'Bộ lọc CRT (Đang bật)' : 'Bộ lọc CRT (Đang tắt)',
                      style: TextStyle(color: _isCrtFilterActive ? const Color(0xFF00FF88) : Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'grind',
                child: Row(
                  children: [
                    Icon(Icons.smart_toy, color: _isAutoGrindActive ? const Color(0xFF00FF88) : Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _isAutoGrindActive ? 'Auto-Grind (Đang cày)' : 'Auto-Grind (Tự động cày)',
                      style: TextStyle(color: _isAutoGrindActive ? const Color(0xFF00FF88) : Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rotate',
                child: const Row(
                  children: [
                    Icon(Icons.screen_rotation, color: Colors.white70, size: 20),
                    SizedBox(width: 10),
                    Text('Xoay ngang / dọc', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reload',
                child: const Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.white70, size: 20),
                    SizedBox(width: 10),
                    Text('Tải lại game', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'settings',
                child: const Row(
                  children: [
                    Icon(Icons.tune, color: Color(0xFF00E5FF), size: 20),
                    SizedBox(width: 10),
                    Text('Cài đặt nút & Cần gạt', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Màn hình game chuẩn tỉ lệ 4:3 với khung vàng Arcade sang trọng
              Expanded(
                flex: 5,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.15), blurRadius: 10),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _buildWebViewWidget(),
                      ),
                    ),
                  ),
                ),
              ),

              // Cụm tay cầm Arcade
              Expanded(
                flex: 5,
                child: ArcadeGamepad(
                  isLandscape: false,
                  buttonScale: _buttonScale,
                  buttonLayout: _buttonLayout,
                  joystickType: _joystickType,
                  joystickSensitivity: _joystickSensitivity,
                  isEditMode: _isCustomizingLayout,
                  customOffsets: _customButtonsPort,
                  onButtonOffsetsChanged: (offsets) {
                    setState(() {
                      _customButtonsPort = offsets;
                    });
                    _saveGamepadSettings();
                  },
                  onButtonEvent: (btn, isDown) => _sendInput(1, btn, isDown),
                  onOpenMenu: _openSettingsDialog,
                  onToggleSpeed: _toggleSpeed,
                  speedMultiplier: _speedMultiplier,
                  onToggleJoystickType: _toggleJoystickType,
                ),
              ),
            ],
          ),

          // Thanh công cụ căn chỉnh vị trí nút trực quan
          if (_isCustomizingLayout) _buildCustomizerToolbar(),
        ],
      ),
    );
  }

  /// Giao diện Ngang (Landscape) chuẩn Handheld: Game ở giữa, Phím điều hướng bên TRÁI, 6 Nút Arcade bên PHẢI
  Widget _buildLandscapeLayout() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Màn hình game căn giữa chuẩn 4:3 viền vàng
          Center(
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: _buildWebViewWidget(),
                ),
              ),
            ),
          ),

          // 2. Cụm điều khiển Arcade phủ toàn màn hình
          Positioned.fill(
            child: ArcadeGamepad(
              isLandscape: true,
              buttonScale: _buttonScale,
              buttonLayout: _buttonLayout,
              joystickType: _joystickType,
              joystickSensitivity: _joystickSensitivity,
              isEditMode: _isCustomizingLayout,
              customOffsets: _customButtonsLand,
              onButtonOffsetsChanged: (offsets) {
                setState(() {
                  _customButtonsLand = offsets;
                });
                _saveGamepadSettings();
              },
              onButtonEvent: (btn, isDown) => _sendInput(1, btn, isDown),
              onOpenMenu: _openSettingsDialog,
              onToggleSpeed: _toggleSpeed,
              speedMultiplier: _speedMultiplier,
              onToggleJoystickType: _toggleJoystickType,
              onToggleRotation: _toggleRotation,
              onExit: () {
                if (widget.isHost) {
                  widget.clanService.notifyHostExited();
                }
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
          ),

          // 3. Thanh công cụ căn chỉnh vị trí nút trực quan
          if (_isCustomizingLayout) _buildCustomizerToolbar(),
        ],
      ),
    );
  }

  /// Thanh công cụ điều khiển chỉnh nút trực quan khi ở chế độ Edit
  Widget _buildCustomizerToolbar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF16120E).withValues(alpha: 0.95),
          border: const Border(bottom: BorderSide(color: Color(0xFFD4AF37), width: 2.5)),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFFD4AF37), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'CHỈNH NÚT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 14),

                // Thanh trượt kéo phần trăm cỡ nút từ 1 đến 100
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF261D15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.straighten, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'CỠ NÚT: %',
                        style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                      SizedBox(
                        width: 120,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            activeTrackColor: const Color(0xFFD4AF37),
                            inactiveTrackColor: Colors.black54,
                            thumbColor: const Color(0xFFFFD700),
                          ),
                          child: Slider(
                            value: _buttonPercent.clamp(1.0, 100.0),
                            min: 1.0,
                            max: 100.0,
                            divisions: 99,
                            onChanged: (val) {
                              setState(() {
                                _buttonPercent = val;
                                _buttonScale = 0.4 + (val / 100.0) * 0.8;
                              });
                            },
                            onChangeEnd: (_) => _saveGamepadSettings(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Huy hiệu thông báo lưới ô vuông căn chỉnh
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00E5FF), width: 1.0),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grid_on, color: Color(0xFF00E5FF), size: 13),
                      SizedBox(width: 4),
                      Text(
                        'LƯỚI CĂN CHỈNH: BẬT',
                        style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Chọn kiểu bố trí nút
                const Text('Kiểu: ', style: TextStyle(color: Colors.white60, fontSize: 11)),
                _buildEditChip('6 Nút', _buttonLayout == 'arcade6', () {
                  setState(() => _buttonLayout = 'arcade6');
                  _saveGamepadSettings();
                }),
                const SizedBox(width: 4),
                _buildEditChip('4 Hàng', _buttonLayout == 'arcade4Row', () {
                  setState(() => _buttonLayout = 'arcade4Row');
                  _saveGamepadSettings();
                }),
                const SizedBox(width: 4),
                _buildEditChip('Cung', _buttonLayout == 'arcade4Arc', () {
                  setState(() => _buttonLayout = 'arcade4Arc');
                  _saveGamepadSettings();
                }),
                const SizedBox(width: 12),

                // Chọn loại cần gạt
                const Text('Gạt: ', style: TextStyle(color: Colors.white60, fontSize: 11)),
                _buildEditChip('360°', _joystickType == 'analog360', () {
                  setState(() => _joystickType = 'analog360');
                  _saveGamepadSettings();
                }),
                const SizedBox(width: 4),
                _buildEditChip('D-Pad', _joystickType == 'dpad4', () {
                  setState(() => _joystickType = 'dpad4');
                  _saveGamepadSettings();
                }),
                const SizedBox(width: 16),

                // Đặt lại mặc định
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 14, color: Colors.orangeAccent),
                  label: const Text('Mặc định', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orangeAccent, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: _resetLayoutPositions,
                ),
                const SizedBox(width: 8),

                // Nút Xong & Lưu (Không popup toast)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16, color: Colors.black),
                  label: const Text('XONG & LƯU', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () {
                    setState(() => _isCustomizingLayout = false);
                    _saveGamepadSettings();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF2C2219),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF553F2F),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildWebViewWidget() {
    if (!_isEngineReady) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFD4AF37)),
            SizedBox(height: 12),
            Text('Đang khởi tạo màn hình Arcade...', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
    }
    if (Platform.isWindows && _winController != null && _winController!.value.isInitialized) {
      return Webview(_winController!);
    } else if (!Platform.isWindows && _mobileController != null) {
      return WebViewWidget(controller: _mobileController!);
    }
    return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
  }
}

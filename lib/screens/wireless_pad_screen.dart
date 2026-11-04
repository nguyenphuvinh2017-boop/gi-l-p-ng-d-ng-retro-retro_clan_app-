import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_windows/webview_windows.dart';
import '../services/clan_netplay_service.dart';
import '../services/app_language.dart';
import '../widgets/arcade_gamepad.dart';

class WirelessPadScreen extends StatefulWidget {
  final ClanNetplayService clanService;
  final String gameTitle;
  final String hostIp;

  const WirelessPadScreen({
    super.key,
    required this.clanService,
    required this.gameTitle,
    required this.hostIp,
  });

  @override
  State<WirelessPadScreen> createState() => _WirelessPadScreenState();
}

class _WirelessPadScreenState extends State<WirelessPadScreen> {
  // Cấu hình phím bấm
  double _buttonScale = 1.0;
  double _buttonPercent = 75.0;
  String _buttonLayout = 'arcadeSquare2x2';
  String _joystickType = 'dpadSquare4'; // 'dpadSquare4' (ô vuông) hoặc 'analog360'
  String _joystickSensitivity = 'normal';
  bool _isEditMode = false;
  WebviewController? _winController;
  WebViewController? _mobileController;
  bool _isWinReady = false;
  final ValueNotifier<Uint8List?> _currentFrameNotifier = ValueNotifier<Uint8List?>(null);

  Map<String, Offset>? _customButtonsLand;
  Map<String, Offset>? _customButtonsPort;

  @override
  void initState() {
    super.initState();
    _loadGamepadSettings();

    // 1. Nhận luồng khung hình trực tiếp từ Host qua WebSocket
    widget.clanService.onScreenFrameReceived = (frame) {
      _currentFrameNotifier.value = frame;
    };

    // 2. Khởi tạo Web Audio & Canvas WebView theo nền tảng
    final p2Url = 'http://${widget.hostIp}:${ClanNetplayService.defaultWsPort}/p2_screen?host=${widget.hostIp}';
    if (Platform.isWindows) {
      _initWindowsWebview(p2Url);
    } else {
      _initMobileWebview(p2Url);
    }

    widget.clanService.onClientDisconnected = () {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFFF2A55),
            duration: Duration(seconds: 3),
            content: Row(
              children: [
                Icon(Icons.exit_to_app, color: Colors.white),
                SizedBox(width: 8),
                Text('Chủ phòng đã thoát game. Đang quay lại sảnh Clan...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    };
  }

  Future<void> _initWindowsWebview(String url) async {
    try {
      _winController = WebviewController();
      await _winController!.initialize();
      await _winController!.setBackgroundColor(Colors.black);
      await _winController!.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _winController!.loadUrl(url);
      if (mounted) {
        setState(() {
          _isWinReady = true;
        });
      }
    } catch (e) {
      debugPrint('Lỗi khởi tạo Windows Webview cho P2: $e');
    }
  }

  void _initMobileWebview(String url) {
    try {
      _mobileController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black);

      if (_mobileController!.platform is AndroidWebViewController) {
        (_mobileController!.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }

      _mobileController!.loadRequest(Uri.parse(url));
    } catch (e) {
      debugPrint('Lỗi khởi tạo Mobile Webview cho P2: $e');
    }
  }

  @override
  void dispose() {
    widget.clanService.onScreenFrameReceived = null;
    widget.clanService.onClientDisconnected = null;
    try {
      _winController?.dispose();
    } catch (_) {}
    _currentFrameNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadGamepadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _buttonScale = prefs.getDouble('arcade_btn_scale') ?? 1.0;
        _buttonPercent = prefs.getDouble('arcade_btn_percent') ?? ((_buttonScale - 0.4) / 0.8 * 100.0).clamp(1.0, 100.0);
        _buttonLayout = prefs.getString('arcade_btn_layout') ?? 'arcadeSquare2x2';
        _joystickType = prefs.getString('arcade_joy_type') ?? 'dpadSquare4';
        _joystickSensitivity = prefs.getString('arcade_joy_sens') ?? 'normal';

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
      });
    } catch (_) {}
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
        final landJson = jsonEncode(_customButtonsLand!.map((k, v) => MapEntry(k, [v.dx, v.dy])));
        await prefs.setString('arcade_btn_positions_land', landJson);
      }
      if (_customButtonsPort != null) {
        final portJson = jsonEncode(_customButtonsPort!.map((k, v) => MapEntry(k, [v.dx, v.dy])));
        await prefs.setString('arcade_btn_positions_port', portJson);
      }
    } catch (_) {}
  }

  void _unlockAudioOnGesture() {
    try {
      if (Platform.isWindows && _winController != null && _isWinReady) {
        _winController!.executeScript('window.unlockAudio && window.unlockAudio();');
      } else if (_mobileController != null) {
        _mobileController!.runJavaScript('window.unlockAudio && window.unlockAudio();');
      }
    } catch (_) {}
  }

  KeyEventResult _handleHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final isDown = event is KeyDownEvent;
    final key = event.logicalKey;

    String? btn;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      btn = 'UP';
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      btn = 'DOWN';
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      btn = 'LEFT';
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      btn = 'RIGHT';
    } else if (key == LogicalKeyboardKey.keyZ || key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.space) {
      btn = 'A';
    } else if (key == LogicalKeyboardKey.keyX || key == LogicalKeyboardKey.keyK) {
      btn = 'B';
    } else if (key == LogicalKeyboardKey.keyC || key == LogicalKeyboardKey.keyU) {
      btn = 'C';
    } else if (key == LogicalKeyboardKey.keyV || key == LogicalKeyboardKey.keyI) {
      btn = 'D';
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.digit2) {
      btn = 'START';
    } else if (key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight || key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.digit6) {
      btn = 'SELECT';
    }

    if (btn != null) {
      _handleButtonEvent(btn, isDown);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleButtonEvent(String button, bool isDown) {
    _unlockAudioOnGesture();
    widget.clanService.sendClientInput(button, isDown);
  }

  Widget _buildLiveGameScreen({required double? height, required bool isLandscape}) {
    return Container(
      height: height,
      margin: EdgeInsets.symmetric(
        horizontal: isLandscape ? 0 : 14,
        vertical: isLandscape ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(isLandscape ? 6 : 12),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildScreenContent(),
    );
  }

  Widget _buildScreenContent() {
    if (Platform.isWindows) {
      if (_winController != null && _isWinReady && _winController!.value.isInitialized) {
        return Webview(_winController!);
      }
    } else {
      if (_mobileController != null) {
        return WebViewWidget(controller: _mobileController!);
      }
    }

    // Hiển thị trực tiếp luồng hình ảnh thời gian thực mượt mà từ Host qua WebSocket!
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: _currentFrameNotifier,
      builder: (context, frame, _) {
        if (frame != null && frame.isNotEmpty) {
          return Image.memory(
            frame,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        );
      },
    );
  }

  void _toggleJoystickType() {
    setState(() {
      _joystickType = _joystickType == 'dpadSquare4' ? 'analog360' : 'dpadSquare4';
    });
    _saveGamepadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape || size.width > size.height;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleHardwareKey,
      child: Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: isLandscape
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF131C31),
              elevation: 2,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppLanguage.isEnglish ? "Player 2" : "Người chơi 2"} - ${widget.gameTitle}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.wifi, color: Color(0xFF00E676), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Đã kết nối tới chủ phòng ${widget.hostIp}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF00E676), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(_isEditMode ? Icons.check : Icons.tune, color: _isEditMode ? const Color(0xFF00E5FF) : Colors.white70),
                  tooltip: _isEditMode ? 'Lưu căn chỉnh' : 'Tùy chỉnh nút',
                  onPressed: () {
                    setState(() => _isEditMode = !_isEditMode);
                    if (!_isEditMode) _saveGamepadSettings();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Rời phòng Clan',
                  onPressed: () {
                    widget.clanService.stopAll();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
      body: SafeArea(
        child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
      ),
    ),
    );
  }

  /// Giao diện Dọc (Portrait)
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Bảng trạng thái Clan & Phím bấm tắt nạp xu nhanh
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF131C31),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'TAY CẦM CLAN LAN (P2)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Color(0xFF00E676), size: 14),
                        SizedBox(width: 4),
                        Text('Độ trễ < 2ms', style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Nút chuyển chế độ cần gạt và chỉnh nút
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _toggleJoystickType,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _joystickType == 'dpadSquare4' ? Icons.grid_view : Icons.track_changes,
                              color: const Color(0xFF00E5FF),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _joystickType == 'dpadSquare4' ? 'Cần gạt: Ô vuông' : 'Cần gạt: 360°',
                              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() => _isEditMode = !_isEditMode);
                      if (!_isEditMode) _saveGamepadSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isEditMode ? const Color(0xFF00E5FF).withValues(alpha: 0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _isEditMode ? const Color(0xFF00E5FF) : Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isEditMode ? Icons.check : Icons.tune,
                            color: _isEditMode ? const Color(0xFF00E5FF) : Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isEditMode ? 'Xong' : 'Chỉnh nút',
                            style: TextStyle(
                              color: _isEditMode ? const Color(0xFF00E5FF) : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Màn hình game phát trực tiếp từ máy chủ (tách luồng mượt mà, không giật lag)
        _buildLiveGameScreen(height: 215, isLandscape: false),

        // Thanh trượt căn chỉnh kích thước nút khi bật chỉnh vị trí
        if (_isEditMode) _buildEditModeBar(),

        // Bàn phím Arcade Player 2 bọc trong Expanded để đảm bảo kích thước chiều cao luôn được xác định chính xác
        Expanded(
          child: ArcadeGamepad(
            isLandscape: false,
            buttonScale: _buttonScale,
            buttonLayout: _buttonLayout,
            joystickType: _joystickType,
            joystickSensitivity: _joystickSensitivity,
            onToggleJoystickType: _toggleJoystickType,
            isEditMode: _isEditMode,
            customOffsets: _customButtonsPort,
            onButtonOffsetsChanged: (newMap) {
              setState(() => _customButtonsPort = newMap);
              _saveGamepadSettings();
            },
            onButtonEvent: _handleButtonEvent,
            onOpenMenu: () {},
            onToggleSpeed: () {},
          ),
        ),
      ],
    );
  }

  /// Giao diện Ngang (Landscape / Desktop)
  Widget _buildLandscapeLayout() {
    return Stack(
      children: [
        // 0. Màn hình game trực tiếp từ máy chủ ở chính giữa (chuẩn 4:3)
        Center(
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: _buildLiveGameScreen(height: null, isLandscape: true),
          ),
        ),

        // 1. Tay cầm Arcade trải dài toàn bộ khung hình ngang
        Positioned.fill(
          child: ArcadeGamepad(
            isLandscape: true,
            buttonScale: _buttonScale,
            buttonLayout: _buttonLayout,
            joystickType: _joystickType,
            joystickSensitivity: _joystickSensitivity,
            onToggleJoystickType: _toggleJoystickType,
            isEditMode: _isEditMode,
            customOffsets: _customButtonsLand,
            onButtonOffsetsChanged: (newMap) {
              setState(() => _customButtonsLand = newMap);
              _saveGamepadSettings();
            },
            onButtonEvent: _handleButtonEvent,
            onOpenMenu: () {
              setState(() => _isEditMode = !_isEditMode);
              if (!_isEditMode) _saveGamepadSettings();
            },
            onToggleSpeed: () {},
            onExit: () {
              widget.clanService.stopAll();
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
        ),

        // Đã tích hợp trực tiếp vào màn hình game chính phía trên

        // Thanh chỉnh nút chế độ ngang
        if (_isEditMode)
          Positioned(
            bottom: 12,
            left: 20,
            right: 20,
            child: _buildEditModeBar(),
          ),
      ],
    );
  }

  /// Thanh công cụ căn chỉnh vị trí & kích thước nút (1% đến 100%)
  Widget _buildEditModeBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131C31).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_on, color: Color(0xFF00E5FF), size: 16),
              const SizedBox(width: 6),
              Text(
                'KÍCH THƯỚC NÚT: ${_buttonPercent.round()}%',
                style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () {
                  setState(() {
                    _customButtonsLand = null;
                    _customButtonsPort = null;
                    _buttonPercent = 75.0;
                    _buttonScale = 1.0;
                  });
                  _saveGamepadSettings();
                },
                child: const Text('Mặc định', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() => _isEditMode = false);
                  _saveGamepadSettings();
                },
                child: const Text('Xong', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _buttonPercent,
              min: 1.0,
              max: 100.0,
              onChanged: (val) {
                setState(() {
                  _buttonPercent = val;
                  _buttonScale = 0.4 + (val / 100.0) * 0.8;
                });
              },
              onChangeEnd: (_) => _saveGamepadSettings(),
            ),
          ),
        ],
      ),
    );
  }
}

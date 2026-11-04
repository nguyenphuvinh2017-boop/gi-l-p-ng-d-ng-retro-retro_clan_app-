import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/clan_netplay_service.dart';
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

  Map<String, Offset>? _customButtonsLand;
  Map<String, Offset>? _customButtonsPort;

  @override
  void initState() {
    super.initState();
    _loadGamepadSettings();

    widget.clanService.onClientDisconnected = () {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 4),
            content: Row(
              children: [
                Icon(Icons.link_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Chủ phòng đã thoát hoặc ngắt kết nối mạng LAN.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
        Navigator.pop(context);
      }
    };
  }

  @override
  void dispose() {
    widget.clanService.onClientDisconnected = null;
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

  void _handleButtonEvent(String button, bool isDown) {
    widget.clanService.sendClientInput(button, isDown);
  }

  void _quickPulseButton(String button) {
    HapticFeedback.heavyImpact();
    widget.clanService.sendClientInput(button, true);
    Future.delayed(const Duration(milliseconds: 120), () {
      widget.clanService.sendClientInput(button, false);
    });
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

    return Scaffold(
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
                    'Người chơi 2 - ${widget.gameTitle}',
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
              // Nút thao tác nhanh Nạp xu & Bắt đầu Player 2
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A800),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.monetization_on, size: 16),
                      label: const Text('NẠP XU (COIN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      onPressed: () => _quickPulseButton('SELECT'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('VÀO GAME (P2)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      onPressed: () => _quickPulseButton('START'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _toggleJoystickType,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _joystickType == 'dpadSquare4' ? Icons.grid_view : Icons.track_changes,
                            color: const Color(0xFF00E5FF),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _joystickType == 'dpadSquare4' ? 'Ô vuông' : '360°',
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
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
            onOpenMenu: () {},
            onToggleSpeed: () {},
          ),
        ),

        // 2. Thanh điều hướng & trạng thái nổi ở giữa trên cùng (không che nút điều khiển)
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF131C31).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_esports, color: Color(0xFF00E676), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'P2: ${widget.gameTitle}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 14, color: Colors.white24),
                  const SizedBox(width: 10),
                  // Nút Nạp xu nhanh
                  InkWell(
                    onTap: () => _quickPulseButton('SELECT'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A800),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.monetization_on, size: 13, color: Colors.black87),
                          SizedBox(width: 3),
                          Text('Nạp Xu', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Nút Bắt đầu P2
                  InkWell(
                    onTap: () => _quickPulseButton('START'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.play_arrow, size: 13, color: Colors.white),
                          SizedBox(width: 3),
                          Text('START P2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 14, color: Colors.white24),
                  const SizedBox(width: 6),
                  // Bật/tắt chế độ chỉnh nút
                  InkWell(
                    onTap: () {
                      setState(() => _isEditMode = !_isEditMode);
                      if (!_isEditMode) _saveGamepadSettings();
                    },
                    child: Icon(
                      _isEditMode ? Icons.check : Icons.tune,
                      color: _isEditMode ? const Color(0xFF00E5FF) : Colors.white70,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Thoát
                  InkWell(
                    onTap: () {
                      widget.clanService.stopAll();
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),

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

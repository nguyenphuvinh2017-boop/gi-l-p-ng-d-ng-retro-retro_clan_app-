import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsDialog extends StatefulWidget {
  const AppSettingsDialog({super.key});

  @override
  State<AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<AppSettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers & Values
  final TextEditingController _nameController = TextEditingController();
  double _buttonScale = 1.0;
  double _buttonPercent = 75.0;
  String _buttonLayout = 'arcade6';
  String _joystickType = 'analog360';
  String _joystickSensitivity = 'normal';
  bool _hapticEnabled = true;
  String _localIp = '127.0.0.1';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _nameController.text = prefs.getString('clan_player_name') ?? prefs.getString('player_name') ?? 'Player_1';
      _buttonScale = prefs.getDouble('arcade_btn_scale') ?? 1.0;
      _buttonPercent = prefs.getDouble('arcade_btn_percent') ?? ((_buttonScale - 0.4) / 0.8 * 100.0).clamp(1.0, 100.0);
      _buttonLayout = prefs.getString('arcade_btn_layout') ?? 'arcade6';
      _joystickType = prefs.getString('arcade_joy_type') ?? 'analog360';
      _joystickSensitivity = prefs.getString('arcade_joy_sens') ?? 'normal';
      _hapticEnabled = prefs.getBool('arcade_haptic') ?? true;

      // Tìm IP mạng nội bộ
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (var iface in interfaces) {
          for (var addr in iface.addresses) {
            if (!addr.isLoopback && (addr.address.startsWith('192.168.') || addr.address.startsWith('10.') || addr.address.startsWith('172.'))) {
              _localIp = addr.address;
              break;
            }
          }
        }
      } catch (_) {}
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clan_player_name', _nameController.text.trim().isEmpty ? 'Player_1' : _nameController.text.trim());
    await prefs.setString('player_name', _nameController.text.trim().isEmpty ? 'Player_1' : _nameController.text.trim());
    await prefs.setDouble('arcade_btn_scale', _buttonScale);
    await prefs.setDouble('arcade_btn_percent', _buttonPercent);
    await prefs.setString('arcade_btn_layout', _buttonLayout);
    await prefs.setString('arcade_joy_type', _joystickType);
    await prefs.setString('arcade_joy_sens', _joystickSensitivity);
    await prefs.setBool('arcade_haptic', _hapticEnabled);
  }

  Future<void> _resetGamepadPositions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('arcade_btn_positions_land');
    await prefs.remove('arcade_btn_positions_port');
    await prefs.setDouble('arcade_btn_scale', 1.0);
    await prefs.setString('arcade_btn_layout', 'arcade6');
    await prefs.setString('arcade_joy_type', 'analog360');
    await prefs.setInt('arcade_layout_version', 3);

    setState(() {
      _buttonScale = 1.0;
      _buttonLayout = 'arcade6';
      _joystickType = 'analog360';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1B2A4A),
          content: Text('✅ Đã đặt lại vị trí tay cầm về mặc định chuẩn!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1524),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2A3C63), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF29A3FF)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF1B2A4A), width: 1.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF29A3FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.settings, color: Color(0xFF29A3FF), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'CÀI ĐẶT RETROCLAN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                          onPressed: () async {
                            await _saveSettings();
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Tab Bar
                  Container(
                    color: const Color(0xFF090D18),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF29A3FF),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFF29A3FF),
                      unselectedLabelColor: Colors.white60,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: const [
                        Tab(icon: Icon(Icons.sports_esports, size: 18), text: 'TAY CẦM'),
                        Tab(icon: Icon(Icons.wifi, size: 18), text: 'MẠNG LAN'),
                        Tab(icon: Icon(Icons.info_outline, size: 18), text: 'THÔNG TIN'),
                      ],
                    ),
                  ),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGamepadTab(),
                        _buildLanTab(),
                        _buildInfoTab(),
                      ],
                    ),
                  ),

                  // Bottom Save Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFF1B2A4A), width: 1.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ĐÓNG', style: TextStyle(color: Colors.white60)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('LƯU CÀI ĐẶT', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await _saveSettings();
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF1B2A4A),
                                  content: Text('✅ Đã lưu cấu hình cài đặt thành công!'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGamepadTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Kích thước nút kéo thanh phần trăm từ 1 đến 100%
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('KÍCH THƯỚC NÚT BẤM (1% - 100%)'),
            Text(
              '%',
              style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('1%', style: TextStyle(color: Colors.white38, fontSize: 11)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: const Color(0xFF29A3FF),
                  inactiveTrackColor: const Color(0xFF1B2A4A),
                  thumbColor: const Color(0xFF29A3FF),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: _buttonPercent.clamp(1.0, 100.0),
                  min: 1.0,
                  max: 100.0,
                  divisions: 99,
                  label: '%',
                  onChanged: (val) {
                    setState(() {
                      _buttonPercent = val;
                      _buttonScale = 0.4 + (val / 100.0) * 0.8;
                    });
                  },
                ),
              ),
            ),
            const Text('100%', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 18),

        // Kiểu bố trí nút hành động
        _buildSectionHeader('KIỂU BỐ TRÍ NÚT HÀNH ĐỘNG'),
        const SizedBox(height: 6),
        _buildRadioRow(
          title: 'Arcade 6 nút (Chuẩn Neo Geo)',
          subtitle: 'Hàng dưới: A+B, A, B — Hàng trên: C+D, C, D',
          value: 'arcade6',
          groupValue: _buttonLayout,
          onChanged: (v) => setState(() => _buttonLayout = v!),
        ),
        _buildRadioRow(
          title: 'Dạng ô vuông 2x2 (A - B - C - D)',
          subtitle: 'Xếp thành khối ô vuông 4 nút gọn gàng & combo bên cạnh',
          value: 'arcadeSquare2x2',
          groupValue: _buttonLayout,
          onChanged: (v) => setState(() => _buttonLayout = v!),
        ),
        _buildRadioRow(
          title: 'Dạng chữ thập (Lên - Xuống - Trái - Phải)',
          subtitle: 'Cụm 4 nút kiểu kim cương console (Lên C, Xuống B, Trái A, Phải D)',
          value: 'arcadeDiamond',
          groupValue: _buttonLayout,
          onChanged: (v) => setState(() => _buttonLayout = v!),
        ),
        _buildRadioRow(
          title: 'Arcade 4 nút thẳng hàng',
          subtitle: 'A, B, C, D nằm ngang theo hàng chuẩn retro',
          value: 'arcade4Row',
          groupValue: _buttonLayout,
          onChanged: (v) => setState(() => _buttonLayout = v!),
        ),
        _buildRadioRow(
          title: 'Vòng cung cổ điển',
          subtitle: '4 nút xếp theo đường vòng cung ngón tay cái',
          value: 'arcade4Arc',
          groupValue: _buttonLayout,
          onChanged: (v) => setState(() => _buttonLayout = v!),
        ),
        const SizedBox(height: 18),

        // Cần gạt di chuyển / D-Pad
        _buildSectionHeader('ĐIỀU KHIỂN DI CHUYỂN (BÊN TAY TRÁI)'),
        const SizedBox(height: 6),
        _buildRadioRow(
          title: 'Cần gạt xoay tròn 360°',
          subtitle: 'Joystick mượt mà xoay góc tự do chuẩn game thùng',
          value: 'analog360',
          groupValue: _joystickType,
          onChanged: (v) => setState(() => _joystickType = v!),
        ),
        _buildRadioRow(
          title: 'Phím ô vuông 4 hướng riêng biệt (Lên - Xuống - Trái - Phải)',
          subtitle: '4 ô phím vuông độc lập, bấm nhạy và định hướng chuẩn xác 100%',
          value: 'dpadSquare4',
          groupValue: _joystickType,
          onChanged: (v) => setState(() => _joystickType = v!),
        ),
        _buildRadioRow(
          title: 'Cụm phím chữ thập D-Pad cổ điển',
          subtitle: 'D-Pad chữ thập 4 hướng truyền thống',
          value: 'dpad4',
          groupValue: _joystickType,
          onChanged: (v) => setState(() => _joystickType = v!),
        ),
        const SizedBox(height: 18),

        // Rung phản hồi & Reset
        _buildSectionHeader('HIỆU ỨNG & ĐẶT LẠI VỊ TRÍ'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rung phản hồi khi chạm (Haptic Feedback)', style: TextStyle(color: Colors.white, fontSize: 13)),
          value: _hapticEnabled,
          activeThumbColor: const Color(0xFF29A3FF),
          onChanged: (v) => setState(() => _hapticEnabled = v),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFB300),
            side: const BorderSide(color: Color(0xFFFFB300)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.restore, size: 18),
          label: const Text('ĐẶT LẠI VỊ TRÍ PHÍM VỀ MẶC ĐỊNH CHUẨN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          onPressed: _resetGamepadPositions,
        ),
      ],
    );
  }

  Widget _buildLanTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('TÊN NGƯỜI CHƠI TRONG CLAN'),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF131C31),
            hintText: 'Nhập tên của bạn...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.person, color: Color(0xFF29A3FF)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF29A3FF), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionHeader('THÔNG TIN KẾT NỐI MẠNG CỤC BỘ (WIFI / LAN)'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131C31),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E2D4A)),
          ),
          child: Column(
            children: [
              _buildInfoRow('Địa chỉ IP thiết bị:', _localIp),
              const Divider(color: Colors.white12, height: 16),
              _buildInfoRow('Cổng lắng nghe (Port):', '8888'),
              const Divider(color: Colors.white12, height: 16),
              _buildInfoRow('Chơi chung Android & iOS:', 'Hỗ trợ 100% cùng mạng WiFi'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '💡 Mẹo: Khi chơi với bạn bè (Android & iOS), chỉ cần cả hai kết nối chung một WiFi hoặc một người bật Điểm phát sóng di động (Hotspot) cho người kia kết nối vào.',
          style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF29A3FF), Color(0xFF9C27B0), Color(0xFFFF2A55)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text('R', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 10),
              const Text('RetroClan App', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Text('Phiên bản 1.0.0 (Release Cross-Platform)', style: TextStyle(color: Color(0xFF29A3FF), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('HỆ THỐNG GIẢ LẬP HỖ TRỢ'),
        const SizedBox(height: 8),
        const Text('• Neo Geo Arcade / FBNeo (Metal Slug, KOF, Neo Bomberman...)\n• NES / Famicom (Contra, Tank, Mario...)\n• SNES / Super Famicom\n• Game Boy Advance (GBA)\n• Sega Genesis / Mega Drive',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6)),
        const SizedBox(height: 16),
        _buildSectionHeader('TÍNH NĂNG ĐẶC BIỆT'),
        const SizedBox(height: 8),
        const Text('• Mạng LAN Clan P2P siêu tốc độ, không độ trễ.\n• Tương thích hoàn toàn giữa iOS và Android.\n• Gamepad ảo tùy biến vị trí tự do theo ý thích.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF29A3FF),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }



  Widget _buildRadioRow({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E88E5).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF29A3FF) : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF29A3FF) : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Color(0xFF29A3FF), fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}

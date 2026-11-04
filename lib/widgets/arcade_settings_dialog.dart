import 'package:flutter/material.dart';

class ArcadeSettingsDialog extends StatefulWidget {
  final VoidCallback onExit;
  final VoidCallback onReset;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onRotate;
  final VoidCallback onOpenLan;
  final Function(double volume)? onVolumeChanged;

  final double currentButtonScale;
  final String currentButtonLayout;
  final String currentJoystickType;
  final String currentJoystickSensitivity;
  final Function(double scale, String layout)? onLayoutChanged;
  final Function(String type, String sensitivity)? onJoystickChanged;
  final VoidCallback? onStartCustomizingLayout;
  final bool isCrtFilterActive;
  final ValueChanged<bool>? onToggleCrtFilter;
  final bool isAutoGrindActive;
  final ValueChanged<bool>? onToggleAutoGrind;
  final VoidCallback? onRewind;
  final VoidCallback? onOpenCheat;

  const ArcadeSettingsDialog({
    super.key,
    required this.onExit,
    required this.onReset,
    required this.onSave,
    required this.onLoad,
    required this.onRotate,
    required this.onOpenLan,
    this.onVolumeChanged,
    this.currentButtonScale = 1.0,
    this.currentButtonLayout = 'arcade6',
    this.currentJoystickType = 'analog360',
    this.currentJoystickSensitivity = 'normal',
    this.onLayoutChanged,
    this.onJoystickChanged,
    this.onStartCustomizingLayout,
    this.isCrtFilterActive = false,
    this.onToggleCrtFilter,
    this.isAutoGrindActive = false,
    this.onToggleAutoGrind,
    this.onRewind,
    this.onOpenCheat,
  });

  @override
  State<ArcadeSettingsDialog> createState() => _ArcadeSettingsDialogState();
}

class _ArcadeSettingsDialogState extends State<ArcadeSettingsDialog> {
  int _selectedTab = 0; // 0: CHUNG, 1: ARCADE

  double _musicVolume = 1.0;
  double _sfxVolume = 0.5;

  bool _isMuted = false;
  bool _autoSaveOnExit = true;
  bool _autoResume = true;

  // Cấu hình Nút & Cần gạt
  double _buttonPercent = 75.0;
  
  late String _buttonLayout;
  late String _joystickType;
  late String _joystickSensitivity;
  late bool _isCrtFilter;
  late bool _isAutoGrind;

  // Cài đặt Arcade Dip Switches
  String _arcadeDifficulty = 'Level 4 (Chuẩn)';
  String _arcadeLives = '3 Mạng';
  bool _freePlayMode = false;

  // Cheats
  bool _cheatInfiniteLives = false;
  bool _cheatMaxBombs = false;
  bool _cheatMaxSpeed = false;

  @override
  void initState() {
    super.initState();
    _isCrtFilter = widget.isCrtFilterActive;
    _isAutoGrind = widget.isAutoGrindActive;
    _buttonPercent = ((widget.currentButtonScale - 0.4) / 0.8 * 100.0).clamp(1.0, 100.0);


    if (widget.currentButtonLayout == 'arcade4Row') {
      _buttonLayout = 'Arcade 4 nút thẳng hàng';
    } else if (widget.currentButtonLayout == 'arcade4Arc') {
      _buttonLayout = 'Vòng cung cổ điển';
    } else if (widget.currentButtonLayout == 'arcadeSquare2x2') {
      _buttonLayout = 'Dạng ô vuông 2x2 (A-B-C-D)';
    } else if (widget.currentButtonLayout == 'arcadeDiamond') {
      _buttonLayout = 'Dạng chữ thập (Lên - Xuống - Trái - Phải)';
    } else {
      _buttonLayout = 'Arcade 6 nút (Chuẩn Neo Geo)';
    }

    if (widget.currentJoystickType == 'dpadSquare4') {
      _joystickType = 'Phím ô vuông 4 hướng riêng biệt (Lên - Xuống - Trái - Phải)';
    } else if (widget.currentJoystickType == 'dpad4') {
      _joystickType = 'Cụm phím chữ thập D-Pad 4 hướng';
    } else {
      _joystickType = 'Cần gạt xoay tròn 360°';
    }

    if (widget.currentJoystickSensitivity == 'high') {
      _joystickSensitivity = 'Cao (Nhạy nhất)';
    } else if (widget.currentJoystickSensitivity == 'low') {
      _joystickSensitivity = 'Thấp';
    } else {
      _joystickSensitivity = 'Chuẩn (Khuyên dùng)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: const Color(0xFF553F2F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7A774), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    const Text(
                      'CÀI ĐẶT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 2))],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B3A2B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE57373), width: 1.5),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs: [ CHUNG ] | [ ARCADE ]
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabBtn('CHUNG', _selectedTab == 0, () => setState(() => _selectedTab = 0)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTabBtn('ARCADE', _selectedTab == 1, () => setState(() => _selectedTab = 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_selectedTab == 0) _buildGeneralTab() else _buildArcadeTab(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Grid các nút chức năng chính
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildActionSquare('THOÁT', Icons.logout, () {
                Navigator.pop(context);
                widget.onExit();
              }),
              _buildActionSquare('LƯU', Icons.save, () {
                Navigator.pop(context);
                widget.onSave();
              }),
              _buildActionSquare('NẠP BẢN LƯU', Icons.folder_open, () {
                Navigator.pop(context);
                widget.onLoad();
              }),
              _buildActionSquare('CHƠI LẠI', Icons.refresh, () {
                Navigator.pop(context);
                widget.onReset();
              }),
              _buildActionSquare('XOAY', Icons.screen_rotation, () {
                Navigator.pop(context);
                widget.onRotate();
              }),
              _buildActionSquare('CHIẾU MÀN HÌNH', Icons.cast, () {
                Navigator.pop(context);
                widget.onOpenLan();
              }),
              _buildActionSquare('CHEAT ENGINE', Icons.bolt, () {
                Navigator.pop(context);
                if (widget.onOpenCheat != null) {
                  widget.onOpenCheat!();
                } else {
                  _showCheatDialog();
                }
              }),
              _buildActionSquare('TUA LÙI 10S', Icons.fast_rewind, () {
                Navigator.pop(context);
                widget.onRewind?.call();
              }),
              _buildActionSquare(_isCrtFilter ? 'CRT: BẬT' : 'BỘ LỌC CRT', Icons.tv, () {
                setState(() => _isCrtFilter = !_isCrtFilter);
                widget.onToggleCrtFilter?.call(_isCrtFilter);
              }),
              _buildActionSquare(_isAutoGrind ? 'CÀY: BẬT' : 'AUTO-GRIND', Icons.smart_toy, () {
                setState(() => _isAutoGrind = !_isAutoGrind);
                widget.onToggleAutoGrind?.call(_isAutoGrind);
              }),
              _buildActionSquare('CHỈNH NÚT', Icons.tune, () {
                Navigator.pop(context);
                widget.onStartCustomizingLayout?.call();
              }),
              _buildActionSquare('VỊ TRÍ NÚT', Icons.grid_goldenratio, _showButtonLayoutDialog),
              _buildActionSquare('CẦN GẠT', Icons.radio_button_checked, _showJoystickConfigDialog),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Phần thanh trượt âm lượng
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ÂM LƯỢNG   ${_isMuted ? "TẮT" : "${(_musicVolume * 100).toInt()}%"}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'HIỆU ỨNG ÂM THANH   ${(_sfxVolume * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _musicVolume,
                      activeColor: const Color(0xFFF2ECE1),
                      inactiveColor: Colors.black45,
                      onChanged: (val) {
                        setState(() {
                          _musicVolume = val;
                          _isMuted = false;
                        });
                        widget.onVolumeChanged?.call(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: _sfxVolume,
                      activeColor: const Color(0xFFF2ECE1),
                      inactiveColor: Colors.black45,
                      onChanged: (val) => setState(() => _sfxVolume = val),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Checkbox cài đặt
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildCheckboxRow('TẮT ÂM THANH GAME', _isMuted, (v) {
                setState(() => _isMuted = v);
                widget.onVolumeChanged?.call(v ? 0.0 : _musicVolume);
              }),
              _buildCheckboxRow('TỰ LƯU KHI THOÁT', _autoSaveOnExit, (v) => setState(() => _autoSaveOnExit = v)),
              _buildCheckboxRow('TỰ TIẾP TỤC GAME', _autoResume, (v) => setState(() => _autoResume = v)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArcadeTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THIẾT LẬP PHẦN CỨNG ARCADE (DIP SWITCHES)',
            style: TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDropdownRow('Độ khó game:', _arcadeDifficulty, [
            'Level 1 (Dễ)',
            'Level 4 (Chuẩn)',
            'Level 8 (Rất khó)'
          ], (v) {
            if (v != null) setState(() => _arcadeDifficulty = v);
          }),
          const SizedBox(height: 10),
          _buildDropdownRow('Số mạng khởi đầu:', _arcadeLives, [
            '1 Mạng',
            '3 Mạng',
            '5 Mạng'
          ], (v) {
            if (v != null) setState(() => _arcadeLives = v);
          }),
          const SizedBox(height: 10),
          _buildCheckboxRow('CHƠI TỰ DO (FREE PLAY - KHÔNG CẦN COIN)', _freePlayMode, (v) {
            setState(() => _freePlayMode = v);
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF2C1E14),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('LƯU CẤU HÌNH ARCADE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- HỘP THOẠI VỊ TRÍ & BỐ CỤC NÚT ---
  void _showButtonLayoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.grid_goldenratio, color: Color(0xFFD4AF37)),
              SizedBox(width: 8),
              Text('VỊ TRÍ & BỐ CỤC NÚT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kích thước cụm nút (1% - 100%):', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('%', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('1%', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(ctx).copyWith(
                        trackHeight: 4,
                        activeTrackColor: const Color(0xFFD4AF37),
                        inactiveTrackColor: Colors.black45,
                        thumbColor: const Color(0xFFFFD700),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: _buttonPercent.clamp(1.0, 100.0),
                        min: 1.0,
                        max: 100.0,
                        divisions: 99,
                        onChanged: (val) {
                          setDialogState(() => _buttonPercent = val);
                          setState(() => _buttonPercent = val);
                        },
                      ),
                    ),
                  ),
                  const Text('100%', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Kiểu bố trí nút:', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (var lo in [
                'Arcade 6 nút (Chuẩn Neo Geo)',
                'Dạng ô vuông 2x2 (A-B-C-D)',
                'Dạng chữ thập (Lên - Xuống - Trái - Phải)',
                'Arcade 4 nút thẳng hàng',
                'Vòng cung cổ điển'
              ])
                RadioListTile<String>(
                  title: Text(lo, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  value: lo,
                  groupValue: _buttonLayout,
                  dense: true,
                  activeColor: const Color(0xFFD4AF37),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => _buttonLayout = val);
                      setState(() => _buttonLayout = val);
                    }
                  },
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(ctx);
                double scale = 0.4 + (_buttonPercent / 100.0) * 0.8;

                String layoutCode = 'arcade6';
                if (_buttonLayout == 'Arcade 4 nút thẳng hàng') layoutCode = 'arcade4Row';
                if (_buttonLayout == 'Vòng cung cổ điển') layoutCode = 'arcade4Arc';
                if (_buttonLayout == 'Dạng ô vuông 2x2 (A-B-C-D)') layoutCode = 'arcadeSquare2x2';
                if (_buttonLayout == 'Dạng chữ thập (Lên - Xuống - Trái - Phải)') layoutCode = 'arcadeDiamond';

                widget.onLayoutChanged?.call(scale, layoutCode);
              },
              child: const Text('Lưu vị trí nút', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // --- HỘP THOẠI CẦN GẠT ---
  void _showJoystickConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.radio_button_checked, color: Color(0xFFD4AF37)),
              SizedBox(width: 8),
              Text('CÀI ĐẶT CẦN GẠT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kiểu điều khiển di chuyển:', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (var jt in [
                'Cần gạt xoay tròn 360°',
                'Phím ô vuông 4 hướng riêng biệt (Lên - Xuống - Trái - Phải)',
                'Cụm phím chữ thập D-Pad 4 hướng'
              ])
                RadioListTile<String>(
                  title: Text(jt, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  value: jt,
                  groupValue: _joystickType,
                  dense: true,
                  activeColor: const Color(0xFFD4AF37),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => _joystickType = val);
                      setState(() => _joystickType = val);
                    }
                  },
                ),
              const SizedBox(height: 10),
              const Text('Độ nhạy cần gạt:', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (var sen in ['Cao (Nhạy nhất)', 'Chuẩn (Khuyên dùng)', 'Thấp'])
                RadioListTile<String>(
                  title: Text(sen, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  value: sen,
                  groupValue: _joystickSensitivity,
                  dense: true,
                  activeColor: const Color(0xFFD4AF37),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => _joystickSensitivity = val);
                      setState(() => _joystickSensitivity = val);
                    }
                  },
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(ctx);
                String typeCode = 'analog360';
                if (_joystickType == 'Phím ô vuông 4 hướng riêng biệt (Lên - Xuống - Trái - Phải)') {
                  typeCode = 'dpadSquare4';
                } else if (_joystickType == 'Cụm phím chữ thập D-Pad 4 hướng') {
                  typeCode = 'dpad4';
                }
                String sensCode = 'normal';
                if (_joystickSensitivity == 'Cao (Nhạy nhất)') sensCode = 'high';
                if (_joystickSensitivity == 'Thấp') sensCode = 'low';

                widget.onJoystickChanged?.call(typeCode, sensCode);
              },
              child: const Text('Lưu cần gạt', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // --- HỘP THOẠI CHEAT CODE ---
  void _showCheatDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.terminal, color: Color(0xFF00FF88)),
              SizedBox(width: 8),
              Text('BẢNG MÃ GIAN LẬN (CHEAT)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Bất tử mạng (Infinite Lives)', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text('Không bao giờ mất mạng khi nổ bom', style: TextStyle(color: Colors.white54, fontSize: 11)),
                value: _cheatInfiniteLives,
                activeThumbColor: const Color(0xFF00FF88),
                onChanged: (val) => setDialogState(() => _cheatInfiniteLives = val),
              ),
              SwitchListTile(
                title: const Text('Vô hạn bom (Max Bombs)', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text('Đặt tối đa bom cùng lúc ngay từ đầu', style: TextStyle(color: Colors.white54, fontSize: 11)),
                value: _cheatMaxBombs,
                activeThumbColor: const Color(0xFF00FF88),
                onChanged: (val) => setDialogState(() => _cheatMaxBombs = val),
              ),
              SwitchListTile(
                title: const Text('Tốc độ tối đa (Max Speed)', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text('Nhân vật di chuyển siêu tốc', style: TextStyle(color: Colors.white54, fontSize: 11)),
                value: _cheatMaxSpeed,
                activeThumbColor: const Color(0xFF00FF88),
                onChanged: (val) => setDialogState(() => _cheatMaxSpeed = val),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('ÁP DỤNG CHEAT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, List<String> items, Function(String?) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF3E2D22),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD4AF37)),
          ),
          child: DropdownButton<String>(
            value: value,
            dropdownColor: const Color(0xFF3E2D22),
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white, fontSize: 11),
            items: items.map((it) => DropdownMenuItem(value: it, child: Text(it))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBtn(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF3E2D22),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF8B6B48)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF2C1E14) : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionSquare(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFF2ECE1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF3E3120), size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF3E3120),
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxRow(String label, bool value, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF3E2D22),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFFD4AF37)),
              ),
              child: value
                  ? const Center(
                      child: Text(
                        '✕',
                        style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

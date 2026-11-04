import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CheatItem {
  final String id;
  final String name;
  final String code;
  bool isEnabled;

  CheatItem({
    required this.id,
    required this.name,
    required this.code,
    this.isEnabled = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'isEnabled': isEnabled,
      };

  factory CheatItem.fromJson(Map<String, dynamic> json) => CheatItem(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        code: json['code'] ?? '',
        isEnabled: json['isEnabled'] ?? false,
      );
}

class CheatManagerDialog extends StatefulWidget {
  final String gameTitle;
  final String console;
  final Function(String code, bool enabled) onApplyCheat;

  const CheatManagerDialog({
    super.key,
    required this.gameTitle,
    required this.console,
    required this.onApplyCheat,
  });

  @override
  State<CheatManagerDialog> createState() => _CheatManagerDialogState();
}

class _CheatManagerDialogState extends State<CheatManagerDialog> {
  List<CheatItem> _cheats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCheats();
  }

  Future<void> _loadCheats() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'cheats_${widget.gameTitle.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
    final raw = prefs.getStringList(key);

    if (raw != null && raw.isNotEmpty) {
      _cheats = raw.map((s) => CheatItem.fromJson(jsonDecode(s))).toList();
    } else {
      // Nạp các mã cheat mẫu phổ biến tùy theo tựa game
      _cheats = _getDefaultCheats(widget.gameTitle, widget.console);
      await _saveCheats();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<CheatItem> _getDefaultCheats(String title, String console) {
    final t = title.toLowerCase();
    final list = <CheatItem>[];

    if (t.contains('pokemon') || t.contains('pokémon')) {
      list.addAll([
        CheatItem(id: 'c1', name: 'Kẹo hiếm vô hạn (999x Rare Candy)', code: '012016D0', isEnabled: false),
        CheatItem(id: 'c2', name: 'Bóng bắt Master Ball 100%', code: '010116D0', isEnabled: false),
        CheatItem(id: 'c3', name: 'Tiền tối đa (\$999,999)', code: '019946D3', isEnabled: false),
        CheatItem(id: 'c4', name: 'Đi xuyên tường (Walk Through Walls)', code: '010156D0', isEnabled: false),
      ]);
    } else if (t.contains('slug') || t.contains('metal')) {
      list.addAll([
        CheatItem(id: 'c1', name: 'Bất tử máu (Invincibility)', code: '10000000 0000', isEnabled: false),
        CheatItem(id: 'c2', name: 'Đạn vô hạn (Infinite Ammo)', code: '10000002 FFFF', isEnabled: false),
        CheatItem(id: 'c3', name: 'Bom vô hạn (Infinite Bombs)', code: '10000004 0063', isEnabled: false),
        CheatItem(id: 'c4', name: 'Mạng chơi vô hạn (Infinite Lives)', code: '10000006 0009', isEnabled: false),
      ]);
    } else if (t.contains('bomber')) {
      list.addAll([
        CheatItem(id: 'c1', name: 'Tối đa số lượng bom (Max Bombs)', code: '010900C0', isEnabled: false),
        CheatItem(id: 'c2', name: 'Tối đa tầm nổ (Max Fire Range)', code: '010901C0', isEnabled: false),
        CheatItem(id: 'c3', name: 'Bất tử (Invincible)', code: '010105C0', isEnabled: false),
      ]);
    } else if (t.contains('contra')) {
      list.addAll([
        CheatItem(id: 'c1', name: '30 Mạng (30 Lives Konami)', code: '001A 001E', isEnabled: false),
        CheatItem(id: 'c2', name: 'Súng đạn chùm (Spread Gun)', code: '00AA 0002', isEnabled: false),
        CheatItem(id: 'c3', name: 'Bất tử máu (Invincible)', code: '00AE 0001', isEnabled: false),
      ]);
    } else if (t.contains('mario')) {
      list.addAll([
        CheatItem(id: 'c1', name: 'Mạng vô hạn (Infinite Lives)', code: '075A 0009', isEnabled: false),
        CheatItem(id: 'c2', name: 'Bất tử sao (Always Star Power)', code: '079E 0001', isEnabled: false),
      ]);
    } else {
      // Cheat mặc định
      list.addAll([
        CheatItem(id: 'c1', name: 'Bất tử máu (God Mode / Infinite HP)', code: '01FF00A0', isEnabled: false),
        CheatItem(id: 'c2', name: 'Mạng vô hạn (Infinite Lives)', code: '010900B0', isEnabled: false),
        CheatItem(id: 'c3', name: 'Tiền tối đa (Max Gold / Coins)', code: '019999C0', isEnabled: false),
      ]);
    }
    return list;
  }

  Future<void> _saveCheats() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'cheats_${widget.gameTitle.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
    final raw = _cheats.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(key, raw);
  }

  void _showAddCheatDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131C31),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
        ),
        title: const Text('Thêm mã Cheat mới', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Tên cheat (Ví dụ: Bất tử máu, Rare Candy)',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              style: const TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Mã Cheat (GameShark, Action Replay, Hex Code)',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final code = codeCtrl.text.trim();
              if (name.isNotEmpty && code.isNotEmpty) {
                setState(() {
                  _cheats.add(CheatItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    code: code,
                    isEnabled: true,
                  ));
                });
                _saveCheats();
                widget.onApplyCheat(code, true);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Thêm & Bật', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F1523),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 540),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFFFFD700), size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHEAT ENGINE (MÃ GIAN LẬN)',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        widget.gameTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),

            // Danh sách cheat
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                  : _cheats.isEmpty
                      ? const Center(
                          child: Text('Chưa có mã cheat nào được lưu.', style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.separated(
                          itemCount: _cheats.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                          itemBuilder: (ctx, index) {
                            final cheat = _cheats[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: cheat.isEnabled
                                    ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                                    : const Color(0xFF182238),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: cheat.isEnabled
                                      ? const Color(0xFFD4AF37)
                                      : Colors.white12,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cheat.name,
                                          style: TextStyle(
                                            color: cheat.isEnabled ? Colors.white : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cheat.code,
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: cheat.isEnabled,
                                    activeThumbColor: const Color(0xFFFFD700),
                                    activeTrackColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                                    inactiveThumbColor: Colors.grey,
                                    inactiveTrackColor: Colors.black45,
                                    onChanged: (val) {
                                      setState(() {
                                        cheat.isEnabled = val;
                                      });
                                      _saveCheats();
                                      widget.onApplyCheat(cheat.code, val);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _cheats.removeAt(index);
                                      });
                                      _saveCheats();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 12),

            // Nút Thêm mã cheat mới
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                label: const Text(
                  '+ THÊM MÃ CHEAT MỚI',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white, letterSpacing: 0.5),
                ),
                onPressed: _showAddCheatDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

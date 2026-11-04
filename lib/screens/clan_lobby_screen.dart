import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_item.dart';
import '../models/lan_message.dart';
import '../services/clan_netplay_service.dart';
import '../services/rom_manager.dart';
import 'emulator_screen.dart';
import 'wireless_pad_screen.dart';

class ClanLobbyScreen extends StatefulWidget {
  final ClanNetplayService clanService;

  const ClanLobbyScreen({super.key, required this.clanService});

  @override
  State<ClanLobbyScreen> createState() => ClanLobbyScreenState();
}

class ClanLobbyScreenState extends State<ClanLobbyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<GameItem> _installedGames = [];
  GameItem? _selectedGame;
  String _localIp = '127.0.0.1';
  bool _isHosting = false;
  bool _isPlayer2Connected = false;

  // Chế độ tham gia
  List<ClanRoomInfo> _discoveredRooms = [];
  final TextEditingController _manualIpController = TextEditingController();
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  void _initData() async {
    _localIp = await widget.clanService.getLocalIp();
    await RomManager.ensureDefaultGames();
    await refreshGames();

    if (_localIp.contains('.')) {
      final parts = _localIp.split('.');
      if (parts.length == 4 && _manualIpController.text.isEmpty) {
        _manualIpController.text = '${parts[0]}.${parts[1]}.${parts[2]}.';
      }
    }

    widget.clanService.onRoomsDiscovered = (rooms) {
      if (mounted) {
        setState(() {
          _discoveredRooms = rooms;
        });
      }
    };

    widget.clanService.onP2ConnectionChanged = (connected) {
      if (mounted) {
        setState(() {
          _isPlayer2Connected = connected;
        });
      }
    };

    widget.clanService.startDiscovery();
  }

  Future<void> refreshGames() async {
    final games = await RomManager.getInstalledGames();
    if (mounted) {
      setState(() {
        _installedGames = games;
        if (_selectedGame == null || !games.any((g) => g.title == _selectedGame!.title)) {
          if (games.isNotEmpty) {
            _selectedGame = games.first;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualIpController.dispose();
    super.dispose();
  }

  Future<void> _startHostRoom() async {
    if (_selectedGame == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orangeAccent,
          content: Text('Vui lòng chọn hoặc thêm game trước khi mở phòng!'),
        ),
      );
      return;
    }

    setState(() {
      _isHosting = true;
    });

    final success = await widget.clanService.startClanRoom(
      roomName: 'Phòng ${_selectedGame!.title}',
      gameTitle: _selectedGame!.title,
    );

    if (!success && mounted) {
      setState(() {
        _isHosting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Không thể mở cổng mạng LAN. Vui lòng kiểm tra quyền Wi-Fi!'),
        ),
      );
    }
  }

  void _launchHostGame() {
    if (_selectedGame != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmulatorScreen(
            game: _selectedGame!,
            clanService: widget.clanService,
            isHost: true,
          ),
        ),
      );
    }
  }

  Future<void> _joinHost(String hostIp) async {
    String cleanIp = hostIp.trim();
    if (cleanIp.isEmpty) return;

    // Hỗ trợ nhập số cuối (ví dụ nhập 15 tự mở rộng thành 192.168.1.15)
    if (int.tryParse(cleanIp) != null) {
      final parts = _localIp.split('.');
      if (parts.length == 4) {
        cleanIp = '${parts[0]}.${parts[1]}.${parts[2]}.$cleanIp';
      }
    }

    setState(() {
      _isJoining = true;
    });

    final success = await widget.clanService.joinClanRoom(
      hostIp: cleanIp,
      onJoined: (gameTitle) {
        if (mounted) {
          setState(() {
            _isJoining = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WirelessPadScreen(
                clanService: widget.clanService,
                gameTitle: gameTitle,
                hostIp: cleanIp,
              ),
            ),
          );
        }
      },
    );

    if (!success && mounted) {
      setState(() {
        _isJoining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Không thể kết nối tới $cleanIp. Hãy đảm bảo 2 máy cùng bắt 1 mạng Wi-Fi!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Trạng thái mạng nội bộ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF16161C),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.wifi, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'IP Mạng Wi-Fi: $_localIp',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Đã kết nối Wi-Fi', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
              ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF2A55),
          labelColor: const Color(0xFFFF2A55),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.sports_esports), text: 'TẠO PHÒNG (P1)'),
            Tab(icon: Icon(Icons.group_add), text: 'VÀO PHÒNG (P2)'),
          ],
        ),

        // Nội dung Tab
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildHostTab(),
              _buildJoinTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHostTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('1. Chọn game muốn mở phòng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF), size: 20),
                tooltip: 'Làm mới danh sách game',
                onPressed: () async {
                  await refreshGames();
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã làm mới danh sách game!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_installedGames.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Thư viện của bạn đang trống! Hãy quay lại tab "Thư viện" và bấm nút "Thêm Game" để chọn file game từ máy trước.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            DropdownButtonFormField<GameItem>(
              key: ValueKey(_selectedGame?.title ?? 'empty'),
              initialValue: _installedGames.any((g) => g.title == _selectedGame?.title)
                  ? _installedGames.firstWhere((g) => g.title == _selectedGame?.title)
                  : (_installedGames.isNotEmpty ? _installedGames.first : null),
              dropdownColor: const Color(0xFF22222C),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1B1B22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: _installedGames.map((g) {
                return DropdownMenuItem(
                  value: g,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          g.console.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Flexible(
                        child: Text(g.title, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedGame = val;
                  });
                  if (_isHosting) {
                    widget.clanService.updateHostedGame(val.title);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF131C31),
                        duration: const Duration(seconds: 2),
                        content: Text('Đã cập nhật game mở phòng: ${val.title}'),
                      ),
                    );
                  }
                }
              },
            ),

          const SizedBox(height: 24),
          const Text('2. Trạng thái phòng Clan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHosting ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.white12,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Phòng mạng LAN:', style: TextStyle(color: Colors.white70)),
                    Text(
                      _isHosting ? 'ĐANG MỞ (Đang phát tín hiệu Wi-Fi)' : 'Đang đóng',
                      style: TextStyle(
                        color: _isHosting ? Colors.greenAccent : Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Người chơi 2 (Clan):', style: TextStyle(color: Colors.white70)),
                    Row(
                      children: [
                        Icon(
                          _isPlayer2Connected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: _isPlayer2Connected ? Colors.greenAccent : Colors.orangeAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPlayer2Connected ? 'Đã kết nối & Sẵn sàng' : (_isHosting ? 'Đang đợi bạn vào...' : 'Chưa kết nối'),
                          style: TextStyle(
                            color: _isPlayer2Connected ? Colors.greenAccent : Colors.white70,
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

          const SizedBox(height: 24),
          if (_isHosting) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'IP Chủ phòng: $_localIp:8989',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.greenAccent, size: 20),
                        tooltip: 'Sao chép IP',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _localIp));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green,
                              content: Text('Đã sao chép IP máy chủ: $_localIp'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bảo bạn của bạn mở Tab "VÀO PHÒNG (P2)" trên máy họ, gõ số: ${_localIp.split('.').last} (hoặc $_localIp) rồi bấm Kết nối!',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],

          if (!_isHosting)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2A55),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('MỞ PHÒNG CLAN (LAN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: _startHostRoom,
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('VÀO GAME VỚI VAI TRÒ CHỦ PHÒNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: _launchHostGame,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await widget.clanService.stopAll();
                  setState(() {
                    _isHosting = false;
                    _isPlayer2Connected = false;
                  });
                },
                child: const Text('Đóng phòng'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJoinTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Phòng Clan đang mở trên Wi-Fi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.greenAccent),
                tooltip: 'Quét lại phòng',
                onPressed: () => widget.clanService.startDiscovery(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_discoveredRooms.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFF2A55)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Đang quét tìm phòng Clan trên mạng Wi-Fi...',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Hãy chắc chắn máy chủ phòng đã bấm "MỞ PHÒNG CLAN"',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.greenAccent,
                        side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.radar, size: 16),
                      label: const Text('Quét toàn mạng Wi-Fi'),
                      onPressed: () => widget.clanService.startDiscovery(),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _discoveredRooms.length,
              itemBuilder: (ctx, idx) {
                final room = _discoveredRooms[idx];
                return Card(
                  color: const Color(0xFF1B1B22),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFF2A55),
                      child: Icon(Icons.sports_esports, color: Colors.white),
                    ),
                    title: Text(room.gameTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('IP Chủ phòng: ${room.hostIp}:${room.port}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A55)),
                      onPressed: _isJoining ? null : () => _joinHost(room.hostIp),
                      child: const Text('Vào làm P2', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 28),
          const Text('Hoặc nhập IP của Chủ phòng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualIpController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 192.168.1.15 hoặc chỉ gõ 15',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1B1B22),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2A55),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isJoining
                    ? null
                    : () {
                        final ip = _manualIpController.text.trim();
                        if (ip.isNotEmpty) _joinHost(ip);
                      },
                child: _isJoining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Kết nối', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '💡 Mẹo: Bạn chỉ cần gõ số cuối (ví dụ chủ phòng là 192.168.1.15 thì chỉ cần gõ "15") rồi bấm Kết nối!',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

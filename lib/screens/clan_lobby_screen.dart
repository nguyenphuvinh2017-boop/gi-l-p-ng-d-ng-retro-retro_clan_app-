import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_item.dart';
import '../models/lan_message.dart';
import '../services/clan_netplay_service.dart';
import '../services/app_language.dart';
import '../services/rom_manager.dart';
import 'emulator_screen.dart';

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
  String? _lastConnectedHostIp;
  bool _isP2WaitingGame = false;
  String? _joinedGameTitle;
  String? _joinedHostIp;

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

    try {
      final prefs = await SharedPreferences.getInstance();
      _lastConnectedHostIp = prefs.getString('last_clan_host_ip');
      if (_lastConnectedHostIp != null && _lastConnectedHostIp!.isNotEmpty) {
        _manualIpController.text = _lastConnectedHostIp!;
        widget.clanService.lastKnownHostIp = _lastConnectedHostIp;
        widget.clanService.scanSubnet(_lastConnectedHostIp);
      }
    } catch (_) {}

    if (_manualIpController.text.isEmpty && _localIp.contains('.')) {
      final parts = _localIp.split('.');
      if (parts.length == 4) {
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
      widget.clanService.notifyGameStart(_selectedGame!.title);
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

  Future<void> _launchP2Game(String gameTitle, String hostIp) async {
    if (!mounted) return;
    setState(() {
      _isJoining = false;
      _isP2WaitingGame = false;
      _lastConnectedHostIp = hostIp;
    });
    SharedPreferences.getInstance().then((p) {
      p.setString('last_clan_host_ip', hostIp);
      widget.clanService.lastKnownHostIp = hostIp;
    }).catchError((_) {});

    GameItem? matchedGame;
    for (var g in _installedGames) {
      if (g.title.toLowerCase() == gameTitle.toLowerCase() ||
          g.title.toLowerCase().contains(gameTitle.toLowerCase()) ||
          gameTitle.toLowerCase().contains(g.title.toLowerCase())) {
        matchedGame = g;
        break;
      }
    }
    if (matchedGame == null && _installedGames.isNotEmpty) {
      matchedGame = _installedGames.first;
    }
    if (matchedGame == null) {
      final romDir = await RomManager.getRomDirectory();
      final targetRom = File('${romDir.path}/neobombe.zip');
      matchedGame = GameItem(
        title: gameTitle.isNotEmpty ? gameTitle : 'Neo Bomberman',
        console: 'arcade',
        pageUrl: '',
        localRomPath: targetRom.path,
        isDownloaded: true,
      );
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmulatorScreen(
            game: matchedGame!,
            clanService: widget.clanService,
            isHost: false,
            hostIp: hostIp,
          ),
        ),
      );
    }
  }

  Future<void> _joinHost(String hostIp, {int? port}) async {
    String cleanIp = hostIp.trim();
    if (cleanIp.isEmpty) return;

    int targetPort = port ?? ClanNetplayService.defaultWsPort;
    if (cleanIp.contains(':')) {
      final parts = cleanIp.split(':');
      cleanIp = parts[0].trim();
      targetPort = int.tryParse(parts[1].trim()) ?? targetPort;
    }

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

    // Lắng nghe khi Chủ phòng bấm Vào Game
    widget.clanService.onGameStartedReceived = (gameTitle) {
      _launchP2Game(gameTitle, cleanIp);
    };

    final success = await widget.clanService.joinClanRoom(
      hostIp: cleanIp,
      port: targetPort,
      onJoined: (gameTitle, isGameRunning) {
        if (mounted) {
          if (isGameRunning) {
            _launchP2Game(gameTitle, cleanIp);
          } else {
            setState(() {
              _isJoining = false;
              _isP2WaitingGame = true;
              _joinedGameTitle = gameTitle;
              _joinedHostIp = cleanIp;
              _lastConnectedHostIp = cleanIp;
            });
            SharedPreferences.getInstance().then((p) {
              p.setString('last_clan_host_ip', cleanIp);
              widget.clanService.lastKnownHostIp = cleanIp;
            }).catchError((_) {});
          }
        }
      },
    );

    if (!success && mounted) {
      setState(() {
        _isJoining = false;
        _isP2WaitingGame = false;
      });
      final errDetail = widget.clanService.lastJoinError != null
          ? '\nChi tiết: ${widget.clanService.lastJoinError}'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
          content: Text('Không thể kết nối tới $cleanIp:$targetPort. Hãy đảm bảo 2 máy cùng Wi-Fi và đã bật Mạng cục bộ trên iOS!$errDetail'),
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
          tabs: [
            Tab(icon: const Icon(Icons.sports_esports), text: AppLanguage.tr('tab_create_room')),
            Tab(icon: const Icon(Icons.group_add), text: AppLanguage.tr('tab_join_room')),
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
          if (_isP2WaitingGame) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF132238),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF00E676), size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Đã kết nối với Chủ phòng (P2)!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🎮 Game phòng: ${_joinedGameTitle ?? "Neo Bomberman"}\n🌐 IP Chủ phòng: ${_joinedHostIp ?? ""}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang đợi Chủ phòng bấm Vào Game...',
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text('VÀO GAME NGAY CÙNG CHỦ PHÒNG (P2)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        if (_joinedGameTitle != null && _joinedHostIp != null) {
                          _launchP2Game(_joinedGameTitle!, _joinedHostIp!);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white60,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        widget.clanService.stopAll();
                        setState(() {
                          _isP2WaitingGame = false;
                        });
                      },
                      child: const Text('Hủy kết nối'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLanguage.tr('step_select_game'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
          Text(AppLanguage.tr('step_room_status'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131C31),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isHosting ? const Color(0xFF00E5FF).withValues(alpha: 0.5) : Colors.white12,
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Phòng mạng LAN:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isHosting ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isHosting ? AppLanguage.tr('status_open') : 'Đang đóng',
                        style: TextStyle(
                          color: _isHosting ? const Color(0xFF00E5FF) : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1F2D4A), height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Người chơi 2 (Clan):', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Row(
                      children: [
                        Icon(
                          _isPlayer2Connected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: _isPlayer2Connected ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPlayer2Connected ? AppLanguage.tr('player2_ready') : (_isHosting ? AppLanguage.tr('waiting_player2') : 'Chưa kết nối'),
                          style: TextStyle(
                            color: _isPlayer2Connected ? const Color(0xFF00E676) : (_isHosting ? const Color(0xFFFFD54F) : Colors.white54),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // NÚT VÀO GAME P1 NẰM NGAY TRUNG TÂM (KHÔNG CẦN CUỘN MÀN HÌNH)
                if (_isHosting) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.sports_esports, color: Colors.white, size: 24),
                      label: Text(
                        _isPlayer2Connected
                            ? AppLanguage.tr('start_game_now')
                            : AppLanguage.tr('start_game_host'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, letterSpacing: 0.5),
                      ),
                      onPressed: _launchHostGame,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await widget.clanService.stopAll();
                        setState(() {
                          _isHosting = false;
                          _isPlayer2Connected = false;
                        });
                      },
                      child: Text(AppLanguage.tr('close_room_btn')),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (!_isHosting)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2A55),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                icon: const Icon(Icons.wifi_tethering, color: Colors.white),
                label: Text(AppLanguage.tr('open_room_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                onPressed: _startHostRoom,
              ),
            )
          else ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131D33),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF29A3FF).withValues(alpha: 0.5), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.wifi_tethering, color: Color(0xFF00E5FF), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Địa chỉ IP máy chủ của bạn:',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$_localIp:8989',
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.copy, size: 16, color: Colors.black87),
                          label: const Text(
                            'Sao chép IP',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _localIp));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF131C31),
                                content: Text('Đã sao chép IP máy chủ: $_localIp'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bảo bạn của bạn mở Tab "VÀO PHÒNG (P2)" trên máy họ, gõ số: ${_localIp.split('.').last} (hoặc $_localIp) rồi bấm Kết nối!',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
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
          if (_isP2WaitingGame) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF132238),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF00E676), size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Đã kết nối với Chủ phòng (P2)!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🎮 Game phòng: ${_joinedGameTitle ?? "Neo Bomberman"}\n🌐 IP Chủ phòng: ${_joinedHostIp ?? ""}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang đợi Chủ phòng bấm Vào Game...',
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text('VÀO GAME NGAY CÙNG CHỦ PHÒNG (P2)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        if (_joinedGameTitle != null && _joinedHostIp != null) {
                          _launchP2Game(_joinedGameTitle!, _joinedHostIp!);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white60,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        widget.clanService.stopAll();
                        setState(() {
                          _isP2WaitingGame = false;
                        });
                      },
                      child: const Text('Hủy kết nối'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_lastConnectedHostIp != null && _lastConnectedHostIp!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF131D33),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Máy chủ vừa kết nối gần nhất:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text(
                          _lastConnectedHostIp!,
                          style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                    label: const Text('Vào ngay', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                    onPressed: _isJoining ? null : () => _joinHost(_lastConnectedHostIp!),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Phòng Clan đang mở trên Wi-Fi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.greenAccent),
                tooltip: 'Quét lại phòng',
                onPressed: () {
                  widget.clanService.forceScan(_lastConnectedHostIp);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(milliseconds: 900), content: Text('Đang quét siêu tốc toàn bộ mạng Wi-Fi...')));
                },
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
                      onPressed: () {
                  widget.clanService.forceScan(_lastConnectedHostIp);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(milliseconds: 900), content: Text('Đang quét siêu tốc toàn bộ mạng Wi-Fi...')));
                },
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
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A55), foregroundColor: Colors.white),
                      onPressed: _isJoining ? null : () => _joinHost(room.hostIp, port: room.port),
                      child: const Text('Vào làm P2', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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

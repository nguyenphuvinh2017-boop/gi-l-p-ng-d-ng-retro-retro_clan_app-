import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/game_item.dart';
import '../services/retrostic_service.dart';
import '../services/rom_manager.dart';
import '../services/clan_netplay_service.dart';
import 'emulator_screen.dart';

class BrowseRetrosticScreen extends StatefulWidget {
  final ClanNetplayService clanService;
  final Function() onGameDownloaded;

  const BrowseRetrosticScreen({
    super.key,
    required this.clanService,
    required this.onGameDownloaded,
  });

  @override
  State<BrowseRetrosticScreen> createState() => _BrowseRetrosticScreenState();
}

class _BrowseRetrosticScreenState extends State<BrowseRetrosticScreen> {
  final RetrosticService _retrostic = RetrosticService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedConsole = 'nes';
  bool _isLoading = false;
  List<GameItem> _games = [];
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadStatus = {};

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      _isLoading = true;
    });

    final games = await _retrostic.getConsoleGames(_selectedConsole);
    if (mounted) {
      setState(() {
        _games = games;
        _isLoading = false;
      });
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _loadGames();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final results = await _retrostic.searchGames(query);
    if (mounted) {
      setState(() {
        _games = results;
        _isLoading = false;
      });
    }
  }

  /// Chọn file đã tải về từ trình duyệt
  Future<void> _pickFileFromDevice() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'nes', 'gba', 'gb', 'gbc', 'smc', 'sfc', 'bin', 'neo'],
        dialogTitle: 'Chọn file game tải từ Retrostic',
      );

      if (files.isNotEmpty && files.first.path != null) {
        final imported = await RomManager.importFileFromDevice(files.first.path!);
        if (imported != null && mounted) {
          widget.onGameDownloaded();
          _showPlayOptionsDialog(imported);
        }
      }
    } catch (_) {}
  }

  Future<void> _downloadAndPlay(GameItem game) async {
    setState(() {
      _downloadProgress[game.title] = 0.05;
      _downloadStatus[game.title] = 'Đang giải mã liên kết tải...';
    });

    // 1. Giải mã URL tải trực tiếp từ Retrostic
    final directUrl = await _retrostic.resolveDirectDownloadUrl(game.pageUrl);

    if (directUrl == null) {
      if (mounted) {
        setState(() {
          _downloadProgress.remove(game.title);
          _downloadStatus[game.title] = 'Lỗi tải (Bảo mật web)';
        });
        _showCloudflareHelpDialog(game);
      }
      return;
    }

    setState(() {
      _downloadStatus[game.title] = 'Đang tải & giải nén ROM...';
    });

    // 2. Tải và giải nén
    final savedGame = await RomManager.downloadAndExtract(
      game: game,
      downloadUrl: directUrl,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[game.title] = progress;
          });
        }
      },
    );

    if (savedGame != null && mounted) {
      setState(() {
        _downloadProgress.remove(game.title);
        _downloadStatus[game.title] = 'Sẵn sàng chơi!';
      });
      widget.onGameDownloaded();
      _showPlayOptionsDialog(savedGame);
    } else if (mounted) {
      setState(() {
        _downloadProgress.remove(game.title);
        _downloadStatus[game.title] = 'Lỗi tải tệp';
      });
      _showCloudflareHelpDialog(game);
    }
  }

  void _showCloudflareHelpDialog(GameItem game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Retrostic chặn tải tự động', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Máy chủ Retrostic yêu cầu xác minh người dùng (Cloudflare/Session) cho game "${game.title}".',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            const Text(
              '👉 Cách đơn giản nhất:\n1. Mở trình duyệt và tải game về máy.\n2. Bấm nút "CHỌN FILE ĐÃ TẢI" bên dưới để đưa game vào app và chơi ngay lập tức!',
              style: TextStyle(color: Colors.greenAccent, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A55)),
            icon: const Icon(Icons.file_upload, size: 18),
            label: const Text('CHỌN FILE ĐÃ TẢI TỪ MÁY', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _pickFileFromDevice();
            },
          ),
        ],
      ),
    );
  }

  void _showPlayOptionsDialog(GameItem game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: Text(game.title, style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
          'ROM đã sẵn sàng trong thư viện! Bạn muốn bắt đầu chơi như thế nào?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmulatorScreen(
                    game: game,
                    clanService: widget.clanService,
                    isHost: false,
                  ),
                ),
              );
            },
            child: const Text('Chơi đơn (1 Người)', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A55)),
            icon: const Icon(Icons.wifi_tethering, size: 18),
            label: const Text('Mở phòng Clan (Chơi cùng bạn)', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.clanService.startClanRoom(
                roomName: 'Phòng ${game.title}',
                gameTitle: game.title,
              );
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmulatorScreen(
                      game: game,
                      clanService: widget.clanService,
                      isHost: true,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thanh tìm kiếm và bộ lọc hệ máy
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF16161C),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm game Retrostic (Mario, Contra, Bomberman)...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFFF2A55)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38),
                          onPressed: () {
                            _searchController.clear();
                            _loadGames();
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFF22222C),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF22222C)),
                    icon: const Icon(Icons.file_upload, color: Color(0xFFFF2A55)),
                    tooltip: 'Thêm file game đã tải về máy',
                    onPressed: _pickFileFromDevice,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: RetrosticService.supportedConsoles.map((c) {
                    final isSelected = _selectedConsole == c['slug'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(c['name']!),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        selectedColor: const Color(0xFFFF2A55),
                        backgroundColor: const Color(0xFF22222C),
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          setState(() {
                            _selectedConsole = c['slug']!;
                          });
                          _loadGames();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Danh sách game
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF2A55)))
              : _games.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, size: 48, color: Colors.white38),
                          const SizedBox(height: 12),
                          const Text('Không tìm thấy game nào', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadGames,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22222C)),
                            child: const Text('Tải lại'),
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _games.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (ctx, idx) {
                        final game = _games[idx];
                        final progress = _downloadProgress[game.title];
                        final status = _downloadStatus[game.title];

                        return Card(
                          color: const Color(0xFF1B1B22),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2A2A35),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.sports_esports, color: Color(0xFFFF2A55)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            game.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFF2A55).withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  game.console.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Color(0xFFFF2A55),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (status != null) ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                      color: status.contains('Lỗi') ? Colors.orangeAccent : Colors.greenAccent,
                                                      fontSize: 11,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ]
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (progress != null)
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: CircularProgressIndicator(
                                          value: progress,
                                          color: const Color(0xFFFF2A55),
                                          strokeWidth: 3,
                                        ),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF2A55),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.download, size: 16),
                                        label: const Text('Tải ROM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: () => _downloadAndPlay(game),
                                      ),
                                  ],
                                ),
                                if (progress != null) ...[
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white12,
                                    color: const Color(0xFFFF2A55),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

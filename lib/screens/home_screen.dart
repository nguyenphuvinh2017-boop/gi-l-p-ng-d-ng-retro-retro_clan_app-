import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/game_item.dart';
import '../services/rom_manager.dart';
import '../services/clan_netplay_service.dart';
import '../services/app_language.dart';
import '../services/retro_metadata_service.dart';
import 'emulator_screen.dart';

class HomeScreen extends StatefulWidget {
  final ClanNetplayService clanService;
  final VoidCallback onOpenStore;
  final VoidCallback onOpenLan;

  const HomeScreen({
    super.key,
    required this.clanService,
    required this.onOpenStore,
    required this.onOpenLan,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<GameItem> _allGames = [];
  bool _isLoading = true;
  bool _isImporting = false;

  // Bộ lọc
  String _selectedSystem = 'ALL';
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  bool _isGridView = false;

  final List<Map<String, String>> _systems = [
    {'label': 'TẤT CẢ', 'key': 'ALL'},
    {'label': 'NES', 'key': 'nes'},
    {'label': 'SNES', 'key': 'snes'},
    {'label': 'GBA', 'key': 'gba'},
    {'label': 'GBC/GB', 'key': 'gbc'},
    {'label': 'NDS', 'key': 'nds'},
    {'label': 'PS1 (PSX)', 'key': 'psx'},
    {'label': 'PSP', 'key': 'psp'},
    {'label': 'NEOGEO', 'key': 'arcade'},
    {'label': 'MAME', 'key': 'mame'},
    {'label': 'SEGA', 'key': 'genesis'},
    {'label': 'N64', 'key': 'n64'},
    {'label': 'PS2', 'key': 'ps2'},
    {'label': '3DS', 'key': '3ds'},
  ];

  final List<Map<String, String>> _filters = [
    {'label': 'TẤT CẢ', 'key': 'ALL'},
    {'label': 'GẦN ĐÂY', 'key': 'RECENT'},
    {'label': 'YÊU THÍCH', 'key': 'FAVORITE'},
    {'label': 'TIẾP TỤC', 'key': 'CONTINUE'},
    {'label': 'A–Z', 'key': 'AZ'},
  ];

  @override
  void initState() {
    super.initState();
    refreshLibrary();
  }

  Future<void> refreshLibrary() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final games = await RomManager.getInstalledGames();
      final List<GameItem> updatedList = [];

      for (var g in games) {
        final isShort = g.title.length <= 8 && !g.title.contains(' ');
        final noImages = g.coverUrl == null || g.inGamePreviewUrl == null || g.coverUrl!.isEmpty || g.inGamePreviewUrl!.isEmpty;
        final isRawCover = g.coverUrl != null && (g.coverUrl!.contains('.zip') || g.coverUrl!.endsWith('mslug5.png'));

        if (noImages || isShort || isRawCover) {
          final raw = g.localRomPath != null ? g.localRomPath!.split(RegExp(r'[/\\]')).last : g.title;
          final meta = RetroMetadataService.resolveMetadata(
            rawFileName: raw,
            defaultConsole: g.console,
          );
          final updated = g.copyWith(
            title: meta['title'] ?? g.title,
            console: meta['console'] ?? g.console,
            coverUrl: meta['cover'] ?? g.coverUrl,
            inGamePreviewUrl: meta['snap'] ?? g.inGamePreviewUrl,
          );
          updatedList.add(updated);
          await RomManager.saveGameToLibrary(updated);
        } else {
          updatedList.add(g);
        }
      }

      if (mounted) {
        setState(() {
          _allGames = updatedList;
        });
      }
    } catch (e) {
      debugPrint('Lỗi nạp thư viện: ');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<GameItem> get _filteredGames {
    var list = List<GameItem>.from(_allGames);

    // Lọc theo từ khóa tìm kiếm
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((g) => g.title.toLowerCase().contains(q) || g.console.toLowerCase().contains(q)).toList();
    }

    // Lọc theo hệ máy (Hỗ trợ toàn diện 12 hệ máy)
    if (_selectedSystem != 'ALL') {
      final s = _selectedSystem.toLowerCase();
      if (s == 'gbc') {
        list = list.where((g) => g.console.toLowerCase() == 'gbc' || g.console.toLowerCase() == 'gb').toList();
      } else if (s == 'psx') {
        list = list.where((g) => g.console.toLowerCase() == 'psx' || g.console.toLowerCase() == 'ps1').toList();
      } else if (s == 'genesis') {
        list = list.where((g) => g.console.toLowerCase() == 'genesis' || g.console.toLowerCase() == 'sega').toList();
      } else {
        list = list.where((g) => g.console.toLowerCase() == s).toList();
      }
    }

    // Lọc theo trạng thái
    if (_selectedFilter == 'FAVORITE') {
      list = list.where((g) => g.isFavorite).toList();
    } else if (_selectedFilter == 'CONTINUE') {
      list = list.where((g) => g.hasSaveState).toList();
    } else if (_selectedFilter == 'RECENT') {
      list.sort((a, b) => (b.lastPlayed ?? DateTime(1970)).compareTo(a.lastPlayed ?? DateTime(1970)));
    } else if (_selectedFilter == 'AZ') {
      list.sort((a, b) => a.title.compareTo(b.title));
    }

    return list;
  }

  /// Chọn file game từ máy tính hoặc điện thoại (.zip, .nes, .gba, .sfc...)
  Future<void> pickAndImportGame() async {
    try {
      setState(() {
        _isImporting = true;
      });

      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: RomManager.supportedExtensions.toList(),
        dialogTitle: 'Chọn file game (.zip, .nes, .gba, .nds, .iso...)',
      );

      if (files.isNotEmpty && files.first.path != null) {
        final filePath = files.first.path!;
        final importedGame = await RomManager.importFileFromDevice(filePath);

        if (importedGame != null && mounted) {
          await refreshLibrary();
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF131C31),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
              ),
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đã thêm "${importedGame.title}" vào thư viện!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'CHƠI NGAY',
                textColor: const Color(0xFFD4AF37),
                onPressed: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  _launchGame(importedGame, false);
                },
              ),
            ),
          );

          // Tự động đóng thông báo sau đúng 4 giây
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Không thể đọc file ROM. Vui lòng kiểm tra lại định dạng file!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Lỗi khi thêm file: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  /// Quét tự động toàn bộ thư mục trên máy để nạp hàng loạt ROM cho 12 hệ máy
  Future<void> scanAndImportFolder() async {
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Chọn thư mục chứa ROMs để quét tự động',
      );

      if (selectedDirectory == null || selectedDirectory.isEmpty) return;

      int cur = 0;
      int tot = 0;
      String currentFileName = '';

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131C31),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
              ),
              title: const Row(
                children: [
                  Icon(Icons.folder_copy, color: Color(0xFF00E5FF)),
                  SizedBox(width: 10),
                  Text('Đang quét thư mục ROM...', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hệ thống đang tự động dò tìm và phân loại 12 hệ máy...',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: tot > 0 ? (cur / tot).clamp(0.0, 1.0) : null,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tot > 0 ? 'Đã tìm thấy: $cur / $tot game' : 'Đang duyệt cây thư mục...',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (currentFileName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      currentFileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );

      final imported = await RomManager.scanDirectoryForRoms(
        selectedDirectory,
        onProgress: (c, t, fn) {
          cur = c;
          tot = t;
          currentFileName = fn;
        },
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Đóng hộp thoại
      }

      await refreshLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF131C31),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF00E5FF)),
            ),
            content: Text(
              '🎉 Đã quét xong! Đã nạp thành công ${imported.length} game vào thư viện.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Lỗi khi quét thư mục: $e')),
        );
      }
    }
  }

  /// Chọn file save state (.sav)
  Future<void> pickSaveState() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sav', 'state', 'srm'],
        dialogTitle: 'Chọn file bản lưu game (.sav, .state)',
      );

      if (files.isNotEmpty && files.first.path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Đã nhận diện file save: ${files.first.name}'),
          ),
        );
      }
    } catch (_) {}
  }

  void _launchGame(GameItem game, bool hostClan) async {
    ScaffoldMessenger.of(context).clearSnackBars();
    await RomManager.recordPlayed(game);

    if (hostClan) {
      await widget.clanService.startClanRoom(
        roomName: 'Phòng ${game.title}',
        gameTitle: game.title,
      );
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmulatorScreen(
            game: game,
            clanService: widget.clanService,
            isHost: hostClan,
          ),
        ),
      );
      refreshLibrary();
    }
  }

  void _confirmDelete(GameItem game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131C31),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        title: const Text('Xác nhận xóa game', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${game.title}" khỏi thư viện?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await RomManager.deleteGame(game);
              await refreshLibrary();
            },
            child: const Text('Xóa vĩnh viễn', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. THANH TÌM KIẾM ĐẦU TRANG
        _buildTopSearchBar(),

        // 2. DÒNG LỌC 1: HỆ MÁY (TẤT CẢ, NES, SNES, GBA, NEOGEO...) + NÚT LIST/GRID
        _buildSystemFilterRow(),

        // 3. DÒNG LỌC 2: PHÂN LOẠI (TẤT CẢ, GẦN ĐÂY, YÊU THÍCH, TIẾP TỤC, A-Z)
        _buildStateFilterRow(),

        // 4. DANH SÁCH GAME HOẶC MÀN HÌNH RỖNG
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
              : _filteredGames.isEmpty
                  ? _buildEmptyState()
                  : _isGridView
                      ? _buildGridView()
                      : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildTopSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      color: const Color(0xFF0F1626),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1A253F),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2B3C63)),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: AppLanguage.tr('search_placeholder'),
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF29A3FF), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildTopIconBtn(Icons.drive_folder_upload, const Color(0xFF00E5FF), scanAndImportFolder, 'Quét thư mục ROM'),
          const SizedBox(width: 6),
          _buildTopIconBtn(Icons.travel_explore, const Color(0xFF29A3FF), widget.onOpenStore, 'Kho Retrostic'),
          const SizedBox(width: 6),
          _buildTopIconBtn(Icons.wifi_tethering, const Color(0xFF00FF88), widget.onOpenLan, 'Sảnh Mạng LAN'),
        ],
      ),
    );
  }

  Widget _buildTopIconBtn(IconData icon, Color color, VoidCallback onTap, String tooltip) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1A253F),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildSystemFilterRow() {
    return Container(
      height: 42,
      color: const Color(0xFF0F1626),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _systems.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 4),
              itemBuilder: (ctx, idx) {
                final sys = _systems[idx];
                final isSelected = _selectedSystem == sys['key'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSystem = sys['key']!;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFF162035),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF29A3FF) : const Color(0xFF223150),
                      ),
                    ),
                    child: Text(
                      (sys['key'] == 'ALL' ? AppLanguage.tr('filter_all') : sys['label']!),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          // View Mode Switcher
          InkWell(
            onTap: () => setState(() => _isGridView = !_isGridView),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                _isGridView ? Icons.view_list : Icons.grid_view,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateFilterRow() {
    return Container(
      height: 38,
      color: const Color(0xFF0F1626),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        children: _filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedFilter = f['key']!;
                  });
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFF162035),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF29A3FF) : const Color(0xFF223150),
                    ),
                  ),
                  child: Text(
                    (f['key'] == 'ALL'
                        ? AppLanguage.tr('filter_all')
                        : f['key'] == 'RECENT'
                            ? AppLanguage.tr('filter_recent')
                            : f['key'] == 'FAVORITE'
                                ? AppLanguage.tr('filter_favorites')
                                : f['key'] == 'CONTINUE'
                                    ? AppLanguage.tr('filter_continue')
                                    : 'A–Z'),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF162035),
                border: Border.all(color: const Color(0xFF29A3FF).withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF1E88E5).withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.sports_esports, size: 64, color: Color(0xFF29A3FF)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thư viện game đang rỗng',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bấm nút bên dưới để chọn file ROM (.zip, .nes, .gba...) bạn vừa tải về từ Retrostic để vào chơi ngay!',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Nút thêm game lớn nổi bật
            SizedBox(
              width: 260,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 6,
                ),
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle, size: 22),
                label: Text(
                  _isImporting ? 'Đang thêm file...' : '➕ THÊM GAME TỪ MÁY',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _isImporting ? null : pickAndImportGame,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _filteredGames.length,
      itemBuilder: (ctx, idx) {
        final game = _filteredGames[idx];
        return _buildRetroGameCard(game);
      },
    );
  }

  Widget _buildGridView() {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 900 ? 4 : (width > 550 ? 3 : 2);

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _filteredGames.length,
      itemBuilder: (ctx, idx) {
        final game = _filteredGames[idx];
        return _buildRetroGridCard(game);
      },
    );
  }

  /// Card game phong cách RetroFun chính xác theo ảnh mẫu
  Widget _buildRetroGameCard(GameItem game) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131C31),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E2D4A)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. CỤM PREVIEW: [BÌA] và [INGAME]
                _buildThumbnails(game),
                const SizedBox(width: 10),

                // 2. TIÊU ĐỀ & THÔNG TIN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${game.console.toUpperCase()} · ${game.hasSaveState ? "CÓ BẢN LƯU" : "SẴN SÀNG"}',
                        style: TextStyle(
                          color: game.hasSaveState ? const Color(0xFF00FF88) : const Color(0xFF29A3FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. CỤM 4 NÚT HÀNH ĐỘNG ARCADE CHUYÊN BIỆT
                _buildActionButtons(game),
              ],
            ),
          ),

          // Thanh phụ bên dưới hiển thị tên & tag console như ảnh mẫu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF1A2640),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    game.title,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  game.console.toUpperCase(),
                  style: const TextStyle(color: Color(0xFFF5A623), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnails(GameItem game) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab BÌA (Cover Boxart)
        _buildThumbBox('BÌA', game.coverUrl, Icons.album, const Color(0xFFF5A623)),
        const SizedBox(width: 4),
        // Tab INGAME (Gameplay Snapshot)
        _buildThumbBox('INGAME', game.inGamePreviewUrl, Icons.tv, const Color(0xFF9C27B0)),
      ],
    );
  }

  Widget _buildThumbBox(String badge, String? imageUrl, IconData fallbackIcon, Color badgeColor) {
    return Stack(
      children: [
        Container(
          width: 62,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1D),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2B3C63)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38),
                        ),
                      );
                    },
                    errorBuilder: (ctx, err, stack) => Icon(fallbackIcon, color: Colors.white24, size: 26),
                  )
                : Icon(fallbackIcon, color: Colors.white24, size: 26),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              badge,
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(GameItem game) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nút 1: Chơi mới (Vàng)
        _buildSquareBtn(
          icon: Icons.play_arrow_rounded,
          bgColor: const Color(0xFFF5A623),
          borderColor: const Color(0xFFFFD166),
          tooltip: 'Chơi mới',
          onTap: () => _launchGame(game, false),
        ),
        const SizedBox(width: 5),

        // Nút 2: Tiếp tục từ bản lưu (Xanh lá)
        _buildSquareBtn(
          icon: Icons.play_circle_fill,
          bgColor: const Color(0xFF4CAF50),
          borderColor: const Color(0xFF81C784),
          tooltip: 'Tiếp tục bản lưu',
          onTap: () => _launchGame(game, false),
        ),
        const SizedBox(width: 5),

        // Nút 3: Yêu thích (Ngôi sao)
        _buildSquareBtn(
          icon: game.isFavorite ? Icons.star : Icons.star_border,
          bgColor: game.isFavorite ? const Color(0xFFFFB300) : const Color(0xFF223150),
          borderColor: const Color(0xFFFFD54F),
          tooltip: 'Yêu thích',
          onTap: () async {
            await RomManager.toggleFavorite(game);
            refreshLibrary();
          },
        ),
        const SizedBox(width: 5),

        // Nút 4: Xóa (Thùng rác đỏ)
        _buildSquareBtn(
          icon: Icons.delete_outline,
          bgColor: const Color(0xFFE53935),
          borderColor: const Color(0xFFEF5350),
          tooltip: 'Xóa game',
          onTap: () => _confirmDelete(game),
        ),
      ],
    );
  }

  Widget _buildSquareBtn({
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildRetroGridCard(GameItem game) {
    final imageUrl = game.coverUrl ?? game.inGamePreviewUrl;

    return InkWell(
      onTap: () => _launchGame(game, false),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131C31),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E2D4A), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. KHU VỰC AVATAR / BÌA GAME
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      child: Container(
                        color: const Color(0xFF0A0F1D),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                                    ),
                                  );
                                },
                                errorBuilder: (ctx, err, stack) {
                                  // Dự phòng: nếu ảnh bìa không tải được thì thử ảnh chụp trong game
                                  if (imageUrl == game.coverUrl &&
                                      game.inGamePreviewUrl != null &&
                                      game.inGamePreviewUrl!.isNotEmpty) {
                                    return Image.network(
                                      game.inGamePreviewUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err2, stack2) => const Center(
                                        child: Icon(Icons.sports_esports, size: 48, color: Color(0xFF29A3FF)),
                                      ),
                                    );
                                  }
                                  return const Center(
                                    child: Icon(Icons.sports_esports, size: 48, color: Color(0xFF29A3FF)),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(Icons.sports_esports, size: 48, color: Color(0xFF29A3FF)),
                              ),
                      ),
                    ),
                  ),

                  // Huy hiệu Hệ máy góc trên bên trái
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5A623),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                      ),
                      child: Text(
                        game.console.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Huy hiệu "BẢN LƯU" góc trên bên phải nếu có save
                  if (game.hasSaveState)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.save, size: 10, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'LƯU',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. PHẦN THÔNG TIN VÀ NÚT ĐIỀU KHIỂN DƯỚI
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    game.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Nút Chơi / Tiếp tục
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5A623),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 14),
                          label: const Text('Chơi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _launchGame(game, false),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Nút LAN Room
                      InkWell(
                        onTap: () => _launchGame(game, true),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2D4A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.wifi_tethering, color: Colors.greenAccent, size: 16),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Nút Yêu thích
                      InkWell(
                        onTap: () async {
                          await RomManager.toggleFavorite(game);
                          refreshLibrary();
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2D4A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            game.isFavorite ? Icons.star : Icons.star_border,
                            color: game.isFavorite ? const Color(0xFFFFB300) : Colors.white60,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

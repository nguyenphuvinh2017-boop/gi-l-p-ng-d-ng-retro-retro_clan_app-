import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_item.dart';
import 'retro_metadata_service.dart';

class RomManager {
  static const String _prefsKey = 'downloaded_games';

  /// Thư mục lưu trữ ROM cục bộ
  static Future<Directory> getRomDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final romDir = Directory('${docs.path}/retro_roms');
    if (!await romDir.exists()) {
      await romDir.create(recursive: true);
    }
    return romDir;
  }

  static bool _isEnsuring = false;

  /// Tự động nạp game mặc định (Neo Bomberman) và BIOS Neo Geo sẵn sàng chơi ngay
  static Future<void> ensureDefaultGames() async {
    if (_isEnsuring) return;
    _isEnsuring = true;
    try {
      final romDir = await getRomDirectory();

      // 1. Sao chép BIOS neogeo.zip nếu chưa có
      final biosFile = File('${romDir.path}/neogeo.zip');
      if (!await biosFile.exists()) {
        try {
          final biosData = await rootBundle.load('assets/emulator/neogeo.zip');
          await biosFile.writeAsBytes(biosData.buffer.asUint8List(), flush: true);
        } catch (_) {}
      }

      // 2. Sao chép ROM Neo Bomberman nếu chưa có
      final targetRom = File('${romDir.path}/neobombe.zip');
      if (!await targetRom.exists()) {
        try {
          final romData = await rootBundle.load('assets/emulator/neobombe.zip');
          await targetRom.writeAsBytes(romData.buffer.asUint8List(), flush: true);
        } catch (_) {}
      }

      // 3. Đưa Neo Bomberman vào thư viện nếu chưa có
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_prefsKey) ?? [];
      final hasBomber = rawList.any((s) => s.toLowerCase().contains('bomber') || s.toLowerCase().contains('neobombe'));

      if (!hasBomber && await targetRom.exists()) {
        final length = await targetRom.length();
        final defaultGame = GameItem(
          title: 'Neo Bomberman',
          console: 'arcade',
          pageUrl: '',
          coverUrl: 'https://raw.githubusercontent.com/libretro-thumbnails/SNK_-_Neo_Geo/master/Named_Boxarts/Neo%20Bomberman.png',
          inGamePreviewUrl: 'https://raw.githubusercontent.com/libretro-thumbnails/SNK_-_Neo_Geo/master/Named_Snaps/Neo%20Bomberman.png',
          localRomPath: targetRom.path,
          isDownloaded: true,
          fileSize: '${(length / (1024 * 1024)).toStringAsFixed(2)} MB',
        );
        await saveGameToLibrary(defaultGame);
      }
    } catch (e) {
      // Bỏ qua nếu có lỗi nạp assets ngầm
    } finally {
      _isEnsuring = false;
    }
  }

  /// Lấy danh sách game đã thêm vào thư viện (Bắt đầu với game sẵn có nếu máy mới)
  static Future<List<GameItem>> getInstalledGames() async {
    final prefs = await SharedPreferences.getInstance();
    var rawList = prefs.getStringList(_prefsKey) ?? [];

    if (rawList.isEmpty) {
      await ensureDefaultGames();
      rawList = prefs.getStringList(_prefsKey) ?? [];
    }

    final List<GameItem> list = [];

    for (var str in rawList) {
      try {
        final item = GameItem.fromJson(jsonDecode(str));
        if (item.localRomPath != null && await File(item.localRomPath!).exists()) {
          // Tự động bổ sung ảnh BÌA và INGAME nếu game chưa có hoặc là tên mã ngắn (như mslug5)
          final isShort = item.title.length <= 8 && !item.title.contains(' ');
          final noImages = item.coverUrl == null || item.inGamePreviewUrl == null || item.coverUrl!.isEmpty || item.inGamePreviewUrl!.isEmpty;
          final isRawCover = item.coverUrl != null && (item.coverUrl!.contains('.zip') || item.coverUrl!.endsWith('mslug5.png'));

          if (noImages || isShort || isRawCover) {
            final fileName = File(item.localRomPath!).uri.pathSegments.last;
            final meta = RetroMetadataService.resolveMetadata(
              rawFileName: fileName,
              defaultConsole: item.console,
            );
            final enriched = item.copyWith(
              title: meta['title'] ?? item.title,
              coverUrl: meta['cover'] ?? item.coverUrl,
              inGamePreviewUrl: meta['snap'] ?? item.inGamePreviewUrl,
              console: meta['console'] ?? item.console,
            );
            list.add(enriched);
          } else {
            list.add(item);
          }
        }
      } catch (_) {}
    }

    return list;
  }

  /// Lưu thông tin game vào thư viện
  static Future<void> saveGameToLibrary(GameItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getInstalledGames();
    list.removeWhere((g) => g.title == item.title || g.localRomPath == item.localRomPath);
    list.insert(0, item);

    final rawList = list.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(_prefsKey, rawList);
  }

  /// Xóa game khỏi thư viện và xóa file trên ổ cứng
  static Future<void> deleteGame(GameItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getInstalledGames();
    list.removeWhere((g) => g.title == item.title || g.localRomPath == item.localRomPath);

    final rawList = list.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(_prefsKey, rawList);

    if (item.localRomPath != null) {
      try {
        final file = File(item.localRomPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Đánh dấu hoặc bỏ yêu thích game
  static Future<void> toggleFavorite(GameItem item) async {
    final updated = item.copyWith(isFavorite: !item.isFavorite);
    await saveGameToLibrary(updated);
  }

  /// Ghi nhận vừa chơi game
  static Future<void> recordPlayed(GameItem item) async {
    final updated = item.copyWith(
      lastPlayed: DateTime.now(),
      hasSaveState: true,
    );
    await saveGameToLibrary(updated);
  }

  static final Set<String> supportedExtensions = {
    'nes', 'smc', 'sfc', 'fig', 'gba', 'gbc', 'gb', 'nds',
    'iso', 'chd', 'pbp', 'cso', 'bin', 'img', 'cue',
    'z64', 'n64', 'v64', 'md', 'gen', 'smd', '3ds', 'cia',
    'zip', '7z', 'neo'
  };

  static String detectConsole(String extension, String fileName) {
    final e = extension.toLowerCase();
    final fn = fileName.toLowerCase();
    if (e == 'nes') return 'nes';
    if (e == 'smc' || e == 'sfc' || e == 'fig') return 'snes';
    if (e == 'gba') return 'gba';
    if (e == 'gbc') return 'gbc';
    if (e == 'gb') return 'gb';
    if (e == 'nds') return 'nds';
    if (e == 'cso') return 'psp';
    if (e == 'pbp') return fn.contains('psp') ? 'psp' : 'psx';
    if (e == 'iso' || e == 'cue' || e == 'chd' || e == 'bin' || e == 'img') {
      if (fn.contains('psp')) return 'psp';
      if (fn.contains('ps2')) return 'ps2';
      return 'psx';
    }
    if (e == 'z64' || e == 'n64' || e == 'v64') return 'n64';
    if (e == 'md' || e == 'gen' || e == 'smd') return 'genesis';
    if (e == '3ds' || e == 'cia') return '3ds';
    if (e == 'neo') return 'arcade';
    return 'nes';
  }

  /// Quét đệ quy toàn bộ thư mục trên thiết bị để tìm và tự động nạp tất cả game
  static Future<List<GameItem>> scanDirectoryForRoms(
    String dirPath, {
    Function(int current, int total, String currentFile)? onProgress,
  }) async {
    final rootDir = Directory(dirPath);
    if (!await rootDir.exists()) return [];

    final List<File> candidateFiles = [];
    try {
      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = entity.uri.pathSegments.last.split('.').last.toLowerCase();
          if (supportedExtensions.contains(ext)) {
            final fn = entity.uri.pathSegments.last.toLowerCase();
            if (!fn.contains('bios') && !fn.startsWith('.')) {
              candidateFiles.add(entity);
            }
          }
        }
      }
    } catch (_) {}

    final List<GameItem> importedGames = [];
    final total = candidateFiles.length;

    for (int i = 0; i < candidateFiles.length; i++) {
      final f = candidateFiles[i];
      onProgress?.call(i + 1, total, f.uri.pathSegments.last);
      try {
        final item = await importFileFromDevice(f.path);
        if (item != null) {
          importedGames.add(item);
        }
      } catch (_) {}
    }

    return importedGames;
  }

  /// Thêm file game được người dùng chọn từ máy (.zip, .nes, .gba, .smc, .sfc...)
  static Future<GameItem?> importFileFromDevice(String sourceFilePath) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) return null;

      final romDir = await getRomDirectory();
      final bytes = await sourceFile.readAsBytes();
      final originalFileName = sourceFile.uri.pathSegments.last;
      final ext = originalFileName.split('.').last.toLowerCase();

      String? targetRomPath;
      String console = detectConsole(ext, originalFileName);
      String title = originalFileName;

      // Xử lý file nén ZIP
      if ((ext == 'zip' || ext == '7z') && bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
        final archive = ZipDecoder().decodeBytes(bytes);
        ArchiveFile? romEntry;
        int consoleRomCount = 0;

        for (var file in archive) {
          if (file.isFile) {
            final fExt = file.name.split('.').last.toLowerCase();
            if (supportedExtensions.contains(fExt) && fExt != 'zip' && fExt != '7z') {
              romEntry = file;
              consoleRomCount++;
              console = detectConsole(fExt, file.name);
            }
          }
        }

        // CHỈ trích xuất nếu file ZIP là nén của đúng 1 file ROM console (.nes, .gba, .sfc...)
        // Nếu chứa nhiều file (như bộ ROM Arcade neobombe.zip có 37 file) hoặc file .bin:
        // -> Giữ nguyên toàn bộ file .ZIP gốc!
        if (romEntry != null && consoleRomCount == 1 && archive.files.where((f) => f.isFile).length <= 2) {
          // Trích xuất file ROM từ ZIP
          final targetFile = File('${romDir.path}/${romEntry.name}');
          await targetFile.writeAsBytes(romEntry.content as List<int>);
          targetRomPath = targetFile.path;
          title = romEntry.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        } else {
          // Là bộ ROM Arcade / Neo Geo (như neobombe.zip) -> giữ nguyên trọn vẹn file ZIP
          final targetFile = File('${romDir.path}/$originalFileName');
          await targetFile.writeAsBytes(bytes);
          targetRomPath = targetFile.path;
          if (console == 'nes') console = 'arcade';
          title = originalFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        }
      } else {
        // File ROM đơn lẻ (.nes, .gba, .sfc...)
        final targetFile = File('${romDir.path}/$originalFileName');
        await targetFile.writeAsBytes(bytes);
        targetRomPath = targetFile.path;
        title = originalFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      }

      // Tự động giải mã tên chuẩn, ảnh bìa [BÌA] và ảnh [INGAME]
      final meta = RetroMetadataService.resolveMetadata(
        rawFileName: originalFileName,
        defaultConsole: console,
      );
      title = meta['title'] ?? title.replaceAll('_', ' ').replaceAll('-', ' ').trim();
      console = meta['console'] ?? console;
      final coverUrl = meta['cover'];
      final inGamePreviewUrl = meta['snap'];

      final game = GameItem(
        title: title,
        console: console,
        pageUrl: '',
        coverUrl: coverUrl,
        inGamePreviewUrl: inGamePreviewUrl,
        localRomPath: targetRomPath,
        isDownloaded: true,
        fileSize: '${(bytes.length / 1024).toStringAsFixed(1)} KB',
      );

      await saveGameToLibrary(game);
      return game;
    } catch (e) {
      return null;
    }
  }

  /// Tải và giải nén ROM từ URL trực tiếp
  static Future<GameItem?> downloadAndExtract({
    required GameItem game,
    required String downloadUrl,
    required Function(double progress) onProgress,
  }) async {
    try {
      final romDir = await getRomDirectory();
      final client = http.Client();

      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['Referer'] = 'https://www.retrostic.com/';
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final List<int> bytes = [];

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }

      String? extractedRomPath;
      String console = game.console;

      if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
        final archive = ZipDecoder().decodeBytes(bytes);
        ArchiveFile? romFile;

        for (var file in archive) {
          if (file.isFile) {
            final ext = file.name.split('.').last.toLowerCase();
            if (['nes', 'gba', 'smc', 'sfc', 'gb', 'gbc', 'bin'].contains(ext)) {
              romFile = file;
              console = ext == 'smc' || ext == 'sfc' ? 'snes' : ext;
              break;
            }
          }
        }

        if (romFile != null) {
          final targetFile = File('${romDir.path}/${romFile.name}');
          await targetFile.writeAsBytes(romFile.content as List<int>);
          extractedRomPath = targetFile.path;
        } else {
          // Lưu tệp ZIP
          final sanitizedName = game.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
          final targetFile = File('${romDir.path}/$sanitizedName.zip');
          await targetFile.writeAsBytes(bytes);
          extractedRomPath = targetFile.path;
        }
      } else {
        final sanitizedName = game.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
        final targetFile = File('${romDir.path}/$sanitizedName.${game.console}');
        await targetFile.writeAsBytes(bytes);
        extractedRomPath = targetFile.path;
      }

      final updated = game.copyWith(
        console: console,
        localRomPath: extractedRomPath,
        isDownloaded: true,
        fileSize: '${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB',
      );
      await saveGameToLibrary(updated);
      return updated;
    } catch (_) {
      return null;
    }
  }

  /// Đọc dữ liệu ROM thành Base64
  static Future<String?> getRomBase64(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return base64Encode(bytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

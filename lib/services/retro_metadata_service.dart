class RetroMetadataService {
  static const String _libretroBase = 'https://raw.githubusercontent.com/libretro-thumbnails';

  /// Danh mục các game kinh điển có metadata chuẩn sẵn
  static final Map<String, Map<String, String>> _knownGames = {
    'neobombe': {
      'title': 'Neo Bomberman',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Neo%20Bomberman.png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Neo%20Bomberman.png',
    },
    'neo bomberman': {
      'title': 'Neo Bomberman',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Neo%20Bomberman.png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Neo%20Bomberman.png',
    },
    'bomberman': {
      'title': 'Bomberman',
      'console': 'nes',
      'cover': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Boxarts/Bomberman%20(USA).png',
      'snap': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Snaps/Bomberman%20(USA).png',
    },
    'contra': {
      'title': 'Contra',
      'console': 'nes',
      'cover': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Boxarts/Contra%20(USA).png',
      'snap': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Snaps/Contra%20(USA).png',
    },
    'super mario bros 3': {
      'title': 'Super Mario Bros. 3',
      'console': 'nes',
      'cover': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Boxarts/Super%20Mario%20Bros.%203%20(USA).png',
      'snap': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Snaps/Super%20Mario%20Bros.%203%20(USA).png',
    },
    'super mario bros': {
      'title': 'Super Mario Bros.',
      'console': 'nes',
      'cover': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Boxarts/Super%20Mario%20Bros.%20(World).png',
      'snap': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Snaps/Super%20Mario%20Bros.%20(World).png',
    },
    'battle city': {
      'title': 'Battle City (Xe Tăng)',
      'console': 'nes',
      'cover': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Boxarts/Battle%20City%20(Japan).png',
      'snap': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Snaps/Battle%20City%20(Japan).png',
    },
    'metal slug': {
      'title': 'Metal Slug',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%20-%20Super%20Vehicle-001.png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%20-%20Super%20Vehicle-001.png',
    },
    'street fighter': {
      'title': 'Street Fighter II',
      'console': 'snes',
      'cover': '$_libretroBase/Nintendo_-_Super_Nintendo_Entertainment_System/master/Named_Boxarts/Street%20Fighter%20II%20(USA).png',
      'snap': '$_libretroBase/Nintendo_-_Super_Nintendo_Entertainment_System/master/Named_Snaps/Street%20Fighter%20II%20(USA).png',
    },
  };

  /// Tự động nhận diện metadata, ảnh bìa [BÌA] và ảnh [INGAME]
  static Map<String, String?> resolveMetadata({
    required String rawFileName,
    required String defaultConsole,
  }) {
    final clean = rawFileName
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .trim()
        .toLowerCase();

    // 1. Kiểm tra trong kho mapping có sẵn
    for (var key in _knownGames.keys) {
      if (clean.contains(key) || key.contains(clean)) {
        final match = _knownGames[key]!;
        return {
          'title': match['title'],
          'console': match['console'],
          'cover': match['cover'],
          'snap': match['snap'],
        };
      }
    }

    // 2. Tạo URL tự động từ Libretro Thumbnails nếu là hệ máy phổ biến
    String consoleFolder = 'Nintendo_-_Nintendo_Entertainment_System';
    if (defaultConsole == 'snes') {
      consoleFolder = 'Nintendo_-_Super_Nintendo_Entertainment_System';
    } else if (defaultConsole == 'gba') {
      consoleFolder = 'Nintendo_-_Game_Boy_Advance';
    } else if (defaultConsole == 'arcade' || defaultConsole == 'neogeo') {
      consoleFolder = 'SNK_-_Neo_Geo';
    }

    final formattedTitle = rawFileName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    final encodedTitle = Uri.encodeComponent(formattedTitle);

    return {
      'title': formattedTitle,
      'console': defaultConsole,
      'cover': '$_libretroBase/$consoleFolder/master/Named_Boxarts/$encodedTitle.png',
      'snap': '$_libretroBase/$consoleFolder/master/Named_Snaps/$encodedTitle.png',
    };
  }
}

class RetroMetadataService {
  static const String _libretroBase = 'https://raw.githubusercontent.com/libretro-thumbnails';

  /// Danh mục các game kinh điển có metadata chuẩn sẵn
  static final Map<String, Map<String, String>> _knownGames = {
    // Metal Slug Series (MAME / Neo Geo)
    'mslug5': {
      'title': 'Metal Slug 5',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%205%20(NGH-2680).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%205%20(NGH-2680).png',
    },
    'metal slug 5': {
      'title': 'Metal Slug 5',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%205%20(NGH-2680).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%205%20(NGH-2680).png',
    },
    'mslug4': {
      'title': 'Metal Slug 4',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%204%20(NGH-2630).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%204%20(NGH-2630).png',
    },
    'metal slug 4': {
      'title': 'Metal Slug 4',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%204%20(NGH-2630).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%204%20(NGH-2630).png',
    },
    'mslug3': {
      'title': 'Metal Slug 3',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%203%20(NGH-2560).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%203%20(NGH-2560).png',
    },
    'metal slug 3': {
      'title': 'Metal Slug 3',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%203%20(NGH-2560).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%203%20(NGH-2560).png',
    },
    'mslug2': {
      'title': 'Metal Slug 2',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%202%20-%20Super%20Vehicle-001_II%20(NGM-2410)%20(NGH-2410).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%202%20-%20Super%20Vehicle-001_II%20(NGM-2410)%20(NGH-2410).png',
    },
    'metal slug 2': {
      'title': 'Metal Slug 2',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%202%20-%20Super%20Vehicle-001_II%20(NGM-2410)%20(NGH-2410).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%202%20-%20Super%20Vehicle-001_II%20(NGM-2410)%20(NGH-2410).png',
    },
    'mslugx': {
      'title': 'Metal Slug X',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%20X%20-%20Super%20Vehicle-001%20(NGM-2500)(NGH-2500).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%20X%20-%20Super%20Vehicle-001%20(NGM-2500)(NGH-2500).png',
    },
    'metal slug x': {
      'title': 'Metal Slug X',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%20X%20-%20Super%20Vehicle-001%20(NGM-2500)(NGH-2500).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%20X%20-%20Super%20Vehicle-001%20(NGM-2500)(NGH-2500).png',
    },
    'mslug': {
      'title': 'Metal Slug',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%20-%20Super%20Vehicle-001.png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%20-%20Super%20Vehicle-001.png',
    },
    'metal slug': {
      'title': 'Metal Slug',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Metal%20Slug%20-%20Super%20Vehicle-001.png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Metal%20Slug%20-%20Super%20Vehicle-001.png',
    },

    // Neo Bomberman
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

    // The King of Fighters Series
    'kof97': {
      'title': "The King of Fighters '97",
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/The%20King%20of%20Fighters%20\'97%20(NGH-2320).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/The%20King%20of%20Fighters%20\'97%20(NGH-2320).png',
    },
    'kof98': {
      'title': "The King of Fighters '98",
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/The%20King%20of%20Fighters%20\'98%20-%20The%20Slugfest%20_%20King%20of%20Fighters%20\'98%20-%20dream%20match%20never%20ends%20(NGH-2420).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/The%20King%20of%20Fighters%20\'98%20-%20The%20Slugfest%20_%20King%20of%20Fighters%20\'98%20-%20dream%20match%20never%20ends%20(NGH-2420).png',
    },
    'kof2002': {
      'title': "The King of Fighters 2002",
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/The%20King%20of%20Fighters%202002%20-%20Challenge%20to%20Ultimate%20Battle%20(NGH-2650).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/The%20King%20of%20Fighters%202002%20-%20Challenge%20to%20Ultimate%20Battle%20(NGH-2650).png',
    },

    // Samurai Shodown
    'samsho': {
      'title': 'Samurai Shodown',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Samurai%20Shodown%20(NGH-045).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Samurai%20Shodown%20(NGH-045).png',
    },
    'samsho2': {
      'title': 'Samurai Shodown II',
      'console': 'arcade',
      'cover': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Boxarts/Samurai%20Shodown%20II%20(NGH-063).png',
      'snap': '$_libretroBase/SNK_-_Neo_Geo/master/Named_Snaps/Samurai%20Shodown%20II%20(NGH-063).png',
    },

    // Cadillacs and Dinosaurs & Capcom Arcade
    'dino': {
      'title': 'Cadillacs and Dinosaurs (Bộ đội)',
      'console': 'arcade',
      'cover': '$_libretroBase/FBNeo_-_Arcade_Games/master/Named_Boxarts/dino.png',
      'snap': '$_libretroBase/FBNeo_-_Arcade_Games/master/Named_Snaps/dino.png',
    },
    'wof': {
      'title': 'Warriors of Fate (Tam Quốc)',
      'console': 'arcade',
      'cover': '$_libretroBase/FBNeo_-_Arcade_Games/master/Named_Boxarts/wof.png',
      'snap': '$_libretroBase/FBNeo_-_Arcade_Games/master/Named_Snaps/wof.png',
    },
    'punisher': {
      'title': 'The Punisher',
      'console': 'arcade',
      'cover': '$_libretroBase/FBNeo_-_Arcade_Games/master/Named_Boxarts/punisher.png',
      'snap': '$_libretroBase/FBNeo_-_Arcade_Games/master/Named_Snaps/punisher.png',
    },

    // Kinh điển NES & SNES
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
      'title': 'Battle City (Bắn Xe Tăng)',
      'console': 'nes',
      'cover': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Boxarts/Battle%20City%20(Japan).png',
      'snap': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Snaps/Battle%20City%20(Japan).png',
    },
    'tank': {
      'title': 'Battle City (Bắn Xe Tăng)',
      'console': 'nes',
      'cover': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Boxarts/Battle%20City%20(Japan).png',
      'snap': '$_libretroBase/Nintendo_-_Nintendo_Entertainment_System/master/Named_Snaps/Battle%20City%20(Japan).png',
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

    final noSpace = clean.replaceAll(' ', '');

    // 1. Kiểm tra chính xác hoặc chứa trong kho mapping có sẵn
    for (var key in _knownGames.keys) {
      final keyClean = key.replaceAll(' ', '');
      if (clean == key || noSpace == keyClean || clean.contains(key) || (key.length >= 4 && clean.contains(key))) {
        final match = _knownGames[key]!;
        return {
          'title': match['title'],
          'console': match['console'],
          'cover': match['cover'],
          'snap': match['snap'],
        };
      }
    }

    // 2. Tạo URL tự động từ Libretro Thumbnails cho toàn bộ 12 hệ máy
    String consoleFolder = 'Nintendo_-_Nintendo_Entertainment_System';
    final c = defaultConsole.toLowerCase();
    if (c == 'snes') {
      consoleFolder = 'Nintendo_-_Super_Nintendo_Entertainment_System';
    } else if (c == 'gba') {
      consoleFolder = 'Nintendo_-_Game_Boy_Advance';
    } else if (c == 'gbc') {
      consoleFolder = 'Nintendo_-_Game_Boy_Color';
    } else if (c == 'gb') {
      consoleFolder = 'Nintendo_-_Game_Boy';
    } else if (c == 'nds') {
      consoleFolder = 'Nintendo_-_Nintendo_DS';
    } else if (c == 'psx' || c == 'ps1') {
      consoleFolder = 'Sony_-_PlayStation';
    } else if (c == 'psp') {
      consoleFolder = 'Sony_-_PlayStation_Portable';
    } else if (c == 'ps2') {
      consoleFolder = 'Sony_-_PlayStation_2';
    } else if (c == 'n64') {
      consoleFolder = 'Nintendo_-_Nintendo_64';
    } else if (c == 'genesis' || c == 'sega') {
      consoleFolder = 'Sega_-_Mega_Drive_-_Genesis';
    } else if (c == 'arcade' || c == 'neogeo') {
      consoleFolder = 'SNK_-_Neo_Geo';
    } else if (c == 'mame') {
      consoleFolder = 'MAME';
    } else if (c == '3ds') {
      consoleFolder = 'Nintendo_-_Nintendo_3DS';
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

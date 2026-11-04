import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/game_item.dart';

class RetrosticService {
  static const String baseUrl = 'https://www.retrostic.com';
  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Consoles supported on Retrostic
  static const List<Map<String, String>> supportedConsoles = [
    {'name': 'Nintendo NES (4 Nút)', 'slug': 'nes', 'icon': 'videogame_asset'},
    {'name': 'Super Nintendo (SNES)', 'slug': 'snes', 'icon': 'sports_esports'},
    {'name': 'Game Boy Advance (GBA)', 'slug': 'gba', 'icon': 'gamepad'},
    {'name': 'Game Boy Color (GBC)', 'slug': 'gbc', 'icon': 'phone_android'},
    {'name': 'Sega Genesis (6 Nút)', 'slug': 'genesis', 'icon': 'tv'},
    {'name': 'Nintendo 64 (N64)', 'slug': 'n64', 'icon': 'casino'},
    {'name': 'PlayStation 1 (PS1)', 'slug': 'ps-1', 'icon': 'album'},
  ];

  /// Get games for a console
  Future<List<GameItem>> getConsoleGames(String consoleSlug, {int page = 1}) async {
    try {
      final url = Uri.parse('$baseUrl/roms/$consoleSlug${page > 1 ? '?page=$page' : ''}');
      final response = await http.get(url, headers: defaultHeaders);

      if (response.statusCode != 200) {
        return _getFallbackGames(consoleSlug);
      }

      final document = html_parser.parse(response.body);
      final List<GameItem> games = [];

      // Find all game cards or links
      final gameLinks = document.querySelectorAll('a[href*="/roms/$consoleSlug/"]');
      final seenSlugs = <String>{};

      for (var element in gameLinks) {
        final href = element.attributes['href'] ?? '';
        if (href.endsWith('/download') || href.contains('?')) continue;
        
        // Match console/game pattern
        final segments = href.split('/').where((s) => s.isNotEmpty).toList();
        if (segments.length >= 3 && segments[0] == 'roms' && segments[1] == consoleSlug) {
          final gameSlug = segments[2];
          if (seenSlugs.contains(gameSlug)) continue;
          seenSlugs.add(gameSlug);

          var title = element.text.trim();
          if (title.isEmpty) {
            title = gameSlug.replaceAll('-', ' ').toUpperCase();
          }

          // Try to find image nearby
          String? coverUrl;
          final img = element.querySelector('img') ?? element.parent?.querySelector('img');
          if (img != null) {
            coverUrl = img.attributes['src'] ?? img.attributes['data-src'];
            if (coverUrl != null && !coverUrl.startsWith('http')) {
              coverUrl = '$baseUrl$coverUrl';
            }
          }

          games.add(GameItem(
            title: title,
            console: consoleSlug,
            pageUrl: href.startsWith('http') ? href : '$baseUrl$href',
            coverUrl: coverUrl,
          ));
        }
      }

      if (games.isEmpty) {
        return _getFallbackGames(consoleSlug);
      }

      return games;
    } catch (e) {
      print('Retrostic fetch error: $e');
      return _getFallbackGames(consoleSlug);
    }
  }

  /// Search games
  Future<List<GameItem>> searchGames(String query) async {
    try {
      final url = Uri.parse('$baseUrl/search?search_term_string=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: defaultHeaders);

      if (response.statusCode != 200) {
        return [];
      }

      final document = html_parser.parse(response.body);
      final List<GameItem> games = [];
      final seenSlugs = <String>{};

      final gameLinks = document.querySelectorAll('a[href*="/roms/"]');
      for (var element in gameLinks) {
        final href = element.attributes['href'] ?? '';
        if (href.endsWith('/download') || href.endsWith('/roms')) continue;

        final segments = href.split('/').where((s) => s.isNotEmpty).toList();
        if (segments.length >= 3 && segments[0] == 'roms') {
          final console = segments[1];
          final gameSlug = segments[2];
          if (seenSlugs.contains(gameSlug)) continue;
          seenSlugs.add(gameSlug);

          var title = element.text.trim();
          if (title.isEmpty) {
            title = gameSlug.replaceAll('-', ' ').toUpperCase();
          }

          games.add(GameItem(
            title: title,
            console: console,
            pageUrl: href.startsWith('http') ? href : '$baseUrl$href',
          ));
        }
      }

      return games;
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  /// Resolves the direct download URL for a game page
  Future<String?> resolveDirectDownloadUrl(String gamePageUrl) async {
    try {
      final client = http.Client();

      // 1. Visit game page and extract cookies & hidden inputs
      final gameUri = Uri.parse(gamePageUrl);
      final pageRes = await client.get(gameUri, headers: defaultHeaders);
      if (pageRes.statusCode != 200) return null;

      final cookieHeader = pageRes.headers['set-cookie'] ?? '';
      final pageDoc = html_parser.parse(pageRes.body);

      final inputs = <String, String>{};
      for (var input in pageDoc.querySelectorAll('input[type="hidden"]')) {
        final name = input.attributes['name'];
        final val = input.attributes['value'] ?? '';
        if (name != null) inputs[name] = val;
      }

      // If hidden inputs missing, try fallback parsing
      if (!inputs.containsKey('session')) {
        final sessionMatch = RegExp(r'name="session"\s+value="([^"]+)"').firstMatch(pageRes.body);
        if (sessionMatch != null) inputs['session'] = sessionMatch.group(1)!;
      }

      // 2. Submit form to download endpoint
      final downloadUrl = gamePageUrl.endsWith('/download') ? gamePageUrl : '$gamePageUrl/download';
      final dlHeaders = Map<String, String>.from(defaultHeaders);
      dlHeaders['Referer'] = gamePageUrl;
      dlHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
      if (cookieHeader.isNotEmpty) {
        dlHeaders['Cookie'] = cookieHeader.split(';').first;
      }

      final postRes = await client.post(
        Uri.parse(downloadUrl),
        headers: dlHeaders,
        body: inputs,
      );

      // 3. Search for window.location.href redirect in download page
      final html = postRes.body;
      final redirectRegex = RegExp(r'window\.location\.href\s*=\s*["\x27]([^"\x27]+)["\x27]');
      final match = redirectRegex.firstMatch(html);
      if (match != null) {
        return match.group(1);
      }

      // Secondary search for direct .zip link
      final zipRegex = RegExp(r'href=["\x27](https?://[^"\x27]+\.zip[^"\x27]*)["\x27]');
      final zipMatch = zipRegex.firstMatch(html);
      if (zipMatch != null) {
        return zipMatch.group(1);
      }

      return null;
    } catch (e) {
      print('Download resolution error: $e');
      return null;
    }
  }

  /// Built-in fallback popular multiplayer games with direct links
  static List<GameItem> _getFallbackGames(String consoleSlug) {
    if (consoleSlug == 'nes') {
      return [
        GameItem(
          title: 'Contra (USA)',
          console: 'nes',
          pageUrl: 'https://www.retrostic.com/roms/nes/contra-388',
          coverUrl: 'https://images.retrostic.com/boxarts/nes/contra-388.jpg',
        ),
        GameItem(
          title: 'Super Mario Bros 3 (USA)',
          console: 'nes',
          pageUrl: 'https://www.retrostic.com/roms/nes/super-mario-bros-3-83138',
          coverUrl: 'https://images.retrostic.com/boxarts/nes/super-mario-bros-3-83138.jpg',
        ),
        GameItem(
          title: 'Teenage Mutant Ninja Turtles III - The Manhattan Project',
          console: 'nes',
          pageUrl: 'https://www.retrostic.com/roms/nes/teenage-mutant-ninja-turtles-iii-the-manhattan-project-83344',
        ),
        GameItem(
          title: 'Battle City (Japan)',
          console: 'nes',
          pageUrl: 'https://www.retrostic.com/roms/nes/battle-city-80860',
        ),
        GameItem(
          title: 'Double Dragon II - The Revenge',
          console: 'nes',
          pageUrl: 'https://www.retrostic.com/roms/nes/double-dragon-ii-the-revenge-81347',
        ),
        GameItem(
          title: 'Chip \'n Dale Rescue Rangers',
          console: 'nes',
          pageUrl: 'https://www.retrostic.com/roms/nes/chip-n-dale-rescue-rangers-81073',
        ),
      ];
    }
    return [];
  }
}

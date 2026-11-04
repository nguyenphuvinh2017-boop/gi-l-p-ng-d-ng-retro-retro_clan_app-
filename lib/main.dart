import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/browse_retrostic_screen.dart';
import 'screens/clan_lobby_screen.dart';
import 'services/clan_netplay_service.dart';
import 'services/rom_manager.dart';
import 'widgets/app_settings_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  runApp(const RetroClanApp());
  // Tự động kiểm tra và giải nén game mặc định trong nền không chặn hiển thị
  RomManager.ensureDefaultGames();
}

class RetroClanApp extends StatelessWidget {
  const RetroClanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retro Clan Play',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D18),
        primaryColor: const Color(0xFF1E88E5),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1E88E5),
          secondary: Color(0xFF29A3FF),
          surface: Color(0xFF131C31),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1626),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final ClanNetplayService _clanService = ClanNetplayService();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<ClanLobbyScreenState> _clanLobbyKey = GlobalKey<ClanLobbyScreenState>();

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    _clanService.stopAll();
    super.dispose();
  }

  void _onBottomDockTapped(int index) {
    if (index == 0) {
      // 1. MÀN HÌNH CHÍNH (Về thư viện game)
      setState(() {
        _currentIndex = 0;
      });
    } else if (index == 1) {
      // 2. THÊM GAME (Mở trình chọn file ROM để nhập vào máy)
      _homeKey.currentState?.pickAndImportGame();
    } else if (index == 2) {
      // 3. MẠNG LAN
      setState(() {
        _currentIndex = 2;
      });
      _clanLobbyKey.currentState?.refreshGames();
    } else if (index == 3) {
      // 4. ONLINE (Kho game Retrostic)
      setState(() {
        _currentIndex = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        key: _homeKey,
        clanService: _clanService,
        onOpenStore: () => setState(() => _currentIndex = 1),
        onOpenLan: () {
          setState(() => _currentIndex = 2);
          _clanLobbyKey.currentState?.refreshGames();
        },
      ),
      BrowseRetrosticScreen(
        clanService: _clanService,
        onGameDownloaded: () {
          _homeKey.currentState?.refreshLibrary();
          _clanLobbyKey.currentState?.refreshGames();
        },
      ),
      ClanLobbyScreen(key: _clanLobbyKey, clanService: _clanService),
    ];

    return Scaffold(
      // Top AppBar mang phong cách RetroFun
      appBar: AppBar(
        title: Row(
          children: [
            // Logo RetroClan chính thức
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF29A3FF).withValues(alpha: 0.4), blurRadius: 6),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icon.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF29A3FF), Color(0xFF9C27B0), Color(0xFFFF2A55)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(text: 'Retro', style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'Clan', style: TextStyle(color: Color(0xFF29A3FF))),
                    ],
                  ),
                ),
                const Text(
                  'PLAY CLASSICS ANYWHERE',
                  style: TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1.0, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Nút chuyển về Thư viện
          if (_currentIndex != 0)
            IconButton(
              icon: const Icon(Icons.collections_bookmark, color: Color(0xFF29A3FF)),
              tooltip: 'Về Thư viện',
              onPressed: () => setState(() => _currentIndex = 0),
            ),
          // Nút Cài đặt
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: 'Cài đặt',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const AppSettingsDialog(),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),

      // DOCK ĐIỀU HƯỚNG 4 NÚT PHONG CÁCH RETROFUN
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF080C16),
          border: const Border(top: BorderSide(color: Color(0xFF1B2A4A), width: 1.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. MÀN HÌNH CHÍNH
                _buildDockBtn(
                  index: 0,
                  icon: Icons.sports_esports,
                  label: 'MÀN HÌNH CHÍNH',
                  gradientColors: [const Color(0xFFFFB300), const Color(0xFFE65100)],
                  isActive: _currentIndex == 0,
                ),
                // 2. THÊM GAME
                _buildDockBtn(
                  index: 1,
                  icon: Icons.add_box_rounded,
                  badgeIcon: Icons.add,
                  label: 'THÊM GAME',
                  gradientColors: [const Color(0xFF42A5F5), const Color(0xFF1565C0)],
                  isActive: false,
                ),
                // 3. MẠNG LAN
                _buildDockBtn(
                  index: 2,
                  icon: Icons.lan,
                  label: 'MẠNG LAN',
                  gradientColors: [const Color(0xFF00E5FF), const Color(0xFF0091EA)],
                  isActive: _currentIndex == 2,
                ),
                // 4. ONLINE
                _buildDockBtn(
                  index: 3,
                  icon: Icons.public,
                  label: 'ONLINE',
                  gradientColors: [const Color(0xFF29B6F6), const Color(0xFF0277BD)],
                  isActive: _currentIndex == 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockBtn({
    required int index,
    required IconData icon,
    IconData? badgeIcon,
    required String label,
    required List<Color> gradientColors,
    required bool isActive,
    bool hasNotification = false,
  }) {
    return InkWell(
      onTap: () => _onBottomDockTapped(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isActive ? Colors.white : Colors.white24,
                      width: isActive ? 1.8 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.first.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      if (badgeIcon != null)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Icon(badgeIcon, color: Colors.yellowAccent, size: 10),
                        ),
                    ],
                  ),
                ),
                if (hasNotification)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF29A3FF) : Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

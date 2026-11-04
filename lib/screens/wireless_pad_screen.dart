import 'package:flutter/material.dart';
import '../services/clan_netplay_service.dart';
import '../widgets/arcade_gamepad.dart';

class WirelessPadScreen extends StatefulWidget {
  final ClanNetplayService clanService;
  final String gameTitle;
  final String hostIp;

  const WirelessPadScreen({
    super.key,
    required this.clanService,
    required this.gameTitle,
    required this.hostIp,
  });

  @override
  State<WirelessPadScreen> createState() => _WirelessPadScreenState();
}

class _WirelessPadScreenState extends State<WirelessPadScreen> {
  @override
  void initState() {
    super.initState();
  }

  void _handleButtonEvent(String button, bool isDown) {
    widget.clanService.sendClientInput(button, isDown);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161C),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Người chơi 2 - ${widget.gameTitle}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Row(
              children: [
                const Icon(Icons.wifi, color: Colors.greenAccent, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Đã kết nối tới máy chủ ${widget.hostIp}',
                  style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Thoát phòng',
            onPressed: () {
              widget.clanService.stopAll();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF2A55).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.sports_esports, color: Color(0xFFFF2A55), size: 48),
                        const SizedBox(height: 10),
                        const Text(
                          'TAY CẦM KHÔNG DÂY CLAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bạn đang điều khiển Người chơi 2 (Player 2) trong game "${widget.gameTitle}"',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, color: Colors.greenAccent, size: 16),
                              SizedBox(width: 6),
                              Text('Độ trễ mạng LAN: < 2ms (Siêu tốc)', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bàn phím Arcade Player 2
          ArcadeGamepad(
            onButtonEvent: _handleButtonEvent,
            onOpenMenu: () {},
            onToggleSpeed: () {},
          ),
        ],
      ),
    );
  }
}

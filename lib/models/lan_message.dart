import 'dart:convert';

enum LanMessageType {
  discover,
  beacon,
  join,
  joined,
  input,
  start,
  sync,
  reset,
  ping,
  pong,
  disconnect
}

class LanMessage {
  final LanMessageType type;
  final Map<String, dynamic> payload;

  LanMessage({required this.type, required this.payload});

  String serialize() {
    return jsonEncode({
      'type': type.name,
      'payload': payload,
    });
  }

  static LanMessage? deserialize(String raw) {
    try {
      final map = jsonDecode(raw);
      final typeStr = map['type'] as String?;
      final type = LanMessageType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => LanMessageType.ping,
      );
      return LanMessage(
        type: type,
        payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      );
    } catch (_) {
      return null;
    }
  }
}

class ClanRoomInfo {
  final String roomName;
  final String gameTitle;
  final String hostIp;
  final int port;
  final DateTime lastSeen;

  ClanRoomInfo({
    required this.roomName,
    required this.gameTitle,
    required this.hostIp,
    required this.port,
    required this.lastSeen,
  });
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  static final ValueNotifier<String> currentLocale = ValueNotifier<String>('vi');

  static bool get isEnglish => currentLocale.value == 'en';

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      currentLocale.value = prefs.getString('app_language') ?? 'vi';
    } catch (_) {}
  }

  static Future<void> setLanguage(String code) async {
    currentLocale.value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', code);
    } catch (_) {}
  }

  static String tr(String key) {
    if (currentLocale.value == 'en') {
      return _en[key] ?? _vi[key] ?? key;
    }
    return _vi[key] ?? _en[key] ?? key;
  }

  static const Map<String, String> _vi = {
    // Navigation
    'nav_home': 'MÀN HÌNH CHÍNH',
    'nav_add_game': 'THÊM GAME',
    'nav_lan': 'MẠNG LAN',
    'nav_online': 'ONLINE',

    // Home Filters
    'filter_all': 'TẤT CẢ',
    'filter_recent': 'GẦN ĐÂY',
    'filter_favorites': 'YÊU THÍCH',
    'filter_continue': 'TIẾP TỤC',
    'search_placeholder': 'Tìm trò chơi...',
    'badge_saved': 'CÓ BẢN LƯU',
    'badge_ready': 'SẴN SÀNG',

    // Settings
    'settings_title': 'CÀI ĐẶT RETROCLAN',
    'tab_gamepad': 'TAY CẦM',
    'tab_lan': 'MẠNG LAN',
    'tab_info': 'THÔNG TIN',
    'tab_system': 'NGÔN NGỮ',
    'language_select': 'Ngôn ngữ hiển thị (Language)',
    'lang_vi': 'Tiếng Việt 🇻🇳',
    'lang_en': 'English 🇺🇸',
    'save_settings': 'LƯU CÀI ĐẶT',
    'close': 'ĐÓNG',
    'settings_saved': '✅ Đã lưu cấu hình cài đặt thành công!',
    'player_name': 'Tên người chơi Clan:',
    'btn_size': 'Kích thước nút bấm Arcade:',
    'btn_layout': 'Bố cục nút Arcade:',
    'joystick_type': 'Kiểu cần gạt (D-Pad):',
    'haptic': 'Rung khi bấm (Haptic):',

    // Clan Lobby
    'tab_create_room': 'TẠO PHÒNG (P1)',
    'tab_join_room': 'VÀO PHÒNG (P2)',
    'wifi_connected': 'Đã kết nối Wi-Fi',
    'wifi_disconnected': 'Chưa kết nối Wi-Fi',
    'step_select_game': '1. Chọn game muốn mở phòng',
    'step_room_status': '2. Trạng thái phòng Clan',
    'lan_room': 'Phòng mạng LAN:',
    'status_open': 'ĐANG MỞ (Phát Wi-Fi)',
    'status_closed': 'CHƯA MỞ',
    'player2_clan': 'Người chơi 2 (Clan):',
    'waiting_player2': 'Đang đợi bạn vào...',
    'player2_ready': 'Đã kết nối & Sẵn sàng',
    'host_ip_title': 'Địa chỉ IP máy chủ của bạn:',
    'copy_ip': 'Sao chép IP',
    'copied': 'Đã sao chép!',
    'start_game_now': '▶ VÀO GAME CHƠI NGAY (P1)',
    'start_game_host': '▶ VÀO GAME VỚI VAI TRÒ CHỦ PHÒNG (P1)',
    'open_room_btn': 'MỞ PHÒNG CLAN (LAN)',
    'close_room_btn': 'Đóng phòng',
    'scan_rooms': 'Tìm phòng tự động',
    'scanning': 'Đang quét phòng...',
    'connect_btn': 'Kết nối',
    'direct_ip': 'Nhập IP trực tiếp',
    'rooms_found': 'Phòng Clan đang mở',
    'no_rooms': 'Chưa tìm thấy phòng nào. Hãy chắc chắn 2 máy cùng bắt 1 mạng Wi-Fi!',

    // In Game / Emulator
    'exit': 'THOÁT',
    'save': 'LƯU',
    'reload_save': 'TẢI LẠI LƯU',
    'restart': 'CHƠI LẠI',
    'rotate': 'XOAY',
    'cast': 'CHIẾU MÀN HÌNH',
    'cheat_engine': 'CHEAT ENGINE',
    'rewind_10s': 'TUA LÙI 10S',
    'game_saved': '✅ Đã lưu tiến trình game thành công!',
    'game_reloaded': '⚡ Đã tải lại tiến trình game thành công!',
    'host_exited': 'Chủ phòng đã thoát game. Đang quay lại sảnh Clan...',
    'p2_title': 'Người chơi 2 - ',
    'p2_connected_to': 'Đã kết nối tới máy chủ ',
    'sound_prompt': '🔊 Chạm vào màn hình để bật âm thanh',
    'tap_to_play': 'CHẠM VÀO MÀN HÌNH ĐỂ BẬT ÂM THANH',
    'btn_customize': 'Chỉnh nút',
    'btn_done': 'Xong',
  };

  static const Map<String, String> _en = {
    // Navigation
    'nav_home': 'HOME',
    'nav_add_game': 'ADD GAME',
    'nav_lan': 'LAN CLAN',
    'nav_online': 'ONLINE',

    // Home Filters
    'filter_all': 'ALL',
    'filter_recent': 'RECENT',
    'filter_favorites': 'FAVORITES',
    'filter_continue': 'CONTINUE',
    'search_placeholder': 'Search games...',
    'badge_saved': 'SAVED',
    'badge_ready': 'READY',

    // Settings
    'settings_title': 'RETROCLAN SETTINGS',
    'tab_gamepad': 'GAMEPAD',
    'tab_lan': 'LAN NETWORK',
    'tab_info': 'INFO',
    'tab_system': 'LANGUAGE',
    'language_select': 'Display Language',
    'lang_vi': 'Tiếng Việt 🇻🇳',
    'lang_en': 'English 🇺🇸',
    'save_settings': 'SAVE SETTINGS',
    'close': 'CLOSE',
    'settings_saved': '✅ Settings saved successfully!',
    'player_name': 'Clan Player Name:',
    'btn_size': 'Arcade Button Size:',
    'btn_layout': 'Arcade Button Layout:',
    'joystick_type': 'Joystick (D-Pad) Type:',
    'haptic': 'Haptic Vibration Feedback:',

    // Clan Lobby
    'tab_create_room': 'CREATE ROOM (P1)',
    'tab_join_room': 'JOIN ROOM (P2)',
    'wifi_connected': 'Wi-Fi Connected',
    'wifi_disconnected': 'Wi-Fi Not Connected',
    'step_select_game': '1. Select Game to Host',
    'step_room_status': '2. Clan Room Status',
    'lan_room': 'LAN Room:',
    'status_open': 'OPEN (Broadcasting)',
    'status_closed': 'CLOSED',
    'player2_clan': 'Player 2 (Clan):',
    'waiting_player2': 'Waiting for Player 2...',
    'player2_ready': 'Connected & Ready',
    'host_ip_title': 'Your Host IP Address:',
    'copy_ip': 'Copy IP',
    'copied': 'Copied!',
    'start_game_now': '▶ START GAME NOW (P1)',
    'start_game_host': '▶ ENTER AS HOST (P1)',
    'open_room_btn': 'OPEN CLAN ROOM (LAN)',
    'close_room_btn': 'Close Room',
    'scan_rooms': 'Scan for Rooms',
    'scanning': 'Scanning for rooms...',
    'connect_btn': 'Connect',
    'direct_ip': 'Direct IP Connect',
    'rooms_found': 'Open Clan Rooms',
    'no_rooms': 'No rooms found. Make sure both devices are on the same Wi-Fi!',

    // In Game / Emulator
    'exit': 'EXIT',
    'save': 'SAVE',
    'reload_save': 'RELOAD SAVE',
    'restart': 'RESTART',
    'rotate': 'ROTATE',
    'cast': 'SCREEN CAST',
    'cheat_engine': 'CHEAT ENGINE',
    'rewind_10s': 'REWIND 10S',
    'game_saved': '✅ Game progress saved successfully!',
    'game_reloaded': '⚡ Game progress reloaded successfully!',
    'host_exited': 'Host exited the game. Returning to Clan Lobby...',
    'p2_title': 'Player 2 - ',
    'p2_connected_to': 'Connected to Host ',
    'sound_prompt': '🔊 Tap screen to enable audio',
    'tap_to_play': 'TAP SCREEN TO ENABLE AUDIO',
    'btn_customize': 'Edit Buttons',
    'btn_done': 'Done',
  };
}

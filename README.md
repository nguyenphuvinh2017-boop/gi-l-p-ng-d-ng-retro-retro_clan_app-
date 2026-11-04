# 🎮 Retro Clan Play (Android & iOS)

Ứng dụng giả lập retro đa nền tảng cho **Android** và **iOS** (hỗ trợ cả Windows & Web) cho phép:
1. **Tìm kiếm & tải ROM game từ Retrostic:** Tự động giải mã token phiên làm việc, tải file `.zip` và trích xuất file ROM vào bộ nhớ máy.
2. **Chơi game trực tiếp:** Tích hợp bộ giả lập Canvas 60 FPS với âm thanh Web Audio và bàn phím ảo Virtual Gamepad cảm ứng đa điểm, rung phản hồi lực (Haptic Feedback).
3. **Chơi chung qua mạng Clan / LAN (Zero-Lag Netplay):**
   - **Tự động dò tìm phòng trên cùng mạng Wi-Fi:** Sử dụng UDP Broadcast Beacon không cần nhập IP thủ công.
   - **Đồng bộ tay cầm Player 2 siêu tốc:** Kết nối WebSocket nội bộ LAN độ trễ cực thấp (< 2ms).
   - **Chế độ Tay cầm không dây (Wireless Gamepad Mode):** Biến điện thoại của bạn bè thành tay cầm Player 2 điều khiển trên máy Host.

---

## 🏗 Kiến trúc ứng dụng

```
retro_clan_app/
├── assets/
│   └── emulator/
│       ├── index.html            # Canvas 60fps, Web Audio & WebGL Renderer
│       └── jsnes.min.js          # Core Giả Lập NES Engine 2 Players
├── lib/
│   ├── models/
│   │   ├── game_item.dart        # Model ROM, metadata, đường dẫn cục bộ
│   │   └── lan_message.dart      # Giao thức truyền tin Netplay (UDP/WS)
│   ├── services/
│   │   ├── retrostic_service.dart# Scraper & Token Resolver cho Retrostic
│   │   ├── rom_manager.dart      # Quản lý tải, giải nén ZIP & Base64 ROM
│   │   └── clan_netplay_service.dart # WebSocket Host/Client & UDP Beacon Discovery
│   ├── widgets/
│   │   └── virtual_gamepad.dart  # Bàn phím ảo phong cách NES (D-Pad, A/B, Select, Start)
│   ├── screens/
│   │   ├── home_screen.dart      # Danh sách game đã tải trong thư viện
│   │   ├── browse_retrostic_screen.dart # Cửa hàng tìm kiếm và 1-click tải ROM
│   │   ├── clan_lobby_screen.dart# Sảnh phòng Clan (Tạo phòng Host & Quét phòng Join)
│   │   ├── emulator_screen.dart  # Màn hình chơi game chính + overlay tay cầm P1
│   │   └── wireless_pad_screen.dart # Màn hình tay cầm Player 2 qua Wi-Fi
│   └── main.dart                 # Điểm khởi chạy & Arcade Dark Theme
```

---

## ⚡ Cơ chế hoạt động của Netplay LAN (Chơi chung cùng mạng)

1. **Host tạo phòng (Player 1):**
   - Khởi chạy WebSocket Server tại cổng `8989` trên IP nội bộ (ví dụ: `192.168.1.15:8989`).
   - Phát sóng gói tin UDP Broadcast mỗi 1.5 giây tới địa chỉ `255.255.255.255:8988` chứa thông tin phòng và tên game.
2. **Thành viên Clan tham gia (Player 2):**
   - Ứng dụng lắng nghe cổng UDP `8988` và tự động hiển thị phòng có sẵn trên Wi-Fi.
   - Nhấn "Join as P2" để kết nối vào WebSocket của Host.
3. **Đồng bộ hóa điều khiển (Input Sync):**
   - Mỗi thao tác nhấn hoặc nhả nút trên bàn phím ảo của Player 2 gửi một gói JSON siêu nhỏ `{ player: 2, btn: 'A', down: true }`.
   - Lõi giả lập trên máy Host nhận tín hiệu và kích hoạt ngay lập tức tay cầm Player 2 trong game.

---

## 🚀 Hướng dẫn chạy và cài đặt

### 1. Chạy trên máy tính để thử nghiệm ngay
```bash
cd retro_clan_app
flutter run -d windows
# Hoặc chạy trên trình duyệt:
flutter run -d chrome
```

### 2. Build file APK cho điện thoại Android
```bash
cd retro_clan_app
flutter build apk --release
```
File APK xuất ra tại: `build/app/outputs/flutter-apk/app-release.apk` (có thể copy trực tiếp vào điện thoại Android để cài đặt).

### 3. Build cho iOS
```bash
cd retro_clan_app
flutter build ipa --no-codesign
```
(Mở thư mục `ios` bằng Xcode trên macOS để cắm cáp và chạy thử nghiệm trên iPhone/iPad).

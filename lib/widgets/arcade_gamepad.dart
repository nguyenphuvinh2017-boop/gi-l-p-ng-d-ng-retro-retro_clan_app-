import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ArcadeGamepad extends StatefulWidget {
  final Function(String btn, bool isDown) onButtonEvent;
  final VoidCallback onOpenMenu;
  final VoidCallback onToggleSpeed;
  final int speedMultiplier;
  final bool isLandscape;
  final VoidCallback? onToggleRotation;
  final VoidCallback? onExit;

  // Cấu hình Nút & Cần gạt
  final double buttonScale;
  final String buttonLayout; // 'arcade6', 'arcadeSquare2x2', 'arcadeDiamond', 'arcade4Row', 'arcade4Arc'
  final String joystickType; // 'analog360', 'dpadSquare4', 'dpad4'
  final String joystickSensitivity; // 'high', 'normal', 'low'

  // Chế độ chỉnh vị trí TỪNG NÚT riêng biệt
  final bool isEditMode;
  final Map<String, Offset>? customOffsets;
  final Function(Map<String, Offset> newOffsets)? onButtonOffsetsChanged;

  const ArcadeGamepad({
    super.key,
    required this.onButtonEvent,
    required this.onOpenMenu,
    required this.onToggleSpeed,
    this.speedMultiplier = 1,
    this.isLandscape = false,
    this.onToggleRotation,
    this.onExit,
    this.buttonScale = 1.0,
    this.buttonLayout = 'arcade6',
    this.joystickType = 'analog360',
    this.joystickSensitivity = 'normal',
    this.isEditMode = false,
    this.customOffsets,
    this.onButtonOffsetsChanged,
  });

  @override
  State<ArcadeGamepad> createState() => _ArcadeGamepadState();
}

class _ArcadeGamepadState extends State<ArcadeGamepad> {
  // Trạng thái cần gạt Joystick 360
  Offset _stickOffset = Offset.zero;
  final double _stickRadius = 40.0;
  String? _lastDirection;

  // Trạng thái D-Pad 4 hướng
  final Set<String> _activeDPadDirs = {};

  // Tọa độ tùy chỉnh cục bộ cho TỪNG NÚT riêng biệt (mượt 60 FPS khi kéo thả)
  Map<String, Offset> _localOffsets = {};

  // Trạng thái theo dõi kéo thả 1:1 tuyệt đối theo con trỏ chuột / cảm ứng
  String? _draggingButtonId;
  Offset _dragStartPointer = Offset.zero;
  Offset _dragStartButtonPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (widget.customOffsets != null) {
      _localOffsets = Map<String, Offset>.from(widget.customOffsets!);
    }
  }

  @override
  void didUpdateWidget(covariant ArcadeGamepad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customOffsets != oldWidget.customOffsets) {
      _localOffsets = widget.customOffsets != null
          ? Map<String, Offset>.from(widget.customOffsets!)
          : {};
    }
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  int get _sensitivityThreshold {
    switch (widget.joystickSensitivity) {
      case 'high':
        return 7;
      case 'low':
        return 18;
      case 'normal':
      default:
        return 12;
    }
  }

  void _updateJoystick(Offset localPosition, Size size) {
    if (widget.isEditMode) return;
    final center = Offset(size.width / 2, size.height / 2);
    final delta = localPosition - center;
    final distance = delta.distance;

    if (distance > _stickRadius) {
      _stickOffset = Offset.fromDirection(delta.direction, _stickRadius);
    } else {
      _stickOffset = delta;
    }

    String? newDir;
    if (distance > _sensitivityThreshold) {
      final angle = delta.direction;
      if (angle >= -pi * 0.75 && angle <= -pi * 0.25) {
        newDir = 'UP';
      } else if (angle >= pi * 0.25 && angle <= pi * 0.75) {
        newDir = 'DOWN';
      } else if (angle.abs() > pi * 0.75) {
        newDir = 'LEFT';
      } else if (angle.abs() < pi * 0.25) {
        newDir = 'RIGHT';
      }
    }

    if (newDir != _lastDirection) {
      if (_lastDirection != null) {
        widget.onButtonEvent(_lastDirection!, false);
      }
      if (newDir != null) {
        _triggerHaptic();
        widget.onButtonEvent(newDir, true);
      }
      _lastDirection = newDir;
    }

    setState(() {});
  }

  void _releaseJoystick() {
    if (widget.isEditMode) return;
    if (_lastDirection != null) {
      widget.onButtonEvent(_lastDirection!, false);
      _lastDirection = null;
    }
    setState(() {
      _stickOffset = Offset.zero;
    });
  }

  void _updateDPadFromOffset(Offset localPosition, Size size) {
    if (widget.isEditMode) return;
    final center = Offset(size.width / 2, size.height / 2);
    final delta = localPosition - center;
    final distance = delta.distance;

    final Set<String> newDirs = {};
    if (distance > _sensitivityThreshold) {
      final angle = delta.direction;
      if (angle >= -pi * 0.625 && angle <= -pi * 0.375) {
        newDirs.add('UP');
      } else if (angle >= pi * 0.375 && angle <= pi * 0.625) {
        newDirs.add('DOWN');
      } else if (angle.abs() >= pi * 0.875) {
        newDirs.add('LEFT');
      } else if (angle.abs() <= pi * 0.125) {
        newDirs.add('RIGHT');
      } else if (angle > -pi * 0.875 && angle < -pi * 0.625) {
        newDirs.addAll(['UP', 'LEFT']);
      } else if (angle > -pi * 0.375 && angle < -pi * 0.125) {
        newDirs.addAll(['UP', 'RIGHT']);
      } else if (angle > pi * 0.625 && angle < pi * 0.875) {
        newDirs.addAll(['DOWN', 'LEFT']);
      } else if (angle > pi * 0.125 && angle < pi * 0.375) {
        newDirs.addAll(['DOWN', 'RIGHT']);
      }
    }

    for (var d in _activeDPadDirs.toList()) {
      if (!newDirs.contains(d)) {
        widget.onButtonEvent(d, false);
        _activeDPadDirs.remove(d);
      }
    }

    for (var d in newDirs) {
      if (!_activeDPadDirs.contains(d)) {
        _triggerHaptic();
        widget.onButtonEvent(d, true);
        _activeDPadDirs.add(d);
      }
    }

    setState(() {});
  }

  void _releaseDPad() {
    if (widget.isEditMode) return;
    for (var d in _activeDPadDirs) {
      widget.onButtonEvent(d, false);
    }
    _activeDPadDirs.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final W = constraints.maxWidth;
        final H = constraints.maxHeight;
        final s = widget.buttonScale;

        final joySize = 130.0 * s;
        final btnSize = 46.0 * s;
        final comboW = 50.0 * s;
        final comboH = 36.0 * s;
        final selectW = 62.0 * s;
        final selectH = 30.0 * s;
        final startW = 62.0 * s;
        final startH = 30.0 * s;
        final menuSize = 34.0 * s;
        final speedSize = 34.0 * s;
        final gap = 14.0 * s;

        // Tính toán tọa độ mặc định chuẩn (Rõ ràng, không bị đè hay lấn vào nhau)
        final Map<String, Offset> defaultPositions = {};

        if (widget.isLandscape) {
          final margin = 24.0 * s;

          // 1. CỤM BÊN TRÁI:
          // Cần gạt ở góc dưới bên trái
          defaultPositions['JOYSTICK'] = Offset(margin, max(0.0, H - margin - joySize));
          // SELECT và X1 ở ngay trên cần gạt
          defaultPositions['SELECT'] = Offset(margin, max(0.0, H - margin - joySize - selectH - 12.0 * s));
          defaultPositions['SPEED'] = Offset(margin + selectW + gap, max(0.0, H - margin - joySize - speedSize - 10.0 * s));

          // 2. CỤM BÊN PHẢI:
          final rowW = comboW + gap + btnSize + gap + btnSize;
          final rightBaseX = W - margin - rowW;
          final bottomBaseY = H - margin;

          final bottomRowY = bottomBaseY - btnSize;
          final topRowY = bottomRowY - gap - btnSize;

          if (widget.buttonLayout == 'arcadeSquare2x2') {
            // Dạng ô vuông 2x2 (A, B ở dưới; C, D ở trên)
            final sqW = comboW + gap + btnSize * 2 + gap;
            final sqBaseX = W - margin - sqW;
            defaultPositions['CD'] = Offset(sqBaseX, topRowY + (btnSize - comboH) / 2);
            defaultPositions['C'] = Offset(sqBaseX + comboW + gap, topRowY);
            defaultPositions['D'] = Offset(sqBaseX + comboW + gap + btnSize + gap, topRowY);

            defaultPositions['AB'] = Offset(sqBaseX, bottomRowY + (btnSize - comboH) / 2);
            defaultPositions['A'] = Offset(sqBaseX + comboW + gap, bottomRowY);
            defaultPositions['B'] = Offset(sqBaseX + comboW + gap + btnSize + gap, bottomRowY);
          } else if (widget.buttonLayout == 'arcadeDiamond') {
            // Dạng chữ thập kim cương (Lên C, Xuống B, Trái A, Phải D)
            final diaSpan = btnSize * 2.2 + gap;
            final diaBaseX = W - margin - diaSpan - comboW - gap;
            final midY = (topRowY + bottomRowY) / 2;

            defaultPositions['CD'] = Offset(diaBaseX, topRowY + (btnSize - comboH) / 2);
            defaultPositions['AB'] = Offset(diaBaseX, bottomRowY + (btnSize - comboH) / 2);

            final clusterX = diaBaseX + comboW + gap;
            defaultPositions['C'] = Offset(clusterX + btnSize * 0.6, topRowY - 6.0 * s); // Lên
            defaultPositions['B'] = Offset(clusterX + btnSize * 0.6, bottomRowY + 6.0 * s); // Xuống
            defaultPositions['A'] = Offset(clusterX, midY); // Trái
            defaultPositions['D'] = Offset(clusterX + btnSize * 1.2, midY); // Phải
          } else if (widget.buttonLayout == 'arcade4Row') {
            // 4 nút thẳng hàng: A+B, C+D ở trên; A, B, C, D ở dưới
            final row4W = btnSize * 4 + gap * 3;
            final right4X = W - margin - row4W;
            defaultPositions['AB'] = Offset(right4X, topRowY + (btnSize - comboH) / 2);
            defaultPositions['CD'] = Offset(right4X + comboW + gap * 2, topRowY + (btnSize - comboH) / 2);
            defaultPositions['A'] = Offset(right4X, bottomRowY);
            defaultPositions['B'] = Offset(right4X + btnSize + gap, bottomRowY);
            defaultPositions['C'] = Offset(right4X + (btnSize + gap) * 2, bottomRowY);
            defaultPositions['D'] = Offset(right4X + (btnSize + gap) * 3, bottomRowY);
          } else if (widget.buttonLayout == 'arcade4Arc') {
            // Vòng cung Neo Geo
            final arcBaseX = W - margin - (220.0 * s);
            defaultPositions['A'] = Offset(arcBaseX, bottomBaseY - btnSize - 6.0 * s);
            defaultPositions['B'] = Offset(arcBaseX + 54.0 * s, bottomBaseY - btnSize - 30.0 * s);
            defaultPositions['C'] = Offset(arcBaseX + 110.0 * s, bottomBaseY - btnSize - 44.0 * s);
            defaultPositions['D'] = Offset(arcBaseX + 166.0 * s, bottomBaseY - btnSize - 28.0 * s);
            defaultPositions['AB'] = Offset(arcBaseX + 50.0 * s, bottomBaseY - comboH);
            defaultPositions['CD'] = Offset(arcBaseX + 128.0 * s, bottomBaseY - comboH);
          } else {
            // Chuẩn Neo Geo 6 nút (2 hàng x 3 nút) - Rõ ràng, rộng rãi, tuyệt đối không bị đè nút
            defaultPositions['AB'] = Offset(rightBaseX, bottomRowY + (btnSize - comboH) / 2);
            defaultPositions['A'] = Offset(rightBaseX + comboW + gap, bottomRowY);
            defaultPositions['B'] = Offset(rightBaseX + comboW + gap + btnSize + gap, bottomRowY);

            defaultPositions['CD'] = Offset(rightBaseX, topRowY + (btnSize - comboH) / 2);
            defaultPositions['C'] = Offset(rightBaseX + comboW + gap, topRowY);
            defaultPositions['D'] = Offset(rightBaseX + comboW + gap + btnSize + gap, topRowY);
          }

          // Phím MENU [≡] và START ngay trên cụm nút hành động bên phải
          defaultPositions['START'] = Offset(W - margin - startW, max(0.0, topRowY - startH - 12.0 * s));
          defaultPositions['MENU'] = Offset(W - margin - startW - gap - menuSize, max(0.0, topRowY - menuSize - 10.0 * s));
        } else {
          // Giao diện Dọc (Portrait)
          final topY = 10.0 * s;
          final totalTopW = selectW + gap + menuSize + gap + speedSize + gap + startW;
          final topStartX = max(0.0, (W - totalTopW) / 2);

          defaultPositions['SELECT'] = Offset(topStartX, topY);
          defaultPositions['MENU'] = Offset(topStartX + selectW + gap, topY);
          defaultPositions['SPEED'] = Offset(topStartX + selectW + gap + menuSize + gap, topY);
          defaultPositions['START'] = Offset(topStartX + selectW + gap + menuSize + gap + speedSize + gap, topY);

          defaultPositions['JOYSTICK'] = Offset(16.0 * s, max(0.0, H - 16.0 * s - joySize));

          final rowW = comboW + gap + btnSize + gap + btnSize;
          final rightBaseX = W - 16.0 * s - rowW;
          final bottomBaseY = H - 16.0 * s;

          final bottomRowY = bottomBaseY - btnSize;
          final topRowY = bottomRowY - gap - btnSize;

          if (widget.buttonLayout == 'arcadeSquare2x2') {
            final sqW = comboW + gap + btnSize * 2 + gap;
            final sqBaseX = W - 16.0 * s - sqW;
            defaultPositions['CD'] = Offset(sqBaseX, topRowY + (btnSize - comboH) / 2);
            defaultPositions['C'] = Offset(sqBaseX + comboW + gap, topRowY);
            defaultPositions['D'] = Offset(sqBaseX + comboW + gap + btnSize + gap, topRowY);

            defaultPositions['AB'] = Offset(sqBaseX, bottomRowY + (btnSize - comboH) / 2);
            defaultPositions['A'] = Offset(sqBaseX + comboW + gap, bottomRowY);
            defaultPositions['B'] = Offset(sqBaseX + comboW + gap + btnSize + gap, bottomRowY);
          } else if (widget.buttonLayout == 'arcadeDiamond') {
            final diaSpan = btnSize * 2.2 + gap;
            final diaBaseX = W - 16.0 * s - diaSpan - comboW - gap;
            final midY = (topRowY + bottomRowY) / 2;

            defaultPositions['CD'] = Offset(diaBaseX, topRowY + (btnSize - comboH) / 2);
            defaultPositions['AB'] = Offset(diaBaseX, bottomRowY + (btnSize - comboH) / 2);

            final clusterX = diaBaseX + comboW + gap;
            defaultPositions['C'] = Offset(clusterX + btnSize * 0.6, topRowY - 6.0 * s);
            defaultPositions['B'] = Offset(clusterX + btnSize * 0.6, bottomRowY + 6.0 * s);
            defaultPositions['A'] = Offset(clusterX, midY);
            defaultPositions['D'] = Offset(clusterX + btnSize * 1.2, midY);
          } else {
            defaultPositions['AB'] = Offset(rightBaseX, bottomRowY + (btnSize - comboH) / 2);
            defaultPositions['A'] = Offset(rightBaseX + comboW + gap, bottomRowY);
            defaultPositions['B'] = Offset(rightBaseX + comboW + gap + btnSize + gap, bottomRowY);

            defaultPositions['CD'] = Offset(rightBaseX, topRowY + (btnSize - comboH) / 2);
            defaultPositions['C'] = Offset(rightBaseX + comboW + gap, topRowY);
            defaultPositions['D'] = Offset(rightBaseX + comboW + gap + btnSize + gap, topRowY);
          }
        }

        return Stack(
          children: [
            // 1. CẦN GẠT JOYSTICK / D-PAD (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'JOYSTICK',
              width: joySize,
              height: joySize,
              defaultPos: defaultPositions['JOYSTICK'] ?? const Offset(20, 100),
              W: W,
              H: H,
              isCircle: true,
              child: widget.joystickType == 'dpadSquare4'
                  ? _buildSquareDPad()
                  : (widget.joystickType == 'dpad4' ? _buildDPad() : _buildArcadeJoystick()),
            ),

            // 2. NÚT SELECT (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'SELECT',
              width: selectW,
              height: selectH,
              defaultPos: defaultPositions['SELECT'] ?? const Offset(20, 20),
              W: W,
              H: H,
              child: _SystemPill(
                label: 'SELECT',
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onDown: () => widget.onButtonEvent('SELECT', true),
                onUp: () => widget.onButtonEvent('SELECT', false),
              ),
            ),

            // 3. NÚT TỐC ĐỘ X1 (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'SPEED',
              width: speedSize,
              height: speedSize,
              defaultPos: defaultPositions['SPEED'] ?? const Offset(90, 20),
              W: W,
              H: H,
              isCircle: true,
              child: _CircularCenterBtn(
                text: 'X${widget.speedMultiplier}',
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onTap: widget.onToggleSpeed,
              ),
            ),

            // 4. NÚT MENU [≡] (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'MENU',
              width: menuSize,
              height: menuSize,
              defaultPos: defaultPositions['MENU'] ?? Offset(W - 120, 20),
              W: W,
              H: H,
              isCircle: true,
              child: _CircularCenterBtn(
                icon: Icons.menu_rounded,
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onTap: widget.onOpenMenu,
              ),
            ),

            // 5. NÚT START (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'START',
              width: startW,
              height: startH,
              defaultPos: defaultPositions['START'] ?? Offset(W - 70, 20),
              W: W,
              H: H,
              child: _SystemPill(
                label: 'START',
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onDown: () => widget.onButtonEvent('START', true),
                onUp: () => widget.onButtonEvent('START', false),
              ),
            ),

            // 6. NÚT C+D (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'CD',
              width: comboW,
              height: comboH,
              defaultPos: defaultPositions['CD'] ?? Offset(W - 170, 100),
              W: W,
              H: H,
              child: _ComboBtn(
                label: 'C+D',
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onDown: () {
                  widget.onButtonEvent('C', true);
                  widget.onButtonEvent('D', true);
                },
                onUp: () {
                  widget.onButtonEvent('C', false);
                  widget.onButtonEvent('D', false);
                },
              ),
            ),

            // 7. NÚT C (Xanh lá) (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'C',
              width: btnSize,
              height: btnSize,
              defaultPos: defaultPositions['C'] ?? Offset(W - 110, 100),
              W: W,
              H: H,
              isCircle: true,
              child: _ArcadeCircleBtn(
                label: 'C',
                primaryColor: const Color(0xFF4CAF50),
                darkColor: const Color(0xFF2E7D32),
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onButtonEvent: widget.onButtonEvent,
              ),
            ),

            // 8. NÚT D (Xanh dương) (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'D',
              width: btnSize,
              height: btnSize,
              defaultPos: defaultPositions['D'] ?? Offset(W - 50, 100),
              W: W,
              H: H,
              isCircle: true,
              child: _ArcadeCircleBtn(
                label: 'D',
                primaryColor: const Color(0xFF2196F3),
                darkColor: const Color(0xFF0D47A1),
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onButtonEvent: widget.onButtonEvent,
              ),
            ),

            // 9. NÚT A+B (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'AB',
              width: comboW,
              height: comboH,
              defaultPos: defaultPositions['AB'] ?? Offset(W - 170, 160),
              W: W,
              H: H,
              child: _ComboBtn(
                label: 'A+B',
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onDown: () {
                  widget.onButtonEvent('A', true);
                  widget.onButtonEvent('B', true);
                },
                onUp: () {
                  widget.onButtonEvent('A', false);
                  widget.onButtonEvent('B', false);
                },
              ),
            ),

            // 10. NÚT A (Đỏ - Đặt bom chính xác 100%) (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'A',
              width: btnSize,
              height: btnSize,
              defaultPos: defaultPositions['A'] ?? Offset(W - 110, 160),
              W: W,
              H: H,
              isCircle: true,
              child: _ArcadeCircleBtn(
                label: 'A',
                primaryColor: const Color(0xFFE53935),
                darkColor: const Color(0xFFB71C1C),
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onButtonEvent: widget.onButtonEvent,
              ),
            ),

            // 11. NÚT B (Vàng/Cam) (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'B',
              width: btnSize,
              height: btnSize,
              defaultPos: defaultPositions['B'] ?? Offset(W - 50, 160),
              W: W,
              H: H,
              isCircle: true,
              child: _ArcadeCircleBtn(
                label: 'B',
                primaryColor: const Color(0xFFFFB300),
                darkColor: const Color(0xFFE65100),
                scale: s,
                isEditMode: widget.isEditMode,
                onHaptic: _triggerHaptic,
                onButtonEvent: widget.onButtonEvent,
              ),
            ),

            // 12. Nút xoay lại góc trên bên PHẢI (khi ở chế độ Ngang và không ở chế độ chỉnh)
            if (widget.isLandscape && widget.onToggleRotation != null && !widget.isEditMode)
              Positioned(
                top: 14,
                right: 16,
                child: InkWell(
                  onTap: () {
                    _triggerHaptic();
                    widget.onToggleRotation!();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                    ),
                    child: const Icon(Icons.screen_rotation, color: Color(0xFFD4AF37), size: 22),
                  ),
                ),
              ),

            // 13. Nút quay lại góc trên bên TRÁI (khi ở chế độ Ngang và không ở chế độ chỉnh)
            if (widget.isLandscape && widget.onExit != null && !widget.isEditMode)
              Positioned(
                top: 14,
                left: 16,
                child: InkWell(
                  onTap: () {
                    _triggerHaptic();
                    widget.onExit!();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white38, width: 1.5),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Khung hỗ trợ Kéo - Thả TỪNG NÚT RIÊNG BIỆT mượt mà 60 FPS
  Widget _buildDraggableButton({
    required String id,
    required Widget child,
    required double width,
    required double height,
    required Offset defaultPos,
    required double W,
    required double H,
    bool isCircle = false,
  }) {
    final pct = _localOffsets[id];
    final curX = pct != null
        ? (pct.dx * W).clamp(0.0, max(0.0, W - width)).toDouble()
        : defaultPos.dx.clamp(0.0, max(0.0, W - width)).toDouble();
    final curY = pct != null
        ? (pct.dy * H).clamp(0.0, max(0.0, H - height)).toDouble()
        : defaultPos.dy.clamp(0.0, max(0.0, H - height)).toDouble();

    if (!widget.isEditMode) {
      return Positioned(
        left: curX,
        top: curY,
        child: child,
      );
    }

    return Positioned(
      left: curX,
      top: curY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          _draggingButtonId = id;
          _dragStartPointer = details.globalPosition;
          _dragStartButtonPos = Offset(curX, curY);
        },
        onPanUpdate: (details) {
          if (_draggingButtonId != id) return;
          final totalDelta = details.globalPosition - _dragStartPointer;
          final newX = (_dragStartButtonPos.dx + totalDelta.dx).clamp(0.0, max(0.0, W - width)).toDouble();
          final newY = (_dragStartButtonPos.dy + totalDelta.dy).clamp(0.0, max(0.0, H - height)).toDouble();
          setState(() {
            _localOffsets[id] = Offset(newX / W, newY / H);
          });
          widget.onButtonOffsetsChanged?.call(_localOffsets);
        },
        onPanEnd: (_) {
          _draggingButtonId = null;
          widget.onButtonOffsetsChanged?.call(_localOffsets);
        },
        onPanCancel: () {
          _draggingButtonId = null;
          widget.onButtonOffsetsChanged?.call(_localOffsets);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(8 * widget.buttonScale),
            border: Border.all(color: const Color(0xFFFFD700), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IgnorePointer(child: child),
              // Biểu tượng kéo thả góc trên
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.open_with, size: 10, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. CẦN GẠT JOYSTICK 360° NGUYÊN BẢN ARCADE
  Widget _buildArcadeJoystick() {
    final outerSize = 130.0 * widget.buttonScale;
    final knobSize = 64.0 * widget.buttonScale;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _updateJoystick(details.localPosition, size),
            onPanUpdate: (details) => _updateJoystick(details.localPosition, size),
            onPanEnd: (_) => _releaseJoystick(),
            onPanCancel: () => _releaseJoystick(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vòng đế tròn bên ngoài màu ngà viền vàng
                Container(
                  width: outerSize,
                  height: outerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF2ECE1),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 3 * widget.buttonScale),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),

                // Lớp lõm bên trong màu tối
                Container(
                  width: outerSize - (24 * widget.buttonScale),
                  height: outerSize - (24 * widget.buttonScale),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1E1712),
                  ),
                ),

                // Các vạch khấc định hướng (4 hướng)
                for (var angle in [0.0, pi / 2, pi, 3 * pi / 2])
                  Transform.rotate(
                    angle: angle,
                    child: Container(
                      width: outerSize - (10 * widget.buttonScale),
                      height: 4 * widget.buttonScale,
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 6 * widget.buttonScale,
                        height: 4 * widget.buttonScale,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7A6854),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                // Viên bi cần gạt màu tím ngọc (Pearl Purple Joystick Knob)
                Transform.translate(
                  offset: _stickOffset * widget.buttonScale,
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFC798EA), Color(0xFF8651B5), Color(0xFF502778)],
                        center: Alignment(-0.3, -0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 14 * widget.buttonScale,
                        height: 14 * widget.buttonScale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 2. CỤM PHÍM CHỮ THẬP D-PAD 4 HƯỚNG
  Widget _buildDPad() {
    final outerSize = 130.0 * widget.buttonScale;
    final wingLength = 44.0 * widget.buttonScale;
    final wingWidth = 44.0 * widget.buttonScale;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _updateDPadFromOffset(details.localPosition, size),
            onPanUpdate: (details) => _updateDPadFromOffset(details.localPosition, size),
            onPanEnd: (_) => _releaseDPad(),
            onPanCancel: () => _releaseDPad(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vòng đế tròn bên ngoài màu ngà viền vàng
                Container(
                  width: outerSize,
                  height: outerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF2ECE1),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 3 * widget.buttonScale),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),

                // Lớp lõm bên trong màu tối
                Container(
                  width: outerSize - (16 * widget.buttonScale),
                  height: outerSize - (16 * widget.buttonScale),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1E1712),
                  ),
                ),

                // D-Pad thân chữ thập đứng
                Container(
                  width: wingWidth,
                  height: outerSize - (24 * widget.buttonScale),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2219),
                    borderRadius: BorderRadius.circular(6 * widget.buttonScale),
                    border: Border.all(color: const Color(0xFF7A6854), width: 1.5),
                  ),
                ),

                // D-Pad thân chữ thập ngang
                Container(
                  width: outerSize - (24 * widget.buttonScale),
                  height: wingWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2219),
                    borderRadius: BorderRadius.circular(6 * widget.buttonScale),
                    border: Border.all(color: const Color(0xFF7A6854), width: 1.5),
                  ),
                ),

                // NÚT LÊN (UP)
                Positioned(
                  top: 14 * widget.buttonScale,
                  child: _buildDPadArrow(
                    direction: 'UP',
                    icon: Icons.arrow_drop_up,
                    width: wingWidth,
                    height: wingLength,
                  ),
                ),

                // NÚT XUỐNG (DOWN)
                Positioned(
                  bottom: 14 * widget.buttonScale,
                  child: _buildDPadArrow(
                    direction: 'DOWN',
                    icon: Icons.arrow_drop_down,
                    width: wingWidth,
                    height: wingLength,
                  ),
                ),

                // NÚT TRÁI (LEFT)
                Positioned(
                  left: 14 * widget.buttonScale,
                  child: _buildDPadArrow(
                    direction: 'LEFT',
                    icon: Icons.arrow_left,
                    width: wingLength,
                    height: wingWidth,
                  ),
                ),

                // NÚT PHẢI (RIGHT)
                Positioned(
                  right: 14 * widget.buttonScale,
                  child: _buildDPadArrow(
                    direction: 'RIGHT',
                    icon: Icons.arrow_right,
                    width: wingLength,
                    height: wingWidth,
                  ),
                ),

                // Điểm lõm trung tâm
                Container(
                  width: 26 * widget.buttonScale,
                  height: 26 * widget.buttonScale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1712),
                    border: Border.all(color: const Color(0xFF7A6854), width: 1.5),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDPadArrow({
    required String direction,
    required IconData icon,
    required double width,
    required double height,
  }) {
    final isDown = _activeDPadDirs.contains(direction);
    return Listener(
      onPointerDown: (_) {
        if (widget.isEditMode) return;
        _triggerHaptic();
        setState(() => _activeDPadDirs.add(direction));
        widget.onButtonEvent(direction, true);
      },
      onPointerUp: (_) {
        if (widget.isEditMode) return;
        setState(() => _activeDPadDirs.remove(direction));
        widget.onButtonEvent(direction, false);
      },
      onPointerCancel: (_) {
        if (widget.isEditMode) return;
        setState(() => _activeDPadDirs.remove(direction));
        widget.onButtonEvent(direction, false);
      },
      child: AnimatedScale(
        scale: isDown ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDown ? const Color(0xFFD4AF37) : Colors.transparent,
            borderRadius: BorderRadius.circular(4 * widget.buttonScale),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isDown ? Colors.black : const Color(0xFFF2ECE1),
              size: 28 * widget.buttonScale,
            ),
          ),
        ),
      ),
    );
  }

  /// 3. CỤM PHÍM Ô VUÔNG 4 HƯỚNG RIÊNG BIỆT (UP, DOWN, LEFT, RIGHT)
  Widget _buildSquareDPad() {
    final outerSize = 132.0 * widget.buttonScale;
    final btnSize = 40.0 * widget.buttonScale;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _updateDPadFromOffset(details.localPosition, size),
            onPanUpdate: (details) => _updateDPadFromOffset(details.localPosition, size),
            onPanEnd: (_) => _releaseDPad(),
            onPanCancel: () => _releaseDPad(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Khung viền vuông bo góc tinh tế
                Container(
                  width: outerSize,
                  height: outerSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16 * widget.buttonScale),
                    color: const Color(0xFF131722),
                    border: Border.all(color: const Color(0xFF2A364F), width: 1.5 * widget.buttonScale),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),

                // NÚT LÊN (UP) - Dạng ô vuông
                Positioned(
                  top: 6 * widget.buttonScale,
                  child: _buildSquareDirectionBtn(
                    direction: 'UP',
                    icon: Icons.keyboard_arrow_up_rounded,
                    size: btnSize,
                  ),
                ),

                // NÚT XUỐNG (DOWN) - Dạng ô vuông
                Positioned(
                  bottom: 6 * widget.buttonScale,
                  child: _buildSquareDirectionBtn(
                    direction: 'DOWN',
                    icon: Icons.keyboard_arrow_down_rounded,
                    size: btnSize,
                  ),
                ),

                // NÚT TRÁI (LEFT) - Dạng ô vuông
                Positioned(
                  left: 6 * widget.buttonScale,
                  child: _buildSquareDirectionBtn(
                    direction: 'LEFT',
                    icon: Icons.keyboard_arrow_left_rounded,
                    size: btnSize,
                  ),
                ),

                // NÚT PHẢI (RIGHT) - Dạng ô vuông
                Positioned(
                  right: 6 * widget.buttonScale,
                  child: _buildSquareDirectionBtn(
                    direction: 'RIGHT',
                    icon: Icons.keyboard_arrow_right_rounded,
                    size: btnSize,
                  ),
                ),

                // Điểm tâm vuông trang trí
                Container(
                  width: 20 * widget.buttonScale,
                  height: 20 * widget.buttonScale,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4 * widget.buttonScale),
                    color: const Color(0xFF1A2234),
                    border: Border.all(color: const Color(0xFF3B4E73), width: 1.0),
                  ),
                  child: Center(
                    child: Container(
                      width: 6 * widget.buttonScale,
                      height: 6 * widget.buttonScale,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSquareDirectionBtn({
    required String direction,
    required IconData icon,
    required double size,
  }) {
    final isDown = _activeDPadDirs.contains(direction);
    return Listener(
      onPointerDown: (_) {
        if (widget.isEditMode) return;
        _triggerHaptic();
        setState(() => _activeDPadDirs.add(direction));
        widget.onButtonEvent(direction, true);
      },
      onPointerUp: (_) {
        if (widget.isEditMode) return;
        setState(() => _activeDPadDirs.remove(direction));
        widget.onButtonEvent(direction, false);
      },
      onPointerCancel: (_) {
        if (widget.isEditMode) return;
        setState(() => _activeDPadDirs.remove(direction));
        widget.onButtonEvent(direction, false);
      },
      child: AnimatedScale(
        scale: isDown ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8 * widget.buttonScale),
            gradient: LinearGradient(
              colors: isDown
                  ? [const Color(0xFF0091EA), const Color(0xFF00B0FF)]
                  : [const Color(0xFF263248), const Color(0xFF192233)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isDown ? const Color(0xFF80D8FF) : const Color(0xFF455A7E),
              width: 1.5 * widget.buttonScale,
            ),
            boxShadow: [
              BoxShadow(
                color: isDown
                    ? const Color(0xFF00B0FF).withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                blurRadius: isDown ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 26 * widget.buttonScale,
              color: isDown ? Colors.white : const Color(0xFFB0BEC5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút chữ nhật bo góc SELECT / START (Có hiệu ứng nhún nhẹ 0.92 khi nhấn)
class _SystemPill extends StatefulWidget {
  final String label;
  final double scale;
  final bool isEditMode;
  final VoidCallback onHaptic;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _SystemPill({
    required this.label,
    required this.scale,
    required this.isEditMode,
    required this.onHaptic,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<_SystemPill> createState() => _SystemPillState();
}

class _SystemPillState extends State<_SystemPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final w = 62.0 * s;
    final h = 30.0 * s;

    return Listener(
      onPointerDown: (_) {
        if (widget.isEditMode) return;
        widget.onHaptic();
        setState(() => _isPressed = true);
        widget.onDown();
      },
      onPointerUp: (_) {
        if (widget.isEditMode) return;
        setState(() => _isPressed = false);
        widget.onUp();
      },
      onPointerCancel: (_) {
        if (widget.isEditMode) return;
        setState(() => _isPressed = false);
        widget.onUp();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        child: Container(
          width: w,
          height: h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isPressed ? const Color(0xFFDED6C8) : const Color(0xFFF2ECE1),
            borderRadius: BorderRadius.circular(15 * s),
            border: Border.all(color: const Color(0xFFC7BBA5), width: 1.5 * s),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isPressed ? 0.6 : 0.4),
                offset: _isPressed ? const Offset(0, 1) : const Offset(0, 2),
                blurRadius: _isPressed ? 2 : 3,
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: const Color(0xFF3E3120),
              fontSize: 10 * s,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút tròn phụ trợ MENU / TỐC ĐỘ (Có hiệu ứng nhún nhẹ 0.92 khi nhấn)
class _CircularCenterBtn extends StatefulWidget {
  final IconData? icon;
  final String? text;
  final double scale;
  final bool isEditMode;
  final VoidCallback onHaptic;
  final VoidCallback onTap;

  const _CircularCenterBtn({
    this.icon,
    this.text,
    required this.scale,
    required this.isEditMode,
    required this.onHaptic,
    required this.onTap,
  });

  @override
  State<_CircularCenterBtn> createState() => _CircularCenterBtnState();
}

class _CircularCenterBtnState extends State<_CircularCenterBtn> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final size = 34.0 * s;

    return Listener(
      onPointerDown: (_) {
        if (widget.isEditMode) return;
        widget.onHaptic();
        setState(() => _isPressed = true);
        widget.onTap();
      },
      onPointerUp: (_) {
        if (widget.isEditMode) return;
        setState(() => _isPressed = false);
      },
      onPointerCancel: (_) {
        if (widget.isEditMode) return;
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _isPressed ? const Color(0xFFDED6C8) : const Color(0xFFF2ECE1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC7BBA5), width: 1.5 * s),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isPressed ? 0.5 : 0.4),
                offset: _isPressed ? const Offset(0, 1) : const Offset(0, 2),
                blurRadius: 3,
              ),
            ],
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(widget.icon, color: const Color(0xFF3E3120), size: 18 * s)
                : Text(
                    widget.text ?? '',
                    style: TextStyle(
                      color: const Color(0xFF3E3120),
                      fontSize: 11 * s,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Nút Combo A+B / C+D (Có hiệu ứng nhún nhẹ 0.92 khi nhấn)
class _ComboBtn extends StatefulWidget {
  final String label;
  final double scale;
  final bool isEditMode;
  final VoidCallback onHaptic;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _ComboBtn({
    required this.label,
    required this.scale,
    required this.isEditMode,
    required this.onHaptic,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<_ComboBtn> createState() => _ComboBtnState();
}

class _ComboBtnState extends State<_ComboBtn> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final w = 50.0 * s;
    final h = 36.0 * s;

    return Listener(
      onPointerDown: (_) {
        if (widget.isEditMode) return;
        widget.onHaptic();
        setState(() => _isPressed = true);
        widget.onDown();
      },
      onPointerUp: (_) {
        if (widget.isEditMode) return;
        setState(() => _isPressed = false);
        widget.onUp();
      },
      onPointerCancel: (_) {
        if (widget.isEditMode) return;
        setState(() => _isPressed = false);
        widget.onUp();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        child: Container(
          width: w,
          height: h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isPressed ? const Color(0xFFDED6C8) : const Color(0xFFF2ECE1),
            borderRadius: BorderRadius.circular(18 * s),
            border: Border.all(color: const Color(0xFFC7BBA5), width: 1.5 * s),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isPressed ? 0.5 : 0.4),
                blurRadius: _isPressed ? 2 : 4,
                offset: _isPressed ? const Offset(0, 1) : const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: const Color(0xFF3E3120),
              fontSize: 11 * s,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút tròn hành động A, B, C, D Arcade (Có hiệu ứng nhún nhẹ 0.92 khi nhấn và phát sáng viền)
class _ArcadeCircleBtn extends StatefulWidget {
  final String label;
  final Color primaryColor;
  final Color darkColor;
  final double scale;
  final bool isEditMode;
  final VoidCallback onHaptic;
  final Function(String btn, bool isDown) onButtonEvent;

  const _ArcadeCircleBtn({
    required this.label,
    required this.primaryColor,
    required this.darkColor,
    required this.scale,
    required this.isEditMode,
    required this.onHaptic,
    required this.onButtonEvent,
  });

  @override
  State<_ArcadeCircleBtn> createState() => _ArcadeCircleBtnState();
}

class _ArcadeCircleBtnState extends State<_ArcadeCircleBtn> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final size = 46.0 * s;

    return Listener(
      onPointerDown: (_) {
        if (widget.isEditMode) return;
        widget.onHaptic();
        setState(() => _isPressed = true);
        widget.onButtonEvent(widget.label, true);
      },
      onPointerUp: (_) {
        if (widget.isEditMode) return;
        setState(() => _isPressed = false);
        widget.onButtonEvent(widget.label, false);
      },
      onPointerCancel: (_) {
        if (widget.isEditMode) return;
        setState(() => _isPressed = false);
        widget.onButtonEvent(widget.label, false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: _isPressed
                  ? [widget.primaryColor.withValues(alpha: 0.85), widget.darkColor]
                  : [widget.primaryColor, widget.darkColor],
              center: const Alignment(-0.25, -0.25),
            ),
            border: Border.all(
              color: _isPressed ? const Color(0xFFFFD700) : const Color(0xFFF2ECE1),
              width: 2 * s,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withValues(alpha: _isPressed ? 0.6 : 0.4),
                blurRadius: _isPressed ? 8 : 6,
                offset: _isPressed ? const Offset(0, 1) : const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18 * s,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

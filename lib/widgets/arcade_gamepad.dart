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
  final String buttonLayout; // 'arcade6', 'arcade4Row', 'arcade4Arc'
  final String joystickType; // 'analog360', 'dpad4'
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
        final btnSize = 44.0 * s;
        final comboW = 44.0 * s;
        final comboH = 38.0 * s;
        final selectW = 64.0 * s;
        final selectH = 32.0 * s;
        final startW = 64.0 * s;
        final startH = 32.0 * s;
        final menuSize = 36.0 * s;
        final speedSize = 36.0 * s;
        final gap = 8.0 * s;

        // Tính toán tọa độ mặc định chuẩn Image 1 (Không có nút nào ở giữa)
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

          if (widget.buttonLayout == 'arcade4Row') {
            // 4 nút thẳng hàng: A+B, C+D ở trên; A, B, C, D ở dưới
            final row4W = btnSize * 4 + gap * 3;
            final right4X = W - margin - row4W;
            defaultPositions['AB'] = Offset(right4X, bottomBaseY - btnSize - 10.0 * s - comboH);
            defaultPositions['CD'] = Offset(right4X + comboW + gap * 2, bottomBaseY - btnSize - 10.0 * s - comboH);
            defaultPositions['A'] = Offset(right4X, bottomBaseY - btnSize);
            defaultPositions['B'] = Offset(right4X + btnSize + gap, bottomBaseY - btnSize);
            defaultPositions['C'] = Offset(right4X + (btnSize + gap) * 2, bottomBaseY - btnSize);
            defaultPositions['D'] = Offset(right4X + (btnSize + gap) * 3, bottomBaseY - btnSize);
          } else if (widget.buttonLayout == 'arcade4Arc') {
            // Vòng cung Neo Geo
            final arcBaseX = W - margin - (220.0 * s);
            defaultPositions['A'] = Offset(arcBaseX, bottomBaseY - btnSize - 6.0 * s);
            defaultPositions['B'] = Offset(arcBaseX + 50.0 * s, bottomBaseY - btnSize - 30.0 * s);
            defaultPositions['C'] = Offset(arcBaseX + 104.0 * s, bottomBaseY - btnSize - 44.0 * s);
            defaultPositions['D'] = Offset(arcBaseX + 158.0 * s, bottomBaseY - btnSize - 28.0 * s);
            defaultPositions['AB'] = Offset(arcBaseX + 48.0 * s, bottomBaseY - comboH);
            defaultPositions['CD'] = Offset(arcBaseX + 122.0 * s, bottomBaseY - comboH);
          } else {
            // Chuẩn Neo Geo 6 nút (2 hàng x 3 nút) đúng như Image 1
            defaultPositions['AB'] = Offset(rightBaseX, bottomBaseY - btnSize + (btnSize - comboH) / 2);
            defaultPositions['A'] = Offset(rightBaseX + comboW + gap, bottomBaseY - btnSize);
            defaultPositions['B'] = Offset(rightBaseX + comboW + gap + btnSize + gap, bottomBaseY - btnSize);

            defaultPositions['CD'] = Offset(rightBaseX, bottomBaseY - btnSize - 10.0 * s - btnSize + (btnSize - comboH) / 2);
            defaultPositions['C'] = Offset(rightBaseX + comboW + gap, bottomBaseY - btnSize - 10.0 * s - btnSize);
            defaultPositions['D'] = Offset(rightBaseX + comboW + gap + btnSize + gap, bottomBaseY - btnSize - 10.0 * s - btnSize);
          }

          // Phím MENU [≡] và START ngay trên cụm nút hành động bên phải
          defaultPositions['START'] = Offset(W - margin - startW, max(0.0, bottomBaseY - btnSize - 10.0 * s - btnSize - startH - 12.0 * s));
          defaultPositions['MENU'] = Offset(W - margin - startW - gap - menuSize, max(0.0, bottomBaseY - btnSize - 10.0 * s - btnSize - menuSize - 10.0 * s));
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

          defaultPositions['AB'] = Offset(rightBaseX, bottomBaseY - btnSize + (btnSize - comboH) / 2);
          defaultPositions['A'] = Offset(rightBaseX + comboW + gap, bottomBaseY - btnSize);
          defaultPositions['B'] = Offset(rightBaseX + comboW + gap + btnSize + gap, bottomBaseY - btnSize);

          defaultPositions['CD'] = Offset(rightBaseX, bottomBaseY - btnSize - 10.0 * s - btnSize + (btnSize - comboH) / 2);
          defaultPositions['C'] = Offset(rightBaseX + comboW + gap, bottomBaseY - btnSize - 10.0 * s - btnSize);
          defaultPositions['D'] = Offset(rightBaseX + comboW + gap + btnSize + gap, bottomBaseY - btnSize - 10.0 * s - btnSize);
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
              child: widget.joystickType == 'dpad4' ? _buildDPad() : _buildArcadeJoystick(),
            ),

            // 2. NÚT SELECT (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'SELECT',
              width: selectW,
              height: selectH,
              defaultPos: defaultPositions['SELECT'] ?? const Offset(20, 20),
              W: W,
              H: H,
              child: _buildSystemPill(
                'SELECT',
                () => widget.onButtonEvent('SELECT', true),
                () => widget.onButtonEvent('SELECT', false),
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
              child: _buildCircularCenterBtn(
                text: 'X${widget.speedMultiplier}',
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
              child: _buildCircularCenterBtn(
                icon: Icons.menu_rounded,
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
              child: _buildSystemPill(
                'START',
                () => widget.onButtonEvent('START', true),
                () => widget.onButtonEvent('START', false),
              ),
            ),

            // 6. NÚT C+D (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'CD',
              width: comboW,
              height: comboH,
              defaultPos: defaultPositions['CD'] ?? Offset(W - 160, 100),
              W: W,
              H: H,
              child: _buildComboBtn('C+D', () {
                widget.onButtonEvent('C', true);
                widget.onButtonEvent('D', true);
              }, () {
                widget.onButtonEvent('C', false);
                widget.onButtonEvent('D', false);
              }),
            ),

            // 7. NÚT C (Xanh lá) (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'C',
              width: btnSize,
              height: btnSize,
              defaultPos: defaultPositions['C'] ?? Offset(W - 100, 100),
              W: W,
              H: H,
              isCircle: true,
              child: _buildArcadeCircleBtn('C', const Color(0xFF4CAF50), const Color(0xFF2E7D32)),
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
              child: _buildArcadeCircleBtn('D', const Color(0xFF2196F3), const Color(0xFF0D47A1)),
            ),

            // 9. NÚT A+B (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'AB',
              width: comboW,
              height: comboH,
              defaultPos: defaultPositions['AB'] ?? Offset(W - 160, 160),
              W: W,
              H: H,
              child: _buildComboBtn('A+B', () {
                widget.onButtonEvent('A', true);
                widget.onButtonEvent('B', true);
              }, () {
                widget.onButtonEvent('A', false);
                widget.onButtonEvent('B', false);
              }),
            ),

            // 10. NÚT A (Đỏ - Đặt bom chính xác 100%) (Kéo thả độc lập)
            _buildDraggableButton(
              id: 'A',
              width: btnSize,
              height: btnSize,
              defaultPos: defaultPositions['A'] ?? Offset(W - 100, 160),
              W: W,
              H: H,
              isCircle: true,
              child: _buildArcadeCircleBtn('A', const Color(0xFFE53935), const Color(0xFFB71C1C)),
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
              child: _buildArcadeCircleBtn('B', const Color(0xFFFFB300), const Color(0xFFE65100)),
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
    );
  }

  Widget _buildSystemPill(String label, VoidCallback onDown, VoidCallback onUp) {
    final s = widget.buttonScale;
    final w = 64.0 * s;
    final h = 32.0 * s;

    return Listener(
      onPointerDown: (_) {
        if (widget.isEditMode) return;
        _triggerHaptic();
        onDown();
      },
      onPointerUp: (_) {
        if (widget.isEditMode) return;
        onUp();
      },
      onPointerCancel: (_) {
        if (widget.isEditMode) return;
        onUp();
      },
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF2ECE1),
          borderRadius: BorderRadius.circular(16 * s),
          border: Border.all(color: const Color(0xFFC7BBA5), width: 1.5 * s),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF3E3120),
            fontSize: 10 * s,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildCircularCenterBtn({IconData? icon, String? text, required VoidCallback onTap}) {
    final s = widget.buttonScale;
    final size = 36.0 * s;

    return InkWell(
      onTap: () {
        if (widget.isEditMode) return;
        _triggerHaptic();
        onTap();
      },
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF2ECE1),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFC7BBA5), width: 1.5 * s),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: const Color(0xFF3E3120), size: 18 * s)
              : Text(
                  text ?? '',
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

  Widget _buildComboBtn(String label, VoidCallback onDown, VoidCallback onUp) {
    final s = widget.buttonScale;
    final w = 44.0 * s;
    final h = 38.0 * s;

    return Listener(
      onPointerDown: (_) {
        if (widget.isEditMode) return;
        _triggerHaptic();
        onDown();
      },
      onPointerUp: (_) {
        if (widget.isEditMode) return;
        onUp();
      },
      onPointerCancel: (_) {
        if (widget.isEditMode) return;
        onUp();
      },
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF2ECE1),
          borderRadius: BorderRadius.circular(19 * s),
          border: Border.all(color: const Color(0xFFC7BBA5), width: 1.5 * s),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF3E3120),
            fontSize: 11 * s,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildArcadeCircleBtn(String label, Color primaryColor, Color darkColor) {
    final s = widget.buttonScale;
    final size = 44.0 * s;

    return Listener(
      onPointerDown: (_) {
        if (widget.isEditMode) return;
        _triggerHaptic();
        widget.onButtonEvent(label, true);
      },
      onPointerUp: (_) {
        if (widget.isEditMode) return;
        widget.onButtonEvent(label, false);
      },
      onPointerCancel: (_) {
        if (widget.isEditMode) return;
        widget.onButtonEvent(label, false);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [primaryColor, darkColor],
            center: const Alignment(-0.25, -0.25),
          ),
          border: Border.all(color: const Color(0xFFF2ECE1), width: 2 * s),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * s,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

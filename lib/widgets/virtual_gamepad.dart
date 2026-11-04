import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VirtualGamepad extends StatelessWidget {
  final Function(String btn, bool isDown) onButtonEvent;
  final bool compact;

  const VirtualGamepad({
    super.key,
    required this.onButtonEvent,
    this.compact = false,
  });

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161C),
        border: Border(
          top: BorderSide(color: const Color(0xFFFF2A55).withValues(alpha: 0.3), width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cụm nút CHỌN (SELECT) & BẮT ĐẦU (START)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSystemButton('CHỌN', () => onButtonEvent('SELECT', true), () => onButtonEvent('SELECT', false)),
                const SizedBox(width: 28),
                _buildSystemButton('BẮT ĐẦU', () => onButtonEvent('START', true), () => onButtonEvent('START', false)),
              ],
            ),
            const SizedBox(height: 8),

            // D-Pad bên trái, Cụm phím A/B bên phải
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildDPad(),
                _buildActionButtons(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemButton(String label, VoidCallback onDown, VoidCallback onUp) {
    return Column(
      children: [
        Listener(
          onPointerDown: (_) {
            _triggerHaptic();
            onDown();
          },
          onPointerUp: (_) => onUp(),
          onPointerCancel: (_) => onUp(),
          child: Container(
            width: 54,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.grey.shade700, width: 1),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFF2A55),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildDPad() {
    const double size = 48.0;
    return SizedBox(
      width: size * 3,
      height: size * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 3,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF222226),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Container(
            width: size,
            height: size * 3,
            decoration: BoxDecoration(
              color: const Color(0xFF222226),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Positioned(
            top: 0,
            child: _buildDPadKey(Icons.arrow_drop_up, 'UP', size),
          ),
          Positioned(
            bottom: 0,
            child: _buildDPadKey(Icons.arrow_drop_down, 'DOWN', size),
          ),
          Positioned(
            left: 0,
            child: _buildDPadKey(Icons.arrow_left, 'LEFT', size),
          ),
          Positioned(
            right: 0,
            child: _buildDPadKey(Icons.arrow_right, 'RIGHT', size),
          ),
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E24),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDPadKey(IconData icon, String direction, double size) {
    return Listener(
      onPointerDown: (_) {
        _triggerHaptic();
        onButtonEvent(direction, true);
      },
      onPointerUp: (_) => onButtonEvent(direction, false),
      onPointerCancel: (_) => onButtonEvent(direction, false),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D35),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black54),
        ),
        child: Icon(icon, color: Colors.white70, size: 30),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Transform.rotate(
      angle: -0.2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCircleButton('B', () => onButtonEvent('B', true), () => onButtonEvent('B', false)),
          const SizedBox(width: 22),
          _buildCircleButton('A', () => onButtonEvent('A', true), () => onButtonEvent('A', false)),
        ],
      ),
    );
  }

  Widget _buildCircleButton(String label, VoidCallback onDown, VoidCallback onUp) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: (_) {
            _triggerHaptic();
            onDown();
          },
          onPointerUp: (_) => onUp(),
          onPointerCancel: (_) => onUp(),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFF3366), Color(0xFFB3002D)],
                center: Alignment(-0.2, -0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiBurst extends StatefulWidget {
  final bool active;
  final Widget child;

  const ConfettiBurst({super.key, required this.active, required this.child});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _pieces = <_Piece>[];
  final _random = Random();

  static const _colors = [
    Color(0xFFC1544A),
    Color(0xFFEAF3DE),
    Color(0xFFFAEEDA),
    Color(0xFFF5C4B3),
    Color(0xFF3B6D11),
    Color(0xFFFAC775),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _launch();
    }
  }

  void _launch() {
    if (MediaQuery.of(context).disableAnimations) return;
    _pieces.clear();
    for (int i = 0; i < 20; i++) {
      _pieces.add(_Piece(
        x: _random.nextDouble(),
        startY: -0.04 - _random.nextDouble() * 0.08,
        color: _colors[i % _colors.length],
        w: 6.0 + _random.nextDouble() * 6.0,
        h: 4.0 + _random.nextDouble() * 4.0,
        fallSpeed: 0.7 + _random.nextDouble() * 0.5,
        startAngle: _random.nextDouble() * 2 * pi,
        spinSpeed: (_random.nextDouble() - 0.5) * 6 * pi,
      ));
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_pieces.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(_pieces, _controller.value),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Piece {
  final double x;
  final double startY;
  final Color color;
  final double w;
  final double h;
  final double fallSpeed;
  final double startAngle;
  final double spinSpeed;

  const _Piece({
    required this.x,
    required this.startY,
    required this.color,
    required this.w,
    required this.h,
    required this.fallSpeed,
    required this.startAngle,
    required this.spinSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;

  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final x = p.x * size.width;
      final y = (p.startY + t * p.fallSpeed) * size.height;
      final opacity = t < 0.65 ? 1.0 : (1.0 - t) / 0.35;
      final angle = p.startAngle + t * p.spinSpeed;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

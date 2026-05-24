import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RelationshipBatteryCard extends StatelessWidget {
  final int percent;
  final String statusLine;
  final String message;

  const RelationshipBatteryCard({
    super.key,
    required this.percent,
    required this.statusLine,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final progress = percent.clamp(0, 100) / 100.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.accentRose.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        children: [
          const Row(
            children: [
              Text(
                'Relationship battery',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
              SizedBox(width: 6),
              Icon(
                Icons.info_outline_rounded,
                color: AppTheme.textMuted,
                size: 17,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 186,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(186, 160),
                  painter: _ConnectionRingPainter(progress),
                ),
                Positioned(
                  top: 43,
                  child: SizedBox(
                    width: 132,
                    height: 66,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 4,
                          child: _AvatarBubble(
                            initial: 'A',
                            background: AppTheme.accentRoseLight,
                            foreground: AppTheme.accentRose,
                          ),
                        ),
                        Positioned(
                          right: 4,
                          child: _AvatarBubble(
                            initial: 'S',
                            background: AppTheme.accentGreenLight,
                            foreground: AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  child: Text(
                    '$percent%',
                    style: const TextStyle(
                      color: AppTheme.accentRose,
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.12,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final String initial;
  final Color background;
  final Color foreground;

  const _AvatarBubble({
    required this.initial,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.055),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: foreground,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ConnectionRingPainter extends CustomPainter {
  final double progress;

  const _ConnectionRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.5;
    final center = Offset(size.width / 2, size.width / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = math.pi * 0.82;
    const totalSweep = math.pi * 1.36;

    final bgPaint = Paint()
      ..color = AppTheme.accentRoseLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = AppTheme.accentRose
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, totalSweep, false, bgPaint);
    canvas.drawArc(rect, startAngle, totalSweep * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ConnectionRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

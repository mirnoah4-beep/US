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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.accentRose.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      child: Column(
        children: [
          SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(250, 250),
                  painter: _ConnectionRingPainter(percent / 100),
                ),
                Positioned(
                  top: 70,
                  child: _buildCoupleAvatars(),
                ),
                Positioned(
                  top: 48,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textPrimary.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppTheme.accentRose,
                      size: 26,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 38,
                  child: Text(
                    '$percent%',
                    style: const TextStyle(
                      color: AppTheme.accentRose,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            statusLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoupleAvatars() {
    return SizedBox(
      width: 178,
      height: 86,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            child: _avatar(
              initial: 'A',
              background: AppTheme.accentRoseLight,
              foreground: AppTheme.accentRose,
            ),
          ),
          Positioned(
            right: 18,
            child: _avatar(
              initial: 'S',
              background: AppTheme.accentGreenLight,
              foreground: AppTheme.accentGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar({
    required String initial,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppTheme.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: foreground,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ConnectionRingPainter extends CustomPainter {
  final double progress;

  _ConnectionRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 16.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

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

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, math.pi * 0.78, math.pi * 1.44, false, bgPaint);
    canvas.drawArc(rect, math.pi * 0.78, math.pi * 1.44 * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ConnectionRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.favorite_border_rounded,
                color: AppTheme.accentRose,
                size: 19,
              ),
              SizedBox(width: 8),
              Text(
                'Relationship battery',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 86,
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      child: _AvatarBubble(
                        label: 'A',
                        background: AppTheme.accentRoseLight,
                        foreground: AppTheme.accentRose,
                      ),
                    ),
                    Positioned(
                      left: 38,
                      child: _AvatarBubble(
                        label: 'S',
                        background: AppTheme.accentGreenLight,
                        foreground: AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                  height: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreenLight.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Good',
                  style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppTheme.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentRose),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message.isEmpty ? 'Recharge with small moments tonight.' : message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _AvatarBubble({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.white, width: 3),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

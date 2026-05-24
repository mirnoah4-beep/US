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

  Color get _batteryColor {
    if (percent >= 75) return AppTheme.accentGreen;
    if (percent >= 50) return AppTheme.warningAmber;
    return AppTheme.accentRose;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Relationship battery',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _batteryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    color: _batteryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation<Color>(_batteryColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            statusLine,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

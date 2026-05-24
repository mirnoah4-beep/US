import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GoalCard extends StatelessWidget {
  final String label;
  final int current;
  final int total;
  final String? sublabel;

  const GoalCard({
    super.key,
    required this.label,
    required this.current,
    required this.total,
    this.sublabel,
  });

  bool get _isComplete => current >= total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _isComplete ? AppTheme.accentGreenLight : AppTheme.cardBeige,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$current',
                style: TextStyle(
                  color: _isComplete ? AppTheme.accentGreen : AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '/$total',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          if (_isComplete) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.accentGreen),
                const SizedBox(width: 4),
                Text(
                  'Done',
                  style: TextStyle(color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class LastDateCard extends StatelessWidget {
  final int daysAgo;

  const LastDateCard({super.key, required this.daysAgo});

  @override
  Widget build(BuildContext context) {
    final isRecent = daysAgo <= 7;
    return Container(
      decoration: BoxDecoration(
        color: isRecent ? AppTheme.accentGreenLight : AppTheme.accentRoseLight,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last date',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                daysAgo == 0 ? 'Today' : '$daysAgo',
                style: TextStyle(
                  color: isRecent ? AppTheme.accentGreen : AppTheme.accentRose,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (daysAgo > 0) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'days ago',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

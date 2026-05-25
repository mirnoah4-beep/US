import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/language_provider.dart';
import '../models/moment_item.dart';
import '../theme/app_theme.dart';

class HeatCard extends StatelessWidget {
  final MomentItem item;
  final VoidCallback onTap;

  const HeatCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: item.heatBgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.heatBorderColor, width: 1.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: item.heatTextColor, size: 24),
            const SizedBox(height: 8),
            Text(
              s.momentTitle(item.id),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              s.daysAgoLabel(item.daysAgo),
              style: TextStyle(
                color: item.heatTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

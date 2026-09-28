import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/home_time_filter.dart';
import '../theme/app_theme.dart';

/// "Hvor mye tid har dere?" — three compact single-select rounded rectangles
/// (18 px radius, the Home shape language; not pills, not Material chips).
/// Selected: burgundy background, white icon/text. Unselected: cream
/// background, burgundy icon/text. Tapping the selected one clears it.
class HomeTimeSelector extends StatelessWidget {
  final AppStrings s;
  final HomeTimeBucket? selected;
  final void Function(HomeTimeBucket) onToggle;

  const HomeTimeSelector({
    super.key,
    required this.s,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.homeTimeQuestion,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        // Wrap (not Row) so large text / 320 dp never overflows — options
        // move to a second line instead.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TimeOption(
              icon: Icons.bolt_rounded,
              label: s.homeTimeQuick,
              selected: selected == HomeTimeBucket.quick,
              onTap: () => onToggle(HomeTimeBucket.quick),
            ),
            _TimeOption(
              icon: Icons.schedule_rounded,
              label: s.homeTimeHour,
              selected: selected == HomeTimeBucket.hour,
              onTap: () => onToggle(HomeTimeBucket.hour),
            ),
            _TimeOption(
              icon: Icons.nightlight_round,
              label: s.homeTimeLong,
              selected: selected == HomeTimeBucket.long,
              onTap: () => onToggle(HomeTimeBucket.long),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppTheme.accentRose;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,   // the label IS the option text; no duplication
      child: Material(
        color: selected ? AppTheme.accentRose : AppTheme.accentRoseLight,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppTheme.accentRose : AppTheme.accentRose.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

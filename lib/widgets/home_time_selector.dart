import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/home_time_filter.dart';
import '../theme/app_theme.dart';

/// Three compact single-select rounded rectangles (18 px radius — not pills,
/// not Material chips), equal widths on one row. Selected: burgundy
/// background, white icon/text. Unselected: light pink background with a
/// faint pink outline, burgundy icon/text. Tapping the selected one clears
/// it. No heading — the selected control is the feedback (den.png).
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
    // One row, three equal widths — never wraps, never overflows (den.png).
    return Row(
      children: [
        Expanded(
          child: _TimeOption(
            icon: Icons.bolt_rounded,
            label: s.homeTimeQuick,
            selected: selected == HomeTimeBucket.quick,
            onTap: () => onToggle(HomeTimeBucket.quick),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimeOption(
            icon: Icons.schedule_rounded,
            label: s.homeTimeHour,
            selected: selected == HomeTimeBucket.hour,
            onTap: () => onToggle(HomeTimeBucket.hour),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimeOption(
            icon: Icons.nightlight_round,
            label: s.homeTimeLong,
            selected: selected == HomeTimeBucket.long,
            onTap: () => onToggle(HomeTimeBucket.long),
          ),
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
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppTheme.accentRose : AppTheme.accentRose.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

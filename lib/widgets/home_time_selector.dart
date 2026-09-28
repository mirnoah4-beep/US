import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/home_time_filter.dart';
import '../theme/app_theme.dart';

/// One quiet segmented control — [ 10 min | 1 t | 2+ t ] — inside a single
/// rounded rectangle (18 px radius, not a pill, not Material chips). Three
/// equal-width text-only segments; selected = burgundy with white text,
/// unselected = light background with burgundy text. Tapping the selected
/// segment clears the filter (the caller's toggle). Session-only state.
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
    final segments = [
      (HomeTimeBucket.quick, s.homeTimeQuick),
      (HomeTimeBucket.hour, s.homeTimeHour),
      (HomeTimeBucket.long, s.homeTimeLong),
    ];
    return Container(
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.accentRoseLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0)
              // Subtle divider, hidden next to the selected segment.
              Container(
                width: 1,
                height: 18,
                color: (selected == segments[i].$1 || selected == segments[i - 1].$1)
                    ? Colors.transparent
                    : AppTheme.accentRose.withValues(alpha: 0.18),
              ),
            Expanded(
              child: _Segment(
                label: segments[i].$2,
                selected: selected == segments[i].$1,
                onTap: () => onToggle(segments[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,   // the label IS the segment text; no duplication
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected ? AppTheme.accentRose : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.accentRose,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

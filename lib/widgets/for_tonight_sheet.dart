import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/couple_preferences.dart';
import '../theme/app_theme.dart';

/// Lightweight per-request override: "For tonight". The controls default to
/// the derived couple profile; the result applies ONLY to the one
/// recommendation request the caller makes with it. Nothing here writes to
/// onboarding/default preferences.
class ForTonightChoice {
  final String availableTime;
  final String childcareState;
  final List<String> locations;
  const ForTonightChoice({
    required this.availableTime,
    required this.childcareState,
    required this.locations,
  });

  /// The bounded payload the `generateWeeklyIdeasNow` callable validates.
  Map<String, dynamic> toOverrides({required bool isParent}) => {
        'availableTime': availableTime,
        if (isParent) 'childcareState': childcareState,
        if (locations.isNotEmpty) 'locationPreferences': locations,
      };
}

Future<ForTonightChoice?> showForTonightSheet(
  BuildContext context, {
  required AppStrings s,
  required CoupleProfile profile,
}) {
  return showModalBottomSheet<ForTonightChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ForTonightSheet(s: s, profile: profile),
  );
}

class _ForTonightSheet extends StatefulWidget {
  final AppStrings s;
  final CoupleProfile profile;
  const _ForTonightSheet({required this.s, required this.profile});

  @override
  State<_ForTonightSheet> createState() => _ForTonightSheetState();
}

class _ForTonightSheetState extends State<_ForTonightSheet> {
  late String _time = widget.profile.availableTime;
  late String _care = widget.profile.childcareState;
  late Set<String> _locations = widget.profile.locationIds.toSet();

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewPadding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(s.forTonightTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(s.forTonightSubtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 18),
            _Label(s.forTonightTime),
            _Chips(
              options: {'fewHours': s.timeFewHours, 'evening': s.timeEvening, 'fullDay': s.timeFullDay},
              selected: {_time},
              onTap: (v) => setState(() => _time = v),
            ),
            if (widget.profile.isParent) ...[
              const SizedBox(height: 14),
              _Label(s.forTonightKids),
              _Chips(
                options: {'kidsHome': s.kidsHome, 'kidFree': s.kidFree},
                selected: {_care},
                onTap: (v) => setState(() => _care = v),
              ),
            ],
            const SizedBox(height: 14),
            _Label(s.forTonightWhere),
            _Chips(
              options: {'nature': s.onbPlaceNatureTitle, 'cafe': s.onbPlaceCafeTitle, 'home': s.onbPlaceHomeTitle, 'out': s.onbPlaceOutTitle},
              selected: _locations,
              onTap: (v) => setState(() {
                _locations = {..._locations};
                if (!_locations.remove(v)) _locations.add(v);
              }),
            ),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRose,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(
                context,
                ForTonightChoice(
                  availableTime: _time,
                  childcareState: _care,
                  locations: kLocationIds.where(_locations.contains).toList(),
                ),
              ),
              child: Text(s.forTonightCta, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(s.forTonightNote, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      );
}

class _Chips extends StatelessWidget {
  final Map<String, String> options;
  final Set<String> selected;
  final void Function(String) onTap;
  const _Chips({required this.options, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: selected.contains(e.key),
              onSelected: (_) => onTap(e.key),
              selectedColor: AppTheme.accentRose.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: selected.contains(e.key) ? AppTheme.accentRose : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: selected.contains(e.key) ? AppTheme.accentRose : const Color(0xFFE2DED8)),
              showCheckmark: false,
            ),
        ],
      );
}

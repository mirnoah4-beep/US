import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Header row of the Home recommendation section:
///   Noe for dere / Something for you        For i kveld →
/// The heading keeps its size and may wrap to a second line on narrow
/// widths / large text; it never clips, and the secondary action never
/// overlaps it (it sits in its own slot, aligned to the top).
class HomeRecommendationHeader extends StatelessWidget {
  final AppStrings s;
  final String heading;
  /// Null hides the secondary action (no partner).
  final VoidCallback? onTonight;
  final bool tonightLoading;
  /// Optional badge shown right after the heading (the "Tonight ×" chip).
  final Widget? badge;

  const HomeRecommendationHeader({
    super.key,
    required this.s,
    required this.heading,
    required this.onTonight,
    this.tonightLoading = false,
    this.badge,
  });

  static const _headingStyle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFamily: 'Georgia',
  );

  @override
  Widget build(BuildContext context) {
    final headingText = Text(heading, style: _headingStyle, softWrap: true);
    final action = onTonight == null ? null : _TonightAction(s: s, onTap: onTonight!, loading: tonightLoading);
    final badgeRow = badge == null ? null : Padding(padding: const EdgeInsets.only(left: 8), child: badge);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure the single-line heading at the CURRENT text scale. If the
        // heading (+ badge) and the action fit side by side, use one row;
        // otherwise stack them so the heading keeps its size and never clips.
        final scaler = MediaQuery.textScalerOf(context);
        final painter = TextPainter(
          text: TextSpan(text: heading, style: _headingStyle),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final actionWidth = action == null ? 0.0 : _TonightAction.estimateWidth(s, scaler) + 8;
        final badgeWidth = badge == null ? 0.0 : 8 + 72 * scaler.scale(1);
        final fitsOneRow = painter.width + badgeWidth + actionWidth <= constraints.maxWidth;
        painter.dispose();

        if (fitsOneRow || action == null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: headingText),
              ?badgeRow,
              if (action != null) ...[const Spacer(), action],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Flexible(child: headingText), ?badgeRow]),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        );
      },
    );
  }

}

class _TonightAction extends StatelessWidget {
  final AppStrings s;
  final VoidCallback onTap;
  final bool loading;
  const _TonightAction({required this.s, required this.onTap, required this.loading});

  static const _style = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);

  /// Text width + icon + gaps + button padding, at the given text scale.
  static double estimateWidth(AppStrings s, TextScaler scaler) {
    final p = TextPainter(
      text: TextSpan(text: s.forTonightTitle, style: _style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final w = p.width;
    p.dispose();
    return w + 3 + 13 + 12;
  }

  @override
  Widget build(BuildContext context) {
    // Secondary action — visually lighter than the heading.
    return TextButton(
      onPressed: loading ? null : onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppTheme.accentRose,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.forTonightTitle, style: _style),
          const SizedBox(width: 3),
          loading
              ? const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5))
              : const Icon(Icons.arrow_forward_rounded, size: 13),
        ],
      ),
    );
  }
}

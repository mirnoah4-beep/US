import 'package:flutter/material.dart';

/// Title of the Home recommendation card. It NEVER breaks a word in the
/// middle ("Bibliotekdat / e"):
///   1. measures the longest word at the current text scale;
///   2. if it does not fit the column, shrinks the font just enough (down
///      to [minFontSize]) so every word fits — multi-word titles then wrap
///      at spaces only (max two lines);
///   3. if even [minFontSize] cannot hold the longest word, the whole title
///      is drawn on ONE line scaled down to fit, so it is still never split.
class IdeaCardTitle extends StatelessWidget {
  final String text;
  const IdeaCardTitle(this.text, {super.key});

  static const style = TextStyle(
    color: Color(0xFF1A1A1A),
    fontSize: 17,
    fontWeight: FontWeight.w700,
    fontFamily: 'Georgia',
    height: 1.2,
  );
  static const minFontSize = 12.0;

  /// Width of the widest word at [fontSize] for the given scaler, measured
  /// with the same effective (inherited + own) style the text renders with.
  static double longestWordWidth(String text, double fontSize, TextScaler scaler, {TextStyle base = style}) {
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final p = TextPainter(
        text: TextSpan(text: word, style: base.copyWith(fontSize: fontSize)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (p.width > widest) widest = p.width;
      p.dispose();
    }
    return widest;
  }

  /// The font size to use for [maxWidth], or null when even [minFontSize]
  /// cannot hold the longest word (→ single scaled line).
  static double? fittingFontSize(String text, double maxWidth, TextScaler scaler, {TextStyle effective = style}) {
    final base = style.fontSize!;
    final widest = longestWordWidth(text, base, scaler, base: effective);
    if (widest <= maxWidth) return base;
    // Start from the linear estimate, then verify by measuring (glyph
    // rounding is not perfectly linear) and step down until it really fits.
    var size = ((base * maxWidth / widest) * 10).floor() / 10;
    while (size >= minFontSize) {
      if (longestWordWidth(text, size, scaler, base: effective) <= maxWidth) return size;
      size -= 0.5;
    }
    return longestWordWidth(text, minFontSize, scaler, base: effective) <= maxWidth ? minFontSize : null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        // Inherited defaults (e.g. Material letterSpacing) affect the render,
        // so measure with the merged style, exactly as Text will draw it.
        final effective = DefaultTextStyle.of(context).style.merge(style);
        final size = fittingFontSize(text, constraints.maxWidth, scaler, effective: effective);
        if (size == null) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text, style: style.copyWith(fontSize: minFontSize), maxLines: 1, softWrap: false),
          );
        }
        return Text(
          text,
          style: style.copyWith(fontSize: size),
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

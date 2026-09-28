// Recommendation-card title: never breaks a word in the middle, at the
// card's real left-column width, for long NO and EN titles.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/widgets/idea_card_title.dart';

const titles = [
  'Bibliotekdate', 'Matlagingskonkurranse', 'Bruktbutikk-utfordring', 'Planlegg drømmereisen',
  'Frokost ute på en hverdag', 'Hvor godt kjenner du meg?', 'Planlegg helgen på ti minutter',
  'Library date', 'Cooking competition', 'Thrift shop challenge', 'Weekday breakfast out',
  'How well do you know me?', 'Plan the weekend in ten minutes', 'Stargazing',
];

/// Left text column of the card: 50 % of the card minus 14 px padding each
/// side; a 360 dp phone gives a ~312 px card → 128 px; 320 dp → ~108 px.
/// (The test font draws ~1 em per glyph, roughly twice as wide as Georgia,
/// so these widths are a harder case than any real device.)
const widths = [108.0, 128.0, 150.0, 240.0];

void main() {
  for (final w in widths) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no mid-word break at ${w}px, ${scale}x', (t) async {
        for (final title in titles) {
          await t.pumpWidget(MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(body: SizedBox(width: w, child: IdeaCardTitle(title))),
            ),
          ));
          expect(t.takeException(), isNull, reason: title);
          final para = t.renderObject<RenderParagraph>(find.text(title));
          final style = para.text.style!;
          final scaledLine = find.byType(FittedBox).evaluate().isNotEmpty;
          if (scaledLine) {
            // Fallback branch: one line, scaled — a word can never be split.
            expect(para.didExceedMaxLines, isFalse, reason: title);
          } else {
            // Every word fits on a line at the chosen size → wraps only at spaces.
            for (final word in title.split(' ')) {
              final p = TextPainter(
                text: TextSpan(text: word, style: style),
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.linear(scale),
                maxLines: 1,
              )..layout();
              expect(p.width <= para.size.width + 0.5, isTrue,
                  reason: '"$word" (${p.width.toStringAsFixed(1)}px) does not fit in ${para.size.width}px at font ${style.fontSize} for "$title"');
              p.dispose();
            }
          }
          expect(style.fontSize! >= IdeaCardTitle.minFontSize, isTrue, reason: title);
        }
      });
    }
  }
}

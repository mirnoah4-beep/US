// Home recommendation header: heading + "For i kveld →" never overflow, clip
// or overlap at 320 dp, at 1.0× and 1.3× text scale, NO and EN.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/l10n/strings.dart';
import 'package:us_app/widgets/home_recommendation_header.dart';

Widget host({required bool no, required double scale, bool withBadge = false}) {
  final s = AppStrings(isNorwegian: no);
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),   // Home's ListView side padding
            child: HomeRecommendationHeader(
              s: s,
              heading: s.somethingForYouTwo,
              onTonight: () {},
              badge: withBadge ? const Text('I kveld ×', style: TextStyle(fontSize: 11)) : null,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> setPhone(WidgetTester t) async {
  t.view.physicalSize = const Size(320, 700);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  for (final no in [true, false]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('${no ? 'NO' : 'EN'} @ ${scale}x: no overflow, no clip, no overlap', (t) async {
        await setPhone(t);
        await t.pumpWidget(host(no: no, scale: scale));
        expect(t.takeException(), isNull, reason: 'RenderFlex overflow would throw here');
        final s = AppStrings(isNorwegian: no);
        final headingFinder = find.text(s.somethingForYouTwo);
        final actionFinder = find.text(s.forTonightTitle);
        expect(headingFinder, findsOneWidget);
        expect(actionFinder, findsOneWidget);
        // Not clipped: the paragraph fits its box (no truncation beyond 2 lines).
        final para = t.renderObject<RenderParagraph>(headingFinder);
        expect(para.textSize.height <= para.size.height + 0.5, isTrue, reason: 'heading clipped');
        expect(para.textSize.width <= para.size.width + 0.5, isTrue, reason: 'heading wider than its box');
        // Font size preserved (no shrinking).
        expect(t.widget<Text>(headingFinder).style!.fontSize, 18);
        // No overlap between heading and the action (side by side, or stacked).
        final h = t.getRect(headingFinder);
        final a = t.getRect(actionFinder);
        expect(h.right <= a.left || h.bottom <= a.top, isTrue, reason: 'heading overlaps the action');
        // Everything inside the 320 dp screen.
        expect(a.right <= 320, isTrue);
      });
    }
  }

  testWidgets('EN @ 1.3x with the Tonight badge still fits', (t) async {
    await setPhone(t);
    await t.pumpWidget(host(no: false, scale: 1.3, withBadge: true));
    expect(t.takeException(), isNull);
    expect(t.getRect(find.text('For tonight')).right <= 320, isTrue);
  });
}

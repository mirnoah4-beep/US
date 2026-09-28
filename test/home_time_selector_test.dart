// Widget: segmented control — NO/EN labels, one row without overflow at 320 dp × 1.3 text scale, semantics, toggle.
import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/l10n/strings.dart';
import 'package:us_app/models/home_time_filter.dart';
import 'package:us_app/widgets/home_time_selector.dart';

Widget host({required bool no, HomeTimeBucket? selected, void Function(HomeTimeBucket)? onToggle, double width = 320, double scale = 1.3}) =>
    MediaQuery(
      data: MediaQueryData(size: Size(width, 700), textScaler: TextScaler.linear(scale)),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: HomeTimeSelector(s: AppStrings(isNorwegian: no), selected: selected, onToggle: onToggle ?? (_) {}),
          ),
        ),
      ),
    );

void main() {
  testWidgets('Norwegian labels, one row, no heading', (t) async {
    await t.pumpWidget(host(no: true));
    expect(find.text('Hvor mye tid har dere?'), findsNothing);
    expect(find.byIcon(Icons.bolt_rounded), findsNothing, reason: 'text-only segments');
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('1 t'), findsOneWidget);
    expect(find.text('2+ t'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('English labels, 320 dp at 1.3× — no overflow, all three on one row', (t) async {
    await t.pumpWidget(host(no: false));
    expect(find.text('1 hr'), findsOneWidget);
    final y = ['10 min', '1 hr', '2+ hrs'].map((l) => t.getTopLeft(find.text(l)).dy).toSet();
    expect(y.length, 1, reason: 'the three options share one row');
    expect(find.text('2+ hrs'), findsOneWidget);
    expect(t.takeException(), isNull, reason: 'a RenderFlex overflow would surface here');
  });

  testWidgets('selected / unselected semantics are exposed', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(host(no: true, selected: HomeTimeBucket.quick));
    final quick = t.getSemantics(find.bySemanticsLabel('10 min'));
    expect(quick.flagsCollection.isSelected, Tristate.isTrue);
    expect(quick.flagsCollection.isButton, isTrue);
    final hour = t.getSemantics(find.bySemanticsLabel('1 t'));
    expect(hour.flagsCollection.isSelected, Tristate.isFalse);
    expect(hour.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('tapping reports the bucket; the holder toggles/clears', (t) async {
    HomeTimeSelection.instance.reset();
    final taps = <HomeTimeBucket>[];
    await t.pumpWidget(host(no: true, onToggle: (b) { taps.add(b); HomeTimeSelection.instance.toggle(b); }));
    await t.tap(find.text('1 t'));
    expect(taps, [HomeTimeBucket.hour]);
    expect(HomeTimeSelection.instance.value, HomeTimeBucket.hour);
    await t.tap(find.text('1 t'));
    expect(HomeTimeSelection.instance.value, isNull);
  });
}

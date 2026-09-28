// Home time shortcut: strict user-facing buckets, parent-mode hard constraint,
// session-only state. Pure.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/models/home_time_filter.dart';
import 'package:us_app/models/idea_library.dart';

void main() {
  final all = parseIdeaLibrary(File('functions/src/ideasLibrary.json').readAsStringSync());

  group('duration parsing and buckets', () {
    test('formats in the library parse to minutes; "+" is open-ended', () {
      expect(parseDuration('10 min'), (minutes: 10, openEnded: false));
      expect(parseDuration('1,5 time'), (minutes: 90, openEnded: false));
      expect(parseDuration('1.5 hours'), (minutes: 90, openEnded: false));
      expect(parseDuration('2 timer+'), (minutes: 120, openEnded: true));
      expect(parseDuration('1 hour+'), (minutes: 60, openEnded: true));
      expect(parseDuration(''), isNull);
      expect(parseDuration('en stund'), isNull);
    });

    test('10 min = ≤10; 1 t = >10 && ≤60 and not open-ended; 2+ t = ≥120', () {
      expect(bucketForDuration('10 min'), HomeTimeBucket.quick);
      expect(bucketForDuration('15 min'), HomeTimeBucket.hour);
      expect(bucketForDuration('60 min'), HomeTimeBucket.hour);
      expect(bucketForDuration('1 time'), HomeTimeBucket.hour);
      expect(bucketForDuration('1 time+'), isNull, reason: 'may exceed the hour');
      expect(bucketForDuration('1,5 time'), isNull, reason: '90 min is neither ≤60 nor ≥120');
      expect(bucketForDuration('2 timer'), HomeTimeBucket.long);
      expect(bucketForDuration('2 timer+'), HomeTimeBucket.long);
      expect(bucketForDuration('3 timer'), HomeTimeBucket.long);
      expect(bucketForDuration('nonsense'), isNull, reason: 'unparseable → excluded from shortcuts');
    });

    test('every library idea has a parseable duration', () {
      for (final i in all) {
        expect(parseDuration(i.durationNo), isNotNull, reason: i.id);
      }
    });
  });

  group('filtering (hard constraints, never relaxed)', () {
    test('10 min never returns longer ideas; 1 t only ≤60; 2+ t only ≥120', () {
      for (final b in HomeTimeBucket.values) {
        final pool = ideasForBucket(all, b, parentMode: false, kidFreeSession: false);
        expect(pool, isNotEmpty, reason: b.name);
        for (final i in pool) {
          final m = parseDuration(i.durationNo)!;
          switch (b) {
            case HomeTimeBucket.quick: expect(m.minutes, lessThanOrEqualTo(10), reason: i.id);
            case HomeTimeBucket.hour: expect(m.minutes, inInclusiveRange(11, 60), reason: i.id); expect(m.openEnded, isFalse, reason: i.id);
            case HomeTimeBucket.long: expect(m.minutes, greaterThanOrEqualTo(120), reason: i.id);
          }
        }
      }
      // 90-minute ideas are in no shortcut but still in the library.
      expect(all.any((i) => i.durationNo == '1,5 time'), isTrue);
      expect(HomeTimeBucket.values.every((b) => ideasForBucket(all, b, parentMode: false, kidFreeSession: false).every((i) => i.durationNo != '1,5 time')), isTrue);
    });

    test('parent mode + kids home → parent-friendly only, in every bucket', () {
      for (final b in HomeTimeBucket.values) {
        final pool = ideasForBucket(all, b, parentMode: true, kidFreeSession: false);
        expect(pool.every((i) => i.parentFriendly), isTrue, reason: b.name);
        expect(pool.any((i) => i.requiresKidFree), isFalse, reason: b.name);
      }
      expect(ideasForBucket(all, HomeTimeBucket.long, parentMode: true, kidFreeSession: false).length, 5);
    });

    test('kid-free session broadens eligibility but never the duration', () {
      final usual = ideasForBucket(all, HomeTimeBucket.long, parentMode: true, kidFreeSession: false);
      final kidFree = ideasForBucket(all, HomeTimeBucket.long, parentMode: true, kidFreeSession: true);
      expect(kidFree.length, greaterThan(usual.length));
      expect(kidFree.any((i) => i.requiresKidFree), isTrue);
      expect(kidFree.every((i) => parseDuration(i.durationNo)!.minutes >= 120), isTrue);
      // Nothing that is neither parent-friendly nor kid-free-only sneaks in.
      expect(kidFree.every((i) => i.parentFriendly || i.requiresKidFree), isTrue);
    });

    test('an incompatible state like "10 min" + a 3-hour idea is impossible', () {
      final quick = ideasForBucket(all, HomeTimeBucket.quick, parentMode: true, kidFreeSession: true);
      expect(quick.any((i) => i.id == 'gå_på_konsert'), isFalse);
      expect(quick.every((i) => parseDuration(i.durationNo)!.minutes <= 10), isTrue);
    });

    test('empty pool stays empty (no fallback to a violating idea)', () {
      final none = ideasForBucket(all.where((i) => i.durationNo == '1,5 time').toList(), HomeTimeBucket.long, parentMode: false, kidFreeSession: false);
      expect(none, isEmpty);
    });

    test('shuffle is deterministic per seed and keeps the pool intact', () {
      final pool = ideasForBucket(all, HomeTimeBucket.hour, parentMode: false, kidFreeSession: false);
      expect(shuffledPool(pool, 7).map((i) => i.id).toList(), shuffledPool(pool, 7).map((i) => i.id).toList());
      expect(shuffledPool(pool, 7).map((i) => i.id).toSet(), pool.map((i) => i.id).toSet());
    });

    test('library idea renders through the Home card with its own cover id and original label', () {
      final w = libraryIdeaAsWeekly(all.firstWhere((i) => i.id == 'bowling'));
      expect(w.imageId, 'bowling');
      expect(w.metaNo, '1 time+');
      expect(w.titleNo, 'Bowling eller minigolf');
    });
  });

  group('session state', () {
    setUp(() => HomeTimeSelection.instance.reset());

    test('tapping the selected option clears it; selecting reseeds', () {
      final sel = HomeTimeSelection.instance;
      expect(sel.value, isNull);
      sel.toggle(HomeTimeBucket.hour);
      expect(sel.value, HomeTimeBucket.hour);
      final seed = sel.seed;
      sel.toggle(HomeTimeBucket.hour);
      expect(sel.value, isNull, reason: 'cleared → normal Home behaviour');
      sel.toggle(HomeTimeBucket.long);
      expect(sel.value, HomeTimeBucket.long);
      expect(sel.seed, isNot(seed));
    });

    test('state is in memory only (no persistence API exists on the holder)', () {
      // The holder is a ValueNotifier with no storage dependency — a fresh
      // process starts at null. Guard against someone adding persistence.
      expect(HomeTimeSelection.instance.value, isNull);
    });
  });
}

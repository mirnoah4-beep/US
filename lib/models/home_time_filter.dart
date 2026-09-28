import 'dart:math';

import 'package:flutter/material.dart';

import 'idea_library.dart';
import 'weekly_idea.dart';

/// Home "Hvor mye tid har dere?" shortcut — session-only, in-memory.
///
/// Buckets follow the user-facing promise strictly (never relaxed):
///   quick: duration ≤ 10 min
///   hour : 10 < duration ≤ 60 min and NOT open-ended ("1 time+" may exceed the hour)
///   long : guaranteed minimum ≥ 120 min ("2 timer+" counts; "1,5 time" does not)
/// An idea that fits none of these is simply not offered by the shortcut.
enum HomeTimeBucket { quick, hour, long }

/// Parsed library duration: minimum minutes and whether it is open-ended ("+").
/// Formats in the library: "10 min", "1 time", "1,5 time", "2 timer", "1 time+".
({int minutes, bool openEnded})? parseDuration(String label) {
  final m = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(min|time|timer|hour|hours|hr|hrs)(\+?)$')
      .firstMatch(label.trim().toLowerCase());
  if (m == null) return null;
  final value = double.parse(m.group(1)!.replaceAll(',', '.'));
  final isMinutes = m.group(2) == 'min';
  return (minutes: (isMinutes ? value : value * 60).round(), openEnded: m.group(3) == '+');
}

HomeTimeBucket? bucketForDuration(String label) {
  final d = parseDuration(label);
  if (d == null) return null;
  if (d.minutes <= 10) return HomeTimeBucket.quick;
  if (d.minutes <= 60) return d.openEnded ? null : HomeTimeBucket.hour;
  if (d.minutes >= 120) return HomeTimeBucket.long;
  return null;
}

HomeTimeBucket? bucketFor(LibraryIdea idea) => bucketForDuration(idea.durationNo);

/// Hard constraints only: the selected bucket AND the parent-mode rule
/// (same `ideaAllowed` the Ideas library uses). Never relaxed.
List<LibraryIdea> ideasForBucket(
  List<LibraryIdea> all,
  HomeTimeBucket bucket, {
  required bool parentMode,
  required bool kidFreeSession,
}) =>
    all
        .where((i) => bucketFor(i) == bucket)
        .where((i) => ideaAllowed(i, parentMode: parentMode, kidFreeSession: kidFreeSession))
        .toList();

/// The session selection. Lives in memory only (survives tab switches,
/// resets on app restart); never written to preferences or Firestore.
class HomeTimeSelection extends ValueNotifier<HomeTimeBucket?> {
  HomeTimeSelection._() : super(null);
  static final HomeTimeSelection instance = HomeTimeSelection._();

  /// Shuffle order fixed per selection so the cards do not jump on rebuilds.
  int _seed = 0;
  int _selections = 0;
  int get seed => _seed;

  /// Tapping the selected option again clears the filter.
  void toggle(HomeTimeBucket bucket) {
    if (value == bucket) {
      value = null;
    } else {
      // Counter keeps the seed unique even for two taps in the same instant.
      _seed = DateTime.now().millisecondsSinceEpoch + (++_selections);
      value = bucket;
    }
  }

  @visibleForTesting
  void reset() { _seed = 0; _selections = 0; value = null; }
}

/// Deterministic shuffle for one selection (seeded), so the pool is stable
/// while the user looks at it but fresh on the next selection.
List<LibraryIdea> shuffledPool(List<LibraryIdea> pool, int seed) {
  final copy = [...pool];
  copy.shuffle(Random(seed));
  return copy;
}

// Same palette family the Ideas screen / server use (card, tag, tag text).
const _kPalettes = [
  (Color(0xFFFAECE7), Color(0xFFF5C4B3), Color(0xFF712B13)),
  (Color(0xFFEAF3DE), Color(0xFFC0DD97), Color(0xFF27500A)),
  (Color(0xFFFAEEDA), Color(0xFFFAC775), Color(0xFF633806)),
  (Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF085041)),
  (Color(0xFFFBEAF0), Color(0xFFF4C0D1), Color(0xFF72243E)),
  (Color(0xFFEAF0FA), Color(0xFFB9CDF2), Color(0xFF1F3A6B)),
  (Color(0xFFF1EAFA), Color(0xFFD3BFF2), Color(0xFF3F2470)),
];

/// Renders a library idea through the existing Home idea card. The original
/// duration label is kept as the card meta; the cover is looked up by the
/// library id (`imageId`), exactly like the Ideas screen does.
WeeklyIdea libraryIdeaAsWeekly(LibraryIdea i) {
  final p = _kPalettes[i.colorIndex % _kPalettes.length];
  return WeeklyIdea(
    titleNo: i.titleNo,
    titleEn: i.titleEn,
    categoryNo: i.categoryNo,
    categoryEn: i.categoryEn,
    metaNo: i.durationNo,
    metaEn: i.durationEn,
    cardColor: p.$1,
    tagColor: p.$2,
    tagTextColor: p.$3,
    icon: i.icon,
    descriptionNo: i.descNo,
    descriptionEn: i.descEn,
    subtitleNo: i.subtitleNo,
    subtitleEn: i.subtitleEn,
    imageId: i.id,
  );
}

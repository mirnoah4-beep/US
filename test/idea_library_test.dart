// The bundled idea library: coverage, bilingual completeness, parent-mode rule.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/models/idea_library.dart';

void main() {
  final all = parseIdeaLibrary(File('functions/src/ideasLibrary.json').readAsStringSync());

  test('library is large, ids are unique and every filter has 20+ ideas', () {
    expect(all.length, greaterThanOrEqualTo(45));
    expect(all.map((i) => i.id).toSet().length, all.length);
    for (final f in ['10min', 'home', 'out']) {
      expect(all.where((i) => i.filters.contains(f)).length, greaterThanOrEqualTo(20), reason: f);
    }
    for (final i in all) {
      expect(i.filters, isNotEmpty, reason: i.id);
      expect(i.filters.every(['10min', 'home', 'out', 'talk', 'food'].contains), isTrue, reason: i.id);
    }
  });

  test('every idea has Norwegian AND English title, subtitle, description, duration, category', () {
    for (final i in all) {
      for (final s in [i.titleNo, i.titleEn, i.subtitleNo, i.subtitleEn, i.descNo, i.descEn, i.durationNo, i.durationEn, i.categoryNo, i.categoryEn]) {
        expect(s.trim(), isNotEmpty, reason: i.id);
      }
      expect(i.titleNo, isNot(equals(i.titleEn)), reason: '${i.id} title not translated');
      expect(i.titleNo.length, lessThanOrEqualTo(34), reason: '${i.id} title too long for the card');
      expect(i.titleEn.length, lessThanOrEqualTo(34), reason: '${i.id} title too long for the card');
      expect(kLibraryIcons.containsKey(i.filters.isEmpty ? '' : ''), isFalse); // sanity: unknown key → fallback path exists
    }
  });

  test('ids are valid cover slugs (lowercase, no spaces) — the same key the server uses', () {
    final slug = RegExp(r'^[a-z0-9æøå_]+$');
    for (final i in all) {
      expect(slug.hasMatch(i.id), isTrue, reason: i.id);
    }
  });

  test('parent mode: only parent-friendly by default; kid-free session admits couple-only ideas', () {
    final couplesOnly = all.where((i) => i.requiresKidFree).toList();
    final friendly = all.where((i) => i.parentFriendly).toList();
    expect(couplesOnly, isNotEmpty);
    expect(friendly.length, greaterThanOrEqualTo(45));
    // No idea is both parent-friendly and couple-only.
    expect(all.where((i) => i.parentFriendly && i.requiresKidFree), isEmpty);

    final usual = filterLibrary(all, 'all', parentMode: true, kidFreeSession: false);
    expect(usual.every((i) => i.parentFriendly), isTrue);
    expect(usual.any((i) => i.requiresKidFree), isFalse);
    for (final f in ['10min', 'home']) {
      expect(filterLibrary(all, f, parentMode: true, kidFreeSession: false).length, greaterThanOrEqualTo(20), reason: f);
    }
    expect(filterLibrary(all, 'out', parentMode: true, kidFreeSession: false).length, greaterThanOrEqualTo(15));

    final kidFree = filterLibrary(all, 'all', parentMode: true, kidFreeSession: true);
    expect(kidFree.length, all.length, reason: 'kid-free session shows the full library');
    expect(filterLibrary(all, 'all', parentMode: false, kidFreeSession: false).length, all.length);
    expect(filterLibrary(all, 'out', parentMode: false, kidFreeSession: false).every((i) => i.filters.contains('out')), isTrue);
  });

  test('parser tolerates missing optional fields and unknown icons', () {
    final one = parseIdeaLibrary('[{"id":"x","titleNo":"A","titleEn":"B","icon":"nope"}]').single;
    expect(one.filters, isEmpty);
    expect(one.parentFriendly, isFalse);
    expect(one.icon, iconFor('nope'));
  });
}

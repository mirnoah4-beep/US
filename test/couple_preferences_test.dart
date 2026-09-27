// Derived couple profile — pure. Mirrors functions/src/__tests__/preferences.test.ts.
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/models/couple_preferences.dart';

void main() {
  test('normalisers accept old and new shapes', () {
    expect(normalizeTime('short'), 'fewHours');
    expect(normalizeTime('halfday'), 'evening');
    expect(normalizeTime('fullDay'), 'fullDay');
    expect(normalizeTime(3), isNull);
    expect(normalizeLocations('home'), ['home']);
    expect(normalizeLocations(['out', 'nature', 'x']), ['nature', 'out']);
    expect(normalizeLocations('both'), kLocationIds);
    expect(normalizeLocations(null), isEmpty);
    expect(hhmmFromParts(20, 5), '20:05');
    expect(hhmmFromParts('20', 5), isNull);
  });

  test('UserPrefs.fromMap never throws and drops junk; toMap emits only allowed keys', () {
    final p = UserPrefs.fromMap({'locationPreferences': 'cafe', 'availableTime': 'day', 'isParent': 'yes', 'bedtimeWeekday': '25:00', 'pace': 'calm'})!;
    expect(p.locationPreferences, ['cafe']);
    expect(p.availableTime, 'fullDay');
    expect(p.isParent, isNull);
    expect(p.bedtimeWeekday, isNull);
    expect(p.toMap().keys, containsAll(['locationPreferences', 'availableTime', 'pace', 'schemaVersion']));
    expect(p.toMap().containsKey('isParent'), isFalse);
    expect(UserPrefs.fromMap(null), isNull);
  });

  test('legacy settings/main maps onboarding and lifestyle fields', () {
    final onb = UserPrefs.fromLegacyMain({'isParent': true, 'place': 'out', 'availableTime': 'short', 'bedtimeHour': 20, 'bedtimeMinute': 30})!;
    expect(onb.locationPreferences, ['out']);
    expect(onb.availableTime, 'fewHours');
    expect(onb.bedtimeWeekday, '20:30');
    expect(onb.bedtimeWeekend, '20:30');
    final life = UserPrefs.fromLegacyMain({'parentMode': false, 'preference': 'both', 'weekdayTime': '2plus'})!;
    expect(life.locationPreferences, kLocationIds);
    expect(life.isParent, isFalse);
    expect(UserPrefs.fromLegacyMain({'onboardingDone': true}), isNull);
  });

  test('two partners with different answers derive one non-destructive profile', () {
    const a = UserPrefs(locationPreferences: ['home', 'nature'], availableTime: 'fullDay', isParent: true, childcareState: 'kidsHome', bedtimeWeekday: '20:00', pace: 'calm');
    const b = UserPrefs(locationPreferences: ['home', 'cafe'], availableTime: 'fewHours', isParent: false, childcareState: 'kidFree', bedtimeWeekday: '19:30', pace: 'active');
    final p = deriveCoupleProfile([a, b]);
    expect(p.locations.map((l) => '${l.id}:${l.weight}'), ['home:2', 'nature:1', 'cafe:1']);
    expect(p.availableTime, 'fewHours');
    expect(p.isParent, isTrue);
    expect(p.childcareState, 'kidsHome');
    expect(p.bedtimeWeekday, '19:30');
    expect(p.pace, 'mixed');
    expect(p.source, 'prefs');
    // Inputs untouched.
    expect(a.availableTime, 'fullDay');
    expect(b.isParent, isFalse);
  });

  test('one partner answered → their answers; none → legacy; nothing → defaults', () {
    final one = deriveCoupleProfile([const UserPrefs(locationPreferences: ['cafe'], availableTime: 'evening', isParent: false), null]);
    expect(one.locationIds, ['cafe']);
    expect(one.childcareState, 'kidFree');
    final legacy = deriveCoupleProfile([null, null], legacy: const UserPrefs(locationPreferences: ['home'], isParent: true));
    expect(legacy.source, 'legacy');
    expect(legacy.childcareState, 'kidsHome');
    final d = deriveCoupleProfile([]);
    expect(d.source, 'defaults');
    expect(d.locations.length, 4);
    expect(d.availableTime, 'evening');
    expect(d.isParent, isFalse);
  });

  test('parent mode never turns false because the other partner said no', () {
    expect(deriveCoupleProfile([const UserPrefs(isParent: true), const UserPrefs(isParent: false)]).isParent, isTrue);
  });

  test('legacy summary keeps RC1 clients sane and only raises parent flags', () {
    final p = deriveCoupleProfile([
      const UserPrefs(locationPreferences: ['home', 'nature'], availableTime: 'fewHours', isParent: false, pace: 'calm'),
    ]);
    final m = legacySummaryFor(p);
    expect(m['onboardingDone'], isTrue);
    expect(m['preference'], 'both');
    expect(m.containsKey('place'), isFalse, reason: 'two locations have no single legacy place');
    expect(m['availableTime'], 'short');
    expect(m['weekdayTime'], '30to60');
    expect(m['isParent'], isFalse);
    // Existing main already says parent → stays true.
    expect(legacySummaryFor(p, existingMain: {'parentMode': true})['parentMode'], isTrue);
    final single = legacySummaryFor(deriveCoupleProfile([const UserPrefs(locationPreferences: ['home'], isParent: true, bedtimeWeekday: '20:30')]));
    expect(single['place'], 'home');
    expect(single['preference'], 'home');
    expect(single['bedtimeHour'], 20);
    expect(single['bedtimeMinute'], 30);
  });
}

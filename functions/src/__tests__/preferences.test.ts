// Derived couple profile — pure tests. Run: npm test
import { test } from 'node:test';
import * as assert from 'node:assert';
import {
  normalizeTime, normalizeLocations, normalizeUserPrefs, legacyPrefsFromMain,
  deriveCoupleProfile, parseOverrides, applyOverrides, lifestyleContextLines,
  preferredEffort, hhmmFromParts,
} from '../preferences';

test('time: new ids, legacy onboarding ids and legacy lifestyle ids all normalise', () => {
  assert.strictEqual(normalizeTime('fewHours'), 'fewHours');
  assert.strictEqual(normalizeTime('short'), 'fewHours');
  assert.strictEqual(normalizeTime('30to60'), 'fewHours');
  assert.strictEqual(normalizeTime('halfday'), 'evening');
  assert.strictEqual(normalizeTime('day'), 'fullDay');
  assert.strictEqual(normalizeTime('fullday'), 'fullDay');
  assert.strictEqual(normalizeTime('bogus'), undefined);
  assert.strictEqual(normalizeTime(3), undefined);
});

test('locations: old single string and new list coexist; unknown ids dropped', () => {
  assert.deepStrictEqual(normalizeLocations('home'), ['home']);
  assert.deepStrictEqual(normalizeLocations(['out', 'nature', 'nature', 'x']), ['nature', 'out']);
  assert.deepStrictEqual(normalizeLocations('both'), ['nature', 'cafe', 'home', 'out']);
  assert.deepStrictEqual(normalizeLocations(undefined), []);
  assert.deepStrictEqual(normalizeLocations(42), []);
});

test('user prefs parser never throws on junk and drops bad fields', () => {
  assert.deepStrictEqual(normalizeUserPrefs({ locationPreferences: 'cafe', availableTime: 'day', isParent: 'yes', bedtimeWeekday: '25:00', pace: 'calm' }),
    { locationPreferences: ['cafe'], pace: 'calm', availableTime: 'fullDay' });
  assert.strictEqual(normalizeUserPrefs(null), null);
  assert.deepStrictEqual(normalizeUserPrefs({}), {});
});

test('legacy settings/main: onboarding fields win, lifestyle fields fill in, bedtime parts map to HH:mm', () => {
  const onboardingOnly = legacyPrefsFromMain({ onboardingDone: true, isParent: true, place: 'out', pace: 'active', availableTime: 'short', bedtimeHour: 20, bedtimeMinute: 30 });
  assert.deepStrictEqual(onboardingOnly, { locationPreferences: ['out'], pace: 'active', availableTime: 'fewHours', isParent: true, bedtimeWeekday: '20:30', bedtimeWeekend: '20:30' });
  const lifestyleOnly = legacyPrefsFromMain({ parentMode: false, preference: 'both', weekdayTime: '2plus', weekendTime: 'fullday', bedtimeWeekday: '20:00', bedtimeWeekend: '21:00' });
  assert.deepStrictEqual(lifestyleOnly, { locationPreferences: ['nature', 'cafe', 'home', 'out'], availableTime: 'evening', isParent: false, bedtimeWeekday: '20:00', bedtimeWeekend: '21:00' });
  assert.strictEqual(legacyPrefsFromMain({ onboardingDone: true }), null);
  assert.strictEqual(legacyPrefsFromMain(null), null);
  assert.strictEqual(hhmmFromParts(7, 5), '07:05');
  assert.strictEqual(hhmmFromParts('7', 5), undefined);
});

test('derived profile: two partners with different answers', () => {
  const a = { locationPreferences: ['home', 'nature'] as const, availableTime: 'fullDay' as const, isParent: true, childcareState: 'kidsHome' as const, bedtimeWeekday: '20:00', pace: 'calm' as const };
  const b = { locationPreferences: ['home', 'cafe'] as const, availableTime: 'fewHours' as const, isParent: false, childcareState: 'kidFree' as const, bedtimeWeekday: '19:30', pace: 'active' as const };
  const p = deriveCoupleProfile([{ ...a, locationPreferences: [...a.locationPreferences] }, { ...b, locationPreferences: [...b.locationPreferences] }]);
  assert.deepStrictEqual(p.locations, [{ id: 'home', weight: 2 }, { id: 'nature', weight: 1 }, { id: 'cafe', weight: 1 }]);
  assert.strictEqual(p.availableTime, 'fewHours', 'more constrained wins');
  assert.strictEqual(p.isParent, true, 'either parent → parent-mode');
  assert.strictEqual(p.childcareState, 'kidsHome', 'conservative default');
  assert.strictEqual(p.bedtimeWeekday, '19:30', 'earliest bedtime is the household constraint');
  assert.strictEqual(p.pace, 'mixed');
  assert.strictEqual(p.source, 'prefs');
});

test('derived profile: one partner answered, the other not yet → their answers, not defaults', () => {
  const p = deriveCoupleProfile([{ locationPreferences: ['cafe'], availableTime: 'evening', isParent: false }, null]);
  assert.deepStrictEqual(p.locations, [{ id: 'cafe', weight: 1 }]);
  assert.strictEqual(p.availableTime, 'evening');
  assert.strictEqual(p.childcareState, 'kidFree');
  assert.strictEqual(p.source, 'prefs');
});

test('derived profile: no prefs docs → legacy main; nothing at all → safe defaults', () => {
  const legacy = deriveCoupleProfile([null, null], { locationPreferences: ['home'], availableTime: 'fewHours', isParent: true });
  assert.strictEqual(legacy.source, 'legacy');
  assert.deepStrictEqual(legacy.locations, [{ id: 'home', weight: 1 }]);
  assert.strictEqual(legacy.childcareState, 'kidsHome', 'parent with no childcare answer → kids home');
  const d = deriveCoupleProfile([], null);
  assert.strictEqual(d.source, 'defaults');
  assert.strictEqual(d.locations.length, 4);
  assert.strictEqual(d.availableTime, 'evening');
  assert.strictEqual(d.isParent, false);
  assert.strictEqual(d.childcareState, 'kidFree');
  assert.strictEqual(d.bedtimeWeekday, null);
});

test('parent-mode never turns false because the other partner answered false', () => {
  assert.strictEqual(deriveCoupleProfile([{ isParent: true }, { isParent: false }]).isParent, true);
  assert.strictEqual(deriveCoupleProfile([{ isParent: false }, { isParent: true }]).isParent, true);
});

test('overrides: validated, bounded, applied for one request only', () => {
  assert.strictEqual(parseOverrides(undefined), null);
  assert.strictEqual(parseOverrides({}), null);
  assert.deepStrictEqual(parseOverrides({ availableTime: 'fullDay', childcareState: 'kidFree', locationPreferences: ['out'] }),
    { availableTime: 'fullDay', childcareState: 'kidFree', locationPreferences: ['out'] });
  assert.throws(() => parseOverrides({ availableTime: 'forever' }), /availableTime/);
  assert.throws(() => parseOverrides({ locationPreferences: ['mars'] }), /locationPreferences/);
  assert.throws(() => parseOverrides({ locationPreferences: 'home' }), /locationPreferences/);
  assert.throws(() => parseOverrides({ evil: true }), /unknown override/);
  assert.throws(() => parseOverrides([1]), /object/);

  const base = deriveCoupleProfile([{ isParent: true, childcareState: 'kidsHome', availableTime: 'fewHours', locationPreferences: ['home'] }]);
  const tonight = applyOverrides(base, { childcareState: 'kidFree', availableTime: 'evening', locationPreferences: ['cafe', 'out'] });
  assert.strictEqual(tonight.overridden, true);
  assert.strictEqual(tonight.childcareState, 'kidFree');
  assert.strictEqual(tonight.availableTime, 'evening');
  assert.deepStrictEqual(tonight.locations.map((l) => l.id), ['cafe', 'out']);
  // The base profile object is untouched (no destructive write-through).
  assert.strictEqual(base.overridden, false);
  assert.strictEqual(base.childcareState, 'kidsHome');
  assert.strictEqual(applyOverrides(base, null), base);
});

test('prompt lines: defaults vs For tonight', () => {
  const base = deriveCoupleProfile([
    { locationPreferences: ['home', 'nature'], availableTime: 'fullDay', isParent: true, childcareState: 'kidsHome', bedtimeWeekday: '20:00', pace: 'calm' },
    { locationPreferences: ['home', 'cafe'], availableTime: 'fewHours', isParent: false, pace: 'calm' },
  ]);
  const lines = lifestyleContextLines(base);
  assert.ok(lines[0].startsWith('Steder de liker: hjemme, natur, by og kafé (begge foretrekker: hjemme)'), lines[0]);
  assert.ok(lines[1].includes('et par timer'), lines[1]);
  assert.ok(lines.some((l) => l.includes('barna er hjemme') && l.includes('20:00')));
  assert.ok(!lines.some((l) => l.startsWith('I KVELD')));

  const tonight = lifestyleContextLines(applyOverrides(base, { childcareState: 'kidFree', availableTime: 'evening' }));
  assert.ok(tonight[0].startsWith('I KVELD'));
  assert.ok(tonight.some((l) => l.includes('barnefri')));
  assert.ok(tonight.some((l) => l.includes('en hel kveld')));
  assert.ok(!tonight.some((l) => l.includes('20:00')), 'bedtime irrelevant when kid-free');
});

test('curated tier nudge follows available time', () => {
  assert.strictEqual(preferredEffort(deriveCoupleProfile([{ availableTime: 'fewHours' }])), 'low');
  assert.strictEqual(preferredEffort(deriveCoupleProfile([{ availableTime: 'fullDay' }])), 'high');
  assert.strictEqual(preferredEffort(deriveCoupleProfile([])), null);
});

// "For tonight" is temporary: generateTemporaryIdeas writes NOTHING, while
// the weekly generateForCouple keeps its exact behaviour. Runs against the
// Firestore emulator on a free-tier couple (curated path → no OpenAI).
//   npm run test:rules
import { test, before, beforeEach } from 'node:test';
import * as assert from 'node:assert';
import * as admin from 'firebase-admin';
import { initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';

import { generateForCouple, generateTemporaryIdeas } from '../generateWeeklyIdeas';

const PROJECT = 'us-app-4bf30';
const C = 'ftCouple';
let env: RulesTestEnvironment;
let db: admin.firestore.Firestore;

before(async () => {
  env = await initializeTestEnvironment({ projectId: PROJECT });
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'run via npm run test:rules');
  // generateWeeklyIdeas uses the DEFAULT admin app.
  const app = admin.apps.find((a) => a?.name === '[DEFAULT]') ?? admin.initializeApp({ projectId: PROJECT });
  db = app.firestore();
});

/// Snapshot of everything For tonight must leave alone, as plain JSON.
async function snapshotState() {
  const [current, history, main, prefsA, prefsB] = await Promise.all([
    db.doc(`couples/${C}/weeklyIdeas/current`).get(),
    db.collection(`couples/${C}/weeklyIdeasHistory`).get(),
    db.doc(`couples/${C}/settings/main`).get(),
    db.doc(`couples/${C}/settings/prefs_A`).get(),
    db.doc(`couples/${C}/settings/prefs_B`).get(),
  ]);
  return JSON.stringify({
    current: current.data() ?? null,
    history: history.docs.map((d) => [d.id, d.data()]).sort(),
    main: main.data() ?? null,
    prefsA: prefsA.data() ?? null,
    prefsB: prefsB.data() ?? null,
  });
}

beforeEach(async () => {
  await env.clearFirestore();
  const b = db.batch();
  b.set(db.doc(`couples/${C}`), { members: ['A', 'B'], status: 'active', subscriptionTier: 'free', batteryLevel: 65 });
  b.set(db.doc(`couples/${C}/settings/main`), { onboardingDone: true, parentMode: true, place: 'home' });
  b.set(db.doc(`couples/${C}/settings/prefs_A`), { locationPreferences: ['home', 'nature'], availableTime: 'evening', isParent: true, childcareState: 'kidsHome', bedtimeWeekday: '20:00' });
  b.set(db.doc(`couples/${C}/settings/prefs_B`), { locationPreferences: ['home'], availableTime: 'fewHours', isParent: false });
  b.set(db.doc(`couples/${C}/weeklyIdeas/current`), { generatedAt: admin.firestore.Timestamp.fromMillis(1_700_000_000_000), weekNumber: 39, generatedBy: 'curated', ideas: [{ title: 'Ukens idé' }] });
  b.set(db.doc(`couples/${C}/weeklyIdeasHistory/week_38_1`), { generatedAt: admin.firestore.Timestamp.fromMillis(1_699_000_000_000), weekNumber: 38, generatedBy: 'curated', ideas: [] });
  // Curated pool with effort tags so the time override changes the ranking.
  for (let i = 0; i < 5; i++) b.set(db.doc(`ideas/low${i}`), { title: `Lav ${i}`, category: 'c', meta: 'm', cardColor: '#fff', tagColor: '#fff', tagTextColor: '#000', iconName: 'x', description: 'd', effort: 'low' });
  for (let i = 0; i < 5; i++) b.set(db.doc(`ideas/high${i}`), { title: `Høy ${i}`, category: 'c', meta: 'm', cardColor: '#fff', tagColor: '#fff', tagTextColor: '#000', iconName: 'x', description: 'd', effort: 'high' });
  await b.commit();
});

test('1–3. For tonight leaves weeklyIdeas/current, history and all preferences byte-identical', async () => {
  const before = await snapshotState();
  const r = await generateTemporaryIdeas(C, { availableTime: 'fewHours', childcareState: 'kidFree', locationPreferences: ['cafe'] });
  assert.ok(r && r.ideas.length > 0);
  assert.strictEqual(r.generatedBy, 'curated');
  assert.strictEqual(await snapshotState(), before);
  // Twice more with different filters — still nothing written, no cooldown.
  await generateTemporaryIdeas(C, { availableTime: 'fullDay' });
  await generateTemporaryIdeas(C, null);
  assert.strictEqual(await snapshotState(), before);
});

test('4. temporary overrides change the profile and the result', async () => {
  const few = await generateTemporaryIdeas(C, { availableTime: 'fewHours', childcareState: 'kidFree', locationPreferences: ['cafe', 'out'] });
  const day = await generateTemporaryIdeas(C, { availableTime: 'fullDay' });
  assert.ok(few && day);
  assert.strictEqual(few.profile.overridden, true);
  assert.strictEqual(few.profile.availableTime, 'fewHours');
  assert.strictEqual(few.profile.childcareState, 'kidFree');
  assert.deepStrictEqual(few.profile.locations.map((l) => l.id), ['cafe', 'out']);
  assert.strictEqual(day.profile.availableTime, 'fullDay');
  assert.strictEqual(day.profile.childcareState, 'kidsHome', 'unspecified override keeps the derived default');
  // Curated ranking follows the time override: few hours → low effort first.
  assert.ok(few.ideas.every((i) => (i as { effort?: string }).effort === 'low'), JSON.stringify(few.ideas.map((i) => i.title)));
  assert.ok(day.ideas.every((i) => (i as { effort?: string }).effort === 'high'), JSON.stringify(day.ideas.map((i) => i.title)));
  // Without overrides the derived profile (fewHours = more constrained) applies.
  const none = await generateTemporaryIdeas(C, null);
  assert.strictEqual(none!.profile.overridden, false);
  assert.strictEqual(none!.profile.availableTime, 'fewHours');
  assert.strictEqual(none!.profile.source, 'prefs');
});

test('5. the weekly generation still archives and replaces exactly as before, with no forTonight field', async () => {
  const summary = await generateForCouple(C);
  assert.strictEqual(summary.generatedBy, 'curated');
  const current = (await db.doc(`couples/${C}/weeklyIdeas/current`).get()).data()!;
  assert.strictEqual(current.generatedBy, 'curated');
  assert.ok(Array.isArray(current.ideas) && current.ideas.length > 0);
  assert.ok(!('forTonight' in current), 'weekly doc carries no For tonight tag');
  assert.deepStrictEqual(Object.keys(current).sort(), ['generatedAt', 'generatedBy', 'ideas', 'weekNumber']);
  const history = await db.collection(`couples/${C}/weeklyIdeasHistory`).get();
  assert.strictEqual(history.size, 2, 'previous set archived');
  assert.ok(history.docs.some((d) => d.data().weekNumber === 39));
  // Preferences untouched by the weekly run too.
  assert.deepStrictEqual((await db.doc(`couples/${C}/settings/prefs_B`).get()).data(), { locationPreferences: ['home'], availableTime: 'fewHours', isParent: false });
});

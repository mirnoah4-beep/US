// settings/prefs_{uid}: partners read both; each writes only their own; the
// legacy settings/main stays member-writable.   npm run test:rules
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'fs';
import { join } from 'path';
import { initializeTestEnvironment, assertSucceeds, assertFails, type RulesTestEnvironment, type RulesTestContext } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc } from 'firebase/firestore';

const PROJECT = 'us-app-4bf30';
const RULES = readFileSync(join(__dirname, '..', '..', '..', 'firestore.rules'), 'utf8');
const A = 'uidA'; const B = 'uidB'; const X = 'uidX'; const C = 'c1';
let env: RulesTestEnvironment;
before(async () => { env = await initializeTestEnvironment({ projectId: PROJECT, firestore: { rules: RULES } }); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'couples', C), { members: [A, B], status: 'active' });
    await setDoc(doc(d, 'couples', C, 'settings', 'main'), { onboardingDone: true, parentMode: false });
    await setDoc(doc(d, 'couples', C, 'settings', `prefs_${B}`), { locationPreferences: ['home'], isParent: true });
  });
});
const dbAs = (uid: string) => env.authenticatedContext(uid).firestore();
const prefs = (uid: string, owner: string) => doc(dbAs(uid), 'couples', C, 'settings', `prefs_${owner}`);
const valid = { locationPreferences: ['nature', 'cafe'], pace: 'calm', availableTime: 'fewHours', isParent: true, childcareState: 'kidsHome', bedtimeWeekday: '20:00', bedtimeWeekend: '21:00', updatedAt: 1, completedAt: 1, schemaVersion: 1 };

test('a member writes their OWN prefs doc (create, update, delete)', async () => {
  await assertSucceeds(setDoc(prefs(A, A), valid));
  await assertSucceeds(updateDoc(prefs(A, A), { availableTime: 'evening' }));
  await assertSucceeds(setDoc(prefs(A, A), { isParent: false }, { merge: true }));
  await assertSucceeds(deleteDoc(prefs(A, A)));
});

test('both partners can read both prefs docs; an outsider cannot', async () => {
  await assertSucceeds(getDoc(prefs(A, B)));
  await assertSucceeds(getDoc(prefs(B, B)));
  await assertFails(getDoc(prefs(X, B)));
});

test('a partner can never overwrite the other\'s raw answers', async () => {
  await assertFails(setDoc(prefs(A, B), valid));
  await assertFails(updateDoc(prefs(A, B), { isParent: false }));
  await assertFails(setDoc(prefs(A, B), { isParent: false }, { merge: true }));
  await assertFails(deleteDoc(prefs(A, B)));
  await assertFails(setDoc(prefs(X, X), valid));   // outsider cannot plant a prefs doc
});

test('prefs schema is bounded: unknown keys, bad enums, oversized lists rejected', async () => {
  await assertFails(setDoc(prefs(A, A), { ...valid, subscriptionTier: 'premium' }));
  await assertFails(setDoc(prefs(A, A), { ...valid, availableTime: 'forever' }));
  await assertFails(setDoc(prefs(A, A), { ...valid, childcareState: 'maybe' }));
  await assertFails(setDoc(prefs(A, A), { ...valid, locationPreferences: 'home' }));
  await assertFails(setDoc(prefs(A, A), { ...valid, locationPreferences: ['a', 'b', 'c', 'd', 'e'] }));
  await assertFails(setDoc(prefs(A, A), { ...valid, isParent: 'yes' }));
});

test('legacy settings/main stays member read/write; other settings docs are closed', async () => {
  await assertSucceeds(getDoc(doc(dbAs(A), 'couples', C, 'settings', 'main')));
  await assertSucceeds(updateDoc(doc(dbAs(A), 'couples', C, 'settings', 'main'), { parentMode: true, place: 'home' }));
  await assertSucceeds(setDoc(doc(dbAs(B), 'couples', C, 'settings', 'main'), { onboardingDone: true }, { merge: true }));
  await assertFails(updateDoc(doc(dbAs(X), 'couples', C, 'settings', 'main'), { parentMode: true }));
  await assertFails(setDoc(doc(dbAs(A), 'couples', C, 'settings', 'other'), { x: 1 }));
});

test('other couple subcollections are unaffected by the settings carve-out', async () => {
  await assertSucceeds(setDoc(doc(dbAs(A), 'couples', C, 'lastTime', 'walk'), { daysAgo: 3 }));
  await assertFails(setDoc(doc(dbAs(X), 'couples', C, 'lastTime', 'walk'), { daysAgo: 3 }));
});

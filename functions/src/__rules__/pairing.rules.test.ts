// Rules for pairing after the joinCouple callable: no client can perform
// the old join handshake any more, while every remaining legitimate client
// flow (cancel invite, member edits, self-heal of one's own coupleId) still
// works.   npm run test:rules

import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'fs';
import { join } from 'path';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  type RulesTestEnvironment,
  type RulesTestContext,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, arrayUnion } from 'firebase/firestore';

const PROJECT = 'us-app-4bf30';
const RULES = readFileSync(join(__dirname, '..', '..', '..', 'firestore.rules'), 'utf8');

const INVITER = 'uidInviter';
const JOINER = 'uidJoiner';
const OUTSIDER = 'uidX';
const PENDING = 'pendingCouple';
const CODE = 'ABCD2345';

let env: RulesTestEnvironment;
before(async () => { env = await initializeTestEnvironment({ projectId: PROJECT, firestore: { rules: RULES } }); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'couples', PENDING), { members: [INVITER], status: 'pending', inviteCode: CODE });
    await setDoc(doc(d, 'invites', CODE), { fromUserId: INVITER, coupleId: PENDING });
    await setDoc(doc(d, 'users', INVITER), { coupleId: null });
    await setDoc(doc(d, 'users', JOINER), { coupleId: null });
    await setDoc(doc(d, 'users', OUTSIDER), { coupleId: null });
    await setDoc(doc(d, 'couples', 'live'), { members: ['m1', 'm2'], status: 'active' });
    await setDoc(doc(d, 'users', 'm1'), { coupleId: 'live' });
    await setDoc(doc(d, 'users', 'm2'), { coupleId: 'live' });
  });
});
const dbAs = (uid: string) => env.authenticatedContext(uid).firestore();

test('a client cannot set ANOTHER user\'s coupleId — even in the old handshake shape', async () => {
  // Exactly what the removed clause used to allow: joiner sets the inviter's
  // null coupleId to a pending couple the inviter is a member of.
  await assertFails(updateDoc(doc(dbAs(JOINER), 'users', INVITER), { coupleId: PENDING }));
  await assertFails(setDoc(doc(dbAs(JOINER), 'users', INVITER), { coupleId: PENDING }, { merge: true }));
  await assertFails(updateDoc(doc(dbAs(OUTSIDER), 'users', 'm1'), { coupleId: null }));
});

test('a client cannot activate a pending couple or add members to it', async () => {
  // The would-be joiner, with a live invite — the old join write.
  await assertFails(updateDoc(doc(dbAs(JOINER), 'couples', PENDING), {
    members: arrayUnion(JOINER), status: 'active', inviteCode: null,
  }));
  await assertFails(updateDoc(doc(dbAs(JOINER), 'couples', PENDING), { members: [INVITER, JOINER] }));
  await assertFails(updateDoc(doc(dbAs(OUTSIDER), 'couples', PENDING), { members: arrayUnion(OUTSIDER) }));
});

test('an outsider cannot hijack an active couple or its members\' profiles', async () => {
  await assertFails(updateDoc(doc(dbAs(OUTSIDER), 'couples', 'live'), { members: arrayUnion(OUTSIDER) }));
  await assertFails(updateDoc(doc(dbAs(OUTSIDER), 'couples', 'live'), { members: ['m1', OUTSIDER] }));
  await assertFails(getDoc(doc(dbAs(OUTSIDER), 'couples', 'live')));
  await assertFails(updateDoc(doc(dbAs(OUTSIDER), 'users', 'm1'), { coupleId: 'somewhere' }));
  await assertFails(deleteDoc(doc(dbAs(OUTSIDER), 'invites', CODE)));
});

test('remaining client flows still work: cancel invite, member edits, own self-heal', async () => {
  // cancelInvite: inviter reads the invite and deletes invite + pending couple.
  await assertSucceeds(getDoc(doc(dbAs(INVITER), 'invites', CODE)));
  await assertSucceeds(deleteDoc(doc(dbAs(INVITER), 'invites', CODE)));
  await assertSucceeds(deleteDoc(doc(dbAs(INVITER), 'couples', PENDING)));
  // Members still edit their own couple doc (togetherSince, streakRecord).
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { streakRecord: 3 }));
  await assertFails(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { subscriptionTier: 'premium' }));
  // _CoupleGate self-heal: a user clears their OWN stale coupleId.
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { coupleId: null }));
  // A member may still add coupleId to their own doc (server does this too).
  await assertSucceeds(setDoc(doc(dbAs(JOINER), 'users', JOINER), { coupleId: null }, { merge: true }));
});

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

// ── Security regression: H1 — couple membership/lifecycle is server-owned ────
// A legitimate member of an active couple must not be able to rewrite the
// server-authoritative fields on the couple document. Only the client-owned
// relationship fields (streakRecord, togetherSince, togetherSinceProposal)
// may change. 'live' is [m1, m2]; m1 acts as an authenticated member.

test('H1: a member cannot add a third member to the couple', async () => {
  await assertFails(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { members: ['m1', 'm2', OUTSIDER] }));
  await assertFails(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { members: arrayUnion(OUTSIDER) }));
});

test('H1: a member cannot remove their partner', async () => {
  await assertFails(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { members: ['m1'] }));
});

test('H1: a member cannot replace the partner identity', async () => {
  await assertFails(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { members: ['m1', OUTSIDER] }));
});

test('H1: a member cannot change couple status', async () => {
  await assertFails(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { status: 'pending' }));
});

test('H1: a member cannot change the invite identity', async () => {
  await assertFails(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { inviteCode: 'HACKED12' }));
});

test('H1: a member cannot self-grant a subscription', async () => {
  await assertFails(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { subscriptionTier: 'premium' }));
});

test('H1: a member cannot smuggle a protected field alongside a legit one', async () => {
  await assertFails(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { streakRecord: 5, members: ['m1', 'm2', OUTSIDER] }));
});

test('H1: a member CAN still perform every legitimate couple edit', async () => {
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { streakRecord: 5 }));
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'couples', 'live'), { togetherSince: new Date() }));
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'couples', 'live'), {
    togetherSinceProposal: { date: new Date(), proposedBy: 'm1' },
  }));
});

// ── Security regression: H3 — users/{uid} fields are gated; coupleId → null ──
// A user may edit only their own client-owned profile/preference fields, and
// may only ever clear coupleId to null — never point it at another couple
// (the write the deleteAccount and Storage authorization bugs relied on).
// In beforeEach, users/m1 = { coupleId: 'live' }, users/uidX = { coupleId: null }.

test('H3: a user cannot repoint their own coupleId at another couple', async () => {
  // couple A -> couple B
  await assertFails(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { coupleId: PENDING }));
  await assertFails(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { coupleId: 'victimCouple' }));
});

test('H3: a user cannot set coupleId from null to an arbitrary couple', async () => {
  // null -> arbitrary id
  await assertFails(updateDoc(doc(dbAs(OUTSIDER), 'users', OUTSIDER), { coupleId: 'live' }));
  await assertFails(setDoc(doc(dbAs(OUTSIDER), 'users', OUTSIDER), { coupleId: 'live' }, { merge: true }));
});

test('H3: a user cannot rewrite server-owned identity fields', async () => {
  await assertFails(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { uid: 'evil' }));
  await assertFails(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { email: 'attacker@example.com' }));
  await assertFails(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { createdAt: new Date() }));
});

test('H3: a user CAN change legitimate profile/preference fields', async () => {
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { displayName: 'New Name' }));
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { avatarUrl: 'https://example.com/a.jpg' }));
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { language: 'en' }));
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { fcmToken: 'token-123' }));
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { savedIdeaIds: ['idea1', 'idea2'] }));
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { smartRemindersEnabled: false }));
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { partnerMessagesEnabled: false }));
});

test('H3: a user CAN still clear their own stale coupleId to null', async () => {
  await assertSucceeds(updateDoc(doc(dbAs('m1'), 'users', 'm1'), { coupleId: null }));
});

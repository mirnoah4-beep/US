// Server-authoritative pairing against the Firestore emulator: the real
// Admin-SDK transactions (createInviteTx / joinCoupleTx) plus their
// interplay with the lifecycle module. Client-side reads use the rules.
//   npm run test:rules

import { test, before, after, beforeEach } from 'node:test';
import * as assert from 'node:assert';
import { readFileSync } from 'fs';
import { join } from 'path';
import * as admin from 'firebase-admin';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  type RulesTestEnvironment,
  type RulesTestContext,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc } from 'firebase/firestore';

import { createInviteTx, joinCoupleTx } from '../pairing';
import { deleteUserData, dissolveCouple } from '../coupleLifecycle';
import type { CleanupBucket } from '../storageCleanup';

const PROJECT = 'us-app-4bf30';
const ROOT = join(__dirname, '..', '..', '..');
const FIRESTORE_RULES = readFileSync(join(ROOT, 'firestore.rules'), 'utf8');

let env: RulesTestEnvironment;
let db: admin.firestore.Firestore;
let bucket: CleanupBucket;

before(async () => {
  env = await initializeTestEnvironment({ projectId: PROJECT, firestore: { rules: FIRESTORE_RULES } });
  const app = admin.apps.find((a) => a?.name === 'pairing-test') ?? admin.initializeApp({ projectId: PROJECT, storageBucket: PROJECT }, 'pairing-test');
  db = app.firestore();
  bucket = app.storage().bucket();
});
after(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const dbAs = (uid: string) => env.authenticatedContext(uid).firestore();
const seed = (fn: (d: ReturnType<RulesTestContext['firestore']>) => Promise<void>) =>
  env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => fn(ctx.firestore()));
const adminGet = async (path: string) => (await db.doc(path).get()).data();
const reason = async (p: Promise<unknown>) => {
  try { await p; return 'ok'; } catch (e) { return (e as { details?: { reason?: string } }).details?.reason ?? (e as Error).message; }
};

test('missing coupleId field on BOTH sides joins successfully (the production bug)', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'users', 'A'), { displayName: 'a' });   // no coupleId key at all
    await setDoc(doc(d, 'users', 'B'), { displayName: 'b' });
  });
  const inv = await createInviteTx(db, 'A');
  const r = await joinCoupleTx(db, 'B', inv.code);
  assert.strictEqual(r.coupleId, inv.coupleId);
  const couple = await adminGet(`couples/${inv.coupleId}`);
  assert.strictEqual(couple?.status, 'active');
  assert.deepStrictEqual([...couple?.members].sort(), ['A', 'B']);
  assert.strictEqual((await adminGet('users/A'))?.coupleId, inv.coupleId);
  assert.strictEqual((await adminGet('users/B'))?.coupleId, inv.coupleId);
  assert.strictEqual((await db.doc(`invites/${inv.code}`).get()).exists, false, 'invite consumed');
});

test('coupleId null joins successfully; final couple has exactly two distinct members', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'users', 'A'), { coupleId: null });
    await setDoc(doc(d, 'users', 'B'), { coupleId: null });
  });
  const inv = await createInviteTx(db, 'A');
  await joinCoupleTx(db, 'B', inv.code);
  const members: string[] = (await adminGet(`couples/${inv.coupleId}`))?.members;
  assert.strictEqual(members.length, 2);
  assert.strictEqual(new Set(members).size, 2);
});

test('joiner doc missing entirely (signup race) still joins and gets a doc', async () => {
  await seed(async (d) => { await setDoc(doc(d, 'users', 'A'), { coupleId: null }); });
  const inv = await createInviteTx(db, 'A');
  await joinCoupleTx(db, 'B', inv.code);
  assert.strictEqual((await adminGet('users/B'))?.coupleId, inv.coupleId);
});

test('A deletes account while paired → B is unpaired; B can pair with A\'s recreated account', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'users', 'A'), { coupleId: null });
    await setDoc(doc(d, 'users', 'B'), { coupleId: null });
  });
  const first = await createInviteTx(db, 'A');
  await joinCoupleTx(db, 'B', first.code);
  // A deletes their account (everything but the Auth user).
  const del = await deleteUserData(db, bucket, 'A');
  assert.deepStrictEqual(del.warnings, []);
  assert.strictEqual((await adminGet('users/B'))?.coupleId, null);
  assert.strictEqual((await db.doc(`couples/${first.coupleId}`).get()).exists, false);
  // A comes back with a new uid and a doc WITHOUT a coupleId key (as in production).
  await seed(async (d) => { await setDoc(doc(d, 'users', 'A2'), { displayName: 'a again' }); });
  const inv = await createInviteTx(db, 'A2');
  const r = await joinCoupleTx(db, 'B', inv.code);
  assert.deepStrictEqual([...(await adminGet(`couples/${r.coupleId}`))?.members].sort(), ['A2', 'B']);
  assert.strictEqual((await adminGet('users/B'))?.coupleId, r.coupleId);
});

test('stale coupleId → missing couple doc self-heals on join and on createInvite', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'users', 'A'), { coupleId: 'gone1' });
    await setDoc(doc(d, 'users', 'B'), { coupleId: 'gone2' });
  });
  const inv = await createInviteTx(db, 'A');
  assert.strictEqual(inv.clearedStale, true);
  assert.strictEqual((await adminGet('users/A'))?.coupleId, null);
  const r = await joinCoupleTx(db, 'B', inv.code);
  assert.strictEqual(r.cleared.joiner, true);
  assert.strictEqual((await adminGet('users/B'))?.coupleId, inv.coupleId);
});

test('stale coupleId → user not in members self-heals', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'couples', 'other'), { members: ['X', 'Y'], status: 'active' });
    await setDoc(doc(d, 'users', 'A'), { coupleId: null });
    await setDoc(doc(d, 'users', 'B'), { coupleId: 'other' });     // points at a couple B is not in
  });
  const inv = await createInviteTx(db, 'A');
  const r = await joinCoupleTx(db, 'B', inv.code);
  assert.strictEqual(r.cleared.joiner, true);
  assert.deepStrictEqual([...(await adminGet('couples/other'))?.members].sort(), ['X', 'Y'], 'the other couple is untouched');
});

test('ended relationship does not block pairing (either side)', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'couples', 'old'), { members: ['A', 'B'], status: 'ended' });
    await setDoc(doc(d, 'users', 'A'), { coupleId: 'old' });
    await setDoc(doc(d, 'users', 'B'), { coupleId: 'old' });
  });
  const inv = await createInviteTx(db, 'A');
  const r = await joinCoupleTx(db, 'B', inv.code);
  assert.strictEqual(r.cleared.joiner, true);
  assert.strictEqual((await adminGet('users/A'))?.coupleId, r.coupleId);
  assert.strictEqual((await adminGet('users/B'))?.coupleId, r.coupleId);
});

test('valid active couple blocks joining another (joiner) and inviting (inviter)', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'couples', 'live'), { members: ['B', 'C'], status: 'active' });
    await setDoc(doc(d, 'users', 'A'), { coupleId: null });
    await setDoc(doc(d, 'users', 'B'), { coupleId: 'live' });
    await setDoc(doc(d, 'users', 'C'), { coupleId: 'live' });
  });
  const inv = await createInviteTx(db, 'A');
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', inv.code)), 'already-paired');
  assert.strictEqual(await reason(createInviteTx(db, 'C')), 'already-paired');
  // Nothing changed for the live couple or the pending one.
  assert.deepStrictEqual([...(await adminGet('couples/live'))?.members].sort(), ['B', 'C']);
  assert.deepStrictEqual((await adminGet(`couples/${inv.coupleId}`))?.members, ['A']);
  assert.strictEqual((await db.doc(`invites/${inv.code}`).get()).exists, true);
});

test('inviter who became paired elsewhere after inviting blocks the join', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'users', 'A'), { coupleId: null });
    await setDoc(doc(d, 'users', 'B'), { coupleId: null });
  });
  const inv = await createInviteTx(db, 'A');
  await seed(async (d) => {
    await setDoc(doc(d, 'couples', 'live'), { members: ['A', 'Z'], status: 'active' });
    await updateDoc(doc(d, 'users', 'A'), { coupleId: 'live' });
  });
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', inv.code)), 'inviter-already-paired');
  assert.strictEqual((await adminGet('users/B'))?.coupleId, null);
});

test('own invite, invalid / expired codes are rejected precisely', async () => {
  await seed(async (d) => { await setDoc(doc(d, 'users', 'A'), { coupleId: null }); });
  const inv = await createInviteTx(db, 'A');
  assert.strictEqual(await reason(joinCoupleTx(db, 'A', inv.code)), 'own-invite');
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', 'NOPE1234')), 'invalid-code');
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', 'bad code!')), 'invalid-code');
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', undefined)), 'invalid-code');
  // Invite whose couple has been cancelled/deleted.
  await seed(async (d) => { await deleteDoc(doc(d, 'couples', inv.coupleId)); });
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', inv.code)), 'invite-expired');
  // Invite whose couple is no longer pending.
  const inv2 = await createInviteTx(db, 'A');
  await seed(async (d) => { await updateDoc(doc(d, 'couples', inv2.coupleId), { status: 'ended' }); });
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', inv2.code)), 'invite-expired');
  // Invite whose inviter account is gone.
  await seed(async (d) => {
    await setDoc(doc(d, 'invites', 'GHZST234'), { fromUserId: 'ghost', coupleId: 'gc' });
    await setDoc(doc(d, 'couples', 'gc'), { members: ['ghost'], status: 'pending', inviteCode: 'GHZST234' });
  });
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', 'GHZST234')), 'invite-expired');
});

test('same invite cannot be consumed twice', async () => {
  await seed(async (d) => {
    for (const u of ['A', 'B', 'C']) await setDoc(doc(d, 'users', u), { coupleId: null });
  });
  const inv = await createInviteTx(db, 'A');
  await joinCoupleTx(db, 'B', inv.code);
  assert.strictEqual(await reason(joinCoupleTx(db, 'C', inv.code)), 'invalid-code');
  assert.deepStrictEqual([...(await adminGet(`couples/${inv.coupleId}`))?.members].sort(), ['A', 'B']);
});

test('concurrent join attempts cannot create 3 members', async () => {
  await seed(async (d) => {
    for (const u of ['A', 'B', 'C', 'D', 'E']) await setDoc(doc(d, 'users', u), { coupleId: null });
  });
  const inv = await createInviteTx(db, 'A');
  const results = await Promise.all(['B', 'C', 'D', 'E'].map((u) => reason(joinCoupleTx(db, u, inv.code))));
  assert.strictEqual(results.filter((r) => r === 'ok').length, 1, JSON.stringify(results));
  const members: string[] = (await adminGet(`couples/${inv.coupleId}`))?.members;
  assert.strictEqual(members.length, 2);
  assert.strictEqual(new Set(members).size, 2);
  assert.ok(members.includes('A'));
  // The losers are still unpaired.
  const paired = (await Promise.all(['B', 'C', 'D', 'E'].map((u) => adminGet(`users/${u}`)))).filter((d) => d?.coupleId).length;
  assert.strictEqual(paired, 1);
});

test('a pending couple that somehow already has two members cannot take a third', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'invites', 'FULL2345'), { fromUserId: 'A', coupleId: 'full' });
    await setDoc(doc(d, 'couples', 'full'), { members: ['A', 'B'], status: 'pending', inviteCode: 'FULL2345' });
    for (const u of ['A', 'B', 'C']) await setDoc(doc(d, 'users', u), { coupleId: null });
  });
  assert.strictEqual(await reason(joinCoupleTx(db, 'C', 'FULL2345')), 'invite-expired');
  assert.deepStrictEqual((await adminGet('couples/full'))?.members, ['A', 'B']);
});

test('createInvite reuses the single live invite and replaces a broken one', async () => {
  await seed(async (d) => { await setDoc(doc(d, 'users', 'A'), { coupleId: null }); });
  const first = await createInviteTx(db, 'A');
  const again = await createInviteTx(db, 'A');
  assert.deepStrictEqual([again.code, again.coupleId, again.reused], [first.code, first.coupleId, true]);
  // Break it: pending couple deleted out from under the invite.
  await seed(async (d) => { await deleteDoc(doc(d, 'couples', first.coupleId)); });
  const replaced = await createInviteTx(db, 'A');
  assert.strictEqual(replaced.reused, false);
  assert.notStrictEqual(replaced.code, first.code);
  assert.strictEqual((await db.doc(`invites/${first.code}`).get()).exists, false, 'broken invite removed');
  assert.strictEqual((await db.doc(`invites/${replaced.code}`).get()).exists, true);
});

test('after a callable pairing the rules let both members in and keep outsiders out', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'users', 'A'), { coupleId: null });
    await setDoc(doc(d, 'users', 'B'), { coupleId: null });
    await setDoc(doc(d, 'users', 'X'), { coupleId: null });
  });
  const inv = await createInviteTx(db, 'A');
  const r = await joinCoupleTx(db, 'B', inv.code);
  await assertSucceeds(getDoc(doc(dbAs('A'), 'couples', r.coupleId)));
  await assertSucceeds(getDoc(doc(dbAs('B'), 'couples', r.coupleId)));
  await assertSucceeds(getDoc(doc(dbAs('B'), 'users', 'A')));      // partner profile
  await assertFails(getDoc(doc(dbAs('X'), 'couples', r.coupleId)));
  await assertFails(getDoc(doc(dbAs('X'), 'users', 'A')));
});

test('lifecycle cleanup after a callable pairing stays idempotent', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'users', 'A'), { coupleId: null });
    await setDoc(doc(d, 'users', 'B'), { coupleId: null });
  });
  const inv = await createInviteTx(db, 'A');
  const r = await joinCoupleTx(db, 'B', inv.code);
  const first = await dissolveCouple(db, bucket, r.coupleId);
  const second = await dissolveCouple(db, bucket, r.coupleId);
  assert.strictEqual(first.existed, true);
  assert.strictEqual(second.existed, false);
  assert.strictEqual((await adminGet('users/A'))?.coupleId, null);
  assert.strictEqual((await adminGet('users/B'))?.coupleId, null);
  // Both can pair again straight away.
  const inv2 = await createInviteTx(db, 'B');
  const r2 = await joinCoupleTx(db, 'A', inv2.code);
  assert.deepStrictEqual([...(await adminGet(`couples/${r2.coupleId}`))?.members].sort(), ['A', 'B']);
});

// ── Security regression: M6 — invite hardening ──────────────────────────────

test('M6: a fresh invite carries a future expiresAt', async () => {
  await seed(async (d) => { await setDoc(doc(d, 'users', 'A'), { coupleId: null }); });
  const inv = await createInviteTx(db, 'A');
  const data = await adminGet(`invites/${inv.code}`);
  assert.ok(data?.expiresAt, 'expiresAt is set');
  assert.ok(data!.expiresAt.toMillis() > Date.now(), 'expiresAt is in the future');
});

test('M6: an expired invite is rejected', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'users', 'A'), { coupleId: null });
    await setDoc(doc(d, 'users', 'B'), { coupleId: null });
  });
  const inv = await createInviteTx(db, 'A');
  // Force the invite into the past.
  await db.doc(`invites/${inv.code}`).update({
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
  });
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', inv.code)), 'invite-expired');
  // The couple was not activated and B was not linked.
  assert.strictEqual((await adminGet(`couples/${inv.coupleId}`))?.status, 'pending');
  assert.strictEqual((await adminGet('users/B'))?.coupleId, null);
});

test('M6: reuse refreshes the expiry window', async () => {
  await seed(async (d) => { await setDoc(doc(d, 'users', 'A'), { coupleId: null }); });
  const inv = await createInviteTx(db, 'A');
  await db.doc(`invites/${inv.code}`).update({
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
  });
  const again = await createInviteTx(db, 'A');
  assert.strictEqual(again.code, inv.code, 'same invite reused');
  const data = await adminGet(`invites/${inv.code}`);
  assert.ok(data!.expiresAt.toMillis() > Date.now(), 'expiry refreshed into the future');
});

test('M6: legacy short / non-alphabet codes are rejected as invalid before any read', async () => {
  await seed(async (d) => { await setDoc(doc(d, 'users', 'B'), { coupleId: null }); });
  for (const bad of ['123456', 'ABCDEF', '1234567', 'ABCD234O', 'ABCD234I', 'abcd2345']) {
    assert.strictEqual(await reason(joinCoupleTx(db, 'B', bad)), 'invalid-code', `code ${bad} must be invalid`);
  }
});

test('M6: an invite with NO expiresAt is rejected — no immortal legacy invites', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'users', 'B'), { coupleId: null });
    await setDoc(doc(d, 'users', 'A'), { coupleId: 'lc' });
    // A legacy invite written before expiresAt existed: valid format, valid
    // pending couple, live inviter — the ONLY thing wrong is no expiresAt.
    await setDoc(doc(d, 'invites', 'LEGACY23'), { fromUserId: 'A', coupleId: 'lc' });
    await setDoc(doc(d, 'couples', 'lc'), { members: ['A'], status: 'pending', inviteCode: 'LEGACY23' });
  });
  assert.strictEqual(await reason(joinCoupleTx(db, 'B', 'LEGACY23')), 'invite-expired');
  // Couple not activated, joiner not linked.
  assert.strictEqual((await adminGet('couples/lc'))?.status, 'pending');
  assert.strictEqual((await adminGet('users/B'))?.coupleId, null);
});

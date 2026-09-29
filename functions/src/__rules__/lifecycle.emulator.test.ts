// Couple / account data lifecycle against the real Storage + Firestore
// emulators. Client uploads go through storage.rules (as the app would);
// cleanup runs with the Admin SDK exactly as the deployed functions do.
//   npm run test:rules
//
// Note: the onCoupleDeleted trigger itself needs the Functions emulator; here
// its body (cleanupCoupleStorage after the document is gone) is exercised
// directly, which is the same helper the trigger calls.

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
import { doc, setDoc, getDoc, collection, getDocs, Timestamp } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

import { dissolveCouple, deleteUserData } from '../coupleLifecycle';
import { cleanupCoupleStorage, cleanupUserStorage } from '../storageCleanup';

const PROJECT = 'us-app-4bf30';
const ROOT = join(__dirname, '..', '..', '..');
const STORAGE_RULES = readFileSync(join(ROOT, 'storage.rules'), 'utf8');
const FIRESTORE_RULES = readFileSync(join(ROOT, 'firestore.rules'), 'utf8');

const A = 'lcA';
const B = 'lcB';
const X = 'lcX';
const Y = 'lcY';

const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00]);
const IMG = { contentType: 'image/jpeg' };

let env: RulesTestEnvironment;
let db: admin.firestore.Firestore;
let bucket: ReturnType<admin.storage.Storage['bucket']>;

// Unique couple ids per test: the Storage emulator's clearStorage() is
// unreliable, so isolation comes from never reusing a prefix.
let seq = 0;
const freshId = (tag: string) => `${tag}${Date.now().toString(36)}${++seq}`;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: FIRESTORE_RULES },
    storage: { rules: STORAGE_RULES },
  });
  // emulators:exec exports FIRESTORE_EMULATOR_HOST / FIREBASE_STORAGE_EMULATOR_HOST;
  // the rules-unit-testing bucket is gs://<projectId>.
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'run via npm run test:rules');
  assert.ok(process.env.FIREBASE_STORAGE_EMULATOR_HOST, 'run via npm run test:rules');
  const app = admin.initializeApp({ projectId: PROJECT, storageBucket: PROJECT }, 'lifecycle-test');
  db = app.firestore();
  bucket = app.storage().bucket();
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const storageAs = (uid: string | null) =>
  uid ? env.authenticatedContext(uid).storage() : env.unauthenticatedContext().storage();
const dbAs = (uid: string) => env.authenticatedContext(uid).firestore();

async function seedCouple(coupleId: string, members: string[]) {
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'couples', coupleId), { members, status: 'active', inviteCode: `INV${coupleId}` });
    await setDoc(doc(d, 'invites', `INV${coupleId}`), { fromUserId: members[0], coupleId });
    for (const m of members) await setDoc(doc(d, 'users', m), { coupleId, displayName: m });
    await setDoc(doc(d, 'couples', coupleId, 'messages', 'm1'), {
      senderId: members[0], type: 'image', storagePath: `couples/${coupleId}/chatImages/m1.jpg`,
      createdAt: Timestamp.now(), clientTs: 1,
    });
    await setDoc(doc(d, 'couples', coupleId, 'memories', 'd1'), { imageUrl: 'x', createdAt: Timestamp.now() });
    await setDoc(doc(d, 'couples', coupleId, 'chat', `read_${members[0]}`), { lastReadAt: Timestamp.now(), unread: 0 });
  });
}

/// Uploads as a real member, through the rules, like the app does.
async function uploadAsMember(uid: string, coupleId: string, sub: 'chatImages' | 'memories', name: string) {
  await assertSucceeds(uploadBytes(ref(storageAs(uid), `couples/${coupleId}/${sub}/${name}`), JPEG, IMG));
}

async function count(prefix: string): Promise<number> {
  const [files] = await bucket.getFiles({ prefix });
  return files.length;
}

async function firestoreDocCount(coupleId: string): Promise<number> {
  let n = 0;
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const d = ctx.firestore();
    if ((await getDoc(doc(d, 'couples', coupleId))).exists()) n++;
    for (const sub of ['messages', 'memories', 'chat']) {
      n += (await getDocs(collection(d, 'couples', coupleId, sub))).size;
    }
  });
  return n;
}

// ── Cleanup helper against real Storage ─────────────────────────────────────

test('couple A cleanup cannot touch couple B (real emulator)', async () => {
  const cA = freshId('cA'); const cB = freshId('cB');
  await seedCouple(cA, [A, B]); await seedCouple(cB, [X, Y]);
  await uploadAsMember(A, cA, 'chatImages', 'm1.jpg');
  await uploadAsMember(A, cA, 'memories', 'd1.jpg');
  await uploadAsMember(X, cB, 'chatImages', 'm1.jpg');
  await uploadAsMember(X, cB, 'memories', 'd1.jpg');

  const r = await cleanupCoupleStorage(bucket, cA);
  assert.deepStrictEqual([r.listed, r.deleted, r.failed], [2, 2, 0]);
  assert.strictEqual(await count(`couples/${cA}/`), 0);
  assert.strictEqual(await count(`couples/${cB}/`), 2);
  await assertSucceeds(getBytes(ref(storageAs(Y), `couples/${cB}/chatImages/m1.jpg`)));
});

test('c1/ cannot match c10/ (real emulator)', async () => {
  const base = freshId('p');
  const c1 = `${base}1`; const c10 = `${base}10`;
  await seedCouple(c1, [A, B]); await seedCouple(c10, [X, Y]);
  await uploadAsMember(A, c1, 'chatImages', 'a.jpg');
  await uploadAsMember(X, c10, 'chatImages', 'a.jpg');
  await uploadAsMember(X, c10, 'memories', 'b.jpg');

  const r = await cleanupCoupleStorage(bucket, c1);
  assert.deepStrictEqual([r.listed, r.deleted, r.failed], [1, 1, 0]);
  assert.strictEqual(await count(`couples/${c10}/`), 2);
});

test('empty prefix succeeds; repeated cleanup succeeds', async () => {
  const c = freshId('e');
  const empty = await cleanupCoupleStorage(bucket, c);
  assert.deepStrictEqual([empty.listed, empty.deleted, empty.failed], [0, 0, 0]);

  await seedCouple(c, [A, B]);
  await uploadAsMember(A, c, 'chatImages', 'a.jpg');
  const first = await cleanupCoupleStorage(bucket, c);
  const second = await cleanupCoupleStorage(bucket, c);
  assert.deepStrictEqual([first.listed, first.deleted, first.failed], [1, 1, 0]);
  assert.deepStrictEqual([second.listed, second.deleted, second.failed], [0, 0, 0]);
});

// ── disconnectPartner path ──────────────────────────────────────────────────

test('disconnect removes chatImages + memories, Firestore data, and the former partner is denied afterwards', async () => {
  const c = freshId('dc'); const other = freshId('ok');
  await seedCouple(c, [A, B]); await seedCouple(other, [X, Y]);
  await uploadAsMember(A, c, 'chatImages', 'm1.jpg');
  await uploadAsMember(B, c, 'chatImages', 'm2.jpg');
  await uploadAsMember(A, c, 'memories', 'd1.jpg');
  await uploadAsMember(X, other, 'chatImages', 'm1.jpg');
  // Sanity: while the couple is active the partner can read.
  await assertSucceeds(getBytes(ref(storageAs(B), `couples/${c}/chatImages/m1.jpg`)));
  await assertSucceeds(getDoc(doc(dbAs(B), 'couples', c, 'messages', 'm1')));

  const r = await dissolveCouple(db, bucket, c);
  assert.strictEqual(r.existed, true);
  assert.deepStrictEqual([r.storage.listed, r.storage.deleted, r.storage.failed], [3, 3, 0]);

  // Storage: exact prefix gone, the other couple untouched.
  assert.strictEqual(await count(`couples/${c}/`), 0);
  assert.strictEqual(await count(`couples/${other}/`), 1);
  // Firestore: couple doc + every subcollection gone, members unlinked, invite gone.
  assert.strictEqual(await firestoreDocCount(c), 0);
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const d = ctx.firestore();
    assert.strictEqual((await getDoc(doc(d, 'users', A))).data()?.coupleId, null);
    assert.strictEqual((await getDoc(doc(d, 'users', B))).data()?.coupleId, null);
    assert.strictEqual((await getDoc(doc(d, 'invites', `INV${c}`))).exists(), false);
  });

  // Former partner: denied on Storage (read, and any new upload into the old
  // prefix) and on Firestore (chat + couple doc).
  await assertFails(getBytes(ref(storageAs(B), `couples/${c}/chatImages/m1.jpg`)));
  await assertFails(uploadBytes(ref(storageAs(B), `couples/${c}/chatImages/new1.jpg`), JPEG, IMG));
  await assertFails(uploadBytes(ref(storageAs(B), `couples/${c}/memories/new1.jpg`), JPEG, IMG));
  await assertFails(getDoc(doc(dbAs(B), 'couples', c)));
  await assertFails(getDocs(collection(dbAs(B), 'couples', c, 'messages')));
  await assertFails(setDoc(doc(dbAs(B), 'couples', c, 'messages', 'zz'), { senderId: B, type: 'text', text: 'hi' }));

  // Second dissolve of the same couple is a clean no-op.
  const again = await dissolveCouple(db, bucket, c);
  assert.strictEqual(again.existed, false);
  assert.deepStrictEqual([again.storage.listed, again.storage.failed], [0, 0]);
});

// ── deleteAccount path ──────────────────────────────────────────────────────

test('account deletion removes user files + couple files + docs', async () => {
  const c = freshId('da');
  await seedCouple(c, [A, B]);
  await uploadAsMember(A, c, 'chatImages', 'm1.jpg');
  await uploadAsMember(B, c, 'memories', 'd1.jpg');
  await assertSucceeds(uploadBytes(ref(storageAs(A), `users/${A}/avatar.jpg`), JPEG, IMG));
  await assertSucceeds(uploadBytes(ref(storageAs(B), `users/${B}/avatar.jpg`), JPEG, IMG));

  const r = await deleteUserData(db, bucket, A);
  assert.deepStrictEqual(r.warnings, []);

  assert.strictEqual(await count(`users/${A}/`), 0);
  assert.strictEqual(await count(`couples/${c}/`), 0);
  assert.strictEqual(await count(`users/${B}/`), 1, 'the partner keeps their own files');
  assert.strictEqual(await firestoreDocCount(c), 0);
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const d = ctx.firestore();
    assert.strictEqual((await getDoc(doc(d, 'users', A))).exists(), false);
    assert.strictEqual((await getDoc(doc(d, 'users', B))).data()?.coupleId, null);
  });
  // The former partner is denied on the old couple.
  await assertFails(getBytes(ref(storageAs(B), `couples/${c}/memories/d1.jpg`)));
  await assertFails(getDoc(doc(dbAs(B), 'couples', c)));

  // Retrying the deletion (e.g. after an Auth failure) is a clean no-op.
  const again = await deleteUserData(db, bucket, A);
  assert.deepStrictEqual(again.warnings, []);
});

test('account deletion of a solo user (no couple) cleans only users/{uid}/', async () => {
  const c = freshId('solo');
  await seedCouple(c, [X, Y]);
  await uploadAsMember(X, c, 'chatImages', 'm1.jpg');
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await setDoc(doc(ctx.firestore(), 'users', A), { displayName: 'solo' });
  });
  await assertSucceeds(uploadBytes(ref(storageAs(A), `users/${A}/avatar.jpg`), JPEG, IMG));

  const r = await deleteUserData(db, bucket, A);
  assert.deepStrictEqual(r.warnings, []);
  assert.strictEqual(await count(`users/${A}/`), 0);
  assert.strictEqual(await count(`couples/${c}/`), 1);
  const u = await cleanupUserStorage(bucket, A);
  assert.deepStrictEqual([u.listed, u.failed], [0, 0]);
});

// ── onCoupleDeleted safety net ──────────────────────────────────────────────

test('safety net: files left behind after the couple doc is gone are still removed', async () => {
  const c = freshId('sn');
  await seedCouple(c, [A, B]);
  await uploadAsMember(A, c, 'chatImages', 'm1.jpg');
  await uploadAsMember(A, c, 'memories', 'd1.jpg');
  // Simulate a couple deleted by another route (Console/script): doc gone, files left.
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const { deleteDoc } = await import('firebase/firestore');
    await deleteDoc(doc(ctx.firestore(), 'couples', c));
  });
  assert.strictEqual(await count(`couples/${c}/`), 2);
  // Even before cleanup the former members are already denied (no couple doc).
  await assertFails(getBytes(ref(storageAs(A), `couples/${c}/chatImages/m1.jpg`)));

  const r = await cleanupCoupleStorage(bucket, c);   // what onCoupleDeleted runs
  assert.deepStrictEqual([r.listed, r.deleted, r.failed], [2, 2, 0]);
  assert.strictEqual(await count(`couples/${c}/`), 0);
});

// ── Active couples are unaffected ───────────────────────────────────────────

test('active couple image send/read unchanged after another couple is dissolved', async () => {
  const gone = freshId('g'); const live = freshId('l');
  await seedCouple(gone, [A, B]); await seedCouple(live, [X, Y]);
  await uploadAsMember(A, gone, 'chatImages', 'm1.jpg');
  await dissolveCouple(db, bucket, gone);

  await uploadAsMember(X, live, 'chatImages', 'after1.jpg');
  await uploadAsMember(Y, live, 'memories', 'after2.jpg');
  await assertSucceeds(getBytes(ref(storageAs(Y), `couples/${live}/chatImages/after1.jpg`)));
  await assertSucceeds(getBytes(ref(storageAs(X), `couples/${live}/memories/after2.jpg`)));
  await assertSucceeds(getDoc(doc(dbAs(Y), 'couples', live, 'messages', 'm1')));
  // Still no client delete / overwrite on chat images.
  await assertFails(uploadBytes(ref(storageAs(X), `couples/${live}/chatImages/after1.jpg`), JPEG, IMG));
});

test('invalid ids are rejected before any prefix is built', async () => {
  await assert.rejects(() => cleanupCoupleStorage(bucket, '../users'), /invalid/);
  await assert.rejects(() => dissolveCouple(db, bucket, 'a/b'), /invalid/);
  await assert.rejects(() => deleteUserData(db, bucket, ''), /invalid/);
});

// ── Security regression: H2 — deleteAccount must not dissolve a couple the
// caller only *claims* to belong to via a client-writable users.coupleId. ────

test('H2: account deletion of an attacker who spoofed coupleId leaves the victim couple intact', async () => {
  const victim = freshId('vic');
  await seedCouple(victim, [B, Y]);            // authentic couple [B, Y]
  await uploadAsMember(B, victim, 'chatImages', 'm1.jpg');
  await uploadAsMember(Y, victim, 'memories', 'd1.jpg');
  const docsBefore = await firestoreDocCount(victim);
  const filesBefore = await count(`couples/${victim}/`);

  // Attacker A: NOT a member of `victim`, but their own user doc points at it.
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await setDoc(doc(ctx.firestore(), 'users', A), { coupleId: victim, displayName: 'attacker' });
  });
  await assertSucceeds(uploadBytes(ref(storageAs(A), `users/${A}/avatar.jpg`), JPEG, IMG));

  const r = await deleteUserData(db, bucket, A);

  // The couple dissolution was skipped entirely — no 'couple'/'storage-couple' warning.
  assert.deepStrictEqual(r.warnings, []);

  // Victim couple is fully intact: doc, members, subcollections and Storage.
  assert.strictEqual(await firestoreDocCount(victim), docsBefore);
  assert.strictEqual(await count(`couples/${victim}/`), filesBefore);
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const d = ctx.firestore();
    const couple = await getDoc(doc(d, 'couples', victim));
    assert.strictEqual(couple.exists(), true, 'victim couple doc survives');
    assert.deepStrictEqual(couple.data()?.members, [B, Y], 'victim members unchanged');
    assert.strictEqual((await getDoc(doc(d, 'users', B))).data()?.coupleId, victim, 'victim B still linked');
    assert.strictEqual((await getDoc(doc(d, 'users', Y))).data()?.coupleId, victim, 'victim Y still linked');
  });

  // Only the attacker's OWN account/data was removed.
  assert.strictEqual(await count(`users/${A}/`), 0, 'attacker files deleted');
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    assert.strictEqual((await getDoc(doc(ctx.firestore(), 'users', A))).exists(), false, 'attacker user doc deleted');
  });
});

test('H2: a nonexistent / bogus coupleId on the user doc dissolves nothing', async () => {
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await setDoc(doc(ctx.firestore(), 'users', A), { coupleId: 'no-such-couple', displayName: 'a' });
  });
  await assertSucceeds(uploadBytes(ref(storageAs(A), `users/${A}/avatar.jpg`), JPEG, IMG));
  const r = await deleteUserData(db, bucket, A);
  assert.deepStrictEqual(r.warnings, []);
  assert.strictEqual(await count(`users/${A}/`), 0);
});

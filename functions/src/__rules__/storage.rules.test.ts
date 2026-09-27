// Firebase Storage security rules tests for chat images.
// Runs against the Storage + Firestore emulators (storage.rules reads
// couple membership from Firestore):  npm run test:rules

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
import { doc, setDoc } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL, deleteObject, getBytes } from 'firebase/storage';

// Same project id as the Firestore suite: the Storage emulator evaluates
// `firestore.get()` against the exec's --project, so the couple fixtures
// must live there. Isolation between suites comes from running the files
// serially (--test-concurrency=1), not from separate ids.
const PROJECT = 'us-app-4bf30';
const ROOT = join(__dirname, '..', '..', '..');
const STORAGE_RULES = readFileSync(join(ROOT, 'storage.rules'), 'utf8');
const FIRESTORE_RULES = readFileSync(join(ROOT, 'firestore.rules'), 'utf8');

const A = 'uidA';
const B = 'uidB';
const OUTSIDER = 'uidX';
const COUPLE = 'c1';
const OTHER_COUPLE = 'c2';

// A minimal valid JPEG header is enough for contentType/size checks.
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00]);
const IMG = { contentType: 'image/jpeg' };

let env: RulesTestEnvironment;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: FIRESTORE_RULES },
    storage: { rules: STORAGE_RULES },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'couples', COUPLE), { members: [A, B], status: 'active' });
    await setDoc(doc(db, 'couples', OTHER_COUPLE), { members: [OUTSIDER], status: 'active' });
  });
});

const storageAs = (uid: string | null) =>
  uid ? env.authenticatedContext(uid).storage() : env.unauthenticatedContext().storage();

const chatImg = (uid: string | null, couple = COUPLE, name = 'm1.jpg') =>
  ref(storageAs(uid), `couples/${couple}/chatImages/${name}`);

// Each test uploads to its OWN object. clearStorage() has proven unreliable
// between tests in the emulator, and the rules (by design) refuse to
// overwrite an existing object — so sharing a name across tests would turn
// every setup upload into a denied overwrite.
let seq = 0;
const fresh = () => `t${Date.now()}${++seq}.jpg`;

test('a member can upload a jpeg into their own couple folder', async () => {
  await assertSucceeds(uploadBytes(chatImg(A, COUPLE, fresh()), JPEG, IMG));
});

test('a member cannot upload into ANOTHER couple\'s folder', async () => {
  await assertFails(uploadBytes(chatImg(A, OTHER_COUPLE), JPEG, IMG));
});

test('an outsider and an unauthenticated user cannot upload', async () => {
  await assertFails(uploadBytes(chatImg(OUTSIDER), JPEG, IMG));
  await assertFails(uploadBytes(chatImg(null), JPEG, IMG));
});

test('non-image content type is rejected', async () => {
  await assertFails(uploadBytes(chatImg(A), JPEG, { contentType: 'application/pdf' }));
  await assertFails(uploadBytes(chatImg(A), JPEG, { contentType: 'text/plain' }));
});

test('files over 5 MB are rejected', async () => {
  const big = new Uint8Array(5 * 1024 * 1024 + 1);
  big.set(JPEG);
  await assertFails(uploadBytes(chatImg(A, COUPLE, 'big.jpg'), big, IMG));
});

test('file name must be a plain id with a .jpg extension', async () => {
  await assertFails(uploadBytes(chatImg(A, COUPLE, 'm1.png'), JPEG, { contentType: 'image/png' }));
  await assertFails(uploadBytes(chatImg(A, COUPLE, 'm1.jpg.exe'), JPEG, IMG));
  await assertFails(uploadBytes(chatImg(A, COUPLE, '..jpg'), JPEG, IMG));
});

test('both members can read; outsider and unauthenticated cannot', async () => {
  const n = fresh();
  await assertSucceeds(uploadBytes(chatImg(A, COUPLE, n), JPEG, IMG));
  await assertSucceeds(getDownloadURL(chatImg(A, COUPLE, n)));
  await assertSucceeds(getBytes(chatImg(B, COUPLE, n)));
  await assertFails(getBytes(chatImg(OUTSIDER, COUPLE, n)));
  await assertFails(getBytes(chatImg(null, COUPLE, n)));
});

test('chat images are immutable: no overwrite, no delete', async () => {
  const n = fresh();
  await assertSucceeds(uploadBytes(chatImg(A, COUPLE, n), JPEG, IMG));
  await assertFails(uploadBytes(chatImg(A, COUPLE, n), JPEG, IMG));   // overwrite by author
  await assertFails(uploadBytes(chatImg(B, COUPLE, n), JPEG, IMG));   // overwrite by partner
  await assertFails(deleteObject(chatImg(A, COUPLE, n)));
  await assertFails(deleteObject(chatImg(B, COUPLE, n)));
});

test('a removed partner loses read access immediately', async () => {
  const n = fresh();
  await assertSucceeds(uploadBytes(chatImg(A, COUPLE, n), JPEG, IMG));
  await assertSucceeds(getBytes(chatImg(B, COUPLE, n)));   // still a member
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await setDoc(doc(ctx.firestore(), 'couples', COUPLE), { members: [A], status: 'active' });
  });
  await assertFails(getBytes(chatImg(B, COUPLE, n)));
  await assertSucceeds(getBytes(chatImg(A, COUPLE, n)));
});

test('the memories folder rules are unchanged', async () => {
  const mem = (uid: string) => ref(storageAs(uid), `couples/${COUPLE}/memories/x.jpg`);
  await assertSucceeds(uploadBytes(mem(A), JPEG, IMG));
  await assertFails(uploadBytes(ref(storageAs(OUTSIDER), `couples/${COUPLE}/memories/y.jpg`), JPEG, IMG));
});

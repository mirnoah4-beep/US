// Security regression (audit M2, rules layer): a password-provider account
// must have a verified email TOKEN claim to reach couple-scoped data, even if
// it is already listed in couples.members. Federated providers are unaffected,
// and own users/{uid} access (the login/verification screen) still works.
//   npm run test:rules

import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'fs';
import { join } from 'path';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  type RulesTestEnvironment,
  type RulesTestContext,
  type TokenOptions,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, serverTimestamp } from 'firebase/firestore';

const PROJECT = 'us-app-4bf30';
const RULES = readFileSync(join(__dirname, '..', '..', '..', 'firestore.rules'), 'utf8');

const A = 'uidA';
const B = 'uidB';
const COUPLE = 'cpl';

// Token shapes: password provider (verified / unverified) and a federated one.
const pwVerified: TokenOptions = { email_verified: true, firebase: { sign_in_provider: 'password' } };
const pwUnverified: TokenOptions = { email_verified: false, firebase: { sign_in_provider: 'password' } };
const google: TokenOptions = { email_verified: false, firebase: { sign_in_provider: 'google.com' } };

let env: RulesTestEnvironment;
before(async () => { env = await initializeTestEnvironment({ projectId: PROJECT, firestore: { rules: RULES } }); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'couples', COUPLE), { members: [A, B], status: 'active' });
    await setDoc(doc(d, 'users', A), { coupleId: COUPLE });
    await setDoc(doc(d, 'users', B), { coupleId: COUPLE });
    await setDoc(doc(d, 'couples', COUPLE, 'messages', 'm1'), {
      senderId: A, type: 'text', text: 'hi', createdAt: serverTimestamp(), clientTs: 1,
    });
    await setDoc(doc(d, 'couples', COUPLE, 'lastTime', 'walk'), { lastDone: serverTimestamp() });
  });
});

const as = (token: TokenOptions) => env.authenticatedContext(A, token).firestore();
const msg = (db: ReturnType<typeof as>) => doc(db, 'couples', COUPLE, 'messages', 'm1');
const sub = (db: ReturnType<typeof as>) => doc(db, 'couples', COUPLE, 'lastTime', 'walk');

test('M2-rules: a VERIFIED password member keeps full couple access', async () => {
  const db = as(pwVerified);
  await assertSucceeds(getDoc(doc(db, 'couples', COUPLE)));
  await assertSucceeds(getDoc(msg(db)));
  await assertSucceeds(getDoc(sub(db)));
  await assertSucceeds(setDoc(sub(db), { lastDone: serverTimestamp() }));
});

test('M2-rules: an UNVERIFIED password member is denied couple access even though in members', async () => {
  const db = as(pwUnverified);
  await assertFails(getDoc(doc(db, 'couples', COUPLE)));   // couple doc read
  await assertFails(getDoc(msg(db)));                      // chat read
  await assertFails(setDoc(doc(db, 'couples', COUPLE, 'messages', 'm2'), {
    senderId: A, type: 'text', text: 'x', createdAt: serverTimestamp(), clientTs: 2,
  }));                                                     // chat write
  await assertFails(getDoc(sub(db)));                      // generic subcollection read
  await assertFails(setDoc(sub(db), { lastDone: serverTimestamp() })); // generic write
  await assertFails(setDoc(doc(db, 'couples', COUPLE, 'settings', 'main'), { x: 1 })); // settings
});

test('M2-rules: a federated (Google) member is allowed regardless of email_verified', async () => {
  const db = as(google);
  await assertSucceeds(getDoc(doc(db, 'couples', COUPLE)));
  await assertSucceeds(getDoc(msg(db)));
  await assertSucceeds(setDoc(sub(db), { lastDone: serverTimestamp() }));
});

test('M2-rules: the login/verification screen still works — an unverified password user reads and updates OWN user doc', async () => {
  const db = as(pwUnverified);
  await assertSucceeds(getDoc(doc(db, 'users', A)));                                  // read own profile
  await assertSucceeds(setDoc(doc(db, 'users', A), { needsEmailVerification: false }, { merge: true })); // verification-screen write
  await assertSucceeds(setDoc(doc(db, 'users', A), { fcmToken: 'tok' }, { merge: true }));               // token write
});

// M2: the users/{uid} PARTNER-read branch is gated too; owner self-read is not.
test('M2-rules: unverified password user can read OWN user doc but NOT the partner user doc', async () => {
  const db = as(pwUnverified);
  await assertSucceeds(getDoc(doc(db, 'users', A)));   // own doc — never gated
  await assertFails(getDoc(doc(db, 'users', B)));       // partner doc — gated
});

test('M2-rules: a VERIFIED password partner can read the partner user doc', async () => {
  await assertSucceeds(getDoc(doc(as(pwVerified), 'users', B)));
});

test('M2-rules: a federated (Google) partner can read the partner user doc', async () => {
  await assertSucceeds(getDoc(doc(as(google), 'users', B)));
});

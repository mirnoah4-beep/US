// Rules for "Oss mot problemet": private answers are owner-only and only
// writable as drafts while the talk is being answered; the mediation doc
// is server-written; non-members see nothing.   npm run test:rules
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'fs';
import { join } from 'path';
import { initializeTestEnvironment, assertSucceeds, assertFails, type RulesTestEnvironment, type RulesTestContext } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, collection, getDocs } from 'firebase/firestore';

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
    await setDoc(doc(d, 'couples', C, 'mediations', 'm1'), { category: 'chores', starterUid: A, partnerUid: B, status: 'answering', submitted: {} });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mInv'), { category: 'chores', starterUid: A, partnerUid: B, status: 'invited', submitted: {} });
    await setDoc(doc(d, 'couples', C, 'mediations', 'm2'), { category: 'time', starterUid: B, partnerUid: A, status: 'answering', submitted: {} });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mDone'), { category: 'chores', starterUid: A, partnerUid: B, status: 'active', submitted: { [A]: true, [B]: true } });
    await setDoc(doc(d, 'couples', C, 'mediations', 'm1', 'private', B), { whatHappened: 'b', whatINeed: 'b', whatICanDo: 'b', draft: true });
    await setDoc(doc(d, 'couples', C, 'mediations', 'm1', 'private', A), { whatHappened: 'locked', whatINeed: 'l', whatICanDo: 'l', draft: false, submittedAt: 1 });
    await setDoc(doc(d, 'couples', C, 'mediations', 'm1', 'safety', B), { flaggedAt: 1, categories: ['fear'] });
  });
});
const dbAs = (uid: string) => env.authenticatedContext(uid).firestore();
const priv = (uid: string, m: string, owner: string) => doc(dbAs(uid), 'couples', C, 'mediations', m, 'private', owner);
const draft = { whatHappened: 'x', whatINeed: 'y', whatICanDo: 'z', draft: true, updatedAt: 1 };

test('members read the mediation doc; outsider cannot; nobody writes it from the client', async () => {
  await assertSucceeds(getDoc(doc(dbAs(A), 'couples', C, 'mediations', 'm1')));
  await assertSucceeds(getDoc(doc(dbAs(B), 'couples', C, 'mediations', 'm1')));
  await assertSucceeds(getDocs(collection(dbAs(B), 'couples', C, 'mediations')));
  await assertFails(getDoc(doc(dbAs(X), 'couples', C, 'mediations', 'm1')));
  await assertFails(updateDoc(doc(dbAs(A), 'couples', C, 'mediations', 'm1'), { status: 'active' }));
  await assertFails(updateDoc(doc(dbAs(A), 'couples', C, 'mediations', 'm1'), { [`submitted.${B}`]: true }));
  await assertFails(setDoc(doc(dbAs(A), 'couples', C, 'mediations', 'new'), { category: 'kids', status: 'invited' }));
  await assertFails(deleteDoc(doc(dbAs(A), 'couples', C, 'mediations', 'm1')));
});

test('partner can NEVER read the other\'s private answers; owner can read their own', async () => {
  await assertSucceeds(getDoc(priv(B, 'm1', B)));
  await assertFails(getDoc(priv(A, 'm1', B)));
  await assertFails(getDoc(priv(B, 'm1', A)));
  await assertFails(getDoc(priv(X, 'm1', B)));
  await assertFails(getDocs(collection(dbAs(A), 'couples', C, 'mediations', 'm1', 'private')));
});

test('owner creates/updates a draft while answering; partner cannot write it', async () => {
  await assertSucceeds(setDoc(priv(A, 'm2', A), draft));   // fresh doc by its owner
  await assertSucceeds(updateDoc(priv(B, 'm1', B), { whatINeed: 'more', updatedAt: 2 }));
  await assertFails(updateDoc(priv(A, 'm1', B), { whatINeed: 'hacked' }));
  await assertFails(setDoc(priv(A, 'm1', B), draft));
  await assertFails(setDoc(priv(X, 'm1', X), draft));
  await assertFails(deleteDoc(priv(B, 'm1', B)));
});

test('client can never write draft:false or submittedAt (server only)', async () => {
  await assertFails(updateDoc(priv(B, 'm1', B), { draft: false }));
  await assertFails(updateDoc(priv(B, 'm1', B), { submittedAt: 123 }));
  await assertFails(setDoc(priv(B, 'm1', B), { ...draft, draft: false }));
  await assertFails(updateDoc(priv(B, 'm1', B), { status: 'submitted' }));
});

test('a locked (submitted) private doc is read-only for its owner', async () => {
  await assertSucceeds(getDoc(priv(A, 'm1', A)));
  await assertFails(updateDoc(priv(A, 'm1', A), { whatINeed: 'changed', updatedAt: 3 }));
  await assertFails(setDoc(priv(A, 'm1', A), draft));
});

test('drafts only while the talk is answering/waiting: not invited, not active/closed, not for a missing talk', async () => {
  await assertFails(setDoc(priv(B, 'mInv', B), draft));
  await assertFails(setDoc(priv(A, 'mDone', A), draft));
  await assertFails(setDoc(priv(A, 'nope', A), draft));
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await updateDoc(doc(ctx.firestore(), 'couples', C, 'mediations', 'mInv'), { status: 'waiting' });
  });
  await assertSucceeds(setDoc(priv(B, 'mInv', B), draft));
});

test('draft schema is bounded: unknown keys and oversized answers rejected', async () => {
  await assertFails(setDoc(priv(A, 'm2', A), { ...draft, secret: 1 }));
  await assertFails(setDoc(priv(A, 'm2', A), { ...draft, whatHappened: 'x'.repeat(2001) }));
  await assertFails(setDoc(priv(A, 'm2', A), { ...draft, whatHappened: 42 }));
  await assertSucceeds(setDoc(priv(A, 'm2', A), draft));
});

test('safety markers are invisible to everyone (server-only)', async () => {
  await assertFails(getDoc(doc(dbAs(B), 'couples', C, 'mediations', 'm1', 'safety', B)));
  await assertFails(getDoc(doc(dbAs(A), 'couples', C, 'mediations', 'm1', 'safety', B)));
  await assertFails(setDoc(doc(dbAs(A), 'couples', C, 'mediations', 'm1', 'safety', A), { flaggedAt: 1 }));
});

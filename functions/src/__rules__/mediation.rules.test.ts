// Rules for "Oss mot problemet" (asymmetric flow): private drafts are
// owner-only and kind-gated by stage; the mediation doc is server-written;
// server/* and safety/* are invisible; non-members see nothing.   npm run test:rules
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
const base = { category: 'chores', initiatorUid: A, partnerUid: B, round: 0, invitation: { texts: {}, rephrases: 0 }, rounds: {} };
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const d = ctx.firestore();
    await setDoc(doc(d, 'couples', C), { members: [A, B], status: 'active' });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mDraft'), { ...base, status: 'drafting' });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mInv'), { ...base, status: 'invited' });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mAns'), { ...base, status: 'answering' });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mRound'), { ...base, status: 'round', round: 1, rounds: { 1: { answered: { [A]: true }, feedback: {} } } });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mDone'), { ...base, status: 'active' });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mAns', 'private', B), { kind: 'answer', view: 'b', need: 'b', draft: true });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mRound', 'private', A), { kind: 'feedback', round: 1, feedback: 'almost', addition: 'secret', draft: false, submittedAt: 1 });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mAns', 'server', 'initiator'), { topic: 'raw topic', wish: 'raw wish' });
    await setDoc(doc(d, 'couples', C, 'mediations', 'mAns', 'safety', B), { flaggedAt: 1, categories: ['fear'] });
  });
});
const dbAs = (uid: string) => env.authenticatedContext(uid).firestore();
const med = (uid: string, m: string) => doc(dbAs(uid), 'couples', C, 'mediations', m);
const priv = (uid: string, m: string, owner: string) => doc(dbAs(uid), 'couples', C, 'mediations', m, 'private', owner);
const topic = { kind: 'topic', topic: 'x', wish: 'y', draft: true, updatedAt: 1 };
const answer = { kind: 'answer', view: 'x', need: 'y', draft: true, updatedAt: 1 };
const feedback = { kind: 'feedback', round: 1, feedback: 'happy', addition: '', draft: true, updatedAt: 1 };

test('members read the mediation doc; outsider cannot; nobody writes it from the client', async () => {
  await assertSucceeds(getDoc(med(A, 'mRound')));
  await assertSucceeds(getDoc(med(B, 'mRound')));
  await assertSucceeds(getDocs(collection(dbAs(B), 'couples', C, 'mediations')));
  await assertFails(getDoc(med(X, 'mRound')));
  await assertFails(updateDoc(med(A, 'mRound'), { status: 'agreement' }));
  await assertFails(updateDoc(med(B, 'mRound'), { 'rounds.1.answered.uidB': true }));
  await assertFails(updateDoc(med(B, 'mRound'), { 'rounds.1.feedback.uidA': 'happy' }));
  await assertFails(setDoc(med(A, 'new'), { category: 'kids', status: 'invited' }));
  await assertFails(deleteDoc(med(A, 'mRound')));
});

test('feedback visibility: before both answered, the partner sees answered[uid] but no choice; the private feedback stays owner-only', async () => {
  const seen = (await getDoc(med(B, 'mRound'))).data()!;
  if (seen.rounds[1].answered[A] !== true) throw new Error('answered flag must be visible');
  if (Object.keys(seen.rounds[1].feedback).length !== 0) throw new Error('choice leaked early');
  if (JSON.stringify(seen).includes('secret') || JSON.stringify(seen).includes('almost')) throw new Error('addition/choice leaked');
  await assertFails(getDoc(priv(B, 'mRound', A)));
  await assertSucceeds(getDoc(priv(A, 'mRound', A)));
});

test('partner can NEVER read the other\'s private draft; owner can read their own; server/* and safety/* invisible', async () => {
  await assertSucceeds(getDoc(priv(B, 'mAns', B)));
  await assertFails(getDoc(priv(A, 'mAns', B)));
  await assertFails(getDoc(priv(X, 'mAns', B)));
  await assertFails(getDocs(collection(dbAs(A), 'couples', C, 'mediations', 'mAns', 'private')));
  await assertFails(getDoc(doc(dbAs(A), 'couples', C, 'mediations', 'mAns', 'server', 'initiator')));
  await assertFails(getDoc(doc(dbAs(B), 'couples', C, 'mediations', 'mAns', 'server', 'initiator')));
  await assertFails(setDoc(doc(dbAs(A), 'couples', C, 'mediations', 'mAns', 'server', 'initiator'), { topic: 'x' }));
  await assertFails(getDoc(doc(dbAs(B), 'couples', C, 'mediations', 'mAns', 'safety', B)));
  await assertFails(setDoc(doc(dbAs(A), 'couples', C, 'mediations', 'mAns', 'safety', A), { flaggedAt: 1 }));
});

test('kind is gated by stage: topic only while drafting, answer only while answering, feedback only during a round', async () => {
  await assertSucceeds(setDoc(priv(A, 'mDraft', A), topic));
  await assertFails(setDoc(priv(A, 'mDraft', A), answer));
  await assertFails(setDoc(priv(A, 'mDraft', A), feedback));
  await assertFails(setDoc(priv(B, 'mInv', B), answer));   // not before the partner picked a time
  await assertSucceeds(updateDoc(priv(B, 'mAns', B), { need: 'more', updatedAt: 2 }));
  await assertFails(setDoc(priv(A, 'mAns', A), topic));   // topic stage is over
  await assertSucceeds(setDoc(priv(B, 'mRound', B), feedback));
  await assertFails(setDoc(priv(B, 'mRound', B), answer));
  await assertFails(setDoc(priv(A, 'mDone', A), feedback));
  await assertFails(setDoc(priv(A, 'nope', A), topic));
});

test('only the owner writes a draft; never draft:false / submittedAt; never delete; locked docs are read-only', async () => {
  await assertFails(setDoc(priv(A, 'mAns', B), answer));
  await assertFails(updateDoc(priv(A, 'mAns', B), { need: 'hacked' }));
  await assertFails(setDoc(priv(X, 'mAns', X), answer));
  await assertFails(updateDoc(priv(B, 'mAns', B), { draft: false }));
  await assertFails(updateDoc(priv(B, 'mAns', B), { submittedAt: 123 }));
  await assertFails(setDoc(priv(B, 'mAns', B), { ...answer, draft: false }));
  await assertFails(deleteDoc(priv(B, 'mAns', B)));
  await assertFails(updateDoc(priv(A, 'mRound', A), { addition: 'changed', updatedAt: 3 }));
  await assertFails(setDoc(priv(A, 'mRound', A), feedback));
});

test('draft schema is bounded per kind: unknown keys, cross-kind keys, bad choice and oversized text rejected', async () => {
  await assertFails(setDoc(priv(A, 'mDraft', A), { ...topic, secret: 1 }));
  await assertFails(setDoc(priv(A, 'mDraft', A), { ...topic, view: 'cross-kind' }));
  await assertFails(setDoc(priv(A, 'mDraft', A), { ...topic, topic: 'x'.repeat(1001) }));
  await assertFails(setDoc(priv(A, 'mDraft', A), { ...topic, topic: 42 }));
  await assertSucceeds(setDoc(priv(A, 'mDraft', A), { kind: 'topic', topic: 'x'.repeat(1000), draft: true }));
  await assertFails(setDoc(priv(B, 'mRound', B), { ...feedback, feedback: 'no' }));
  await assertFails(setDoc(priv(B, 'mRound', B), { ...feedback, addition: 'x'.repeat(301) }));
  await assertFails(setDoc(priv(B, 'mRound', B), { ...feedback, round: 'one' }));
  await assertSucceeds(setDoc(priv(B, 'mRound', B), { ...feedback, feedback: 'almost', addition: 'x'.repeat(300) }));
});

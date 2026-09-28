// "Oss mot problemet" ops against the Firestore emulator with a fake AI.
//   npm run test:rules
import { test, before, beforeEach } from 'node:test';
import * as assert from 'node:assert';
import * as admin from 'firebase-admin';
import { initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import {
  createMediation, respondToInvite, submitAnswers, nudgePartner, confirmOrCorrectNeed, editAgreement,
  acceptAgreement, setNeutralState, retrySummary, dueReminders, expireStale, type MediationAi, type Ctx,
} from '../mediationOps';
import { agreementHash } from '../mediation';
import { purgePrivateData } from '../mediationOps';
import { dissolveCouple } from '../coupleLifecycle';
import type { CleanupBucket } from '../storageCleanup';

const PROJECT = 'us-app-4bf30';
const C = 'medCouple'; const A = 'uidA'; const B = 'uidB'; const X = 'uidX';
let env: RulesTestEnvironment; let db: admin.firestore.Firestore; let bucket: CleanupBucket;

const good = (uidFirst: string, uidSecond: string) => ({
  sameTeam: 'Dere vil begge ha ro hjemme.', different: 'Dere ser ulikt på hvor mye som gjøres.',
  needs: { [uidFirst]: 'B trenger å bli sett.', [uidSecond]: 'A trenger litt hjelp.' }, idea: 'Prøv en fast oppvaskdag.',
  agreement: { shared: 'Vi deler oppvasken.', perPartner: { [uidFirst]: 'B tar to dager.', [uidSecond]: 'A sier ifra tidligere.' } },
});
function fakeAi(opts: { flag?: (texts: string[]) => boolean; broken?: number; langs?: string[] } = {}): MediationAi & { calls: { safety: number; generate: number } } {
  let broken = opts.broken ?? 0;
  const calls = { safety: 0, generate: 0 };
  return {
    calls,
    async safety(_s, texts) { calls.safety++; return { flagged: opts.flag ? opts.flag(texts) : false, categories: opts.flag?.(texts) ? ['fear'] : [] }; },
    async generate(_s, prompt) {
      calls.generate++;
      if (broken > 0) { broken--; return { nonsense: true }; }
      // Mirror the uids in the prompt order (partner first, starter second).
      const m = prompt.match(/Two partners: .*? \(id (\w+)\) and .*? \(id (\w+)\)/)!;
      const langs = opts.langs ?? (prompt.includes('AND English') ? ['no', 'en'] : prompt.includes('English') && !prompt.includes('Norwegian') ? ['en'] : ['no']);
      return Object.fromEntries(langs.map((l) => [l, good(m[1], m[2])]));
    },
  };
}
const ctx = (ai: MediationAi, now?: () => Date): Ctx => ({ db, ai, now });
const reason = async (p: Promise<unknown>) => { try { await p; return 'ok'; } catch (e) { return (e as { details?: { reason?: string } }).details?.reason ?? (e as Error).message; } };
const answers = (tag: string) => ({ whatHappened: `hendte ${tag}`, whatINeed: `trenger ${tag}`, whatICanDo: `kan ${tag}`, draft: true });
const mref = (id: string) => db.doc(`couples/${C}/mediations/${id}`);

before(async () => {
  env = await initializeTestEnvironment({ projectId: PROJECT });
  const app = admin.apps.find((a) => a?.name === 'med-test') ?? admin.initializeApp({ projectId: PROJECT, storageBucket: PROJECT }, 'med-test');
  db = app.firestore(); bucket = app.storage().bucket();
});
beforeEach(async () => {
  await env.clearFirestore();
  const b = db.batch();
  b.set(db.doc(`couples/${C}`), { members: [A, B], status: 'active' });
  b.set(db.doc(`users/${A}`), { displayName: 'Adel', language: 'no', timeZone: 'Europe/Oslo', coupleId: C });
  b.set(db.doc(`users/${B}`), { displayName: 'Liv', language: 'en', timeZone: 'Europe/Oslo', coupleId: C });
  b.set(db.doc(`users/${X}`), { displayName: 'X', language: 'no' });
  await b.commit();
});

/// Runs the flow up to both submitted → summary. Returns the mediation id.
async function toSummary(ai: MediationAi): Promise<string> {
  const { mediationId } = await createMediation(ctx(ai), A, C, 'chores');
  await respondToInvite(ctx(ai), B, C, mediationId, 'now');
  await mref(mediationId).collection('private').doc(A).set(answers('a'));
  await mref(mediationId).collection('private').doc(B).set(answers('b'));
  const r1 = await submitAnswers(ctx(ai), A, C, mediationId);
  assert.ok(!r1.flagged && !r1.bothSubmitted);
  const r2 = await submitAnswers(ctx(ai), B, C, mediationId);
  assert.ok(!r2.flagged && r2.bothSubmitted && r2.summaryReady);
  return mediationId;
}

test('happy path: invite → respond → private answers → summary in BOTH languages, private docs deleted', async () => {
  const ai = fakeAi();
  const id = await toSummary(ai);
  const m = (await mref(id).get()).data()!;
  assert.strictEqual(m.status, 'summary');
  assert.deepStrictEqual(m.summary.langs.sort(), ['en', 'no'], 'partners differ in language → both generated');
  assert.ok(m.summary.texts.no.needs[A] && m.summary.texts.en.needs[B]);
  assert.strictEqual(m.agreement.revision, 1);
  assert.strictEqual(m.agreement.hash, agreementHash(C, id, 1, m.agreement.texts));
  assert.strictEqual((await mref(id).collection('private').doc(A).get()).exists, false, 'raw answers removed');
  assert.strictEqual((await mref(id).collection('private').doc(B).get()).exists, false);
  assert.strictEqual(ai.calls.safety, 2, 'safety screened on every submission');
});

test('summary is never generated before both submitted; a single submission just locks the draft', async () => {
  const ai = fakeAi();
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'trust');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await mref(id).collection('private').doc(A).set(answers('a'));
  const r = await submitAnswers(ctx(ai), A, C, id);
  assert.ok(!r.flagged && !r.bothSubmitted);
  const m = (await mref(id).get()).data()!;
  assert.strictEqual(m.status, 'waiting');
  assert.strictEqual(m.summary, undefined);
  assert.strictEqual(ai.calls.generate, 0);
  const p = (await mref(id).collection('private').doc(A).get()).data()!;
  assert.strictEqual(p.draft, false); assert.ok(p.submittedAt);
  assert.strictEqual(await reason(submitAnswers(ctx(ai), A, C, id)), 'already-submitted');
});

test('safety path: flagged submission is invisible — no submitted flag, no pause, partner sees "not answered"', async () => {
  const ai = fakeAi({ flag: (t) => t.some((x) => x.includes('redd')) });
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'trust');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await mref(id).collection('private').doc(B).set({ ...answers('b'), whatHappened: 'Jeg er redd for hva han gjør.' });
  await mref(id).collection('private').doc(A).set(answers('a'));
  const rb = await submitAnswers(ctx(ai), B, C, id);
  assert.deepStrictEqual(rb, { flagged: true, categories: ['fear'] });
  const m = (await mref(id).get()).data()!;
  assert.strictEqual(m.status, 'answering', 'no pause, no state change');
  assert.deepStrictEqual(m.submitted, {}, 'partner sees "not answered yet"');
  assert.strictEqual((await mref(id).collection('safety').doc(B).get()).exists, true, 'server-only marker');
  assert.strictEqual((await mref(id).collection('private').doc(B).get()).data()!.draft, true, 'answers stay a private draft');
  // The other partner can still submit; no summary without both.
  const ra = await submitAnswers(ctx(ai), A, C, id);
  assert.ok(!ra.flagged && !ra.bothSubmitted);
  assert.strictEqual(ai.calls.generate, 0);
  // Explicit phrases flag even when the model says no.
  const ai2 = fakeAi();
  const { mediationId: id2 } = await createMediation(ctx(ai2), A, C, 'trust').catch(() => ({ mediationId: '' }));
  assert.strictEqual(id2, '', 'only one open talk per couple');
});

test('flagged talk later expires like any unanswered talk (neutral)', async () => {
  const ai = fakeAi({ flag: () => true });
  const { mediationId: id } = await createMediation(ctx(ai, () => new Date('2026-09-01T10:00:00Z')), A, C, 'other');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await mref(id).collection('private').doc(A).set(answers('a'));
  await submitAnswers(ctx(ai), A, C, id);
  assert.strictEqual(await expireStale(db, new Date('2026-09-05T10:00:00Z')), 0, 'not yet');
  assert.strictEqual(await expireStale(db, new Date('2026-09-09T10:00:00Z')), 1);
  assert.strictEqual((await mref(id).get()).data()!.status, 'expired');
});

test('non-member denied everywhere; partner cannot act for the other', async () => {
  const ai = fakeAi();
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'money');
  assert.strictEqual(await reason(createMediation(ctx(ai), X, C, 'money')), 'not a member');
  assert.strictEqual(await reason(respondToInvite(ctx(ai), X, C, id, 'now')), 'not a member');
  assert.strictEqual(await reason(respondToInvite(ctx(ai), A, C, id, 'now')), 'not-invitee', 'starter cannot answer the invitation for the partner');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await mref(id).collection('private').doc(B).set(answers('b'));
  assert.strictEqual(await reason(submitAnswers(ctx(ai), A, C, id)), 'answers-missing', 'A cannot submit B\'s answers (only own private doc is read)');
  assert.strictEqual(await reason(submitAnswers(ctx(ai), X, C, id)), 'not a member');
  assert.strictEqual(await reason(nudgePartner(ctx(ai), X, C, id)), 'not a member');
  assert.strictEqual(await reason(setNeutralState(ctx(ai), X, C, id, 'paused')), 'not a member');
});

test('nudge: only while waiting, only by the submitter, at most once per hour', async () => {
  const ai = fakeAi();
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'time');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  assert.strictEqual(await reason(nudgePartner(ctx(ai), A, C, id)), 'wrong-status');
  await mref(id).collection('private').doc(A).set(answers('a'));
  await submitAnswers(ctx(ai), A, C, id);
  assert.strictEqual(await reason(nudgePartner(ctx(ai), B, C, id)), 'wrong-status', 'the one who has not submitted cannot nudge');
  assert.deepStrictEqual(await nudgePartner(ctx(ai), A, C, id), { partnerUid: B });
  assert.strictEqual(await reason(nudgePartner(ctx(ai), A, C, id)), 'too-soon');
  assert.deepStrictEqual(await nudgePartner(ctx(ai, () => new Date(Date.now() + 61 * 60 * 1000)), A, C, id), { partnerUid: B });
});

test('correction affects only the caller\'s own needs line, in every language', async () => {
  const ai = fakeAi();
  const id = await toSummary(ai);
  const before = (await mref(id).get()).data()!.summary.texts;
  await confirmOrCorrectNeed(ctx(ai), A, C, id, 'Adel trenger mer søvn.');
  await confirmOrCorrectNeed(ctx(ai), B, C, id, null);
  const m = (await mref(id).get()).data()!;
  assert.strictEqual(m.summary.texts.no.needs[A], 'Adel trenger mer søvn.');
  assert.strictEqual(m.summary.texts.en.needs[A], 'Adel trenger mer søvn.');
  assert.strictEqual(m.summary.texts.no.needs[B], before.no.needs[B], 'partner line untouched');
  assert.strictEqual(m.summary.texts.no.sameTeam, before.no.sameTeam);
  assert.deepStrictEqual(m.summary.needsConfirmed, { [A]: 'corrected', [B]: 'confirmed' });
  assert.strictEqual(ai.calls.generate, 1, 'no AI re-run on correction');
  assert.strictEqual(await reason(confirmOrCorrectNeed(ctx(ai), A, C, id, 'x'.repeat(301))), 'invalid-text');
});

test('accept is bound to the revision hash; an edit clears acceptances; both accepts → active & immutable', async () => {
  const ai = fakeAi();
  const id = await toSummary(ai);
  const m0 = (await mref(id).get()).data()!;
  const h1 = m0.agreement.hash as string;
  // Wrong / replayed hash rejected.
  assert.strictEqual(await reason(acceptAgreement(ctx(ai), A, C, id, 'a'.repeat(64))), 'hash-mismatch');
  assert.strictEqual(await reason(acceptAgreement(ctx(ai), A, C, id, 'nope')), 'invalid-hash');
  assert.deepStrictEqual(await acceptAgreement(ctx(ai), A, C, id, h1), { active: false });
  // B edits → revision 2, A's acceptance is gone, old hash no longer accepted.
  const e = await editAgreement(ctx(ai), B, C, id, 'We split the dishes fairly.', 'Liv does the dishes on weekdays.');
  assert.strictEqual(e.revision, 2);
  const m1 = (await mref(id).get()).data()!;
  assert.deepStrictEqual(m1.agreement.accepts, {});
  assert.strictEqual(m1.agreement.texts.en.perPartner[B], 'Liv does the dishes on weekdays.');
  assert.strictEqual(m1.agreement.texts.en.perPartner[A], m0.agreement.texts.en.perPartner[A], 'A\'s line untouched by B');
  assert.strictEqual(await reason(acceptAgreement(ctx(ai), A, C, id, h1)), 'hash-mismatch', 'old revision cannot be replayed');
  // Both accept the current revision → active.
  assert.deepStrictEqual(await acceptAgreement(ctx(ai), A, C, id, e.hash), { active: false });
  assert.deepStrictEqual(await acceptAgreement(ctx(ai), B, C, id, e.hash), { active: true });
  const m2 = (await mref(id).get()).data()!;
  assert.strictEqual(m2.status, 'active');
  assert.ok(m2.agreement.activatedAt);
  assert.ok(m2.agreement.accepts[A].at && m2.agreement.accepts[B].at, 'server timestamps recorded');
  // Immutable now.
  assert.strictEqual(await reason(editAgreement(ctx(ai), A, C, id, 's', 'm')), 'wrong-status');
  assert.strictEqual(await reason(acceptAgreement(ctx(ai), A, C, id, e.hash)), 'wrong-status');
  assert.strictEqual(await reason(confirmOrCorrectNeed(ctx(ai), A, C, id, 'late')), 'wrong-status');
  assert.strictEqual(await reason(setNeutralState(ctx(ai), A, C, id, 'paused')), 'wrong-status');
});

test('pause/close are neutral: no reason, no "by whom" on the document', async () => {
  const ai = fakeAi();
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'kids');
  await setNeutralState(ctx(ai), B, C, id, 'paused');
  const m = (await mref(id).get()).data()!;
  assert.strictEqual(m.status, 'paused');
  assert.ok(!('pausedBy' in m) && !('reason' in m));
  await setNeutralState(ctx(ai), A, C, id, 'closed');
  assert.strictEqual((await mref(id).get()).data()!.status, 'closed');
});

test('invalid AI output twice → summaryFailed, private answers kept; retry succeeds and then deletes them', async () => {
  const ai = fakeAi({ broken: 2 });
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'chores');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await mref(id).collection('private').doc(A).set(answers('a'));
  await mref(id).collection('private').doc(B).set(answers('b'));
  await submitAnswers(ctx(ai), A, C, id);
  const r = await submitAnswers(ctx(ai), B, C, id);
  assert.ok(!r.flagged && r.bothSubmitted && !r.summaryReady);
  assert.strictEqual((await mref(id).get()).data()!.status, 'summaryFailed');
  assert.strictEqual((await mref(id).collection('private').doc(A).get()).exists, true);
  assert.deepStrictEqual(await retrySummary(ctx(ai), A, C, id), { summaryReady: true });
  assert.strictEqual((await mref(id).get()).data()!.status, 'summary');
  assert.strictEqual((await mref(id).collection('private').doc(A).get()).exists, false);
});

test('timing: "tonight" schedules a reminder that the scheduler sends once; "now" none', async () => {
  const ai = fakeAi();
  const at = () => new Date('2026-09-28T16:00:00Z');   // 18:00 Oslo
  const { mediationId: id } = await createMediation(ctx(ai, at), A, C, 'time');
  const r = await respondToInvite(ctx(ai, at), B, C, id, 'tonight');
  assert.strictEqual(r.reminderAt!.toISOString(), '2026-09-28T17:00:00.000Z');
  assert.deepStrictEqual(await dueReminders(db, new Date('2026-09-28T16:59:00Z')), []);
  assert.deepStrictEqual(await dueReminders(db, new Date('2026-09-28T17:01:00Z')), [{ coupleId: C, mediationId: id, uid: B }]);
  assert.deepStrictEqual(await dueReminders(db, new Date('2026-09-28T18:00:00Z')), [], 'sent only once');
  const { mediationId: id2 } = await createMediation(ctx(ai), A, C, 'time').catch(() => ({ mediationId: null }));
  assert.strictEqual(id2, null, 'still one open talk');
});

test('lifecycle: dissolveCouple removes mediations, private answers and safety markers', async () => {
  const ai = fakeAi({ flag: (t) => t.some((x) => x.includes('redd')) });
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'trust');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await mref(id).collection('private').doc(B).set({ ...answers('b'), whatINeed: 'redd' });
  await submitAnswers(ctx(ai), B, C, id);
  assert.strictEqual((await mref(id).collection('safety').doc(B).get()).exists, true);
  await dissolveCouple(db, bucket, C);
  assert.strictEqual((await mref(id).get()).exists, false);
  assert.strictEqual((await mref(id).collection('private').doc(B).get()).exists, false);
  assert.strictEqual((await mref(id).collection('safety').doc(B).get()).exists, false);
  assert.strictEqual((await db.collection(`couples/${C}/mediations`).get()).size, 0);
});

test('close deletes every private draft and safety marker of the talk', async () => {
  const ai = fakeAi({ flag: (t) => t.some((x) => x.includes('redd')) });
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'trust');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await mref(id).collection('private').doc(A).set(answers('a'));
  await mref(id).collection('private').doc(B).set({ ...answers('b'), whatINeed: 'redd' });
  await submitAnswers(ctx(ai), B, C, id);                        // flagged → safety marker
  await submitAnswers(ctx(ai), A, C, id);                        // locked private doc
  await setNeutralState(ctx(ai), A, C, id, 'closed');
  assert.strictEqual((await mref(id).get()).data()!.status, 'closed');
  assert.strictEqual((await mref(id).collection('private').get()).size, 0);
  assert.strictEqual((await mref(id).collection('safety').get()).size, 0);
  assert.strictEqual(await purgePrivateData(mref(id)), 0, 'idempotent');
});

test('expiry deletes private drafts and safety markers too', async () => {
  const ai = fakeAi({ flag: () => true });
  const { mediationId: id } = await createMediation(ctx(ai, () => new Date('2026-09-01T10:00:00Z')), A, C, 'money');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await mref(id).collection('private').doc(B).set(answers('b'));
  await submitAnswers(ctx(ai), B, C, id);                        // flagged
  await mref(id).collection('private').doc(A).set(answers('a')); // untouched draft
  assert.strictEqual(await expireStale(db, new Date('2026-09-09T10:00:00Z')), 1);
  assert.strictEqual((await mref(id).get()).data()!.status, 'expired');
  assert.strictEqual((await mref(id).collection('private').get()).size, 0);
  assert.strictEqual((await mref(id).collection('safety').get()).size, 0);
});

test('a flagged user resubmitting still-flagged text is flagged again and can never proceed', async () => {
  const ai = fakeAi({ flag: (t) => t.some((x) => x.includes('redd')) });
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'trust');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await mref(id).collection('private').doc(B).set({ ...answers('b'), whatINeed: 'redd' });
  const first = await submitAnswers(ctx(ai), B, C, id);
  const second = await submitAnswers(ctx(ai), B, C, id);
  assert.ok(first.flagged && second.flagged);
  const m = (await mref(id).get()).data()!;
  assert.deepStrictEqual(m.submitted, {});
  assert.strictEqual(m.status, 'answering');
  assert.strictEqual((await mref(id).collection('private').doc(B).get()).data()!.draft, true);
  // The safety screen offers "Avslutt samtalen" → neutral close, private data gone.
  await setNeutralState(ctx(ai), B, C, id, 'closed');
  assert.strictEqual((await mref(id).get()).data()!.status, 'closed');
  assert.strictEqual((await mref(id).collection('safety').get()).size, 0);
  assert.strictEqual(ai.calls.safety, 2, 'screened on each submission');
});

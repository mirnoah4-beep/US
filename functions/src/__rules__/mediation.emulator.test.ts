// "Oss mot problemet" (asymmetric, multi-round) ops against the Firestore
// emulator with a fake AI.   npm run test:rules
import { test, before, beforeEach } from 'node:test';
import * as assert from 'node:assert';
import * as admin from 'firebase-admin';
import { initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import {
  createMediation, submitTopic, rephraseInvitation, approveInvitation, respondToInvite, submitAnswer, submitFeedback,
  retryGeneration, nudgePartner, editAgreement, acceptAgreement, setNeutralState, purgePrivateData, dueReminders, expireStale,
  type MediationAi, type Ctx,
} from '../mediationOps';
import { agreementHash, UNRESOLVED_NOTE } from '../mediation';
import { dissolveCouple } from '../coupleLifecycle';
import type { CleanupBucket } from '../storageCleanup';

const PROJECT = 'us-app-4bf30';
const C = 'medCouple'; const A = 'uidA'; const B = 'uidB'; const X = 'uidX';
let env: RulesTestEnvironment; let db: admin.firestore.Firestore; let bucket: CleanupBucket;

const roundOut = (first: string, second: string, n: number) => ({
  sameTeam: 'Dere vil begge ha ro hjemme.', different: 'Dere ser ulikt på hvor mye som gjøres.',
  needs: { [first]: 'Liv trenger å bli sett.', [second]: 'Adel trenger litt hjelp.' }, proposal: `Prøv en fast oppvaskdag (v${n}).`,
});
function fakeAi(opts: { flag?: (texts: string[]) => boolean; broken?: number } = {}): MediationAi & { calls: { safety: number; generate: number }; prompts: string[] } {
  let broken = opts.broken ?? 0; let gen = 0;
  const calls = { safety: 0, generate: 0 }; const prompts: string[] = [];
  return {
    calls, prompts,
    async safety(_s, texts) { calls.safety++; const f = opts.flag ? opts.flag(texts) : false; return { flagged: f, categories: f ? ['fear'] : [] }; },
    async generate(_s, prompt) {
      calls.generate++; prompts.push(prompt);
      if (broken > 0) { broken--; return { nonsense: true }; }
      const langs = prompt.includes('AND English') ? ['no', 'en'] : prompt.includes('English') && !prompt.includes('Norwegian') ? ['en'] : ['no'];
      if (prompt.startsWith('Topic:') && prompt.includes('Write a short, warm invitation')) {
        const n = prompt.match(/rephrase #(\d)/)?.[1] ?? '0';
        return Object.fromEntries(langs.map((l) => [l, `Hei – vil du snakke om husarbeid med meg? (${l} r${n})`]));
      }
      if (prompt.includes('Two partners:')) {
        const m = prompt.match(/Two partners: .*? \(id (\w+)\) and .*? \(id (\w+)\)/)!;
        return Object.fromEntries(langs.map((l) => [l, roundOut(m[1], m[2], 1)]));
      }
      if (prompt.startsWith('Round ')) {
        gen++;
        return Object.fromEntries(langs.map((l) => [l, { proposal: `Prøv en fast oppvaskdag (rev${gen} ${l}).`, whatChanged: 'Dagen ble justert.' }]));
      }
      throw new Error(`unexpected prompt: ${prompt.slice(0, 60)}`);
    },
  };
}
const ctx = (ai: MediationAi, now?: () => Date): Ctx => ({ db, ai, now });
const reason = async (p: Promise<unknown>) => { try { await p; return 'ok'; } catch (e) { return (e as { details?: { reason?: string } }).details?.reason ?? (e as Error).message; } };
const mref = (id: string) => db.doc(`couples/${C}/mediations/${id}`);
const priv = (id: string, uid: string) => mref(id).collection('private').doc(uid);
const topic = (t = 'oppvasken') => ({ kind: 'topic', topic: `Jeg blir sliten av ${t}`, wish: 'Mer ro på kveldene', draft: true });
const answer = (t = 'b') => ({ kind: 'answer', view: `slik ser jeg det ${t}`, need: `jeg trenger ${t}`, draft: true });
const fb = (feedback: 'happy' | 'almost', round: number, addition = '') => ({ kind: 'feedback', feedback, round, addition, draft: true });

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

/// A (initiator) → invitation approved → B answered → round 1 open.
async function toInvited(ai: MediationAi, now?: () => Date): Promise<string> {
  const { mediationId: id } = await createMediation(ctx(ai, now), A, C, 'chores');
  await priv(id, A).set(topic());
  const r = await submitTopic(ctx(ai, now), A, C, id);
  assert.ok(!r.flagged && r.generated);
  await approveInvitation(ctx(ai, now), A, C, id);
  return id;
}
async function toRound1(ai: MediationAi, now?: () => Date): Promise<string> {
  const id = await toInvited(ai, now);
  await respondToInvite(ctx(ai, now), B, C, id, 'now');
  await priv(id, B).set(answer());
  const r = await submitAnswer(ctx(ai, now), B, C, id);
  assert.ok(!r.flagged && r.generated);
  return id;
}
async function bothFeedback(ai: MediationAi, id: string, a: 'happy' | 'almost', b: 'happy' | 'almost', round: number) {
  await priv(id, A).set(fb(a, round, a === 'almost' ? 'heller helg' : ''));
  await priv(id, B).set(fb(b, round, b === 'almost' ? 'rather weekdays' : ''));
  const r1 = await submitFeedback(ctx(ai), A, C, id);
  assert.ok(!r1.flagged && !r1.bothAnswered && r1.outcome === 'waiting');
  const r2 = await submitFeedback(ctx(ai), B, C, id);
  assert.ok(!r2.flagged && r2.bothAnswered);
  return r2.outcome;
}

test('happy path: topic → invitation (both languages) → approve → answer → round 1 → both happy → agreement; raw inputs gone', async () => {
  const ai = fakeAi();
  const id = await toRound1(ai);
  const m1 = (await mref(id).get()).data()!;
  assert.strictEqual(m1.status, 'round'); assert.strictEqual(m1.round, 1);
  assert.deepStrictEqual(m1.invitation.langs.sort(), ['en', 'no']);
  assert.ok(m1.rounds['1'].texts.no.needs[A] && m1.rounds['1'].texts.en.needs[B]);
  assert.deepStrictEqual(m1.rounds['1'].answered, {}); assert.deepStrictEqual(m1.rounds['1'].feedback, {});
  // Both perspectives reached the round-1 prompt, then were deleted.
  const p = ai.prompts.find((x) => x.includes('Two partners:'))!;
  assert.match(p, /Liv — how they see it: slik ser jeg det b \| what they need: jeg trenger b/);
  assert.match(p, /Adel — what they wanted to bring up: Jeg blir sliten av oppvasken \| what they hope gets better: Mer ro på kveldene/);
  assert.strictEqual((await mref(id).collection('server').doc('initiator').get()).exists, false, 'server copy deleted after round 1');
  assert.strictEqual((await priv(id, A).get()).exists, false); assert.strictEqual((await priv(id, B).get()).exists, false);
  assert.strictEqual(ai.calls.safety, 2, 'topic and answer each screened');

  assert.strictEqual(await bothFeedback(ai, id, 'happy', 'happy', 1), 'agreement');
  const m2 = (await mref(id).get()).data()!;
  assert.strictEqual(m2.status, 'agreement');
  assert.strictEqual(m2.agreement.texts.no.shared, m1.rounds['1'].texts.no.proposal);
  assert.strictEqual(m2.agreement.hash, agreementHash(C, id, 1, m2.agreement.texts));
  assert.deepStrictEqual(m2.rounds['1'].feedback, { [A]: 'happy', [B]: 'happy' }, 'choices revealed once both answered');
  assert.strictEqual((await mref(id).collection('private').get()).size, 0);
  assert.strictEqual(ai.calls.generate, 2, 'no AI call for the agreement itself');
});

test('feedback visibility: until both answered, the shared doc shows only answered[uid]=true — never the choice', async () => {
  const ai = fakeAi();
  const id = await toRound1(ai);
  await priv(id, A).set(fb('almost', 1, 'litt senere'));
  await submitFeedback(ctx(ai), A, C, id);
  const m = (await mref(id).get()).data()!;
  assert.deepStrictEqual(m.rounds['1'].answered, { [A]: true });
  assert.deepStrictEqual(m.rounds['1'].feedback, {});
  assert.ok(!JSON.stringify(m).includes('almost') && !JSON.stringify(m).includes('litt senere'), 'no choice, no addition on the shared doc');
  assert.strictEqual(m.status, 'round');
  assert.strictEqual(await reason(submitFeedback(ctx(ai), A, C, id)), 'already-answered', 'one shot per round');
});

test('revision: one "almost" → round 2 with a revised proposal + whatChanged; additions consumed; three rounds → unresolved', async () => {
  const ai = fakeAi();
  const id = await toRound1(ai);
  assert.strictEqual(await bothFeedback(ai, id, 'almost', 'happy', 1), 'revised');
  const m2 = (await mref(id).get()).data()!;
  assert.strictEqual(m2.status, 'round'); assert.strictEqual(m2.round, 2);
  assert.match(m2.rounds['2'].texts.no.proposal, /rev1 no/); assert.match(m2.rounds['2'].texts.en.proposal, /rev1 en/);
  assert.strictEqual(m2.rounds['2'].whatChanged.no, 'Dagen ble justert.');
  assert.strictEqual(m2.rounds['2'].texts.no.sameTeam, m2.rounds['1'].texts.no.sameTeam, 'summary carried over');
  assert.deepStrictEqual(m2.rounds['1'].feedback, { [A]: 'almost', [B]: 'happy' });
  assert.strictEqual((await mref(id).collection('private').get()).size, 0, 'feedback docs deleted');
  const rp = ai.prompts.find((x) => x.startsWith('Round 2'))!;
  assert.match(rp, /Adel: almost — wants a tweak: heller helg/);
  assert.strictEqual(ai.calls.safety, 3, 'each non-empty addition screened (topic, answer, A\'s addition)');
  // Round 2: still not happy → round 3; round 3: still not happy → unresolved (no 4th generation).
  assert.strictEqual(await bothFeedback(ai, id, 'happy', 'almost', 2), 'revised');
  assert.strictEqual((await mref(id).get()).data()!.round, 3);
  const gens = ai.calls.generate;
  assert.strictEqual(await bothFeedback(ai, id, 'almost', 'almost', 3), 'unresolved');
  const m4 = (await mref(id).get()).data()!;
  assert.strictEqual(m4.status, 'unresolved');
  assert.deepStrictEqual(m4.closingNote, UNRESOLVED_NOTE);
  assert.ok(!('expiresAt' in m4) && !('agreement' in m4));
  assert.strictEqual(ai.calls.generate, gens, 'no generation after the last round');
  assert.strictEqual((await mref(id).collection('private').get()).size, 0);
  assert.strictEqual(await reason(createMediation(ctx(ai), A, C, 'kids')), 'ok', 'unresolved is an end state → a new talk may start');
});

test('rephrase: at most 3, each a fresh generation; approve only from invitationDraft; only the initiator', async () => {
  const ai = fakeAi();
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'chores');
  assert.strictEqual(await reason(approveInvitation(ctx(ai), A, C, id)), 'wrong-status');
  await priv(id, A).set(topic());
  assert.strictEqual(await reason(submitTopic(ctx(ai), B, C, id)), 'not-initiator');
  await submitTopic(ctx(ai), A, C, id);
  assert.match((await mref(id).get()).data()!.invitation.texts.no, /r0/);
  for (let i = 1; i <= 3; i++) {
    const r = await rephraseInvitation(ctx(ai), A, C, id);
    assert.deepStrictEqual(r, { generated: true, rephrases: i });
    assert.match((await mref(id).get()).data()!.invitation.texts.no, new RegExp(`r${i}`));
  }
  assert.strictEqual(await reason(rephraseInvitation(ctx(ai), A, C, id)), 'rephrase-limit');
  assert.strictEqual(await reason(rephraseInvitation(ctx(ai), B, C, id)), 'not-initiator');
  assert.strictEqual(await reason(approveInvitation(ctx(ai), B, C, id)), 'not-initiator');
  assert.deepStrictEqual(await approveInvitation(ctx(ai), A, C, id), { partnerUid: B });
  const m = (await mref(id).get()).data()!;
  assert.strictEqual(m.status, 'invited'); assert.ok(m.invitation.approvedAt);
  assert.strictEqual((await mref(id).collection('server').doc('initiator').get()).exists, true, 'topic kept server-side until round 1');
  assert.strictEqual((await priv(id, A).get()).exists, false, 'private topic draft removed after submit');
});

test('safety at every stage: flagged topic / answer / addition is invisible to the partner and blocks only that step', async () => {
  const ai = fakeAi({ flag: (t) => t.some((x) => x.includes('redd')) });
  // Topic.
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'trust');
  await priv(id, A).set({ ...topic(), topic: 'Jeg er redd for hva han gjør.' });
  assert.deepStrictEqual(await submitTopic(ctx(ai), A, C, id), { flagged: true, categories: ['fear'] });
  let m = (await mref(id).get()).data()!;
  assert.strictEqual(m.status, 'drafting'); assert.deepStrictEqual(m.invitation.texts, {});
  assert.strictEqual((await mref(id).collection('safety').doc(A).get()).exists, true);
  assert.strictEqual((await priv(id, A).get()).data()!.draft, true, 'draft untouched, can be rewritten');
  assert.strictEqual((await mref(id).collection('server').doc('initiator').get()).exists, false, 'nothing copied server-side');
  await priv(id, A).set(topic());
  assert.ok((await submitTopic(ctx(ai), A, C, id)).flagged === false);
  await approveInvitation(ctx(ai), A, C, id);
  // Answer.
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await priv(id, B).set({ ...answer(), need: 'redd' });
  assert.deepStrictEqual(await submitAnswer(ctx(ai), B, C, id), { flagged: true, categories: ['fear'] });
  m = (await mref(id).get()).data()!;
  assert.strictEqual(m.status, 'answering'); assert.strictEqual(m.round, 0);
  assert.strictEqual((await priv(id, B).get()).data()!.draft, true);
  await priv(id, B).set(answer());
  assert.ok((await submitAnswer(ctx(ai), B, C, id)).flagged === false);
  // Addition.
  await priv(id, A).set(fb('almost', 1, 'jeg er redd'));
  assert.deepStrictEqual(await submitFeedback(ctx(ai), A, C, id), { flagged: true, categories: ['fear'] });
  m = (await mref(id).get()).data()!;
  assert.deepStrictEqual(m.rounds['1'].answered, {}, 'partner sees "not answered yet"');
  assert.strictEqual((await mref(id).collection('safety').get()).size, 2, 'markers for A and B, server-only');
  // The safety screen offers a neutral close → everything private is purged, incl. server/*.
  await setNeutralState(ctx(ai), A, C, id, 'closed');
  assert.strictEqual((await mref(id).collection('private').get()).size, 0);
  assert.strictEqual((await mref(id).collection('safety').get()).size, 0);
  assert.strictEqual((await mref(id).collection('server').get()).size, 0);
  assert.strictEqual(await purgePrivateData(mref(id)), 0, 'idempotent');
});

test('non-member denied everywhere; roles enforced (initiator writes topic, partner answers)', async () => {
  const ai = fakeAi();
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'money');
  assert.strictEqual(await reason(createMediation(ctx(ai), X, C, 'money')), 'not a member');
  assert.strictEqual(await reason(submitTopic(ctx(ai), X, C, id)), 'not a member');
  await priv(id, B).set(topic());
  assert.strictEqual(await reason(submitTopic(ctx(ai), B, C, id)), 'not-initiator');
  await priv(id, A).set(topic()); await submitTopic(ctx(ai), A, C, id); await approveInvitation(ctx(ai), A, C, id);
  assert.strictEqual(await reason(respondToInvite(ctx(ai), A, C, id, 'now')), 'not-invitee');
  assert.strictEqual(await reason(respondToInvite(ctx(ai), X, C, id, 'now')), 'not a member');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  await priv(id, A).set(answer('a'));
  assert.strictEqual(await reason(submitAnswer(ctx(ai), A, C, id)), 'not-invitee');
  assert.strictEqual(await reason(submitAnswer(ctx(ai), B, C, id)), 'answer-invalid', 'B has no draft yet');
  assert.strictEqual(await reason(nudgePartner(ctx(ai), X, C, id)), 'not a member');
  assert.strictEqual(await reason(setNeutralState(ctx(ai), X, C, id, 'paused')), 'not a member');
  assert.strictEqual(await reason(submitFeedback(ctx(ai), A, C, id)), 'wrong-status');
});

test('nudge: initiator while invited/answering; whoever answered a round; at most once per hour', async () => {
  const ai = fakeAi();
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'time');
  assert.strictEqual(await reason(nudgePartner(ctx(ai), A, C, id)), 'wrong-status', 'nothing to wait for while drafting');
  await priv(id, A).set(topic()); await submitTopic(ctx(ai), A, C, id); await approveInvitation(ctx(ai), A, C, id);
  assert.strictEqual(await reason(nudgePartner(ctx(ai), B, C, id)), 'wrong-status', 'the invitee is the one being waited for');
  assert.deepStrictEqual(await nudgePartner(ctx(ai), A, C, id), { partnerUid: B });
  assert.strictEqual(await reason(nudgePartner(ctx(ai), A, C, id)), 'too-soon');
  await respondToInvite(ctx(ai), B, C, id, 'now');
  assert.deepStrictEqual(await nudgePartner(ctx(ai, () => new Date(Date.now() + 61 * 60 * 1000)), A, C, id), { partnerUid: B });
  await priv(id, B).set(answer()); await submitAnswer(ctx(ai), B, C, id);
  assert.strictEqual(await reason(nudgePartner(ctx(ai, () => new Date(Date.now() + 3 * 3600 * 1000)), A, C, id)), 'wrong-status', 'round open, A has not answered');
  await priv(id, B).set(fb('happy', 1)); await submitFeedback(ctx(ai), B, C, id);
  assert.deepStrictEqual(await nudgePartner(ctx(ai), B, C, id), { partnerUid: A });
});

test('accept is bound to the revision hash; an edit clears acceptances; both accepts → active & immutable', async () => {
  const ai = fakeAi();
  const id = await toRound1(ai);
  await bothFeedback(ai, id, 'happy', 'happy', 1);
  const m0 = (await mref(id).get()).data()!;
  const h1 = m0.agreement.hash as string;
  assert.strictEqual(await reason(acceptAgreement(ctx(ai), A, C, id, 'a'.repeat(64))), 'hash-mismatch');
  assert.strictEqual(await reason(acceptAgreement(ctx(ai), A, C, id, 'nope')), 'invalid-hash');
  assert.deepStrictEqual(await acceptAgreement(ctx(ai), A, C, id, h1), { active: false });
  const e = await editAgreement(ctx(ai), B, C, id, 'We split the dishes fairly.', 'Liv does the dishes on weekdays.');
  assert.strictEqual(e.revision, 2);
  const m1 = (await mref(id).get()).data()!;
  assert.deepStrictEqual(m1.agreement.accepts, {});
  assert.strictEqual(m1.agreement.texts.en.perPartner[B], 'Liv does the dishes on weekdays.');
  assert.strictEqual(m1.agreement.texts.en.perPartner[A], m0.agreement.texts.en.perPartner[A], 'A\'s line untouched by B');
  assert.strictEqual(await reason(acceptAgreement(ctx(ai), A, C, id, h1)), 'hash-mismatch', 'old revision cannot be replayed');
  assert.deepStrictEqual(await acceptAgreement(ctx(ai), A, C, id, e.hash), { active: false });
  assert.deepStrictEqual(await acceptAgreement(ctx(ai), B, C, id, e.hash), { active: true });
  const m2 = (await mref(id).get()).data()!;
  assert.strictEqual(m2.status, 'active');
  assert.ok(m2.agreement.activatedAt && m2.agreement.accepts[A].at && m2.agreement.accepts[B].at);
  assert.ok(!('expiresAt' in m2));
  assert.strictEqual(await reason(editAgreement(ctx(ai), A, C, id, 's', 'm')), 'wrong-status');
  assert.strictEqual(await reason(acceptAgreement(ctx(ai), A, C, id, e.hash)), 'wrong-status');
  assert.strictEqual(await reason(setNeutralState(ctx(ai), A, C, id, 'paused')), 'wrong-status');
});

test('pause/close are neutral: no reason, no "by whom" on the document; paused talks never expire', async () => {
  const ai = fakeAi();
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'kids');
  await setNeutralState(ctx(ai), B, C, id, 'paused');
  const m = (await mref(id).get()).data()!;
  assert.strictEqual(m.status, 'paused');
  assert.ok(!('pausedBy' in m) && !('reason' in m) && !('expiresAt' in m));
  assert.strictEqual(await expireStale(db, new Date('2030-01-01T00:00:00Z')), 0);
  await setNeutralState(ctx(ai), A, C, id, 'closed');
  assert.strictEqual((await mref(id).get()).data()!.status, 'closed');
});

test('generation failures: invitation, round 1 and revision each go to generationFailed and retry succeeds', async () => {
  const ai = fakeAi({ broken: 2 });
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'chores');
  await priv(id, A).set(topic());
  assert.deepStrictEqual(await submitTopic(ctx(ai), A, C, id), { flagged: false, generated: false });
  assert.strictEqual((await mref(id).get()).data()!.status, 'generationFailed');
  assert.strictEqual((await mref(id).collection('server').doc('initiator').get()).exists, true, 'input kept for retry');
  assert.deepStrictEqual(await retryGeneration(ctx(ai), A, C, id), { generated: true });
  assert.strictEqual((await mref(id).get()).data()!.status, 'invitationDraft');
  await approveInvitation(ctx(ai), A, C, id);
  await respondToInvite(ctx(ai), B, C, id, 'now');
  const ai2 = fakeAi({ broken: 2 }); ai2.prompts.length = 0;
  await priv(id, B).set(answer());
  assert.deepStrictEqual(await submitAnswer(ctx(ai2), B, C, id), { flagged: false, generated: false });
  assert.strictEqual((await mref(id).get()).data()!.failedStage, 'round1');
  assert.strictEqual((await priv(id, B).get()).exists, true, 'answer kept for retry');
  assert.deepStrictEqual(await retryGeneration(ctx(ai2), B, C, id), { generated: true });
  assert.strictEqual((await mref(id).get()).data()!.status, 'round');
  assert.strictEqual((await priv(id, B).get()).exists, false);
  const ai3 = fakeAi({ broken: 2 });
  await priv(id, A).set(fb('almost', 1, 'x')); await priv(id, B).set(fb('happy', 1));
  await submitFeedback(ctx(ai3), A, C, id);
  const r = await submitFeedback(ctx(ai3), B, C, id);
  assert.ok(!r.flagged && r.bothAnswered && r.outcome === 'generationFailed');
  assert.strictEqual((await mref(id).get()).data()!.failedStage, 'revision2');
  assert.deepStrictEqual(await retryGeneration(ctx(ai3), A, C, id), { generated: true });
  const m = (await mref(id).get()).data()!;
  assert.strictEqual(m.status, 'round'); assert.strictEqual(m.round, 2);
});

test('timing: "tonight" schedules a reminder that the scheduler sends once; answering clears it', async () => {
  const ai = fakeAi();
  const at = () => new Date('2026-09-28T16:00:00Z');   // 18:00 Oslo
  const id = await toInvited(ai, at);
  const r = await respondToInvite(ctx(ai, at), B, C, id, 'tonight');
  assert.strictEqual(r.reminderAt!.toISOString(), '2026-09-28T17:00:00.000Z');
  assert.deepStrictEqual(await dueReminders(db, new Date('2026-09-28T16:59:00Z')), []);
  assert.deepStrictEqual(await dueReminders(db, new Date('2026-09-28T17:01:00Z')), [{ coupleId: C, mediationId: id, uid: B }]);
  assert.deepStrictEqual(await dueReminders(db, new Date('2026-09-28T18:00:00Z')), [], 'sent only once');
  assert.strictEqual(await reason(createMediation(ctx(ai), A, C, 'time')), 'already-open');
});

test('expiry is refreshed at every completed step and removed in end states', async () => {
  const ai = fakeAi();
  const t0 = new Date('2026-09-01T10:00:00Z');
  const id = await toInvited(ai, () => t0);
  const e0 = (await mref(id).get()).data()!.expiresAt.toDate() as Date;
  assert.strictEqual(e0.toISOString(), '2026-09-08T10:00:00.000Z');
  const t1 = new Date('2026-09-06T10:00:00Z');
  await respondToInvite(ctx(ai, () => t1), B, C, id, 'now');
  await priv(id, B).set(answer());
  await submitAnswer(ctx(ai, () => t1), B, C, id);
  const e1 = (await mref(id).get()).data()!.expiresAt.toDate() as Date;
  assert.strictEqual(e1.toISOString(), '2026-09-13T10:00:00.000Z', 'a live talk does not expire mid-conversation');
  assert.strictEqual(await expireStale(db, new Date('2026-09-09T00:00:00Z')), 0);
  assert.strictEqual(await expireStale(db, new Date('2026-09-14T00:00:00Z')), 1);
  assert.strictEqual((await mref(id).get()).data()!.status, 'expired');
  assert.strictEqual((await mref(id).collection('private').get()).size, 0);
});

test('lifecycle: dissolveCouple removes mediations, private drafts, server copies and safety markers', async () => {
  const ai = fakeAi({ flag: (t) => t.some((x) => x.includes('redd')) });
  const { mediationId: id } = await createMediation(ctx(ai), A, C, 'trust');
  await priv(id, A).set(topic());
  await submitTopic(ctx(ai), A, C, id);
  await priv(id, B).set({ kind: 'answer', view: 'redd', need: 'x', draft: true });
  assert.strictEqual((await mref(id).collection('server').doc('initiator').get()).exists, true);
  await dissolveCouple(db, bucket, C);
  assert.strictEqual((await mref(id).get()).exists, false);
  assert.strictEqual((await mref(id).collection('private').get()).size, 0);
  assert.strictEqual((await mref(id).collection('server').get()).size, 0);
  assert.strictEqual((await db.collection(`couples/${C}/mediations`).get()).size, 0);
});

test('scheduler cannot be starved: 250 stale docs + 1 due reminder + 1 due expiry are all handled in ONE run', async () => {
  const ai = fakeAi();
  const past = admin.firestore.Timestamp.fromDate(new Date('2026-09-01T00:00:00Z'));
  let batch = db.batch(); let inBatch = 0;
  for (let i = 0; i < 250; i++) {
    batch.set(db.doc(`couples/${C}/mediations/stale${i}`), {
      category: 'other', initiatorUid: A, partnerUid: B, status: i % 2 ? 'closed' : 'active', round: 1,
      reminderAt: past, reminderSent: true, expiresAt: past,
    });
    if (++inBatch === 400) { await batch.commit(); batch = db.batch(); inBatch = 0; }
  }
  await batch.commit();
  const at = () => new Date('2026-09-28T16:00:00Z');
  const due = await toInvited(ai, at);
  await respondToInvite(ctx(ai, at), B, C, due, 'tonight');                       // reminder 17:00Z
  await mref(due).update({ status: 'paused' });                                    // free the "one open talk" slot…
  const { mediationId: old } = await createMediation(ctx(ai, () => new Date('2026-09-01T10:00:00Z')), A, C, 'money');
  await mref(due).update({ status: 'answering' });                                 // …then restore
  const now = new Date('2026-09-28T18:00:00Z');
  assert.deepStrictEqual(await dueReminders(db, now), [{ coupleId: C, mediationId: due, uid: B }], 'the one due reminder is found past 250 stale docs');
  assert.strictEqual(await expireStale(db, now), 1, 'the one due expiry is processed');
  assert.strictEqual((await mref(old).get()).data()!.status, 'expired');
  const remR = await db.collectionGroup('mediations').where('reminderAt', '<=', admin.firestore.Timestamp.fromDate(now)).get();
  const remE = await db.collectionGroup('mediations').where('expiresAt', '<=', admin.firestore.Timestamp.fromDate(now)).get();
  assert.strictEqual(remR.size, 0); assert.strictEqual(remE.size, 0);
  const stale = (await db.doc(`couples/${C}/mediations/stale7`).get()).data()!;
  assert.ok(!('expiresAt' in stale) && !('reminderAt' in stale) && !('reminderSent' in stale));
  assert.strictEqual(stale.status, 'closed', 'stale docs are otherwise untouched');
});

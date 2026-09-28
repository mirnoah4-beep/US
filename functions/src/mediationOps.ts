// "Oss mot problemet" — Firestore operations (asymmetric, multi-round).
// Every op validates the caller (membership + role) server-side and is the
// ONLY writer of the mediation document; clients may write their own
// private draft only (rules).
//
// Layout (all under the couple → existing lifecycle deletion covers it):
//   couples/{c}/mediations/{m}                  members read; server writes
//   couples/{c}/mediations/{m}/private/{uid}    owner-only draft (kind: topic | answer | feedback)
//   couples/{c}/mediations/{m}/server/initiator server-only copy of topic+wish until round 1
//   couples/{c}/mediations/{m}/safety/{uid}     server-only marker, never content

import { firestore } from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  agreementFromProposal, agreementHash, applyAgreementEdit, bothAccepted, buildInvitationPrompt, buildRevisionPrompt,
  buildRound1Prompt, canNudge, combineSafety, expiryInstant, isCategory, isTiming, langOf, parseInvitationOutput,
  parseRevisionOutput, parseRoundOutput, parseSafetyOutput, phraseSafetyScan, reminderInstant, validateAnswer,
  validateFeedback, validateTopic, ANSWERING_STATUSES, EXPIRABLE_STATUSES, OPEN_STATUSES, FACILITATOR_SYSTEM_PROMPT,
  SAFETY_SYSTEM_PROMPT, MAX_REPHRASES, MAX_ROUNDS, UNRESOLVED_NOTE,
  type Accept, type AgreementByLang, type ByLang, type Category, type Feedback, type Lang, type Partner,
  type RoundByLang, type SafetyModelOutput, type Status, type Timing,
} from './mediation';

type Db = firestore.Firestore;
const FieldValue = firestore.FieldValue;

/// The AI seam — the real implementation calls OpenAI; tests inject fakes.
export interface MediationAi {
  safety(systemPrompt: string, texts: string[]): Promise<unknown>;
  generate(systemPrompt: string, userPrompt: string): Promise<unknown>;
}
export interface Ctx { db: Db; ai: MediationAi; now?: () => Date }
const nowOf = (c: Ctx) => (c.now ? c.now() : new Date());

// ── Helpers ─────────────────────────────────────────────────────────────────

async function requireMember(db: Db, uid: string, coupleId: unknown): Promise<{ coupleId: string; members: string[] }> {
  if (typeof coupleId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(coupleId)) throw new HttpsError('invalid-argument', 'coupleId');
  const snap = await db.collection('couples').doc(coupleId).get();
  if (!snap.exists) throw new HttpsError('not-found', 'couple');
  const members: string[] = (snap.data()?.members ?? []).filter((m: unknown): m is string => typeof m === 'string');
  if (!members.includes(uid)) throw new HttpsError('permission-denied', 'not a member');
  return { coupleId, members };
}
function mediationRef(db: Db, coupleId: string, mediationId: unknown) {
  if (typeof mediationId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(mediationId)) throw new HttpsError('invalid-argument', 'mediationId');
  return db.collection('couples').doc(coupleId).collection('mediations').doc(mediationId);
}
const err = (reason: string, code: 'failed-precondition' | 'permission-denied' | 'not-found' | 'invalid-argument' | 'resource-exhausted' = 'failed-precondition') =>
  new HttpsError(code, reason, { reason });

async function loadUser(db: Db, uid: string): Promise<Partner & { timeZone: unknown }> {
  const d = (await db.collection('users').doc(uid).get()).data() ?? {};
  const lang = langOf(d.language);
  const name = typeof d.displayName === 'string' && d.displayName.trim() ? d.displayName.trim() : (lang === 'no' ? 'Partneren din' : 'Your partner');
  return { uid, name, lang, timeZone: d.timeZone };
}
const langsOf = (a: Partner, b: Partner): Lang[] => [...new Set([a.lang, b.lang])];

/// Fresh 7-day expiry from now — refreshed at every completed step so a
/// live talk never expires mid-conversation; removed in end states.
const freshExpiry = (c: Ctx) => firestore.Timestamp.fromDate(expiryInstant(nowOf(c)));
const CLEAR_TRIGGERS = { expiresAt: FieldValue.delete(), reminderAt: FieldValue.delete(), reminderSent: FieldValue.delete() };

/// Safety screen on ONE person's private texts. Flagged → server-only
/// marker + result to that caller; nothing on the shared document.
async function screen(c: Ctx, ref: firestore.DocumentReference, uid: string, stage: string, texts: string[]): Promise<{ flagged: boolean; categories: string[] }> {
  const nonEmpty = texts.filter((t) => t.trim().length > 0);
  if (nonEmpty.length === 0) return { flagged: false, categories: [] };
  let model: SafetyModelOutput | null = null;
  try { model = parseSafetyOutput(await c.ai.safety(SAFETY_SYSTEM_PROMPT, nonEmpty)); } catch { model = null; }
  const a = combineSafety(phraseSafetyScan(nonEmpty), model);
  if (a.flagged) {
    await ref.collection('safety').doc(uid).set({ flaggedAt: FieldValue.serverTimestamp(), categories: a.categories, source: a.source, stage }, { merge: true });
  }
  return { flagged: a.flagged, categories: a.categories };
}

async function generateJson(c: Ctx, prompt: string, parse: (raw: unknown) => unknown | null): Promise<unknown | null> {
  for (let attempt = 0; attempt < 2; attempt++) {
    try { const p = parse(await c.ai.generate(FACILITATOR_SYSTEM_PROMPT, prompt)); if (p) return p; } catch { /* retry */ }
  }
  return null;
}

// ── Create → topic → invitation ─────────────────────────────────────────────

export async function createMediation(c: Ctx, uid: string, coupleId: unknown, category: unknown) {
  const { coupleId: cid, members } = await requireMember(c.db, uid, coupleId);
  if (!isCategory(category)) throw err('invalid-category', 'invalid-argument');
  const partnerUid = members.find((m) => m !== uid);
  if (!partnerUid) throw err('no-partner');
  const col = c.db.collection('couples').doc(cid).collection('mediations');
  const open = await col.where('status', 'in', [...OPEN_STATUSES]).limit(1).get();
  if (!open.empty) throw err('already-open');
  const ref = col.doc();
  await ref.set({
    category, initiatorUid: uid, partnerUid, status: 'drafting' as Status, round: 0,
    createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), expiresAt: freshExpiry(c),
    timing: null, invitation: { texts: {}, rephrases: 0, approvedAt: null }, rounds: {},
  });
  return { mediationId: ref.id, partnerUid };
}

export type SubmitResult = { flagged: true; categories: string[] } | { flagged: false; generated: boolean };

/// Initiator submits topic + wish: safety screen, then the neutral
/// invitation is generated. The raw text moves to the server-only copy
/// (needed again for round 1) and the private doc is deleted.
export async function submitTopic(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown): Promise<SubmitResult> {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const [mSnap, pSnap] = await Promise.all([ref.get(), ref.collection('private').doc(uid).get()]);
  const m = mSnap.data();
  if (!m) throw err('not-found', 'not-found');
  if (m.initiatorUid !== uid) throw err('not-initiator', 'permission-denied');
  if (m.status !== 'drafting') throw err('wrong-status');
  const input = validateTopic(pSnap.data());
  if (!input) throw err('topic-invalid', 'invalid-argument');
  const s = await screen(c, ref, uid, 'topic', [input.topic, input.wish]);
  if (s.flagged) return { flagged: true, categories: s.categories };

  await ref.collection('server').doc('initiator').set({ topic: input.topic, wish: input.wish, savedAt: FieldValue.serverTimestamp() });
  await ref.collection('private').doc(uid).delete();
  const generated = await generateInvitation(c, cid, ref.id, 0);
  return { flagged: false, generated };
}

async function generateInvitation(c: Ctx, coupleId: string, mediationId: string, rephrase: number): Promise<boolean> {
  const ref = mediationRef(c.db, coupleId, mediationId);
  const m = (await ref.get()).data()!;
  const [init, partner, srv] = await Promise.all([loadUser(c.db, m.initiatorUid), loadUser(c.db, m.partnerUid), ref.collection('server').doc('initiator').get()]);
  const raw = srv.data();
  if (!raw) throw err('topic-missing');
  const langs = langsOf(init, partner);
  const prompt = buildInvitationPrompt({ category: m.category as Category, initiator: init, partner, topic: raw.topic, wish: raw.wish, langs, rephrase });
  const out = (await generateJson(c, prompt, (r) => parseInvitationOutput(r, langs, [raw.topic, raw.wish]))) as ByLang | null;
  if (!out) {
    await ref.update({ status: 'generationFailed' as Status, failedStage: 'invitation', updatedAt: FieldValue.serverTimestamp() });
    return false;
  }
  await ref.update({
    status: 'invitationDraft' as Status, failedStage: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp(), expiresAt: freshExpiry(c),
    'invitation.texts': out, 'invitation.rephrases': rephrase, 'invitation.langs': langs,
  });
  return true;
}

export async function rephraseInvitation(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown) {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const m = (await ref.get()).data();
  if (!m) throw err('not-found', 'not-found');
  if (m.initiatorUid !== uid) throw err('not-initiator', 'permission-denied');
  if (m.status !== 'invitationDraft') throw err('wrong-status');
  const n = (m.invitation?.rephrases ?? 0) as number;
  if (n >= MAX_REPHRASES) throw err('rephrase-limit', 'resource-exhausted');
  return { generated: await generateInvitation(c, cid, ref.id, n + 1), rephrases: n + 1 };
}

export async function approveInvitation(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown) {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  return c.db.runTransaction(async (tx) => {
    const m = (await tx.get(ref)).data();
    if (!m) throw err('not-found', 'not-found');
    if (m.initiatorUid !== uid) throw err('not-initiator', 'permission-denied');
    if (m.status !== 'invitationDraft') throw err('wrong-status');
    tx.update(ref, { status: 'invited' as Status, 'invitation.approvedAt': FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), expiresAt: freshExpiry(c) });
    return { partnerUid: m.partnerUid as string };
  });
}

// ── Partner: timing + answer → round 1 ──────────────────────────────────────

export async function respondToInvite(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown, timing: unknown) {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  if (!isTiming(timing)) throw err('invalid-timing', 'invalid-argument');
  const ref = mediationRef(c.db, cid, mediationId);
  const user = await loadUser(c.db, uid);
  const remindAt = reminderInstant(timing as Timing, nowOf(c), user.timeZone);
  return c.db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    if (!d) throw err('not-found', 'not-found');
    if (d.partnerUid !== uid) throw err('not-invitee', 'permission-denied');
    if (d.status !== 'invited') throw err('wrong-status');
    tx.update(ref, {
      status: 'answering' as Status, timing, updatedAt: FieldValue.serverTimestamp(), expiresAt: freshExpiry(c),
      reminderAt: remindAt ? firestore.Timestamp.fromDate(remindAt) : FieldValue.delete(), reminderSent: FieldValue.delete(),
    });
    return { initiatorUid: d.initiatorUid as string, timing: timing as Timing, reminderAt: remindAt };
  });
}

/// Partner submits view + need: safety screen, then round 1 (summary +
/// proposal) from BOTH perspectives. Both raw inputs are deleted afterwards.
export async function submitAnswer(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown): Promise<SubmitResult> {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const [mSnap, pSnap] = await Promise.all([ref.get(), ref.collection('private').doc(uid).get()]);
  const m = mSnap.data();
  if (!m) throw err('not-found', 'not-found');
  if (m.partnerUid !== uid) throw err('not-invitee', 'permission-denied');
  if (!ANSWERING_STATUSES.includes(m.status)) throw err('wrong-status');
  const input = validateAnswer(pSnap.data());
  if (!input) throw err('answer-invalid', 'invalid-argument');
  const s = await screen(c, ref, uid, 'answer', [input.view, input.need]);
  if (s.flagged) return { flagged: true, categories: s.categories };
  await ref.collection('private').doc(uid).update({ draft: false, submittedAt: FieldValue.serverTimestamp() });
  await ref.update({ answeredAt: FieldValue.serverTimestamp(), reminderAt: FieldValue.delete(), reminderSent: FieldValue.delete() });
  return { flagged: false, generated: await generateRound1(c, cid, ref.id) };
}

async function generateRound1(c: Ctx, coupleId: string, mediationId: string): Promise<boolean> {
  const ref = mediationRef(c.db, coupleId, mediationId);
  const m = (await ref.get()).data()!;
  const [init, partner, srv, priv] = await Promise.all([
    loadUser(c.db, m.initiatorUid), loadUser(c.db, m.partnerUid),
    ref.collection('server').doc('initiator').get(), ref.collection('private').doc(m.partnerUid).get(),
  ]);
  const raw = srv.data(); const ans = validateAnswer(priv.data());
  if (!raw || !ans) throw err('inputs-missing');
  const langs = langsOf(init, partner);
  const invitation = (m.invitation?.texts?.[langs[0]] ?? Object.values(m.invitation?.texts ?? {})[0] ?? '') as string;
  const prompt = buildRound1Prompt({ category: m.category as Category, initiator: init, partner, invitation, topic: raw.topic, wish: raw.wish, view: ans.view, need: ans.need, langs });
  const uids = [m.partnerUid, m.initiatorUid];
  const out = (await generateJson(c, prompt, (r) => parseRoundOutput(r, langs, uids))) as RoundByLang | null;
  if (!out) {
    await ref.update({ status: 'generationFailed' as Status, failedStage: 'round1', updatedAt: FieldValue.serverTimestamp() });
    return false;
  }
  const batch = c.db.batch();
  batch.update(ref, {
    status: 'round' as Status, round: 1, failedStage: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp(), expiresAt: freshExpiry(c),
    'rounds.1': { texts: out, answered: {}, feedback: {}, generatedAt: FieldValue.serverTimestamp(), langs },
  });
  // Raw perspectives have served their purpose.
  batch.delete(ref.collection('server').doc('initiator'));
  batch.delete(ref.collection('private').doc(m.partnerUid));
  await batch.commit();
  return true;
}

// ── Rounds: feedback → agreement | revision | unresolved ───────────────────

export type FeedbackResult =
  | { flagged: true; categories: string[] }
  | { flagged: false; bothAnswered: boolean; outcome: 'waiting' | 'agreement' | 'revised' | 'unresolved' | 'generationFailed' };

/// Either partner, once per round. Until BOTH have answered, the shared
/// document shows only answered[uid]=true — never the choice. The addition
/// text lives only in the private doc (deleted once consumed).
export async function submitFeedback(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown): Promise<FeedbackResult> {
  const { coupleId: cid, members } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const [mSnap, pSnap] = await Promise.all([ref.get(), ref.collection('private').doc(uid).get()]);
  const m = mSnap.data();
  if (!m) throw err('not-found', 'not-found');
  if (m.status !== 'round') throw err('wrong-status');
  const round = m.round as number;
  if (m.rounds?.[round]?.answered?.[uid] === true) throw err('already-answered');
  const input = validateFeedback(pSnap.data());
  if (!input || (pSnap.data()?.round ?? round) !== round) throw err('feedback-invalid', 'invalid-argument');
  const s = await screen(c, ref, uid, `feedback${round}`, [input.addition]);
  if (s.flagged) return { flagged: true, categories: s.categories };
  const partnerUid = members.find((x) => x !== uid)!;

  const both = await c.db.runTransaction(async (tx) => {
    const cur = (await tx.get(ref)).data()!;
    if (cur.status !== 'round' || cur.round !== round) throw err('wrong-status');
    if (cur.rounds?.[round]?.answered?.[uid] === true) throw err('already-answered');
    const bothNow = cur.rounds?.[round]?.answered?.[partnerUid] === true;
    tx.update(ref.collection('private').doc(uid), { draft: false, submittedAt: FieldValue.serverTimestamp() });
    tx.update(ref, { [`rounds.${round}.answered.${uid}`]: true, updatedAt: FieldValue.serverTimestamp(), expiresAt: freshExpiry(c) });
    return bothNow;
  });
  if (!both) return { flagged: false, bothAnswered: false, outcome: 'waiting' };

  const outcome = await resolveRound(c, cid, ref.id);
  return { flagged: false, bothAnswered: true, outcome };
}

async function resolveRound(c: Ctx, coupleId: string, mediationId: string): Promise<'agreement' | 'revised' | 'unresolved' | 'generationFailed'> {
  const ref = mediationRef(c.db, coupleId, mediationId);
  const m = (await ref.get()).data()!;
  const round = m.round as number;
  const uids = [m.partnerUid as string, m.initiatorUid as string];
  const privs = await Promise.all(uids.map((u) => ref.collection('private').doc(u).get()));
  const fb: Record<string, { feedback: Feedback; addition: string }> = {};
  uids.forEach((u, i) => { const v = validateFeedback(privs[i].data()); if (v) fb[u] = v; });
  if (uids.some((u) => !fb[u])) throw err('feedback-missing');
  const choices = Object.fromEntries(uids.map((u) => [u, fb[u].feedback]));
  const langs = (m.rounds[round].langs ?? ['no']) as Lang[];
  const texts = m.rounds[round].texts as RoundByLang;
  const batch = c.db.batch();
  // Reveal the choices only now that both have answered.
  batch.update(ref, { [`rounds.${round}.feedback`]: choices });

  if (uids.every((u) => fb[u].feedback === 'happy')) {
    const proposal: ByLang = Object.fromEntries(langs.map((l) => [l, texts[l]!.proposal]));
    const agreement = agreementFromProposal(proposal, uids);
    const hash = agreementHash(coupleId, mediationId, 1, agreement);
    batch.update(ref, {
      status: 'agreement' as Status, updatedAt: FieldValue.serverTimestamp(), expiresAt: freshExpiry(c),
      agreement: { revision: 1, texts: agreement, hash, editedBy: null, editedAt: null, accepts: {}, activatedAt: null },
    });
    privs.forEach((p) => batch.delete(p.ref));
    await batch.commit();
    return 'agreement';
  }
  if (round >= MAX_ROUNDS) {
    batch.update(ref, { status: 'unresolved' as Status, closingNote: UNRESOLVED_NOTE, updatedAt: FieldValue.serverTimestamp(), ...CLEAR_TRIGGERS });
    privs.forEach((p) => batch.delete(p.ref));
    await batch.commit();
    await purgePrivateData(ref);
    return 'unresolved';
  }
  await batch.commit();
  const [partner, init] = await Promise.all([loadUser(c.db, uids[0]), loadUser(c.db, uids[1])]);
  const prompt = buildRevisionPrompt({ round: round + 1, langs, partnerFirst: partner, initiator: init, previous: texts, feedback: fb });
  const additions = uids.map((u) => fb[u].addition).filter(Boolean);
  const out = (await generateJson(c, prompt, (r) => parseRevisionOutput(r, langs, additions))) as Partial<Record<Lang, { proposal: string; whatChanged: string }>> | null;
  if (!out) {
    await ref.update({ status: 'generationFailed' as Status, failedStage: `revision${round + 1}`, updatedAt: FieldValue.serverTimestamp() });
    return 'generationFailed';
  }
  const nextTexts: RoundByLang = {};
  for (const l of langs) nextTexts[l] = { ...texts[l]!, proposal: out[l]!.proposal };
  const b2 = c.db.batch();
  b2.update(ref, {
    status: 'round' as Status, round: round + 1, failedStage: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp(), expiresAt: freshExpiry(c),
    [`rounds.${round + 1}`]: { texts: nextTexts, whatChanged: Object.fromEntries(langs.map((l) => [l, out[l]!.whatChanged])), answered: {}, feedback: {}, generatedAt: FieldValue.serverTimestamp(), langs },
  });
  privs.forEach((p) => b2.delete(p.ref));   // additions consumed
  await b2.commit();
  return 'revised';
}

/// Retries whichever generation failed (invitation, round 1, revision).
export async function retryGeneration(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown) {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const m = (await ref.get()).data();
  if (!m) throw err('not-found', 'not-found');
  if (m.status !== 'generationFailed') throw err('wrong-status');
  const stage = m.failedStage as string;
  if (stage === 'invitation') return { generated: await generateInvitation(c, cid, ref.id, (m.invitation?.rephrases ?? 0) as number) };
  if (stage === 'round1') return { generated: await generateRound1(c, cid, ref.id) };
  if (stage?.startsWith('revision')) {
    await ref.update({ status: 'round' as Status });
    return { generated: (await resolveRound(c, cid, ref.id)) !== 'generationFailed' };
  }
  throw err('unknown-stage');
}

// ── Nudge ───────────────────────────────────────────────────────────────────

export async function nudgePartner(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown) {
  const { coupleId: cid, members } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const partnerUid = members.find((x) => x !== uid)!;
  const now = nowOf(c);
  return c.db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    if (!d) throw err('not-found', 'not-found');
    const waitingOnPartner =
      ((d.status === 'invited' || d.status === 'answering') && d.initiatorUid === uid) ||
      (d.status === 'round' && d.rounds?.[d.round]?.answered?.[uid] === true && d.rounds?.[d.round]?.answered?.[partnerUid] !== true) ||
      (d.status === 'agreement' && d.agreement?.accepts?.[uid] && !d.agreement?.accepts?.[partnerUid]);
    if (!waitingOnPartner) throw err('wrong-status');
    const last = d.nudges?.[uid]?.toDate?.() ?? null;
    if (!canNudge(last, now)) throw err('too-soon', 'resource-exhausted');
    tx.update(ref, { [`nudges.${uid}`]: FieldValue.serverTimestamp() });
    return { partnerUid };
  });
}

// ── Agreement: edit / accept (unchanged mechanics; status 'agreement') ──────

export async function editAgreement(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown, shared: unknown, mine: unknown) {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const user = await loadUser(c.db, uid);
  return c.db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    if (!d) throw err('not-found', 'not-found');
    if (d.status !== 'agreement') throw err('wrong-status');
    const cur = d.agreement?.texts as AgreementByLang | undefined;
    if (!cur) throw err('no-agreement');
    const next = applyAgreementEdit(cur, uid, user.lang, String(shared ?? ''), String(mine ?? ''));
    if (!next) throw err('invalid-text', 'invalid-argument');
    const revision = (d.agreement.revision as number) + 1;
    const hash = agreementHash(cid, ref.id, revision, next);
    tx.update(ref, {
      'agreement.texts': next, 'agreement.revision': revision, 'agreement.hash': hash,
      'agreement.editedBy': uid, 'agreement.editedAt': FieldValue.serverTimestamp(), 'agreement.accepts': {},
      updatedAt: FieldValue.serverTimestamp(), expiresAt: freshExpiry(c),
    });
    return { revision, hash };
  });
}

export async function acceptAgreement(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown, hash: unknown) {
  const { coupleId: cid, members } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  if (typeof hash !== 'string' || !/^[0-9a-f]{64}$/.test(hash)) throw err('invalid-hash', 'invalid-argument');
  return c.db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    if (!d) throw err('not-found', 'not-found');
    if (d.status !== 'agreement') throw err('wrong-status');
    const a = d.agreement;
    if (!a) throw err('no-agreement');
    const expected = agreementHash(cid, ref.id, a.revision as number, a.texts as AgreementByLang);
    if (expected !== a.hash || hash !== expected) throw err('hash-mismatch');
    const accepts: Record<string, Accept | undefined> = { ...(a.accepts ?? {}), [uid]: { hash, at: 'pending' } };
    const done = bothAccepted(accepts, members, expected);
    tx.update(ref, {
      [`agreement.accepts.${uid}`]: { hash, at: FieldValue.serverTimestamp() },
      ...(done ? { status: 'active' as Status, 'agreement.activatedAt': FieldValue.serverTimestamp(), ...CLEAR_TRIGGERS } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { active: done };
  });
}

// ── Private-data purge ──────────────────────────────────────────────────────

/// Deletes every private/{uid} draft, the server-only initiator copy and
/// every safety/{uid} marker of a talk. Idempotent.
export async function purgePrivateData(ref: firestore.DocumentReference): Promise<number> {
  const [priv, srv, safety] = await Promise.all([ref.collection('private').get(), ref.collection('server').get(), ref.collection('safety').get()]);
  const docs = [...priv.docs, ...srv.docs, ...safety.docs];
  if (docs.length === 0) return 0;
  const batch = ref.firestore.batch();
  docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return docs.length;
}

// ── Pause / close (neutral) ─────────────────────────────────────────────────

export async function setNeutralState(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown, state: 'paused' | 'closed') {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const result = await c.db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    if (!d) throw err('not-found', 'not-found');
    if (!OPEN_STATUSES.includes(d.status) && !(state === 'closed' && d.status === 'paused')) throw err('wrong-status');
    tx.update(ref, { status: state as Status, updatedAt: FieldValue.serverTimestamp(), ...CLEAR_TRIGGERS });
    return { status: state };
  });
  if (state === 'closed') await purgePrivateData(ref);
  return result;
}

// ── Scheduler work (paged; trigger fields deleted so nothing matches twice) ─

const SCHEDULER_PAGE = 200;
const SCHEDULER_MAX_PAGES = 25;

export async function dueReminders(db: Db, now: Date): Promise<Array<{ coupleId: string; mediationId: string; uid: string }>> {
  const out: Array<{ coupleId: string; mediationId: string; uid: string }> = [];
  for (let page = 0; page < SCHEDULER_MAX_PAGES; page++) {
    const snap = await db.collectionGroup('mediations').where('reminderAt', '<=', firestore.Timestamp.fromDate(now)).limit(SCHEDULER_PAGE).get();
    if (snap.empty) break;
    const batch = db.batch();
    for (const d of snap.docs) {
      const m = d.data();
      batch.update(d.ref, { reminderAt: FieldValue.delete(), reminderSent: FieldValue.delete() });
      if (m.reminderSent !== true && ANSWERING_STATUSES.includes(m.status)) out.push({ coupleId: d.ref.parent.parent!.id, mediationId: d.id, uid: m.partnerUid });
    }
    await batch.commit();
    if (snap.size < SCHEDULER_PAGE) break;
  }
  return out;
}

export async function expireStale(db: Db, now: Date): Promise<number> {
  let n = 0;
  for (let page = 0; page < SCHEDULER_MAX_PAGES; page++) {
    const snap = await db.collectionGroup('mediations').where('expiresAt', '<=', firestore.Timestamp.fromDate(now)).limit(SCHEDULER_PAGE).get();
    if (snap.empty) break;
    const batch = db.batch();
    const toPurge: firestore.DocumentReference[] = [];
    for (const d of snap.docs) {
      const m = d.data();
      if (EXPIRABLE_STATUSES.includes(m.status)) {
        batch.update(d.ref, { status: 'expired' as Status, updatedAt: FieldValue.serverTimestamp(), ...CLEAR_TRIGGERS });
        toPurge.push(d.ref); n++;
      } else {
        batch.update(d.ref, { expiresAt: FieldValue.delete() });
      }
    }
    await batch.commit();
    for (const ref of toPurge) await purgePrivateData(ref);
    if (snap.size < SCHEDULER_PAGE) break;
  }
  return n;
}

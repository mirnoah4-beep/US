// "Oss mot problemet" — Firestore operations. Every op validates the caller
// (membership + role) server-side and is the ONLY writer of the mediation
// document; clients may write their own private draft only (rules).
//
// Layout (all under the couple, so the existing lifecycle deletion covers it):
//   couples/{c}/mediations/{m}                 members read; server writes
//   couples/{c}/mediations/{m}/private/{uid}   owner-only draft; server locks/deletes
//   couples/{c}/mediations/{m}/safety/{uid}    server-only marker, never content

import { firestore } from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  agreementHash, applyAgreementEdit, bothAccepted, buildGenerationPrompt, canNudge, combineSafety,
  expiryInstant, isCategory, isTiming, langOf, outputIsNeutral, parseGenerationOutput, parseSafetyOutput,
  phraseSafetyScan, reminderInstant, validateAnswers, ANSWERING_STATUSES, EXPIRABLE_STATUSES, OPEN_STATUSES,
  FACILITATOR_SYSTEM_PROMPT, SAFETY_SYSTEM_PROMPT, MAX_NEED_CHARS,
  type Accept, type AgreementByLang, type Answers, type Category, type GenerationOutput, type Lang, type Partner,
  type SafetyModelOutput, type Status, type SummaryByLang, type Timing,
} from './mediation';

type Db = firestore.Firestore;
const FieldValue = firestore.FieldValue;

/// The AI seam — the real implementation calls OpenAI; tests inject fakes.
export interface MediationAi {
  /// Returns parsed JSON (or throws) for the safety screen of ONE person's answers.
  safety(systemPrompt: string, texts: string[]): Promise<unknown>;
  /// Returns parsed JSON (or throws) for summary + agreement generation.
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

async function loadUser(db: Db, uid: string): Promise<{ name: string; lang: Lang; timeZone: unknown }> {
  const d = (await db.collection('users').doc(uid).get()).data() ?? {};
  const name = typeof d.displayName === 'string' && d.displayName.trim() ? d.displayName.trim() : (langOf(d.language) === 'no' ? 'Partneren din' : 'Your partner');
  return { name, lang: langOf(d.language), timeZone: d.timeZone };
}

// ── Create / respond ────────────────────────────────────────────────────────

export async function createMediation(c: Ctx, uid: string, coupleId: unknown, category: unknown) {
  const { coupleId: cid, members } = await requireMember(c.db, uid, coupleId);
  if (!isCategory(category)) throw err('invalid-category', 'invalid-argument');
  const partnerUid = members.find((m) => m !== uid);
  if (!partnerUid) throw err('no-partner');
  const col = c.db.collection('couples').doc(cid).collection('mediations');
  const open = await col.where('status', 'in', [...OPEN_STATUSES]).limit(1).get();
  if (!open.empty) throw err('already-open');
  const now = nowOf(c);
  const ref = col.doc();
  await ref.set({
    category, starterUid: uid, partnerUid, status: 'invited' as Status,
    createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    expiresAt: firestore.Timestamp.fromDate(expiryInstant(now)),
    timing: null, reminderAt: null, reminderSent: false,
    submitted: {}, nudges: {},
  });
  return { mediationId: ref.id, partnerUid };
}

export async function respondToInvite(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown, timing: unknown) {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  if (!isTiming(timing)) throw err('invalid-timing', 'invalid-argument');
  const ref = mediationRef(c.db, cid, mediationId);
  const user = await loadUser(c.db, uid);
  const now = nowOf(c);
  const remindAt = reminderInstant(timing as Timing, now, user.timeZone);
  return c.db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw err('not-found', 'not-found');
    const d = snap.data()!;
    if (d.partnerUid !== uid) throw err('not-invitee', 'permission-denied');
    if (d.status !== 'invited') throw err('wrong-status');
    tx.update(ref, {
      status: 'answering' as Status, timing, updatedAt: FieldValue.serverTimestamp(),
      reminderAt: remindAt ? firestore.Timestamp.fromDate(remindAt) : null, reminderSent: remindAt ? false : true,
    });
    return { starterUid: d.starterUid as string, timing: timing as Timing, reminderAt: remindAt };
  });
}

// ── Submit (with per-submission safety screen) ──────────────────────────────

export type SubmitResult =
  | { flagged: true; categories: string[] }
  | { flagged: false; bothSubmitted: boolean; partnerUid: string; summaryReady: boolean };

export async function submitAnswers(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown): Promise<SubmitResult> {
  const { coupleId: cid, members } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const privRef = ref.collection('private').doc(uid);
  const [mSnap, pSnap] = await Promise.all([ref.get(), privRef.get()]);
  if (!mSnap.exists) throw err('not-found', 'not-found');
  const m = mSnap.data()!;
  if (!ANSWERING_STATUSES.includes(m.status)) throw err('wrong-status');
  if (m.submitted?.[uid] === true) throw err('already-submitted');
  const v = validateAnswers(pSnap.data());
  if (!v.ok) throw err(`answers-${v.field}`, 'invalid-argument');
  const partnerUid = members.find((x) => x !== uid)!;

  // Safety screen on the CALLER'S OWN answers, every submission. A flag is
  // returned to this caller only; nothing about it is written where the
  // partner could see it, and the talk keeps looking "not answered yet".
  const texts = [v.answers.whatHappened, v.answers.whatINeed, v.answers.whatICanDo];
  let model: SafetyModelOutput | null = null;
  try { model = parseSafetyOutput(await c.ai.safety(SAFETY_SYSTEM_PROMPT, texts)); } catch { model = null; }
  const assessment = combineSafety(phraseSafetyScan(texts), model);
  if (assessment.flagged) {
    await ref.collection('safety').doc(uid).set({
      flaggedAt: FieldValue.serverTimestamp(), categories: assessment.categories, source: assessment.source,
    }, { merge: true });
    return { flagged: true, categories: assessment.categories };
  }

  const bothSubmitted = await c.db.runTransaction(async (tx) => {
    const cur = (await tx.get(ref)).data()!;
    if (!ANSWERING_STATUSES.includes(cur.status)) throw err('wrong-status');
    if (cur.submitted?.[uid] === true) throw err('already-submitted');
    const both = cur.submitted?.[partnerUid] === true;
    tx.update(privRef, { draft: false, submittedAt: FieldValue.serverTimestamp() });
    tx.update(ref, { [`submitted.${uid}`]: true, status: 'waiting' as Status, updatedAt: FieldValue.serverTimestamp() });
    return both;
  });
  let summaryReady = false;
  if (bothSubmitted) summaryReady = await generateSummary(c, cid, ref.id);
  return { flagged: false, bothSubmitted, partnerUid, summaryReady };
}

// ── Summary generation (server-triggered) ───────────────────────────────────

/// Runs the facilitator model for a talk where BOTH have submitted. On
/// success writes summary + agreement (revision 1), deletes both private
/// answer documents (data minimisation) and sets status 'summary'. On two
/// invalid outputs sets 'summaryFailed' (retryable). Returns success.
export async function generateSummary(c: Ctx, coupleId: string, mediationId: string): Promise<boolean> {
  const ref = mediationRef(c.db, coupleId, mediationId);
  const m = (await ref.get()).data();
  if (!m) return false;
  const uids = [m.starterUid as string, m.partnerUid as string];
  if (!uids.every((u) => m.submitted?.[u] === true)) throw err('not-both-submitted');
  const [privA, privB, userA, userB] = await Promise.all([
    ref.collection('private').doc(uids[0]).get(), ref.collection('private').doc(uids[1]).get(),
    loadUser(c.db, uids[0]), loadUser(c.db, uids[1]),
  ]);
  const vA = validateAnswers(privA.data()); const vB = validateAnswers(privB.data());
  if (!vA.ok || !vB.ok) throw err('answers-missing');
  const answers: Record<string, Answers> = { [uids[0]]: vA.answers, [uids[1]]: vB.answers };
  const langs: Lang[] = [...new Set([userA.lang, userB.lang])];
  const starter: Partner = { uid: uids[0], name: userA.name, lang: userA.lang };
  const partner: Partner = { uid: uids[1], name: userB.name, lang: userB.lang };
  const prompt = buildGenerationPrompt({ category: m.category as Category, starter, partner, answers, langs });

  let out: GenerationOutput | null = null;
  for (let attempt = 0; attempt < 2 && !out; attempt++) {
    try {
      const parsed = parseGenerationOutput(await c.ai.generate(FACILITATOR_SYSTEM_PROMPT, prompt), langs, uids);
      if (parsed && outputIsNeutral(parsed)) out = parsed;
    } catch { out = null; }
  }
  if (!out) {
    await ref.update({ status: 'summaryFailed' as Status, updatedAt: FieldValue.serverTimestamp() });
    return false;
  }
  const revision = 1;
  const hash = agreementHash(coupleId, mediationId, revision, out.agreement);
  const batch = c.db.batch();
  batch.update(ref, {
    status: 'summary' as Status, updatedAt: FieldValue.serverTimestamp(),
    summary: { texts: out.summary, needsConfirmed: {}, generatedAt: FieldValue.serverTimestamp(), langs },
    agreement: { revision, texts: out.agreement, hash, editedBy: null, editedAt: null, accepts: {}, activatedAt: null },
  });
  // The raw answers have served their purpose — remove them.
  batch.delete(ref.collection('private').doc(uids[0]));
  batch.delete(ref.collection('private').doc(uids[1]));
  await batch.commit();
  return true;
}

export async function retrySummary(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown) {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const m = (await ref.get()).data();
  if (!m) throw err('not-found', 'not-found');
  if (m.status !== 'summaryFailed') throw err('wrong-status');
  return { summaryReady: await generateSummary(c, cid, ref.id) };
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
    if (d.status !== 'waiting' || d.submitted?.[uid] !== true || d.submitted?.[partnerUid] === true) throw err('wrong-status');
    const last = d.nudges?.[uid]?.toDate?.() ?? null;
    if (!canNudge(last, now)) throw err('too-soon', 'resource-exhausted');
    tx.update(ref, { [`nudges.${uid}`]: FieldValue.serverTimestamp() });
    return { partnerUid };
  });
}

// ── Needs: confirm / correct own line only ──────────────────────────────────

export async function confirmOrCorrectNeed(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown, correction: unknown) {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const text = correction === undefined || correction === null ? null : String(correction).replace(/\s+/g, ' ').trim();
  if (text !== null && (text.length === 0 || text.length > MAX_NEED_CHARS)) throw err('invalid-text', 'invalid-argument');
  return c.db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    if (!d) throw err('not-found', 'not-found');
    if (d.status !== 'summary') throw err('wrong-status');
    const texts = d.summary?.texts as SummaryByLang | undefined;
    if (!texts) throw err('no-summary');
    const update: Record<string, unknown> = { [`summary.needsConfirmed.${uid}`]: text === null ? 'confirmed' : 'corrected', updatedAt: FieldValue.serverTimestamp() };
    if (text !== null) {
      for (const lang of Object.keys(texts) as Lang[]) {
        if (!(uid in (texts[lang]?.needs ?? {}))) throw err('not-your-line', 'permission-denied');
        update[`summary.texts.${lang}.needs.${uid}`] = text;   // only the caller's line
      }
    }
    tx.update(ref, update);
    return { corrected: text !== null };
  });
}

// ── Agreement: edit / accept ────────────────────────────────────────────────

export async function editAgreement(c: Ctx, uid: string, coupleId: unknown, mediationId: unknown, shared: unknown, mine: unknown) {
  const { coupleId: cid } = await requireMember(c.db, uid, coupleId);
  const ref = mediationRef(c.db, cid, mediationId);
  const user = await loadUser(c.db, uid);
  return c.db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    if (!d) throw err('not-found', 'not-found');
    if (d.status !== 'summary') throw err('wrong-status');          // 'active' is immutable
    const cur = d.agreement?.texts as AgreementByLang | undefined;
    if (!cur) throw err('no-agreement');
    const next = applyAgreementEdit(cur, uid, user.lang, String(shared ?? ''), String(mine ?? ''));
    if (!next) throw err('invalid-text', 'invalid-argument');
    const revision = (d.agreement.revision as number) + 1;
    const hash = agreementHash(cid, ref.id, revision, next);
    tx.update(ref, {
      'agreement.texts': next, 'agreement.revision': revision, 'agreement.hash': hash,
      'agreement.editedBy': uid, 'agreement.editedAt': FieldValue.serverTimestamp(),
      'agreement.accepts': {},                                        // every edit clears all acceptances
      updatedAt: FieldValue.serverTimestamp(),
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
    if (d.status !== 'summary') throw err('wrong-status');          // active → immutable, no re-accept
    const a = d.agreement;
    if (!a) throw err('no-agreement');
    // The server recomputes the hash from stored content — never trusts the client's.
    const expected = agreementHash(cid, ref.id, a.revision as number, a.texts as AgreementByLang);
    if (expected !== a.hash || hash !== expected) throw err('hash-mismatch');
    const accepts: Record<string, Accept | undefined> = { ...(a.accepts ?? {}), [uid]: { hash, at: 'pending' } };
    const done = bothAccepted(accepts, members, expected);
    tx.update(ref, {
      [`agreement.accepts.${uid}`]: { hash, at: FieldValue.serverTimestamp() },
      ...(done ? { status: 'active' as Status, 'agreement.activatedAt': FieldValue.serverTimestamp() } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { active: done };
  });
}

// ── Private-data purge ──────────────────────────────────────────────────────

/// Deletes every private/{uid} draft and safety/{uid} marker of a talk.
/// Run when a talk ends without a summary (close, expiry) — the summary
/// path deletes the private docs itself. Idempotent.
export async function purgePrivateData(ref: firestore.DocumentReference): Promise<number> {
  const [priv, safety] = await Promise.all([ref.collection('private').get(), ref.collection('safety').get()]);
  const docs = [...priv.docs, ...safety.docs];
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
    // No "by whom", no reason — the partner only ever sees the neutral state.
    tx.update(ref, { status: state as Status, updatedAt: FieldValue.serverTimestamp(), reminderAt: null, reminderSent: true });
    return { status: state };
  });
  // Closing ends the talk for good: nothing private stays behind.
  if (state === 'closed') await purgePrivateData(ref);
  return result;
}

// ── Scheduler work ──────────────────────────────────────────────────────────

/// Reminders whose time has come (partner chose "tonight"/"tomorrow").
export async function dueReminders(db: Db, now: Date): Promise<Array<{ coupleId: string; mediationId: string; uid: string }>> {
  const snap = await db.collectionGroup('mediations').where('reminderAt', '<=', firestore.Timestamp.fromDate(now)).limit(200).get();
  const out: Array<{ coupleId: string; mediationId: string; uid: string }> = [];
  for (const d of snap.docs) {
    const m = d.data();
    if (m.reminderSent === true || !ANSWERING_STATUSES.includes(m.status) || m.submitted?.[m.partnerUid] === true) {
      await d.ref.update({ reminderAt: null, reminderSent: true });
      continue;
    }
    await d.ref.update({ reminderAt: null, reminderSent: true });
    out.push({ coupleId: d.ref.parent.parent!.id, mediationId: d.id, uid: m.partnerUid });
  }
  return out;
}

/// Talks without two submissions after EXPIRY_DAYS → 'expired' (neutral).
/// A flagged (invisible) submission counts as not submitted, so the talk
/// simply expires like any other unanswered one.
export async function expireStale(db: Db, now: Date): Promise<number> {
  const snap = await db.collectionGroup('mediations').where('expiresAt', '<=', firestore.Timestamp.fromDate(now)).limit(200).get();
  let n = 0;
  for (const d of snap.docs) {
    const m = d.data();
    if (EXPIRABLE_STATUSES.includes(m.status)) {
      await d.ref.update({ status: 'expired' as Status, expiresAt: null, reminderAt: null, reminderSent: true, updatedAt: FieldValue.serverTimestamp() });
      await purgePrivateData(d.ref);
      n++;
    } else {
      await d.ref.update({ expiresAt: null });
    }
  }
  return n;
}

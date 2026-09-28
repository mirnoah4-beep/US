// "Oss mot problemet" / "Us vs. the problem" — pure logic (no firebase-admin).
//
// A 5-minute structured talk: both partners answer three questions
// privately, the server produces a neutral summary + a short draft
// agreement, and both accept the same revision with a "handshake".
// Everything here is deterministic and unit-tested; I/O lives in
// mediationOps.ts, the callables in index.ts.

import { createHash } from 'crypto';

// ── Vocabulary ──────────────────────────────────────────────────────────────

export const CATEGORIES = ['communication', 'time', 'money', 'kids', 'chores', 'trust', 'intimacy', 'other'] as const;
export type Category = typeof CATEGORIES[number];
export const isCategory = (v: unknown): v is Category => typeof v === 'string' && (CATEGORIES as readonly string[]).includes(v);

export const TIMINGS = ['now', 'tonight', 'tomorrow'] as const;
export type Timing = typeof TIMINGS[number];
export const isTiming = (v: unknown): v is Timing => typeof v === 'string' && (TIMINGS as readonly string[]).includes(v);

/// drafting        — initiator writes topic + wish (private)
/// invitationDraft — neutral invitation generated; initiator approves/rephrases
/// invited         — partner has not answered the invitation
/// answering       — partner writes view + need (private)
/// round           — round N summary + proposal exist; both give feedback
/// generationFailed— AI produced no valid output twice; retry allowed
/// agreement       — both were happy; draft agreement may be edited/accepted
/// active          — both accepted the same revision; content frozen
/// paused / closed / unresolved — neutral end states (no reason stored)
/// expired         — no progress within EXPIRY_DAYS
export const STATUSES = ['drafting', 'invitationDraft', 'invited', 'answering', 'round', 'generationFailed', 'agreement', 'active', 'paused', 'closed', 'unresolved', 'expired'] as const;
export type Status = typeof STATUSES[number];

export const OPEN_STATUSES: readonly Status[] = ['drafting', 'invitationDraft', 'invited', 'answering', 'round', 'generationFailed', 'agreement'];
/// States that wait on a person and therefore expire after EXPIRY_DAYS of no progress.
export const EXPIRABLE_STATUSES: readonly Status[] = ['drafting', 'invitationDraft', 'invited', 'answering', 'round', 'generationFailed', 'agreement'];
/// States in which the partner may still be reminded to answer.
export const ANSWERING_STATUSES: readonly Status[] = ['answering'];

export const MAX_REPHRASES = 3;
export const MAX_ROUNDS = 3;
export const MAX_TOPIC_CHARS = 1000;
export const MAX_ADDITION_CHARS = 300;

export const EXPIRY_DAYS = 7;
export const NUDGE_MIN_GAP_MS = 60 * 60 * 1000;
export const MAX_ANSWER_CHARS = 2000;
export const MAX_NEED_CHARS = 300;
export const MAX_AGREEMENT_CHARS = 280;
export const REMINDER_HOUR = 19;          // local time for "tonight"/"tomorrow"
export const LATE_EVENING_MINUTES = 19 * 60 + 30;   // ≥ 19:30 → "tonight" = in 15 minutes
export const LATE_TONIGHT_DELAY_MS = 15 * 60 * 1000;

export type Lang = 'no' | 'en';
export const langOf = (raw: unknown): Lang => (raw === 'en' ? 'en' : 'no');

// ── Private inputs (three kinds, one private doc per user at a time) ────────

export type PrivateKind = 'topic' | 'answer' | 'feedback';
export type Feedback = 'happy' | 'almost';

export interface TopicInput { topic: string; wish: string }
export interface AnswerInput { view: string; need: string }
export interface FeedbackInput { feedback: Feedback; addition: string }

function str(raw: Record<string, unknown>, k: string, max: number, required = true): string | null {
  const v = raw[k];
  if (v === undefined || v === null) return required ? null : '';
  if (typeof v !== 'string' || v.length > max) return null;
  const t = v.replace(/\s+/g, ' ').trim();
  return required && t.length === 0 ? null : t;
}

export function validateTopic(raw: Record<string, unknown> | undefined | null): TopicInput | null {
  if (!raw || raw.kind !== 'topic') return null;
  const topic = str(raw, 'topic', MAX_TOPIC_CHARS); const wish = str(raw, 'wish', MAX_TOPIC_CHARS);
  return topic && wish ? { topic, wish } : null;
}
export function validateAnswer(raw: Record<string, unknown> | undefined | null): AnswerInput | null {
  if (!raw || raw.kind !== 'answer') return null;
  const view = str(raw, 'view', MAX_TOPIC_CHARS); const need = str(raw, 'need', MAX_TOPIC_CHARS);
  return view && need ? { view, need } : null;
}
export function validateFeedback(raw: Record<string, unknown> | undefined | null): FeedbackInput | null {
  if (!raw || raw.kind !== 'feedback') return null;
  if (raw.feedback !== 'happy' && raw.feedback !== 'almost') return null;
  const addition = str(raw, 'addition', MAX_ADDITION_CHARS, false);
  if (addition === null) return null;
  return { feedback: raw.feedback, addition };
}

// ── Timing / reminders ──────────────────────────────────────────────────────

function isValidTimeZone(tz: unknown): tz is string {
  if (typeof tz !== 'string' || !tz) return false;
  try { new Intl.DateTimeFormat('en-GB', { timeZone: tz }); return true; } catch { return false; }
}

function localParts(at: Date, tz: string) {
  const f = new Intl.DateTimeFormat('en-GB', { timeZone: tz, hour12: false, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
  const p = Object.fromEntries(f.formatToParts(at).map((x) => [x.type, x.value])) as Record<string, string>;
  return { y: Number(p.year), m: Number(p.month), d: Number(p.day), hour: Number(p.hour) % 24, minute: Number(p.minute) };
}

/// UTC instant of `y-m-d hour:00` in [tz]: treat the wall time as UTC, then
/// correct by the zone offset observed at that instant (twice, for DST edges).
export function localToUtc(y: number, m: number, d: number, hour: number, tz: string): Date {
  const wanted = Date.UTC(y, m - 1, d, hour, 0, 0);
  let guess = wanted;
  for (let i = 0; i < 2; i++) {
    const lp = localParts(new Date(guess), tz);
    const wall = Date.UTC(lp.y, lp.m - 1, lp.d, lp.hour, lp.minute);
    const offset = wall - guess;
    guess = wanted - offset;
  }
  return new Date(guess);
}

/// When to remind the responder, in the responder's local time:
///   tonight  → today 19:00, or in 15 minutes when it is already 19:30 or
///              later (and, for the gap 19:00–19:29, also 15 minutes —
///              19:00 has passed);
///   tomorrow → tomorrow 19:00;
///   now      → null (no reminder).
export function reminderInstant(timing: Timing, now: Date, timeZone: unknown): Date | null {
  if (timing === 'now') return null;
  const tz = isValidTimeZone(timeZone) ? timeZone : 'Europe/Oslo';
  const lp = localParts(now, tz);
  if (timing === 'tonight') {
    const minutes = lp.hour * 60 + lp.minute;
    if (minutes >= REMINDER_HOUR * 60) return new Date(now.getTime() + LATE_TONIGHT_DELAY_MS);
    return localToUtc(lp.y, lp.m, lp.d, REMINDER_HOUR, tz);
  }
  const tomorrow = new Date(Date.UTC(lp.y, lp.m - 1, lp.d + 1));
  return localToUtc(tomorrow.getUTCFullYear(), tomorrow.getUTCMonth() + 1, tomorrow.getUTCDate(), REMINDER_HOUR, tz);
}

export function expiryInstant(createdAt: Date): Date {
  return new Date(createdAt.getTime() + EXPIRY_DAYS * 24 * 60 * 60 * 1000);
}

// ── Agreement hash ──────────────────────────────────────────────────────────

export interface AgreementTexts { shared: string; perPartner: Record<string, string> }
export type AgreementByLang = Partial<Record<Lang, AgreementTexts>>;

function canonical(value: unknown): unknown {
  if (typeof value === 'string') return value.normalize('NFC');
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value as object).sort().map((k) => [k, canonical((value as Record<string, unknown>)[k])]));
  }
  return value;
}

/// sha256 of the canonical JSON of {coupleId, mediationId, revision, texts}
/// — keys sorted at every level (so perPartner is sorted by uid), strings
/// NFC-normalised. An accept is bound to exactly this content.
export function agreementHash(coupleId: string, mediationId: string, revision: number, texts: AgreementByLang): string {
  const json = JSON.stringify(canonical({ coupleId, mediationId, revision, texts }));
  return createHash('sha256').update(json).digest('hex');
}

// ── Safety ──────────────────────────────────────────────────────────────────

export interface SafetyAssessment { flagged: boolean; categories: string[]; source: 'phrases' | 'model' | 'none' }

/// Small high-confidence phrase list (NO/EN): clear violence, threats,
/// coercive control, sexual coercion, fear for safety, immediate danger.
/// Deliberately conservative — everyday conflict words ("sint", "krangel",
/// "angry") are NOT here. Matching alone flags only the explicit set.
const DANGER_PHRASES: Array<[RegExp, string]> = [
  [/\b(slår|slo|sparker|sparket|kvelte|kveler|dytter|dyttet) (meg|henne|ham|barna|barnet)\b/i, 'violence'],
  [/\b(hits?|hit|punche[sd]?|kick(s|ed)?|choke[sd]?|strangle[sd]?|shove[sd]?) (me|her|him|the kids|the children)\b/i, 'violence'],
  [/\b(truer|truet) (meg|med å)\b/i, 'threats'],
  [/\bthreaten(s|ed)? (me|to (hurt|kill))\b/i, 'threats'],
  [/\b(redd for (livet|å bli slått|hva (han|hun) gjør))\b/i, 'fear'],
  [/\b(afraid|scared) (for my life|he'?ll hurt me|she'?ll hurt me|of what (he|she) (will|might) do)\b/i, 'fear'],
  [/\b(tvinger|tvang|presser) meg til (sex|å ha sex)\b/i, 'sexual_coercion'],
  [/\b(forces?|forced|pressures?) me (to have sex|into sex)\b/i, 'sexual_coercion'],
  [/\b(får ikke lov til å (gå ut|treffe|ha egne penger)|kontrollerer (alt jeg|pengene mine|telefonen min))\b/i, 'coercive_control'],
  [/\b(not allowed to (leave|see my friends|have my own money)|controls (all my|my money|my phone))\b/i, 'coercive_control'],
  [/\b(jeg (er|føler meg) ikke trygg|i (am|don'?t feel) safe at home|ring(e)? politiet|call(ed)? the police|nødsituasjon|i'?m in danger)\b/i, 'danger'],
];

export function phraseSafetyScan(texts: string[]): string[] {
  const hits = new Set<string>();
  for (const t of texts) for (const [re, cat] of DANGER_PHRASES) if (re.test(t)) hits.add(cat);
  return [...hits].sort();
}

/// The strict JSON the safety model must return.
export interface SafetyModelOutput { flagged: boolean; categories: string[] }
export function parseSafetyOutput(raw: unknown): SafetyModelOutput | null {
  if (!raw || typeof raw !== 'object') return null;
  const o = raw as Record<string, unknown>;
  if (typeof o.flagged !== 'boolean') return null;
  const cats = Array.isArray(o.categories) ? o.categories.filter((c): c is string => typeof c === 'string').slice(0, 6) : [];
  return { flagged: o.flagged, categories: cats };
}

/// Combines the phrase scan with the model verdict:
///   * explicit phrase hit → flagged (source 'phrases');
///   * otherwise flagged only when the model says so (source 'model');
///   * a null/invalid model output never flags on its own.
export function combineSafety(phraseHits: string[], model: SafetyModelOutput | null): SafetyAssessment {
  if (phraseHits.length > 0) return { flagged: true, categories: phraseHits, source: 'phrases' };
  if (model?.flagged) return { flagged: true, categories: model.categories, source: 'model' };
  return { flagged: false, categories: [], source: 'none' };
}

export const SAFETY_SYSTEM_PROMPT =
  'You screen one person\'s private answers from a couples app for SAFETY ONLY. ' +
  'Answer strictly as JSON {"flagged": boolean, "categories": string[]}. ' +
  'Set flagged=true ONLY for clear signs of: physical violence, threats, coercive control, sexual coercion, ' +
  'fear for one\'s safety, or immediate danger. Ordinary conflict, anger, sadness, criticism, arguing, ' +
  'money or chores disagreements are NOT flags. When unsure, flagged=false. Categories from: ' +
  'violence, threats, coercive_control, sexual_coercion, fear, danger.';

// ── Generation: invitation, round 1, revision ───────────────────────────────

export interface Partner { uid: string; name: string; lang: Lang }

const CATEGORY_LABEL: Record<Lang, Record<Category, string>> = {
  no: { communication: 'kommunikasjon', time: 'tid sammen', money: 'økonomi', kids: 'barn og familie', chores: 'husarbeid', trust: 'tillit', intimacy: 'nærhet', other: 'noe annet' },
  en: { communication: 'communication', time: 'time together', money: 'money', kids: 'kids and family', chores: 'chores', trust: 'trust', intimacy: 'intimacy', other: 'something else' },
};
export const categoryLabel = (c: Category, lang: Lang): string => CATEGORY_LABEL[lang][c];

export const FACILITATOR_SYSTEM_PROMPT =
  'You are a warm, neutral facilitator for a couple using a small everyday app. ' +
  'You NEVER pick a winner, never say who is right or wrong, never diagnose, never use labels ' +
  '(toxic, narcissistic, manipulative, etc.), never invent motives, never shame, and never push reconciliation. ' +
  'You write in plain, kind, short everyday language (no therapy or legal tone). ' +
  'Return ONLY strict JSON matching the requested schema, nothing else.';

const langNames = (langs: Lang[]) => langs.map((l) => (l === 'no' ? 'Norwegian (bokmål)' : 'English')).join(' AND ');

// ── Verbatim guard (word level) ─────────────────────────────────────────────

const normWords = (t: string): string[] =>
  t.toLowerCase().normalize('NFC').replace(/[^\p{L}\p{N}\s]/gu, ' ').split(/\s+/).filter(Boolean);

/// True when [output] repeats 5+ consecutive words of any [raw] text
/// (case-insensitive, punctuation stripped). Single topic words like
/// "telefonen" or "husarbeid" are fine; copied sentences are not.
export function repeatsVerbatim(output: string, raws: string[], run = 5): boolean {
  const out = normWords(output);
  if (out.length < run) return false;
  const grams = new Set<string>();
  for (let i = 0; i + run <= out.length; i++) grams.add(out.slice(i, i + run).join(' '));
  for (const r of raws) {
    const w = normWords(r);
    for (let i = 0; i + run <= w.length; i++) if (grams.has(w.slice(i, i + run).join(' '))) return true;
  }
  return false;
}

/// Words that judge, absolutise or label — not allowed in any generated text.
const FORBIDDEN_OUTPUT = /\b(narsissist|narcissist|toxic|toksisk|manipulat\w*|gaslight\w*|has? the right|har rett|tar feil|is wrong|skyld(en|ig)?|to blame|blame|alltid|aldri|always|never)\b/i;
export const textIsNeutral = (t: string): boolean => !FORBIDDEN_OUTPUT.test(t);

// ── Invitation ──────────────────────────────────────────────────────────────

export interface InvitationInput { category: Category; initiator: Partner; partner: Partner; topic: string; wish: string; langs: Lang[]; rephrase: number }
export type ByLang = Partial<Record<Lang, string>>;

export function buildInvitationPrompt(i: InvitationInput): string {
  return [
    `Topic: ${categoryLabel(i.category, 'en')}.`,
    `${i.initiator.name} wants to bring something up with their partner ${i.partner.name}.`,
    `What ${i.initiator.name} wrote privately (NEVER quote it): "${i.topic}" — and what they hope gets better: "${i.wish}".`,
    `Write a short, warm invitation addressed to ${i.partner.name} (second person), in ${langNames(i.langs)}, max 280 characters per language:`,
    'name the topic gently, express the hope as a shared wish, no blame, no quotes of harsh wording, no absolutes, no evaluation of the partner.',
    i.rephrase > 0 ? `This is rephrase #${i.rephrase}: use clearly different wording and structure than a typical first attempt.` : '',
    `Return JSON: {${i.langs.map((l) => `"${l}": string`).join(', ')}}`,
  ].filter(Boolean).join('\n');
}

export function parseInvitationOutput(raw: unknown, langs: Lang[], rawInputs: string[]): ByLang | null {
  if (!raw || typeof raw !== 'object') return null;
  const out: ByLang = {};
  for (const lang of langs) {
    const t = cleanLine((raw as Record<string, unknown>)[lang], MAX_AGREEMENT_CHARS);
    if (!t || !textIsNeutral(t) || repeatsVerbatim(t, rawInputs)) return null;
    out[lang] = t;
  }
  return out;
}

// ── Round 1: summary + proposal ─────────────────────────────────────────────

export interface RoundTexts { sameTeam: string; different: string; needs: Record<string, string>; proposal: string }
export type RoundByLang = Partial<Record<Lang, RoundTexts>>;

export interface Round1Input {
  category: Category; initiator: Partner; partner: Partner; invitation: string;
  topic: string; wish: string; view: string; need: string; langs: Lang[];
}

/// The partner (non-initiator) is named first.
export function buildRound1Prompt(i: Round1Input): string {
  const first = i.partner; const second = i.initiator;
  const per = i.langs.map((l) => `"${l}": {"sameTeam": string, "different": string, "needs": {"${first.uid}": string, "${second.uid}": string}, "proposal": string}`).join(', ');
  return [
    `Topic: ${categoryLabel(i.category, 'en')}. The invitation ${second.name} sent: "${i.invitation}"`,
    `Two partners: ${first.name} (id ${first.uid}) and ${second.name} (id ${second.uid}). Always mention ${first.name} before ${second.name}.`,
    `${first.name} — how they see it: ${i.view} | what they need: ${i.need}`,
    `${second.name} — what they wanted to bring up: ${i.topic} | what they hope gets better: ${i.wish}`,
    `Write in ${langNames(i.langs)}, each text max ${MAX_AGREEMENT_CHARS} characters, warm, everyday, second person plural for shared lines.`,
    '"sameTeam": where they want the same thing. "different": where they see it differently, without judging.',
    '"needs": one line per person starting with their name, in their own words. "proposal": ONE small concrete thing to try this week, phrased as a suggestion.',
    `Return JSON: {${per}}`,
  ].join('\n');
}

export function parseRoundOutput(raw: unknown, langs: Lang[], uids: string[]): RoundByLang | null {
  if (!raw || typeof raw !== 'object') return null;
  const out: RoundByLang = {};
  for (const lang of langs) {
    const b = (raw as Record<string, unknown>)[lang] as Record<string, unknown> | undefined;
    if (!b || typeof b !== 'object') return null;
    const sameTeam = cleanLine(b.sameTeam, MAX_AGREEMENT_CHARS); const different = cleanLine(b.different, MAX_AGREEMENT_CHARS);
    const proposal = cleanLine(b.proposal, MAX_AGREEMENT_CHARS); const needsRaw = b.needs as Record<string, unknown> | undefined;
    if (!sameTeam || !different || !proposal || !needsRaw) return null;
    const needs: Record<string, string> = {};
    for (const uid of uids) { const n = cleanLine(needsRaw[uid], MAX_NEED_CHARS); if (!n) return null; needs[uid] = n; }
    const all = [sameTeam, different, proposal, ...Object.values(needs)];
    if (!all.every(textIsNeutral)) return null;
    out[lang] = { sameTeam, different, needs, proposal };
  }
  return out;
}

// ── Rounds 2–3: revision from feedback ──────────────────────────────────────

export interface RevisionInput {
  round: number; langs: Lang[]; partnerFirst: Partner; initiator: Partner;
  previous: RoundByLang;
  feedback: Record<string, { feedback: Feedback; addition: string }>;   // uid → private feedback
}
export interface RevisionTexts { proposal: string; whatChanged: string }
export type RevisionByLang = Partial<Record<Lang, RevisionTexts>>;

export function buildRevisionPrompt(i: RevisionInput): string {
  const prevLang = (i.previous[i.langs[0]] ?? Object.values(i.previous)[0])!;
  const fb = [i.partnerFirst, i.initiator].map((p) => {
    const f = i.feedback[p.uid];
    if (!f) return `${p.name}: (no feedback)`;
    return f.feedback === 'happy' ? `${p.name}: happy with the proposal${f.addition ? ` — adds: ${f.addition}` : ''}` : `${p.name}: almost — wants a tweak${f.addition ? `: ${f.addition}` : ''}`;
  }).join('\n');
  const per = i.langs.map((l) => `"${l}": {"proposal": string, "whatChanged": string}`).join(', ');
  return [
    `Round ${i.round} of at most ${MAX_ROUNDS}. Previous proposal: "${prevLang.proposal}"`,
    `Where they agree: ${prevLang.sameTeam} | Where they differ: ${prevLang.different}`,
    'Feedback (private, do not quote harsh wording):', fb,
    `Revise the proposal in ${langNames(i.langs)} (max ${MAX_AGREEMENT_CHARS} characters each): keep what both were happy with, change only what the tweak asks for, still ONE small step, still a suggestion.`,
    '"whatChanged": one short sentence saying what was adjusted, without attributing it to a person.',
    `Return JSON: {${per}}`,
  ].join('\n');
}

export function parseRevisionOutput(raw: unknown, langs: Lang[], rawAdditions: string[]): RevisionByLang | null {
  if (!raw || typeof raw !== 'object') return null;
  const out: RevisionByLang = {};
  for (const lang of langs) {
    const b = (raw as Record<string, unknown>)[lang] as Record<string, unknown> | undefined;
    if (!b) return null;
    const proposal = cleanLine(b.proposal, MAX_AGREEMENT_CHARS); const whatChanged = cleanLine(b.whatChanged, MAX_AGREEMENT_CHARS);
    if (!proposal || !whatChanged || !textIsNeutral(proposal) || !textIsNeutral(whatChanged)) return null;
    if (repeatsVerbatim(proposal, rawAdditions) || repeatsVerbatim(whatChanged, rawAdditions)) return null;
    out[lang] = { proposal, whatChanged };
  }
  return out;
}

/// The draft agreement built from the accepted proposal — no AI call.
/// shared = the proposal; each partner starts with a neutral "tries it"
/// line they can refine with the existing edit sheet.
export function agreementFromProposal(proposal: ByLang, uids: string[]): AgreementByLang {
  const line: Record<Lang, string> = { no: 'Prøver forslaget denne uka.', en: 'Tries the suggestion this week.' };
  const out: AgreementByLang = {};
  for (const lang of Object.keys(proposal) as Lang[]) {
    out[lang] = { shared: proposal[lang]!, perPartner: Object.fromEntries(uids.map((u) => [u, line[lang]])) };
  }
  return out;
}

/// Neutral closing note after three rounds without agreement.
export const UNRESOLVED_NOTE: Record<Lang, string> = {
  no: 'Det er helt greit å ikke bli enige i dag. Kanskje det er lettere å ta praten videre ansikt til ansikt – uten skjerm.',
  en: "It's completely fine not to agree today. It may be easier to continue the conversation face to face – without a screen.",
};

function cleanLine(v: unknown, max: number): string | null {
  if (typeof v !== 'string') return null;
  const s = v.replace(/\s+/g, ' ').trim();
  if (s.length === 0) return null;
  return s.length > max ? `${s.slice(0, max - 1).trimEnd()}…` : s;
}

// ── Edits / accepts ─────────────────────────────────────────────────────────

/// Applies a partner's edit: the shared line and ONLY the editor's own line,
/// in the editor's language. The other language keeps its own lines for the
/// untouched parts and receives the edited text verbatim (untranslated) so
/// both partners always see the same current content.
export function applyAgreementEdit(
  current: AgreementByLang, editorUid: string, editorLang: Lang, shared: string, mine: string,
): AgreementByLang | null {
  const s = cleanLine(shared, MAX_AGREEMENT_CHARS);
  const m = cleanLine(mine, MAX_AGREEMENT_CHARS);
  if (!s || !m) return null;
  const next: AgreementByLang = {};
  for (const lang of Object.keys(current) as Lang[]) {
    const cur = current[lang]!;
    if (!(editorUid in cur.perPartner)) return null;
    next[lang] = { shared: s, perPartner: { ...cur.perPartner, [editorUid]: m } };
  }
  if (!(editorLang in next)) next[editorLang] = { shared: s, perPartner: { [editorUid]: m } };
  return next;
}

export interface Accept { hash: string; at: unknown }
/// Both accepted the CURRENT hash → active.
export function bothAccepted(accepts: Record<string, Accept | undefined>, uids: string[], hash: string): boolean {
  return uids.every((u) => accepts[u]?.hash === hash);
}

export function canNudge(lastAt: Date | null, now: Date): boolean {
  return !lastAt || now.getTime() - lastAt.getTime() >= NUDGE_MIN_GAP_MS;
}

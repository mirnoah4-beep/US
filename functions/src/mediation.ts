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

/// invited     — partner has not answered the invitation
/// answering   — both may write/submit private answers
/// waiting     — one partner has submitted
/// summary     — summary + draft agreement exist; needs may be corrected,
///               agreement may be edited/accepted
/// active      — both accepted the same revision; content frozen
/// paused / closed — neutral end states (no reason is ever stored here)
/// expired     — no two submissions within EXPIRY_DAYS
/// summaryFailed — AI produced no valid output twice; retry allowed
export const STATUSES = ['invited', 'answering', 'waiting', 'summary', 'active', 'paused', 'closed', 'expired', 'summaryFailed'] as const;
export type Status = typeof STATUSES[number];

export const OPEN_STATUSES: readonly Status[] = ['invited', 'answering', 'waiting', 'summary', 'summaryFailed'];
export const ANSWERING_STATUSES: readonly Status[] = ['answering', 'waiting'];
export const EXPIRABLE_STATUSES: readonly Status[] = ['invited', 'answering', 'waiting'];

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

// ── Answers ─────────────────────────────────────────────────────────────────

export interface Answers { whatHappened: string; whatINeed: string; whatICanDo: string }

/// Validates a private answers document for submission. Returns the trimmed
/// answers or the field that is missing/too long.
export function validateAnswers(raw: Record<string, unknown> | undefined | null):
  { ok: true; answers: Answers } | { ok: false; field: keyof Answers | 'missing' } {
  if (!raw) return { ok: false, field: 'missing' };
  const out: Partial<Answers> = {};
  for (const k of ['whatHappened', 'whatINeed', 'whatICanDo'] as const) {
    const v = raw[k];
    if (typeof v !== 'string' || v.trim().length === 0 || v.length > MAX_ANSWER_CHARS) return { ok: false, field: k };
    out[k] = v.trim();
  }
  return { ok: true, answers: out as Answers };
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

// ── Summary + agreement generation (prompt + schema) ────────────────────────

export interface Partner { uid: string; name: string; lang: Lang }

export interface SummaryTexts {
  sameTeam: string;
  different: string;
  needs: Record<string, string>;     // uid → line
  idea: string;
}
export type SummaryByLang = Partial<Record<Lang, SummaryTexts>>;

export interface GenerationInput {
  category: Category;
  starter: Partner;      // named SECOND in the output (alternation rule)
  partner: Partner;      // named first
  answers: Record<string, Answers>;
  langs: Lang[];
}

const CATEGORY_LABEL: Record<Lang, Record<Category, string>> = {
  no: { communication: 'kommunikasjon', time: 'tid sammen', money: 'økonomi', kids: 'barn og familie', chores: 'husarbeid', trust: 'tillit', intimacy: 'nærhet', other: 'noe annet' },
  en: { communication: 'communication', time: 'time together', money: 'money', kids: 'kids and family', chores: 'chores', trust: 'trust', intimacy: 'intimacy', other: 'something else' },
};
export const categoryLabel = (c: Category, lang: Lang): string => CATEGORY_LABEL[lang][c];

export const FACILITATOR_SYSTEM_PROMPT =
  'You are a warm, neutral facilitator for a couple using a small everyday app. ' +
  'You NEVER pick a winner, never say who is right or wrong, never diagnose, never use labels ' +
  '(toxic, narcissistic, manipulative, etc.), never invent motives, never shame, and never push reconciliation. ' +
  'You describe what both said in plain, kind, short everyday language (no therapy or legal tone), ' +
  'name what each person needs in their own words, and suggest ONE small, concrete thing to try. ' +
  'Return ONLY strict JSON matching the requested schema, nothing else.';

/// Builds the user prompt. The partner who did NOT start is named first.
export function buildGenerationPrompt(input: GenerationInput): string {
  const first = input.partner;
  const second = input.starter;
  const a = (p: Partner) => input.answers[p.uid];
  const langNames = input.langs.map((l) => (l === 'no' ? 'Norwegian (bokmål)' : 'English')).join(' AND ');
  const perLang = input.langs.map((l) => `"${l}": {"sameTeam": string, "different": string, "needs": {"${first.uid}": string, "${second.uid}": string}, "idea": string, "agreement": {"shared": string, "perPartner": {"${first.uid}": string, "${second.uid}": string}}}`).join(', ');
  return [
    `Topic: ${categoryLabel(input.category, 'en')}.`,
    `Two partners: ${first.name} (id ${first.uid}) and ${second.name} (id ${second.uid}). Always mention ${first.name} before ${second.name}.`,
    '',
    `${first.name} wrote — What happened: ${a(first).whatHappened} | What I need: ${a(first).whatINeed} | What I could do myself: ${a(first).whatICanDo}`,
    `${second.name} wrote — What happened: ${a(second).whatHappened} | What I need: ${a(second).whatINeed} | What I could do myself: ${a(second).whatICanDo}`,
    '',
    `Write everything in ${langNames}. Each text max ${MAX_AGREEMENT_CHARS} characters, warm and everyday, second person plural ("dere"/"you two") for shared lines.`,
    '"sameTeam": where they agree or want the same thing. "different": where they see it differently, without judging. ',
    '"needs": one line per person starting with their name, in their own words. "idea": one small concrete thing to try this week (this is a suggestion).',
    '"agreement": "shared" = one short sentence both could say ("Vi prøver…"/"We\'ll try…"); "perPartner" = one short "<name> gjør…"/"<name> will…" line each, based on what they said they could do themselves.',
    `Return JSON: {${perLang}}`,
  ].join('\n');
}

export interface GenerationOutput { summary: SummaryByLang; agreement: AgreementByLang }

function cleanLine(v: unknown, max: number): string | null {
  if (typeof v !== 'string') return null;
  const s = v.replace(/\s+/g, ' ').trim();
  if (s.length === 0) return null;
  return s.length > max ? `${s.slice(0, max - 1).trimEnd()}…` : s;
}

/// Validates the model's JSON against the schema for the requested languages
/// and uids. Returns null when anything required is missing or malformed —
/// the caller retries once, then marks summaryFailed.
export function parseGenerationOutput(raw: unknown, langs: Lang[], uids: string[]): GenerationOutput | null {
  if (!raw || typeof raw !== 'object') return null;
  const root = raw as Record<string, unknown>;
  const summary: SummaryByLang = {};
  const agreement: AgreementByLang = {};
  for (const lang of langs) {
    const block = root[lang];
    if (!block || typeof block !== 'object') return null;
    const b = block as Record<string, unknown>;
    const sameTeam = cleanLine(b.sameTeam, MAX_AGREEMENT_CHARS);
    const different = cleanLine(b.different, MAX_AGREEMENT_CHARS);
    const idea = cleanLine(b.idea, MAX_AGREEMENT_CHARS);
    const needsRaw = b.needs as Record<string, unknown> | undefined;
    const agr = b.agreement as Record<string, unknown> | undefined;
    if (!sameTeam || !different || !idea || !needsRaw || !agr) return null;
    const needs: Record<string, string> = {};
    const perPartner: Record<string, string> = {};
    const ppRaw = agr.perPartner as Record<string, unknown> | undefined;
    for (const uid of uids) {
      const n = cleanLine(needsRaw[uid], MAX_NEED_CHARS);
      const p = cleanLine(ppRaw?.[uid], MAX_AGREEMENT_CHARS);
      if (!n || !p) return null;
      needs[uid] = n; perPartner[uid] = p;
    }
    const shared = cleanLine(agr.shared, MAX_AGREEMENT_CHARS);
    if (!shared) return null;
    summary[lang] = { sameTeam, different, needs, idea };
    agreement[lang] = { shared, perPartner };
  }
  return { summary, agreement };
}

/// Output must not contain judging/labelling language. Cheap guard on top
/// of the prompt; a hit counts as invalid output (→ retry).
const FORBIDDEN_OUTPUT = /\b(narsissist|narcissist|toxic|toksisk|manipulat|gaslight|has? the right|har rett|tar feil|is wrong|skyld(en|ig)|to blame|blame)\b/i;
export function outputIsNeutral(out: GenerationOutput): boolean {
  const all: string[] = [];
  for (const s of Object.values(out.summary)) if (s) all.push(s.sameTeam, s.different, s.idea, ...Object.values(s.needs));
  for (const a of Object.values(out.agreement)) if (a) all.push(a.shared, ...Object.values(a.perPartner));
  return !all.some((t) => FORBIDDEN_OUTPUT.test(t));
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

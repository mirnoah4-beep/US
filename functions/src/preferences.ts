// Couple recommendation profile — pure, no firebase-admin.
//
// Raw answers live PER USER in couples/{coupleId}/settings/prefs_{uid}; the
// couple profile is DERIVED on read and never written back over anyone's
// answers. Legacy single-value fields on settings/main (written by RC1 and
// older) are a fallback, and safe defaults apply only when nothing exists.
// Every reader here tolerates missing fields, wrong types, old string values
// where the new shape is a list, and both time vocabularies.

export const LOCATION_IDS = ['nature', 'cafe', 'home', 'out'] as const;
export type LocationId = typeof LOCATION_IDS[number];

export const TIME_IDS = ['fewHours', 'evening', 'fullDay'] as const;
export type AvailableTime = typeof TIME_IDS[number];

export const CHILDCARE_IDS = ['kidsHome', 'kidFree'] as const;
export type ChildcareState = typeof CHILDCARE_IDS[number];

export const PACE_IDS = ['calm', 'mixed', 'active'] as const;
export type Pace = typeof PACE_IDS[number];

/// One user's raw answers (all optional — partially answered docs are valid).
export interface UserPrefs {
  locationPreferences?: LocationId[];
  pace?: Pace;
  availableTime?: AvailableTime;
  isParent?: boolean;
  childcareState?: ChildcareState;
  bedtimeWeekday?: string;   // 'HH:mm'
  bedtimeWeekend?: string;   // 'HH:mm'
}

export interface RankedLocation { id: LocationId; weight: number; }

export interface CoupleProfile {
  /// Union of both partners' locations; weight 2 = chosen by both, 1 = one-sided.
  locations: RankedLocation[];
  /// The more constrained of the two answers (fits both people).
  availableTime: AvailableTime;
  /// True if EITHER partner is a parent.
  isParent: boolean;
  /// Usual situation, not truth: kidsHome is the conservative default.
  childcareState: ChildcareState;
  bedtimeWeekday: string | null;
  bedtimeWeekend: string | null;
  pace: Pace;
  /// Where the profile came from, for logs/tests.
  source: 'prefs' | 'legacy' | 'defaults';
  /// Set when a per-session override replaced defaults for this request.
  overridden: boolean;
}

// ── Normalisers ─────────────────────────────────────────────────────────────

const TIME_ORDER: Record<AvailableTime, number> = { fewHours: 0, evening: 1, fullDay: 2 };

/// Accepts the new ids, the legacy onboarding ids (short/evening/day) and the
/// legacy lifestyle ids (under30/30to60/2plus, little/halfday/fullday).
export function normalizeTime(raw: unknown): AvailableTime | undefined {
  if (typeof raw !== 'string') return undefined;
  switch (raw) {
    case 'fewHours': case 'short': case 'under30': case '30to60': case 'little': return 'fewHours';
    case 'evening': case '2plus': case 'halfday': return 'evening';
    case 'fullDay': case 'day': case 'fullday': return 'fullDay';
    default: return undefined;
  }
}

/// Accepts a list, a single string (legacy `place`), or the lifestyle
/// `preference` vocabulary (home/out/both). Unknown ids are dropped.
export function normalizeLocations(raw: unknown): LocationId[] {
  const items = Array.isArray(raw) ? raw : typeof raw === 'string' ? [raw] : [];
  const out = new Set<LocationId>();
  for (const it of items) {
    if (typeof it !== 'string') continue;
    if ((LOCATION_IDS as readonly string[]).includes(it)) out.add(it as LocationId);
    else if (it === 'both') LOCATION_IDS.forEach((l) => out.add(l));
    else if (it === 'city') out.add('cafe');
    else if (it === 'activities') out.add('out');
  }
  return LOCATION_IDS.filter((l) => out.has(l));
}

export function normalizeChildcare(raw: unknown): ChildcareState | undefined {
  return raw === 'kidsHome' || raw === 'kidFree' ? raw : undefined;
}

export function normalizePace(raw: unknown): Pace | undefined {
  return raw === 'calm' || raw === 'mixed' || raw === 'active' ? raw : undefined;
}

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;
export function normalizeHHmm(raw: unknown): string | undefined {
  return typeof raw === 'string' && HHMM.test(raw) ? raw : undefined;
}

export function hhmmFromParts(hour: unknown, minute: unknown): string | undefined {
  if (typeof hour !== 'number' || !Number.isInteger(hour) || hour < 0 || hour > 23) return undefined;
  const m = typeof minute === 'number' && Number.isInteger(minute) && minute >= 0 && minute <= 59 ? minute : 0;
  return `${String(hour).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

/// Parses a prefs_{uid} document. Never throws; unknown/missing → undefined.
export function normalizeUserPrefs(raw: Record<string, unknown> | undefined | null): UserPrefs | null {
  if (!raw) return null;
  const p: UserPrefs = {};
  const loc = normalizeLocations(raw.locationPreferences);
  if (loc.length) p.locationPreferences = loc;
  const pace = normalizePace(raw.pace); if (pace) p.pace = pace;
  const t = normalizeTime(raw.availableTime); if (t) p.availableTime = t;
  if (typeof raw.isParent === 'boolean') p.isParent = raw.isParent;
  const c = normalizeChildcare(raw.childcareState); if (c) p.childcareState = c;
  const bw = normalizeHHmm(raw.bedtimeWeekday); if (bw) p.bedtimeWeekday = bw;
  const be = normalizeHHmm(raw.bedtimeWeekend); if (be) p.bedtimeWeekend = be;
  return p;
}

/// Reads the legacy couple-level settings/main document (onboarding fields
/// AND lifestyle fields) into one UserPrefs-shaped fallback.
export function legacyPrefsFromMain(main: Record<string, unknown> | undefined | null): UserPrefs | null {
  if (!main) return null;
  const p: UserPrefs = {};
  const loc = normalizeLocations(main.place ?? main.preference);
  if (loc.length) p.locationPreferences = loc;
  const pace = normalizePace(main.pace); if (pace) p.pace = pace;
  const t = normalizeTime(main.availableTime) ?? normalizeTime(main.weekdayTime) ?? normalizeTime(main.weekendTime);
  if (t) p.availableTime = t;
  if (typeof main.isParent === 'boolean') p.isParent = main.isParent;
  else if (typeof main.parentMode === 'boolean') p.isParent = main.parentMode;
  const bw = normalizeHHmm(main.bedtimeWeekday) ?? hhmmFromParts(main.bedtimeHour, main.bedtimeMinute);
  const be = normalizeHHmm(main.bedtimeWeekend) ?? bw;
  if (bw) p.bedtimeWeekday = bw;
  if (be) p.bedtimeWeekend = be;
  return Object.keys(p).length ? p : null;
}

// ── Derivation ──────────────────────────────────────────────────────────────

function earliest(a?: string, b?: string): string | null {
  if (a && b) return a <= b ? a : b;
  return a ?? b ?? null;
}

/// Derives the couple profile from the partners' raw answers. Missing
/// partners/answers fall back to [legacy], then to defaults. Nothing is
/// merged destructively — the inputs are untouched.
export function deriveCoupleProfile(
  users: Array<UserPrefs | null | undefined>,
  legacy: UserPrefs | null = null,
): CoupleProfile {
  const answered = users.filter((u): u is UserPrefs => !!u && Object.keys(u).length > 0);
  const source: CoupleProfile['source'] = answered.length ? 'prefs' : legacy ? 'legacy' : 'defaults';
  const inputs = answered.length ? answered : legacy ? [legacy] : [];

  // Locations: union, weight 2 when every answering partner chose it.
  const counts = new Map<LocationId, number>();
  let locationVoters = 0;
  for (const u of inputs) {
    if (!u.locationPreferences?.length) continue;
    locationVoters++;
    for (const l of u.locationPreferences) counts.set(l, (counts.get(l) ?? 0) + 1);
  }
  const locations: RankedLocation[] = counts.size
    ? LOCATION_IDS.filter((l) => counts.has(l))
        .map((l) => ({ id: l, weight: locationVoters > 1 && counts.get(l) === locationVoters ? 2 : 1 }))
        .sort((a, b) => b.weight - a.weight)
    : LOCATION_IDS.map((id) => ({ id, weight: 1 }));

  // Time: the more constrained answer.
  const times = inputs.map((u) => u.availableTime).filter((t): t is AvailableTime => !!t);
  const availableTime = times.length
    ? times.reduce((a, b) => (TIME_ORDER[a] <= TIME_ORDER[b] ? a : b))
    : 'evening';

  // Parent: either says yes → yes.
  const isParent = inputs.some((u) => u.isParent === true);

  // Childcare: conservative — if anyone says kidsHome, kids are home.
  const care = inputs.map((u) => u.childcareState).filter((c): c is ChildcareState => !!c);
  const childcareState: ChildcareState = !isParent
    ? 'kidFree'
    : care.includes('kidsHome') || care.length === 0 ? 'kidsHome' : 'kidFree';

  // Bedtime: household constraint, earliest wins; only meaningful with kids home.
  const bedtimeWeekday = isParent ? inputs.map((u) => u.bedtimeWeekday).reduce<string | null>((acc, v) => earliest(acc ?? undefined, v), null) : null;
  const bedtimeWeekend = isParent ? inputs.map((u) => u.bedtimeWeekend).reduce<string | null>((acc, v) => earliest(acc ?? undefined, v), null) : null;

  const paces = inputs.map((u) => u.pace).filter((p): p is Pace => !!p);
  const pace: Pace = paces.length === 0 ? 'mixed' : paces.every((p) => p === paces[0]) ? paces[0] : 'mixed';

  return { locations, availableTime, isParent, childcareState, bedtimeWeekday, bedtimeWeekend, pace, source, overridden: false };
}

// ── Per-session override ("For tonight") ────────────────────────────────────

export interface SessionOverrides {
  availableTime?: AvailableTime;
  childcareState?: ChildcareState;
  locationPreferences?: LocationId[];
}

/// Validates client-supplied overrides. Returns null when nothing usable was
/// sent; throws on a malformed payload so the callable can reject it.
export function parseOverrides(raw: unknown): SessionOverrides | null {
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== 'object' || Array.isArray(raw)) throw new Error('overrides must be an object');
  const o = raw as Record<string, unknown>;
  const allowed = ['availableTime', 'childcareState', 'locationPreferences'];
  for (const k of Object.keys(o)) if (!allowed.includes(k)) throw new Error(`unknown override: ${k}`);
  const out: SessionOverrides = {};
  if (o.availableTime !== undefined) {
    const t = normalizeTime(o.availableTime);
    if (!t) throw new Error('invalid availableTime');
    out.availableTime = t;
  }
  if (o.childcareState !== undefined) {
    const c = normalizeChildcare(o.childcareState);
    if (!c) throw new Error('invalid childcareState');
    out.childcareState = c;
  }
  if (o.locationPreferences !== undefined) {
    if (!Array.isArray(o.locationPreferences) || o.locationPreferences.length > LOCATION_IDS.length) {
      throw new Error('invalid locationPreferences');
    }
    const loc = normalizeLocations(o.locationPreferences);
    if (loc.length !== o.locationPreferences.length) throw new Error('invalid locationPreferences');
    if (loc.length) out.locationPreferences = loc;
  }
  return Object.keys(out).length ? out : null;
}

/// Applies overrides for ONE request. Defaults on disk are never touched.
export function applyOverrides(profile: CoupleProfile, o: SessionOverrides | null): CoupleProfile {
  if (!o) return profile;
  return {
    ...profile,
    availableTime: o.availableTime ?? profile.availableTime,
    childcareState: o.childcareState ?? profile.childcareState,
    locations: o.locationPreferences?.length
      ? o.locationPreferences.map((id) => ({ id, weight: 2 }))
      : profile.locations,
    overridden: true,
  };
}

// ── Prompt context (Norwegian — the ideas prompt is Norwegian) ──────────────

const LOCATION_NO: Record<LocationId, string> = {
  nature: 'natur', cafe: 'by og kafé', home: 'hjemme', out: 'aktiviteter og opplevelser',
};
const TIME_NO: Record<AvailableTime, string> = {
  fewHours: 'et par timer', evening: 'en hel kveld', fullDay: 'en hel dag',
};
const PACE_NO: Record<Pace, string> = { calm: 'rolig', mixed: 'blandet', active: 'aktivt' };

export function lifestyleContextLines(p: CoupleProfile): string[] {
  const both = p.locations.filter((l) => l.weight === 2).map((l) => LOCATION_NO[l.id]);
  const one = p.locations.filter((l) => l.weight === 1).map((l) => LOCATION_NO[l.id]);
  const lines: string[] = [];
  if (p.overridden) lines.push('I KVELD (engangs-ønske, overstyrer vanlige preferanser):');
  lines.push(
    `Steder de liker: ${p.locations.map((l) => LOCATION_NO[l.id]).join(', ')}`
    + (both.length && one.length ? ` (begge foretrekker: ${both.join(', ')})` : ''),
  );
  lines.push(`Tilgjengelig tid: ${TIME_NO[p.availableTime]}${p.overridden ? '' : ' (det mest begrensede av de to)'}`);
  lines.push(`Tempo: ${PACE_NO[p.pace]}`);
  if (p.isParent) {
    if (p.childcareState === 'kidsHome') {
      const bt = p.bedtimeWeekday ? `, barna legger seg ca. ${p.bedtimeWeekday}` : '';
      lines.push(`Foreldre: ja — barna er hjemme${bt}. Ideene må passe etter leggetid eller med barna til stede.`);
    } else {
      lines.push('Foreldre: ja — men barnefri denne gangen (barnevakt). Ideer utenfor hjemmet passer fint.');
    }
  } else {
    lines.push('Foreldre: nei');
  }
  return lines;
}

/// Curated-tier scoring nudge: the effort a suggestion should have given the
/// time available. 'low' for a few hours, 'high' for a full day, else neutral.
export function preferredEffort(p: CoupleProfile): 'low' | 'high' | null {
  if (p.availableTime === 'fewHours') return 'low';
  if (p.availableTime === 'fullDay') return 'high';
  return null;
}

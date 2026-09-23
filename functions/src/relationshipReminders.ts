// Smart relationship reminders — evaluation logic.
//
// Kept separate from index.ts so the guards below can be unit-tested as pure
// functions without booting firebase-admin.
//
// Timezone: every date/time decision below is made in the RECIPIENT's own IANA
// timezone, read from users/{uid}.timeZone. Resolved with Intl, which ships the
// full IANA database in Node 20 — so DST transitions are handled by the
// platform and no UTC offset is ever hard-coded.

import type { ReminderType } from './notificationStrings';

// Activity ids come from lib/models/moment_item.dart — do not invent new ones.
export const QUALITY_TIME_ACTIVITIES = [
  'walk',
  'game',
  'no_kids',
  'phone_free',
  'home_date',
] as const;

export const DATE_ACTIVITIES = [
  'date_night',
  'home_date',
  'went_out',
] as const;

export const DAY_MS = 24 * 60 * 60 * 1000;

/// Activity staleness thresholds — how long since the last relevant log
/// before we consider mentioning it.
export const QUALITY_TIME_THRESHOLD_MS = 3 * DAY_MS;
export const DATE_THRESHOLD_MS = 7 * DAY_MS;

/// Per-type cooldowns — how long before the SAME reminder may repeat.
export const QUALITY_TIME_COOLDOWN_MS = 3 * DAY_MS;
export const DATE_COOLDOWN_MS = 7 * DAY_MS;
export const WEEKLY_COOLDOWN_MS = 7 * DAY_MS;

/// Server-side safety window — never send automatically inside these hours,
/// evaluated in the recipient's local time.
export const QUIET_START_HOUR = 22;
export const QUIET_END_HOUR = 8;

/// The local hour at which the daily reminder is delivered.
export const REMINDER_HOUR = 19;

export interface LocalParts {
  hour: number;
  /// Local calendar day, 'YYYY-MM-DD'. This is what "per day" means everywhere.
  day: string;
  /// 0 = Sunday, in local time.
  weekday: number;
}

/// True only for a timezone identifier Intl can actually resolve. Anything
/// else — absent, empty, misspelled, an offset string — is invalid, and an
/// invalid timezone must never be silently replaced with a guess.
export function isValidTimeZone(timeZone: unknown): timeZone is string {
  if (typeof timeZone !== 'string' || timeZone.length === 0) return false;

  // Intl also accepts fixed offsets like '+02:00'. Those are rejected on
  // purpose: an offset cannot follow daylight-saving transitions, so storing
  // one would silently drift by an hour twice a year. Require a real IANA
  // region identifier ('Area/Location') or plain UTC.
  const isIana = timeZone.includes('/') || timeZone === 'UTC';
  if (!isIana) return false;

  try {
    new Intl.DateTimeFormat('en-GB', { timeZone });
    return true;
  } catch {
    return false;
  }
}

/// Wall-clock parts for an instant in the given IANA timezone.
/// Returns null when the timezone is unusable, so callers must handle it
/// rather than fall back to a default region.
export function localParts(now: Date, timeZone: unknown): LocalParts | null {
  if (!isValidTimeZone(timeZone)) return null;
  const fmt = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    weekday: 'short',
  });
  const parts = Object.fromEntries(
    fmt.formatToParts(now).map((p) => [p.type, p.value]),
  ) as Record<string, string>;

  // 'hour' can come back as '24' at midnight in some ICU versions.
  const hour = Number(parts.hour) % 24;
  const weekdayMap: Record<string, number> = {
    Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
  };
  return {
    hour,
    day: `${parts.year}-${parts.month}-${parts.day}`,
    weekday: weekdayMap[parts.weekday] ?? 0,
  };
}

/// True inside the do-not-disturb window (22:00–08:00 Oslo).
export function isWithinQuietHours(hour: number): boolean {
  return hour >= QUIET_START_HOUR || hour < QUIET_END_HOUR;
}

/// Per-user anti-spam state, stored server-only at rateLimits/relationship_{uid}.
export interface ReminderState {
  lastReminderDay?: string;      // recipient-local 'YYYY-MM-DD' — max 1/day
  lastDateAt?: number;
  lastQualityTimeAt?: number;
  lastWeeklyAt?: number;
}

/// Rollout gate. Only a client build that understands the
/// `relationship_reminder` FCM payload writes this field, so the scheduler can
/// never notify an app version that would not know what to do with the tap.
export const RELATIONSHIP_REMINDERS_VERSION = 1;

/// Eligibility is POSITIVE and requires BOTH:
///   - an explicit rollout version marker (the client understands the payload)
///   - a valid IANA timezone (we know when 19:00 is for this person)
/// Absent or malformed values are always ineligible — never inferred, never
/// guessed from language or IP.
export function isRolloutEligible(data: Record<string, unknown> | undefined): boolean {
  const version = data?.relationshipRemindersVersion;
  const versionOk = typeof version === 'number'
    && Number.isFinite(version)
    && version >= RELATIONSHIP_REMINDERS_VERSION;
  return versionOk && isValidTimeZone(data?.timeZone);
}

/// Per-user preferences, from users/{uid}.
///
/// Defaults are OFF: a missing field must never mean "ON" server-side, so an
/// existing user cannot be opted in before the new client writes their real
/// choice. The new client persists explicit values on first launch.
export interface ReminderPrefs {
  smartRemindersEnabled: boolean;
  qualityTimeReminderEnabled: boolean;
  dateReminderEnabled: boolean;
  weeklyRelationshipReminderEnabled: boolean;
}

export interface ReminderInput {
  /// True only when the user carries the rollout marker. Checked first.
  rolloutEligible: boolean;
  nowMs: number;
  /// Recipient's local calendar day.
  localDay: string;
  /// Recipient's local hour (0-23).
  localHour: number;
  isSunday: boolean;
  /// Latest lastDone across QUALITY_TIME_ACTIVITIES, or 0 if never logged.
  qualityTimeLastDoneMs: number;
  /// Latest lastDone across DATE_ACTIVITIES, or 0 if never logged.
  dateLastDoneMs: number;
  state: ReminderState;
  prefs: ReminderPrefs;
}

/// The single decision point for automatic reminders.
///
/// Priority: date → quality-time → weekly. Returns at most one type, or null.
/// Every anti-spam rule lives here so it is testable in isolation.
export function chooseReminderType(input: ReminderInput): ReminderType | null {
  const { nowMs, localDay, localHour, isSunday, state, prefs } = input;

  // Rollout gate first: an app build that cannot handle the payload must
  // never be sent one, whatever the preferences say.
  if (!input.rolloutEligible) return null;

  // Master switch.
  if (!prefs.smartRemindersEnabled) return null;

  // Deliver only at the recipient's own 19:00 — this is what stops every user
  // worldwide from being notified at the same instant.
  if (localHour !== REMINDER_HOUR) return null;

  // Server-side safety window, in local time.
  if (isWithinQuietHours(localHour)) return null;

  // Max one automatic reminder per user per LOCAL day, across all types.
  if (state.lastReminderDay === localDay) return null;

  const staleFor = (lastDoneMs: number) =>
    lastDoneMs === 0 ? Number.POSITIVE_INFINITY : nowMs - lastDoneMs;

  const cooledDown = (lastSentMs: number | undefined, cooldownMs: number) =>
    lastSentMs === undefined || nowMs - lastSentMs >= cooldownMs;

  // 1. Date reminder — no date activity for ~7 days.
  if (
    prefs.dateReminderEnabled
    && staleFor(input.dateLastDoneMs) >= DATE_THRESHOLD_MS
    && cooledDown(state.lastDateAt, DATE_COOLDOWN_MS)
  ) {
    return 'date';
  }

  // 2. Quality-time reminder — no together activity for ~3 days.
  if (
    prefs.qualityTimeReminderEnabled
    && staleFor(input.qualityTimeLastDoneMs) >= QUALITY_TIME_THRESHOLD_MS
    && cooledDown(state.lastQualityTimeAt, QUALITY_TIME_COOLDOWN_MS)
  ) {
    return 'quality_time';
  }

  // 3. Weekly check-in — Sundays only.
  if (
    isSunday
    && prefs.weeklyRelationshipReminderEnabled
    && cooledDown(state.lastWeeklyAt, WEEKLY_COOLDOWN_MS)
  ) {
    return 'weekly';
  }

  return null;
}

/// The state patch to commit once a reminder of `type` has been sent.
export function reminderStatePatch(
  type: ReminderType,
  nowMs: number,
  localDay: string,
): ReminderState {
  const patch: ReminderState = { lastReminderDay: localDay };
  if (type === 'date') patch.lastDateAt = nowMs;
  if (type === 'quality_time') patch.lastQualityTimeAt = nowMs;
  if (type === 'weekly') patch.lastWeeklyAt = nowMs;
  return patch;
}

/// Reads user prefs, defaulting to OFF.
///
/// A missing field means "this user has not told us yet", never "ON". Only an
/// explicit `true` written by the new client enables a reminder type.
export function readReminderPrefs(data: Record<string, unknown> | undefined): ReminderPrefs {
  const bool = (v: unknown) => v === true;
  return {
    smartRemindersEnabled: bool(data?.smartRemindersEnabled),
    qualityTimeReminderEnabled: bool(data?.qualityTimeReminderEnabled),
    dateReminderEnabled: bool(data?.dateReminderEnabled),
    weeklyRelationshipReminderEnabled: bool(data?.weeklyRelationshipReminderEnabled),
  };
}

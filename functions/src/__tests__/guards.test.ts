// Unit tests for the server-side security and anti-spam guards.
// Run: npm test   (Node 20 built-in test runner — no extra dependency)

import { test } from 'node:test';
import * as assert from 'node:assert';

import {
  partnerRateDecision,
  resolvePartnerTarget,
  PARTNER_MIN_GAP_MS,
} from '../partnerMessaging';
import { isPartnerTemplateId } from '../notificationStrings';
import {
  chooseReminderType,
  isWithinQuietHours,
  localParts,
  isValidTimeZone,
  REMINDER_HOUR,
  reminderStatePatch,
  readReminderPrefs,
  isRolloutEligible,
  RELATIONSHIP_REMINDERS_VERSION,
  DAY_MS,
  type ReminderPrefs,
  type ReminderState,
} from '../relationshipReminders';

const A = 'uidA';
const B = 'uidB';
const COUPLE = { members: [A, B] };

// ── 3. Only the verified partner is targeted ────────────────────────────────

test('resolves the other member as the partner', () => {
  const r = resolvePartnerTarget(A, { coupleId: 'c1' }, COUPLE);
  assert.ok(r.ok);
  assert.strictEqual(r.partnerId, B);
  assert.strictEqual(r.coupleId, 'c1');
});

test('partner resolution is symmetric', () => {
  const r = resolvePartnerTarget(B, { coupleId: 'c1' }, COUPLE);
  assert.ok(r.ok);
  assert.strictEqual(r.partnerId, A);
});

// ── 4. A client cannot make the server send to another uid ──────────────────

test('a non-member cannot target the couple', () => {
  const r = resolvePartnerTarget('intruder', { coupleId: 'c1' }, COUPLE);
  assert.ok(!r.ok);
  assert.strictEqual(r.reason, 'not-a-member');
});

test('client-supplied recipient fields are ignored entirely', () => {
  // Even when the caller stuffs a recipient into their own user doc, the
  // target is derived only from couple membership.
  const r = resolvePartnerTarget(
    A,
    { coupleId: 'c1', partnerId: 'victim', fcmToken: 'attacker-token' },
    COUPLE,
  );
  assert.ok(r.ok);
  assert.strictEqual(r.partnerId, B);
});

test('unauthenticated callers are rejected', () => {
  const r = resolvePartnerTarget(null, { coupleId: 'c1' }, COUPLE);
  assert.ok(!r.ok);
  assert.strictEqual(r.reason, 'unauthenticated');
});

// ── 5. A user without a partner cannot use the function ─────────────────────

test('user with no coupleId is rejected', () => {
  const r = resolvePartnerTarget(A, {}, undefined);
  assert.ok(!r.ok);
  assert.strictEqual(r.reason, 'no-couple');
});

test('missing couple document is rejected', () => {
  const r = resolvePartnerTarget(A, { coupleId: 'gone' }, undefined);
  assert.ok(!r.ok);
  assert.strictEqual(r.reason, 'couple-not-found');
});

test('solo member (no partner yet) is rejected', () => {
  const r = resolvePartnerTarget(A, { coupleId: 'c1' }, { members: [A] });
  assert.ok(!r.ok);
  assert.strictEqual(r.reason, 'no-partner');
});

test('missing user document is rejected', () => {
  const r = resolvePartnerTarget(A, undefined, COUPLE);
  assert.ok(!r.ok);
  assert.strictEqual(r.reason, 'user-not-found');
});

// ── 6. Invalid templateId is rejected ───────────────────────────────────────

test('accepts exactly the four predefined templates', () => {
  for (const id of ['miss_us_time', 'tonight', 'date_soon', 'time_with_you']) {
    assert.ok(isPartnerTemplateId(id), `${id} should be valid`);
  }
});

test('rejects unknown, empty and non-string templateIds', () => {
  for (const bad of ['', 'free_text', 'MISS_US_TIME', null, undefined, 42, {}, ['tonight']]) {
    assert.ok(!isPartnerTemplateId(bad), `${JSON.stringify(bad)} should be invalid`);
  }
});

// ── 7. Rate limiting ────────────────────────────────────────────────────────

const DAY = '2026-09-23';

test('first send of the day is allowed', () => {
  const d = partnerRateDecision(undefined, DAY, 1_000_000);
  assert.ok(d.allowed);
  assert.strictEqual(d.next.count, 1);
});

test('blocks a second send inside the 30 minute gap', () => {
  const now = 1_000_000;
  const d = partnerRateDecision({ day: DAY, count: 1, lastSentAt: now - 60_000 }, DAY, now);
  assert.ok(!d.allowed);
  assert.strictEqual(d.reason, 'too-soon');
});

test('allows a send once the 30 minute gap has passed', () => {
  const now = 10_000_000;
  const d = partnerRateDecision(
    { day: DAY, count: 1, lastSentAt: now - PARTNER_MIN_GAP_MS },
    DAY,
    now,
  );
  assert.ok(d.allowed);
  assert.strictEqual(d.next.count, 2);
});

test('blocks the 4th send in one day', () => {
  const now = 10_000_000;
  const d = partnerRateDecision(
    { day: DAY, count: 3, lastSentAt: now - 2 * PARTNER_MIN_GAP_MS },
    DAY,
    now,
  );
  assert.ok(!d.allowed);
  assert.strictEqual(d.reason, 'daily-limit');
});

test('daily counter resets on a new Oslo day', () => {
  const now = 10_000_000;
  const d = partnerRateDecision(
    { day: '2026-09-22', count: 3, lastSentAt: now - 2 * PARTNER_MIN_GAP_MS },
    DAY,
    now,
  );
  assert.ok(d.allowed);
  assert.strictEqual(d.next.count, 1);
});

// ── 9 & 10. Automatic reminder gating ───────────────────────────────────────

const NOW = Date.parse('2026-09-23T17:00:00Z'); // 19:00 Oslo, a Wednesday
const ON: ReminderPrefs = {
  smartRemindersEnabled: true,
  qualityTimeReminderEnabled: true,
  dateReminderEnabled: true,
  weeklyRelationshipReminderEnabled: true,
};

function input(over: Partial<Parameters<typeof chooseReminderType>[0]> = {}) {
  return {
    rolloutEligible: true,
    nowMs: NOW,
    localDay: '2026-09-23',
    localHour: REMINDER_HOUR,
    isSunday: false,
    qualityTimeLastDoneMs: NOW - 1 * DAY_MS,
    dateLastDoneMs: NOW - 1 * DAY_MS,
    state: {} as ReminderState,
    prefs: ON,
    ...over,
  };
}

test('no reminder when both activities are recent', () => {
  assert.strictEqual(chooseReminderType(input()), null);
});

test('quality-time reminder after 3 stale days', () => {
  assert.strictEqual(
    chooseReminderType(input({ qualityTimeLastDoneMs: NOW - 3 * DAY_MS })),
    'quality_time',
  );
});

test('date reminder after 7 stale days, and it outranks quality-time', () => {
  assert.strictEqual(
    chooseReminderType(input({
      dateLastDoneMs: NOW - 7 * DAY_MS,
      qualityTimeLastDoneMs: NOW - 7 * DAY_MS,
    })),
    'date',
  );
});

test('never-logged activity counts as stale', () => {
  assert.strictEqual(
    chooseReminderType(input({ dateLastDoneMs: 0, qualityTimeLastDoneMs: 0 })),
    'date',
  );
});

test('recent activity suppresses its own reminder', () => {
  // Date logged yesterday, quality-time stale -> quality-time only.
  assert.strictEqual(
    chooseReminderType(input({
      dateLastDoneMs: NOW - 1 * DAY_MS,
      qualityTimeLastDoneMs: NOW - 5 * DAY_MS,
    })),
    'quality_time',
  );
});

test('max one reminder per Oslo day', () => {
  assert.strictEqual(
    chooseReminderType(input({
      qualityTimeLastDoneMs: NOW - 5 * DAY_MS,
      state: { lastReminderDay: '2026-09-23' },
    })),
    null,
  );
});

test('quality-time cooldown is 3 days', () => {
  const stale = { qualityTimeLastDoneMs: NOW - 10 * DAY_MS };
  assert.strictEqual(
    chooseReminderType(input({ ...stale, state: { lastQualityTimeAt: NOW - 2 * DAY_MS } })),
    null,
  );
  assert.strictEqual(
    chooseReminderType(input({ ...stale, state: { lastQualityTimeAt: NOW - 3 * DAY_MS } })),
    'quality_time',
  );
});

test('date cooldown is 7 days', () => {
  const stale = { dateLastDoneMs: NOW - 30 * DAY_MS, qualityTimeLastDoneMs: NOW };
  assert.strictEqual(
    chooseReminderType(input({ ...stale, state: { lastDateAt: NOW - 6 * DAY_MS } })),
    null,
  );
  assert.strictEqual(
    chooseReminderType(input({ ...stale, state: { lastDateAt: NOW - 7 * DAY_MS } })),
    'date',
  );
});

test('weekly reminder only on Sunday, with a 7 day cooldown', () => {
  const fresh = { dateLastDoneMs: NOW, qualityTimeLastDoneMs: NOW };
  assert.strictEqual(chooseReminderType(input({ ...fresh, isSunday: false })), null);
  assert.strictEqual(chooseReminderType(input({ ...fresh, isSunday: true })), 'weekly');
  assert.strictEqual(
    chooseReminderType(input({
      ...fresh,
      isSunday: true,
      state: { lastWeeklyAt: NOW - 6 * DAY_MS },
    })),
    null,
  );
});

// ── 11. Quiet hours / preferences ───────────────────────────────────────────

test('quiet hours cover 22:00-07:59 Oslo', () => {
  for (const h of [22, 23, 0, 3, 7]) assert.ok(isWithinQuietHours(h), `${h} should be quiet`);
  for (const h of [8, 12, 19, 21]) assert.ok(!isWithinQuietHours(h), `${h} should be allowed`);
});

test('no automatic send inside quiet hours', () => {
  assert.strictEqual(
    chooseReminderType(input({ localHour: 23, qualityTimeLastDoneMs: NOW - 9 * DAY_MS })),
    null,
  );
});

test('delivers only at the local reminder hour', () => {
  const due = { qualityTimeLastDoneMs: NOW - 9 * DAY_MS };
  assert.strictEqual(chooseReminderType(input({ ...due, localHour: 19 })), 'quality_time');
  for (const h of [0, 8, 12, 18, 20, 21]) {
    assert.strictEqual(
      chooseReminderType(input({ ...due, localHour: h })),
      null,
      `hour ${h} must not deliver`,
    );
  }
});

test('master toggle off suppresses everything', () => {
  assert.strictEqual(
    chooseReminderType(input({
      qualityTimeLastDoneMs: 0,
      dateLastDoneMs: 0,
      prefs: { ...ON, smartRemindersEnabled: false },
    })),
    null,
  );
});

test('per-type toggles are independent', () => {
  const stale = { dateLastDoneMs: 0, qualityTimeLastDoneMs: 0 };
  assert.strictEqual(
    chooseReminderType(input({ ...stale, prefs: { ...ON, dateReminderEnabled: false } })),
    'quality_time',
  );
  assert.strictEqual(
    chooseReminderType(input({
      ...stale,
      prefs: { ...ON, dateReminderEnabled: false, qualityTimeReminderEnabled: false },
    })),
    null,
  );
});

test('preferences default to OFF when absent — never opt an existing user in', () => {
  assert.deepStrictEqual(readReminderPrefs(undefined), {
    smartRemindersEnabled: false,
    qualityTimeReminderEnabled: false,
    dateReminderEnabled: false,
    weeklyRelationshipReminderEnabled: false,
  });
  // Only an explicit true enables a type.
  assert.strictEqual(readReminderPrefs({ smartRemindersEnabled: true }).smartRemindersEnabled, true);
  // Truthy-but-not-true values must not enable anything.
  for (const junk of ['true', 1, {}, []]) {
    assert.strictEqual(
      readReminderPrefs({ smartRemindersEnabled: junk }).smartRemindersEnabled,
      false,
      `${JSON.stringify(junk)} must not enable`,
    );
  }
});

// ── Rollout gate ────────────────────────────────────────────────────────────

test('rollout eligibility requires an explicit version marker', () => {
  const tz = 'Europe/Oslo';
  assert.ok(isRolloutEligible({ relationshipRemindersVersion: RELATIONSHIP_REMINDERS_VERSION, timeZone: tz }));
  assert.ok(isRolloutEligible({ relationshipRemindersVersion: 2, timeZone: tz }));
  // The marker alone is no longer enough — a valid timezone is also required.
  assert.ok(!isRolloutEligible({ relationshipRemindersVersion: RELATIONSHIP_REMINDERS_VERSION }));
});

test('rollout eligibility is never inferred from a missing or bad field', () => {
  const ineligible: Array<Record<string, unknown> | undefined> = [
    undefined,
    {},
    { coupleId: 'c1', fcmToken: 'tok' },              // a normal existing user
    { relationshipRemindersVersion: 0, timeZone: 'Europe/Oslo' },
    { relationshipRemindersVersion: -1, timeZone: 'Europe/Oslo' },
    { relationshipRemindersVersion: '1', timeZone: 'Europe/Oslo' },   // string
    { relationshipRemindersVersion: true, timeZone: 'Europe/Oslo' },
    { relationshipRemindersVersion: null, timeZone: 'Europe/Oslo' },
    { relationshipRemindersVersion: NaN, timeZone: 'Europe/Oslo' },
    { relationshipRemindersVersion: Infinity * 0, timeZone: 'Europe/Oslo' },
    { smartRemindersEnabled: true },                  // prefs without the marker
  ];
  for (const data of ineligible) {
    assert.ok(!isRolloutEligible(data), `${JSON.stringify(data)} must be ineligible`);
  }
});

test('an ineligible user is never sent a reminder, whatever their prefs say', () => {
  // Everything else maximally says "send": stale activities, no cooldowns,
  // all toggles on, outside quiet hours.
  const wouldOtherwiseSend = input({
    dateLastDoneMs: 0,
    qualityTimeLastDoneMs: 0,
    isSunday: true,
  });
  assert.strictEqual(chooseReminderType(wouldOtherwiseSend), 'date');
  assert.strictEqual(
    chooseReminderType({ ...wouldOtherwiseSend, rolloutEligible: false }),
    null,
  );
});

test('an existing pre-upgrade user resolves to ineligible AND all-off', () => {
  // Exactly what an untouched user doc looks like today.
  const legacyUser = { coupleId: 'c1', fcmToken: 'tok', language: 'no' };
  assert.ok(!isRolloutEligible(legacyUser));
  const prefs = readReminderPrefs(legacyUser);
  assert.strictEqual(
    chooseReminderType(input({
      rolloutEligible: isRolloutEligible(legacyUser),
      prefs,
      dateLastDoneMs: 0,
      qualityTimeLastDoneMs: 0,
      isSunday: true,
    })),
    null,
  );
});

test('state patch records only the type that was sent', () => {
  const patch = reminderStatePatch('date', NOW, '2026-09-23');
  assert.deepStrictEqual(patch, { lastReminderDay: '2026-09-23', lastDateAt: NOW });
});

// ── Timezone: per-user IANA handling ───────────────────────────────────────

test('accepts real IANA zones, rejects junk', () => {
  for (const tz of [
    'Europe/Oslo', 'America/New_York', 'America/Los_Angeles',
    'Asia/Dubai', 'Asia/Tokyo', 'Australia/Sydney', 'UTC',
  ]) {
    assert.ok(isValidTimeZone(tz), `${tz} should be valid`);
  }
  for (const bad of [
    undefined, null, '', '   ', 'Oslo', 'Norway', 'NO', 'CEST',
    '+02:00', 'Europe/Nowhere', 42, {}, [], true,
  ]) {
    assert.ok(!isValidTimeZone(bad), `${JSON.stringify(bad)} should be invalid`);
  }
});

test('localParts returns null for a missing or invalid timezone', () => {
  const now = new Date('2026-09-23T17:00:00Z');
  for (const bad of [undefined, null, '', 'Europe/Nowhere', '+02:00', 99]) {
    assert.strictEqual(localParts(now, bad), null, `${JSON.stringify(bad)} must be null`);
  }
});

test('the same instant maps to different local hours per zone', () => {
  // 17:00 UTC on 2026-09-23.
  const now = new Date('2026-09-23T17:00:00Z');
  assert.strictEqual(localParts(now, 'Europe/Oslo')!.hour, 19);        // CEST, UTC+2
  assert.strictEqual(localParts(now, 'America/New_York')!.hour, 13);   // EDT,  UTC-4
  assert.strictEqual(localParts(now, 'America/Los_Angeles')!.hour, 10);// PDT,  UTC-7
  assert.strictEqual(localParts(now, 'Asia/Dubai')!.hour, 21);         // UTC+4
  assert.strictEqual(localParts(now, 'Asia/Tokyo')!.hour, 2);          // UTC+9, next day
  assert.strictEqual(localParts(now, 'Asia/Tokyo')!.day, '2026-09-24');
});

test('each zone reaches its own 19:00 at a different instant', () => {
  // The UTC instant at which it is 19:00 locally, per zone, on 2026-09-23/24.
  const localSeven: Record<string, string> = {
    'Europe/Oslo':         '2026-09-23T17:00:00Z',
    'America/New_York':    '2026-09-23T23:00:00Z',
    'America/Los_Angeles': '2026-09-24T02:00:00Z',
    'Asia/Dubai':          '2026-09-23T15:00:00Z',
    'Asia/Tokyo':          '2026-09-23T10:00:00Z',
  };
  const instants = Object.values(localSeven);
  // All five are distinct instants — nobody is notified simultaneously.
  assert.strictEqual(new Set(instants).size, instants.length);

  for (const [tz, iso] of Object.entries(localSeven)) {
    assert.strictEqual(localParts(new Date(iso), tz)!.hour, REMINDER_HOUR, `${tz} at ${iso}`);
  }
});

test('two users in different zones each get exactly one send, at their own 19:00', () => {
  const oslo = 'Europe/Oslo';
  const tokyo = 'Asia/Tokyo';
  const due = { dateLastDoneMs: 0, qualityTimeLastDoneMs: 0 };

  // Simulate the hourly scheduler across a full UTC day.
  const sends: Record<string, string[]> = { [oslo]: [], [tokyo]: [] };
  const state: Record<string, ReminderState> = { [oslo]: {}, [tokyo]: {} };

  for (let h = 0; h < 48; h++) {
    const now = new Date(Date.UTC(2026, 8, 23, h, 0, 0));
    for (const tz of [oslo, tokyo]) {
      const local = localParts(now, tz)!;
      const type = chooseReminderType({
        rolloutEligible: true,
        nowMs: now.getTime(),
        localDay: local.day,
        localHour: local.hour,
        isSunday: local.weekday === 0,
        ...due,
        state: state[tz],
        prefs: ON,
      });
      if (type !== null) {
        sends[tz].push(now.toISOString());
        state[tz] = { ...state[tz], ...reminderStatePatch(type, now.getTime(), local.day) };
      }
    }
  }

  // Two local days simulated -> exactly two sends each, one per local day.
  assert.strictEqual(sends[oslo].length, 2, `oslo: ${sends[oslo]}`);
  assert.strictEqual(sends[tokyo].length, 2, `tokyo: ${sends[tokyo]}`);
  // And never at the same instant as each other.
  assert.strictEqual(sends[oslo][0] === sends[tokyo][0], false);
  assert.strictEqual(sends[oslo][0], '2026-09-23T17:00:00.000Z'); // 19:00 CEST
  assert.strictEqual(sends[tokyo][0], '2026-09-23T10:00:00.000Z'); // 19:00 JST
});

test('local-day rate limit resets on the local calendar day, not UTC', () => {
  // Tokyo is UTC+9, so its day rolls over at 15:00 UTC the previous day.
  const tz = 'Asia/Tokyo';
  const before = localParts(new Date('2026-09-23T14:59:00Z'), tz)!;
  const after = localParts(new Date('2026-09-23T15:01:00Z'), tz)!;
  assert.strictEqual(before.day, '2026-09-23');
  assert.strictEqual(after.day, '2026-09-24');

  // Same UTC day, different local days -> the second one is not blocked.
  const blocked = chooseReminderType(input({
    localDay: before.day,
    state: { lastReminderDay: before.day },
    qualityTimeLastDoneMs: 0,
  }));
  const allowed = chooseReminderType(input({
    localDay: after.day,
    state: { lastReminderDay: before.day },
    qualityTimeLastDoneMs: 0,
  }));
  assert.strictEqual(blocked, null);
  // dateLastDoneMs is recent in this fixture, so quality-time is the pick.
  assert.strictEqual(allowed, 'quality_time');
});

test('Sunday is determined in local time', () => {
  // 2026-09-20 is a Sunday. Mid-day UTC it is Sunday in both zones.
  const midday = new Date('2026-09-20T12:00:00Z');
  assert.strictEqual(localParts(midday, 'Europe/Oslo')!.weekday, 0);
  assert.strictEqual(localParts(midday, 'Asia/Tokyo')!.weekday, 0);

  // Late Sunday UTC has already rolled into Monday in both (Oslo +2, Tokyo +9).
  const late = new Date('2026-09-20T22:00:00Z');
  assert.strictEqual(localParts(late, 'Europe/Oslo')!.weekday, 1);
  assert.strictEqual(localParts(late, 'Asia/Tokyo')!.weekday, 1);

  // Early Sunday UTC is still Saturday in Los Angeles but Sunday in Oslo —
  // proof the weekday is per-recipient, not global.
  const early = new Date('2026-09-20T03:00:00Z');
  assert.strictEqual(localParts(early, 'Europe/Oslo')!.weekday, 0);
  assert.strictEqual(localParts(early, 'America/Los_Angeles')!.weekday, 6);
});

test('DST transitions are handled by IANA data, not hard-coded offsets', () => {
  // Europe/Oslo: CEST (UTC+2) in September, CET (UTC+1) in January.
  assert.strictEqual(localParts(new Date('2026-09-23T17:00:00Z'), 'Europe/Oslo')!.hour, 19);
  assert.strictEqual(localParts(new Date('2026-01-15T18:00:00Z'), 'Europe/Oslo')!.hour, 19);

  // Europe/Oslo DST ends 2026-10-25. The UTC instant of local 19:00 shifts.
  assert.strictEqual(localParts(new Date('2026-10-24T17:00:00Z'), 'Europe/Oslo')!.hour, 19);
  assert.strictEqual(localParts(new Date('2026-10-26T18:00:00Z'), 'Europe/Oslo')!.hour, 19);

  // America/New_York DST ends 2026-11-01: EDT (UTC-4) -> EST (UTC-5).
  assert.strictEqual(localParts(new Date('2026-10-31T23:00:00Z'), 'America/New_York')!.hour, 19);
  assert.strictEqual(localParts(new Date('2026-11-02T00:00:00Z'), 'America/New_York')!.hour, 19);

  // Southern hemisphere runs the other way — Sydney is UTC+10 / +11.
  assert.strictEqual(localParts(new Date('2026-06-15T09:00:00Z'), 'Australia/Sydney')!.hour, 19);
  assert.strictEqual(localParts(new Date('2026-12-15T08:00:00Z'), 'Australia/Sydney')!.hour, 19);
});

// ── 5. Missing / invalid timezone → no automatic reminder ──────────────────

test('missing timezone makes a user ineligible', () => {
  assert.ok(!isRolloutEligible({ relationshipRemindersVersion: 1 }));
  assert.ok(!isRolloutEligible({ relationshipRemindersVersion: 1, timeZone: '' }));
  assert.ok(!isRolloutEligible({ relationshipRemindersVersion: 1, timeZone: null }));
});

test('invalid timezone makes a user ineligible — never guessed from language', () => {
  for (const bad of ['Oslo', 'Norway', 'CEST', '+02:00', 'Europe/Nowhere', 1, true]) {
    assert.ok(
      !isRolloutEligible({ relationshipRemindersVersion: 1, timeZone: bad, language: 'no' }),
      `${JSON.stringify(bad)} must be ineligible`,
    );
  }
});

test('eligibility requires BOTH the version marker and a valid timezone', () => {
  assert.ok(!isRolloutEligible({ timeZone: 'Europe/Oslo' }));                          // no version
  assert.ok(!isRolloutEligible({ relationshipRemindersVersion: 1 }));                  // no tz
  assert.ok(isRolloutEligible({ relationshipRemindersVersion: 1, timeZone: 'Asia/Tokyo' }));
});

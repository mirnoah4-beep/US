// Authorization and rate-limit guards for sendPartnerNotification.
//
// Extracted as pure functions so every security rule below is unit-testable
// without booting firebase-admin or the emulator. index.ts holds only the I/O.

export const PARTNER_MAX_PER_DAY = 3;
export const PARTNER_MIN_GAP_MS = 30 * 60 * 1000;

export type PartnerTargetFailure =
  | 'unauthenticated'
  | 'invalid-template'
  | 'user-not-found'
  | 'no-couple'
  | 'couple-not-found'
  | 'not-a-member'
  | 'no-partner';

export type PartnerTargetResult =
  | { ok: true; partnerId: string; coupleId: string }
  | { ok: false; reason: PartnerTargetFailure };

/// Derives the delivery target purely from server-held state.
///
/// `senderId` must come from request.auth.uid. Nothing here reads a recipient
/// uid, an fcm token, or a sender identity from client input — by construction
/// the client cannot influence who receives the message.
export function resolvePartnerTarget(
  senderId: string | null,
  senderData: Record<string, unknown> | undefined,
  coupleData: Record<string, unknown> | undefined,
): PartnerTargetResult {
  if (!senderId) return { ok: false, reason: 'unauthenticated' };
  if (senderData === undefined) return { ok: false, reason: 'user-not-found' };

  const coupleId = typeof senderData.coupleId === 'string' ? senderData.coupleId : '';
  if (!coupleId) return { ok: false, reason: 'no-couple' };

  if (coupleData === undefined) return { ok: false, reason: 'couple-not-found' };

  const members = Array.isArray(coupleData.members)
    ? (coupleData.members as unknown[]).filter((m): m is string => typeof m === 'string')
    : [];
  if (!members.includes(senderId)) return { ok: false, reason: 'not-a-member' };

  const partnerId = members.find((id) => id !== senderId);
  if (!partnerId) return { ok: false, reason: 'no-partner' };

  return { ok: true, partnerId, coupleId };
}

export interface PartnerRateState {
  day?: string;
  count?: number;
  lastSentAt?: number;
}

export type PartnerRateDecision =
  | { allowed: true; next: Required<PartnerRateState> }
  | { allowed: false; reason: 'too-soon' | 'daily-limit' };

/// Sliding daily quota plus a minimum gap. Pure so both limits are testable.
export function partnerRateDecision(
  state: PartnerRateState | undefined,
  osloDay: string,
  nowMs: number,
): PartnerRateDecision {
  const data = state ?? {};
  const lastSentAt = data.lastSentAt ?? 0;

  if (lastSentAt && nowMs - lastSentAt < PARTNER_MIN_GAP_MS) {
    return { allowed: false, reason: 'too-soon' };
  }

  const sameDay = data.day === osloDay;
  const count = sameDay ? (data.count ?? 0) : 0;
  if (count >= PARTNER_MAX_PER_DAY) {
    return { allowed: false, reason: 'daily-limit' };
  }

  return { allowed: true, next: { day: osloDay, count: count + 1, lastSentAt: nowMs } };
}

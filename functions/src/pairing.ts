// Server-authoritative pairing: createInvite + joinCouple.
//
// The invite CODE is the only thing a client supplies. Everything else —
// the couple, the inviter, both users' current relationship — is read
// server-side inside one Admin-SDK transaction. Client-supplied coupleIds,
// uids or members are never trusted.
//
// Relationship classification (used by both callables):
//   * "active"  — the user's coupleId references an EXISTING couple whose
//                 status is 'active' AND whose members contain the uid.
//                 Only this blocks pairing.
//   * "stale"   — coupleId set, but the couple doc is missing, the user is
//                 not in its members, or the couple is no longer active
//                 (ended, still pending, …). Cleared server-side, then
//                 pairing continues.
//   * "none"    — coupleId null OR the field is absent (treated identically).

import { randomBytes } from 'crypto';
import { firestore } from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

// ── Pure helpers ────────────────────────────────────────────────────────────

/// Current codes are 8 chars from a 32-char alphabet; legacy codes were
/// 6 digits. Anything else is rejected before any read.
export const INVITE_CODE_PATTERN = /^[A-Z0-9]{6,8}$/;

export function normalizeInviteCode(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const code = raw.replace(/\s+/g, '').toUpperCase();
  return INVITE_CODE_PATTERN.test(code) ? code : null;
}

/// Reads a coupleId field the way the product means it: null and absent
/// are the same thing; anything that is not a non-empty string is "none".
export function coupleIdOf(userData: Record<string, unknown> | undefined | null): string | null {
  const raw = userData?.coupleId;
  return typeof raw === 'string' && raw.length > 0 ? raw : null;
}

export type RelationshipState =
  | { kind: 'none' }
  | { kind: 'active'; coupleId: string }
  | { kind: 'stale'; coupleId: string; reason: 'missing' | 'not-member' | 'not-active' };

export interface CoupleView {
  exists: boolean;
  members?: unknown;
  status?: unknown;
}

export function membersOf(couple: CoupleView | Record<string, unknown> | undefined | null): string[] {
  const raw = (couple as { members?: unknown } | null | undefined)?.members;
  return Array.isArray(raw) ? raw.filter((m): m is string => typeof m === 'string' && m.length > 0) : [];
}

/// Classifies the relationship a user document points at. [targetCoupleId]
/// is the pending couple currently being joined/created: a reference to it
/// is neither active nor stale — it is simply the operation in progress.
export function classifyRelationship(
  uid: string,
  coupleId: string | null,
  couple: CoupleView | null,
  targetCoupleId?: string,
): RelationshipState {
  if (!coupleId) return { kind: 'none' };
  if (targetCoupleId && coupleId === targetCoupleId) return { kind: 'none' };
  if (!couple || !couple.exists) return { kind: 'stale', coupleId, reason: 'missing' };
  if (!membersOf(couple).includes(uid)) return { kind: 'stale', coupleId, reason: 'not-member' };
  if (couple.status !== 'active') return { kind: 'stale', coupleId, reason: 'not-active' };
  return { kind: 'active', coupleId };
}

/// Reasons carried to the client in HttpsError.details.reason. The client
/// maps these 1:1 — never a generic "permission denied".
export type PairingFailure =
  | 'invalid-code'
  | 'invite-expired'
  | 'own-invite'
  | 'already-paired'
  | 'inviter-already-paired';

const HTTPS_CODE: Record<PairingFailure, 'invalid-argument' | 'not-found' | 'failed-precondition'> = {
  'invalid-code': 'not-found',
  'invite-expired': 'failed-precondition',
  'own-invite': 'failed-precondition',
  'already-paired': 'failed-precondition',
  'inviter-already-paired': 'failed-precondition',
};

export function pairingError(reason: PairingFailure): HttpsError {
  return new HttpsError(HTTPS_CODE[reason], reason, { reason });
}

/// Generates candidate codes. Charset excludes O/0/I/1 (32 chars, which
/// divides 256 evenly, so `byte % 32` has no modulo bias).
export const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export function generateInviteCode(bytes: Buffer = randomBytes(8)): string {
  let code = '';
  for (let i = 0; i < 8; i++) code += INVITE_ALPHABET[bytes[i] % INVITE_ALPHABET.length];
  return code;
}

// ── Transactions ────────────────────────────────────────────────────────────

type Db = firestore.Firestore;
type Tx = firestore.Transaction;

async function readCouple(tx: Tx, db: Db, coupleId: string): Promise<CoupleView> {
  const snap = await tx.get(db.collection('couples').doc(coupleId));
  return { exists: snap.exists, members: snap.data()?.members, status: snap.data()?.status };
}

/// Reads users/{uid} and classifies its relationship, fetching the
/// referenced couple only when there is one. All reads — no writes.
async function readRelationship(
  tx: Tx, db: Db, uid: string, targetCoupleId?: string,
): Promise<{ exists: boolean; state: RelationshipState }> {
  const snap = await tx.get(db.collection('users').doc(uid));
  const coupleId = coupleIdOf(snap.data());
  if (!coupleId || coupleId === targetCoupleId) {
    return { exists: snap.exists, state: classifyRelationship(uid, coupleId, null, targetCoupleId) };
  }
  const couple = await readCouple(tx, db, coupleId);
  return { exists: snap.exists, state: classifyRelationship(uid, coupleId, couple, targetCoupleId) };
}

export interface JoinResult {
  coupleId: string;
  /// Stale references that were cleared on the way (for logs/tests).
  cleared: { joiner: boolean; inviter: boolean };
}

/// Joins the caller to the pending couple behind [rawCode]. One atomic
/// transaction: every validation reads current server state; the invite is
/// consumed in the same commit, so a code can never be redeemed twice and
/// two concurrent joiners can never both land in the couple.
export async function joinCoupleTx(db: Db, uid: string, rawCode: unknown): Promise<JoinResult> {
  const code = normalizeInviteCode(rawCode);
  if (!code) throw pairingError('invalid-code');

  return db.runTransaction(async (tx) => {
    // ── reads ──
    const inviteRef = db.collection('invites').doc(code);
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) throw pairingError('invalid-code');
    const inviterUid = inviteSnap.data()?.fromUserId;
    const coupleId = inviteSnap.data()?.coupleId;
    if (typeof inviterUid !== 'string' || !inviterUid || typeof coupleId !== 'string' || !coupleId) {
      throw pairingError('invalid-code');
    }
    if (inviterUid === uid) throw pairingError('own-invite');

    const coupleRef = db.collection('couples').doc(coupleId);
    const coupleSnap = await tx.get(coupleRef);
    if (!coupleSnap.exists) throw pairingError('invite-expired');
    const couple = coupleSnap.data() ?? {};
    if (couple.status !== 'pending') throw pairingError('invite-expired');
    const members = membersOf(couple);
    if (!members.includes(inviterUid)) throw pairingError('invite-expired');
    if (members.some((m) => m !== inviterUid)) throw pairingError('invite-expired'); // already has a second member

    const joiner = await readRelationship(tx, db, uid, coupleId);
    const inviter = await readRelationship(tx, db, inviterUid, coupleId);
    if (!inviter.exists) throw pairingError('invite-expired'); // inviter account is gone
    if (joiner.state.kind === 'active') throw pairingError('already-paired');
    if (inviter.state.kind === 'active') throw pairingError('inviter-already-paired');

    // ── writes ──
    tx.update(coupleRef, {
      members: [inviterUid, uid],          // exactly two distinct users, never arrayUnion
      status: 'active',
      inviteCode: null,
      activatedAt: firestore.FieldValue.serverTimestamp(),
    });
    // The joiner's doc may not exist yet (signup race) — merge-set is safe.
    tx.set(db.collection('users').doc(uid), { coupleId }, { merge: true });
    tx.update(db.collection('users').doc(inviterUid), { coupleId });
    tx.delete(inviteRef);
    return {
      coupleId,
      cleared: { joiner: joiner.state.kind === 'stale', inviter: inviter.state.kind === 'stale' },
    };
  });
}

export interface CreateInviteResult {
  code: string;
  coupleId: string;
  reused: boolean;
  clearedStale: boolean;
}

/// Creates (or reuses) the caller's single pending invite. Rejects when the
/// caller has a valid ACTIVE relationship; clears a stale reference first.
/// [candidates] lets tests inject deterministic codes.
export async function createInviteTx(
  db: Db, uid: string, candidates: string[] = Array.from({ length: 5 }, () => generateInviteCode()),
): Promise<CreateInviteResult> {
  return db.runTransaction(async (tx) => {
    // ── reads ──
    const self = await readRelationship(tx, db, uid);
    if (self.state.kind === 'active') throw pairingError('already-paired');

    // One live invite per user: reuse it if its pending couple is intact.
    const existing = await tx.get(db.collection('invites').where('fromUserId', '==', uid).limit(1));
    let reuse: { code: string; coupleId: string } | null = null;
    let orphan: { code: string; coupleId: string | null; lonePendingCouple: boolean } | null = null;
    if (!existing.empty) {
      const d = existing.docs[0];
      const cid = typeof d.data().coupleId === 'string' && d.data().coupleId ? (d.data().coupleId as string) : null;
      const pending = cid ? await readCouple(tx, db, cid) : null;
      const lone = !!pending && pending.exists && pending.status === 'pending'
        && membersOf(pending).length === 1 && membersOf(pending)[0] === uid;
      if (lone) reuse = { code: d.id, coupleId: cid as string };
      else orphan = { code: d.id, coupleId: cid, lonePendingCouple: lone };
    }
    let fresh: string | null = null;
    if (!reuse) {
      for (const c of candidates) {
        if (!INVITE_CODE_PATTERN.test(c)) continue;
        const s = await tx.get(db.collection('invites').doc(c));
        if (!s.exists) { fresh = c; break; }
      }
      if (!fresh) throw new HttpsError('resource-exhausted', 'Could not generate a unique invite code. Try again.');
    }

    // ── writes ──
    if (self.state.kind === 'stale') {
      tx.set(db.collection('users').doc(uid), { coupleId: null }, { merge: true });
    }
    if (reuse) return { ...reuse, reused: true, clearedStale: self.state.kind === 'stale' };

    if (orphan) {
      // A broken invite (couple missing, ended, or joined by someone else):
      // drop the invite doc so the code stops resolving. The couple doc is
      // never touched here — it is either gone or belongs to a real
      // relationship the lifecycle module owns.
      tx.delete(db.collection('invites').doc(orphan.code));
    }
    const coupleRef = db.collection('couples').doc();
    tx.set(coupleRef, {
      members: [uid],
      status: 'pending',
      inviteCode: fresh,
      createdAt: firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('invites').doc(fresh as string), {
      fromUserId: uid,
      coupleId: coupleRef.id,
      createdAt: firestore.FieldValue.serverTimestamp(),
    });
    return { code: fresh as string, coupleId: coupleRef.id, reused: false, clearedStale: self.state.kind === 'stale' };
  });
}

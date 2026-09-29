// Couple / account data lifecycle — the one authoritative implementation
// shared by disconnectPartner, deleteAccount and the onCoupleDeleted safety
// net (index.ts owns the triggers; this file owns the behaviour).
//
// Policy (documented in LAUNCH_CHECKLIST.md → Data lifecycle):
//   * disconnect deletes the couple's Firestore data (messages, chat state,
//     memories, plans, settings …) AND every Storage object under
//     couples/{coupleId}/ — chat images and memories are gone for good;
//   * account deletion does the same for the couple and additionally deletes
//     users/{uid}/ in Storage and the user document;
//   * the former partner loses access the moment the couple document is
//     deleted (every rule resolves membership through it);
//   * every step is idempotent and server-authoritative; Storage residue is
//     logged, never swallowed.

import type { firestore } from 'firebase-admin';
import {
  cleanupCoupleStorage,
  cleanupUserStorage,
  isValidStorageId,
  type CleanupBucket,
  type CleanupResult,
} from './storageCleanup';

export interface DissolveResult {
  /// False when the couple document was already gone (Storage still swept).
  existed: boolean;
  storage: CleanupResult;
}

/// Fully dissolves a couple: unlinks every member (coupleId -> null), deletes
/// any pending invite, deletes every Storage object under couples/{id}/, then
/// recursively deletes the couple doc + subcollections. Idempotent: safe to
/// call for a couple that is already gone.
export async function dissolveCouple(
  db: firestore.Firestore,
  bucket: CleanupBucket,
  coupleId: string,
): Promise<DissolveResult> {
  if (!isValidStorageId(coupleId)) throw new Error('invalid coupleId');
  const coupleRef = db.collection('couples').doc(coupleId);
  const coupleSnap = await coupleRef.get();

  if (coupleSnap.exists) {
    const members: string[] = coupleSnap.data()?.members ?? [];
    const inviteCode: string | undefined = coupleSnap.data()?.inviteCode ?? undefined;
    // Unlink every member so both partners return to the solo/invite screen.
    await Promise.all(
      members.map((m) =>
        db.collection('users').doc(m).update({ coupleId: null }).catch(() => {})
      )
    );
    if (inviteCode) {
      await db.collection('invites').doc(inviteCode).delete().catch(() => {});
    }
  }

  // Files first, then the document: while the document exists a residual
  // failure here can still be retried by the callers, and once it is deleted
  // the onCoupleDeleted safety net runs this same cleanup again.
  const storage = await cleanupCoupleStorage(bucket, coupleId);
  if (coupleSnap.exists) {
    await db.recursiveDelete(coupleRef);
  }
  return { existed: coupleSnap.exists, storage };
}

export interface DeleteUserDataResult {
  /// Human-readable step names that did not fully succeed (no user content).
  warnings: string[];
}

/// Everything deleteAccount removes BEFORE the Auth user: the user's own
/// Storage prefix, the couple (via dissolveCouple) and the user document.
/// Each step is attempted regardless of the previous one and is idempotent,
/// so a retried call finishes what an interrupted one started.
export async function deleteUserData(
  db: firestore.Firestore,
  bucket: CleanupBucket,
  uid: string,
): Promise<DeleteUserDataResult> {
  if (!isValidStorageId(uid)) throw new Error('invalid uid');
  const warnings: string[] = [];

  // Look up the couple before deleting the user doc.
  let coupleId: string | undefined;
  try {
    const userSnap = await db.collection('users').doc(uid).get();
    const raw = userSnap.data()?.coupleId;
    coupleId = typeof raw === 'string' && raw ? raw : undefined;
  } catch { warnings.push('read-user'); }

  // 1. The user's own Storage files (avatar, etc.).
  try {
    const r = await cleanupUserStorage(bucket, uid);
    if (r.failed > 0) warnings.push('storage-user');
  } catch (e) {
    console.error('[storageCleanup] user cleanup threw', (e as { code?: unknown })?.code ?? 'unknown');
    warnings.push('storage-user');
  }

  // 2. Dissolve the couple (unlinks every member, deletes couple Storage, the
  //    couple doc + subcollections and its invite).
  //
  //    SECURITY: users/{uid}.coupleId is client-writable and must NOT be
  //    trusted as proof of membership. Before touching the couple we read the
  //    authoritative couple document and confirm this uid is actually in its
  //    `members`. A spoofed, stale or foreign coupleId (couple missing, or the
  //    caller not a member) means we dissolve NOTHING — no unlink, no Storage
  //    deletion, no recursive delete of another couple's data — and only the
  //    caller's own account/user data is removed (steps 1 and 3). This mirrors
  //    the membership check disconnectPartner already performs.
  if (coupleId) {
    let isMember = false;
    try {
      const coupleSnap = await db.collection('couples').doc(coupleId).get();
      const rawMembers = coupleSnap.data()?.members;
      const members: string[] = Array.isArray(rawMembers)
        ? rawMembers.filter((m): m is string => typeof m === 'string')
        : [];
      isMember = coupleSnap.exists && members.includes(uid);
    } catch (e) {
      console.error('[lifecycle] couple membership read threw', (e as { code?: unknown })?.code ?? 'unknown');
      warnings.push('read-couple');
    }
    if (isMember) {
      try {
        const r = await dissolveCouple(db, bucket, coupleId);
        if (r.storage.failed > 0) warnings.push('storage-couple');
      } catch (e) {
        console.error('[lifecycle] dissolveCouple threw', (e as { code?: unknown })?.code ?? 'unknown');
        warnings.push('couple');
      }
    } else {
      // Not a member of the referenced couple — do not touch it.
      console.warn('[lifecycle] deleteAccount: caller not a member of referenced coupleId; skipping couple dissolution');
    }
  }

  // 3. The Firestore user doc (and any subcollections).
  try {
    await db.recursiveDelete(db.collection('users').doc(uid));
  } catch { warnings.push('firestore-user'); }

  return { warnings };
}

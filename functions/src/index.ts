import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { generateForCouple, generateTemporaryIdeas, getWeekNumber } from './generateWeeklyIdeas';
import { parseOverrides } from './preferences';
import { IDEA_LIBRARY, libraryIdeaDoc } from './ideasLibrary';
import { resolveCoverForIdea } from './ideaImages';
import OpenAI from 'openai';
import {
  isPartnerTemplateId,
  partnerMessageBody,
  partnerMessageTitle,
  reminderBody,
  reminderTitle,
  chatMessageTitle,
  chatIdeaBody,
  chatImageBody,
} from './notificationStrings';
import {
  chooseReminderType,
  DATE_ACTIVITIES,
  localParts,
  REMINDER_HOUR,
  QUALITY_TIME_ACTIVITIES,
  isRolloutEligible,
  readReminderPrefs,
  reminderStatePatch,
  type ReminderState,
} from './relationshipReminders';
import {
  partnerRateDecision,
  resolvePartnerTarget,
  type PartnerTargetFailure,
} from './partnerMessaging';
import {
  chatPushData,
  isFanoutableMessage,
  messagePreview,
  metaPreview,
  resolveChatRecipient,
} from './chatMessaging';
import { dissolveCouple, deleteUserData } from './coupleLifecycle';
import { cleanupCoupleStorage } from './storageCleanup';
import { createInviteTx, joinCoupleTx } from './pairing';

admin.initializeApp();

// Scheduled: every Sunday at 18:00 Oslo time
export const generateWeeklyIdeasScheduled = onSchedule(
  // generateForCouple -> callOpenAI and ensureCoverImages both read
  // process.env.OPENAI_API_KEY. A secret declared on a helper's own callable
  // does NOT propagate to other functions — it must be bound on every deployed
  // function that executes the code.
  {
    schedule: '0 18 * * 0',
    timeZone: 'Europe/Oslo',
    region: 'europe-west1',
    secrets: ['OPENAI_API_KEY'],
  },
  async () => {
    const snap = await admin.firestore()
      .collection('couples')
      .get();

    const results = await Promise.allSettled(
      snap.docs.map((doc) => generateForCouple(doc.id))
    );
    const failed = results.filter((r) => r.status === 'rejected').length;
    console.log(`Week ${getWeekNumber()}: generated for ${snap.size} couples (${failed} failed)`);
  }
);

// FCM helper: send to a user by uid
async function sendToUser(uid: string, title: string, body: string, data: Record<string, string>) {
  const userSnap = await admin.firestore().collection('users').doc(uid).get();
  if (!userSnap.exists) return;
  const token: string | undefined = userSnap.data()?.fcmToken;
  if (!token) return;
  await admin.messaging().send({ token, notification: { title, body }, data });
}

// Firestore trigger: FCM to partner when an idea request is created
export const onIdeaRequestCreated = onDocumentCreated(
  { document: 'couples/{coupleId}/ideaRequests/{requestId}', region: 'europe-west1' },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const coupleId: string = event.params.coupleId;
    const requestId: string = event.params.requestId;
    const senderName: string = data.senderName ?? 'Din partner';
    const ideaTitle: string = data.ideaTitle ?? '';
    const sentBy: string = data.sentBy ?? '';

    const coupleSnap = await admin.firestore().collection('couples').doc(coupleId).get();
    if (!coupleSnap.exists) return;

    const members: string[] = coupleSnap.data()?.members ?? [];
    const partnerId = members.find((id) => id !== sentBy);
    if (!partnerId) return;

    await sendToUser(partnerId,
      `${senderName} delte en idé`,
      `"${ideaTitle}" — trykk for å svare`,
      { type: 'idea_request', coupleId, requestId },
    );
  }
);

// Format a Firestore Timestamp as "fre 6. jun, 19:00" (NO) or "Fri Jun 6, 19:00" (EN)
function formatPlanDate(ts: admin.firestore.Timestamp, isNorwegian: boolean): string {
  const dt = ts.toDate();
  const shortDaysNo = ['Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør', 'Søn'];
  const shortDaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const monthsNo = ['jan', 'feb', 'mar', 'apr', 'mai', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'des'];
  const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const dayIdx = (dt.getDay() + 6) % 7; // Mon=0
  const monthIdx = dt.getMonth();
  const day = dt.getDate();
  const h = String(dt.getHours()).padStart(2, '0');
  const m = String(dt.getMinutes()).padStart(2, '0');
  return isNorwegian
    ? `${shortDaysNo[dayIdx]} ${day}. ${monthsNo[monthIdx]}, ${h}:${m}`
    : `${shortDaysEn[dayIdx]} ${monthsEn[monthIdx]} ${day}, ${h}:${m}`;
}

// Firestore trigger: FCM to sender when partner accepts/declines an idea request
export const onIdeaRequestUpdated = onDocumentUpdated(
  { document: 'couples/{coupleId}/ideaRequests/{requestId}', region: 'europe-west1' },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasAccepted = before.status !== 'accepted' && after.status === 'accepted';
    const wasDeclined = before.status !== 'declined' && after.status === 'declined';
    if (!wasAccepted && !wasDeclined) return;

    const coupleId: string = event.params.coupleId;
    const requestId: string = event.params.requestId;
    const sentBy: string = after.sentBy ?? '';
    const ideaTitle: string = after.ideaTitle ?? '';

    const coupleSnap = await admin.firestore().collection('couples').doc(coupleId).get();
    if (!coupleSnap.exists) return;

    const members: string[] = coupleSnap.data()?.members ?? [];
    const partnerId = members.find((id) => id !== sentBy);
    const partnerSnap = partnerId
      ? await admin.firestore().collection('users').doc(partnerId).get()
      : null;
    const partnerName: string = partnerSnap?.data()?.displayName ?? 'Din partner';

    // Look up sender's language preference for bilingual body.
    const senderSnap = await admin.firestore().collection('users').doc(sentBy).get();
    const language: string = senderSnap.data()?.language ?? 'no';
    const isNorwegian = language !== 'en';

    if (wasAccepted) {
      // Include plan date/time if B wrote it back to the request doc.
      const acceptedAt = after.acceptedAt as admin.firestore.Timestamp | undefined;
      const proposedAt = after.proposedAt as admin.firestore.Timestamp | undefined;
      const dateTs = acceptedAt ?? proposedAt;
      const datePart = dateTs ? ` – ${formatPlanDate(dateTs, isNorwegian)}` : '';

      const title = isNorwegian ? `${partnerName} sa ja! 🎉` : `${partnerName} said yes! 🎉`;
      const body = isNorwegian
        ? `${partnerName} godkjente «${ideaTitle}»${datePart}`
        : `${partnerName} accepted «${ideaTitle}»${datePart}`;

      await sendToUser(sentBy, title, body, { type: 'idea_accepted', coupleId, requestId });
    } else if (wasDeclined) {
      const title = isNorwegian ? 'Kanskje neste gang' : 'Maybe next time';
      const body = isNorwegian
        ? `${partnerName} takket nei til «${ideaTitle}»`
        : `${partnerName} declined «${ideaTitle}»`;

      await sendToUser(sentBy, title, body, { type: 'idea_declined', coupleId, requestId });
    }
  }
);

// Firestore trigger: FCM to partner when a plan is added
export const onWeeklyPlanCreated = onDocumentCreated(
  { document: 'couples/{coupleId}/weeklyPlan/{planId}', region: 'europe-west1' },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const coupleId: string = event.params.coupleId;
    const planId: string = event.params.planId;
    const sentBy: string = data.sentBy ?? '';
    const activity: string = data.activity ?? '';

    const senderSnap = await admin.firestore().collection('users').doc(sentBy).get();
    const senderName: string = senderSnap.data()?.displayName ?? 'Din partner';

    const coupleSnap = await admin.firestore().collection('couples').doc(coupleId).get();
    const members: string[] = coupleSnap.data()?.members ?? [];
    const partnerId = members.find((id) => id !== sentBy);
    if (!partnerId) return;

    await sendToUser(partnerId,
      `${senderName} la til en plan`,
      `"${activity}" — bekreft for å låse inn`,
      { type: 'plan_created', coupleId, planId },
    );
  }
);

// Firestore trigger: FCM to partner when a plan is cancelled (doc deleted)
export const onWeeklyPlanDeleted = onDocumentDeleted(
  { document: 'couples/{coupleId}/weeklyPlan/{planId}', region: 'europe-west1' },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const coupleId: string = event.params.coupleId;
    const sentBy: string = data.sentBy ?? '';
    const activity: string = data.activity ?? '';
    const dateTs = data.date as admin.firestore.Timestamp | undefined;

    const senderSnap = await admin.firestore().collection('users').doc(sentBy).get();
    const senderName: string = senderSnap.data()?.displayName ?? 'Din partner';
    const language: string = senderSnap.data()?.language ?? 'no';
    const isNorwegian = language !== 'en';

    const coupleSnap = await admin.firestore().collection('couples').doc(coupleId).get();
    if (!coupleSnap.exists) return;
    const members: string[] = coupleSnap.data()?.members ?? [];
    const partnerId = members.find((id) => id !== sentBy);
    if (!partnerId) return;

    const datePart = dateTs ? ` – ${formatPlanDate(dateTs, isNorwegian)}` : '';
    const body = isNorwegian
      ? `avlyste ${activity}${datePart}`
      : `cancelled ${activity}${datePart}`;

    await sendToUser(partnerId, senderName, body, { type: 'plan_cancelled', coupleId });
  }
);

// Invite cleanup: when a couple flips from pending -> active (a partner joined
// via joinByCode), delete the now-consumed invite. joinByCode sets inviteCode
// to null, so we read the code from the BEFORE snapshot.
export const onCoupleActivated = onDocumentUpdated(
  { document: 'couples/{coupleId}', region: 'europe-west1' },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const becameActive = before.status === 'pending' && after.status === 'active';
    if (!becameActive) return;

    const inviteCode: string | undefined = before.inviteCode ?? undefined;
    if (!inviteCode) return;

    await admin.firestore().collection('invites').doc(inviteCode).delete();
  }
);

// On-demand callable: triggered from app when weeklyIdeas is missing or stale
export const generateWeeklyIdeasNow = onCall(
  // See the note on generateWeeklyIdeasScheduled — same transitive dependency.
  { region: 'europe-west1', secrets: ['OPENAI_API_KEY'] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const coupleId: unknown = request.data?.coupleId;
    if (typeof coupleId !== 'string' || !coupleId) {
      throw new HttpsError('invalid-argument', 'coupleId is required');
    }
    const coupleSnap = await admin.firestore().collection('couples').doc(coupleId).get();
    if (!coupleSnap.exists) {
      throw new HttpsError('not-found', 'Couple not found');
    }
    const members: string[] = coupleSnap.data()?.members ?? [];
    if (!members.includes(request.auth.uid)) {
      throw new HttpsError('permission-denied', 'Not a member of this couple');
    }
    await generateForCouple(coupleId);
    return { success: true };
  }
);

// Callable: "For tonight" — a TEMPORARY idea set for one request. The
// bounded overrides (time, kids home / kid-free, locations) are validated
// here and steer only this generation. Nothing is written: the weekly set
// (weeklyIdeas/current), its history and both partners' preferences are
// untouched; the client shows the result and discards it. Separate from the
// weekly cooldown so adjusting the filters and trying again just works —
// bounded only by a per-couple hourly cap (premium runs cost an OpenAI call).
export const generateForTonight = onCall(
  { region: 'europe-west1', secrets: ['OPENAI_API_KEY'] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const coupleId: unknown = request.data?.coupleId;
    if (typeof coupleId !== 'string' || !coupleId) {
      throw new HttpsError('invalid-argument', 'coupleId is required');
    }
    const coupleSnap = await admin.firestore().collection('couples').doc(coupleId).get();
    if (!coupleSnap.exists) {
      throw new HttpsError('not-found', 'Couple not found');
    }
    const members: string[] = coupleSnap.data()?.members ?? [];
    if (!members.includes(request.auth.uid)) {
      throw new HttpsError('permission-denied', 'Not a member of this couple');
    }
    let overrides = null;
    try {
      overrides = parseOverrides(request.data?.overrides);
    } catch (e) {
      throw new HttpsError('invalid-argument', (e as Error).message);
    }
    // Cost cap: FOR_TONIGHT_MAX_PER_HOUR temporary generations per couple per
    // rolling hour, tracked in the server-only rateLimits collection.
    const limitRef = admin.firestore().collection('rateLimits').doc(`forTonight_${coupleId}`);
    const allowed = await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(limitRef);
      const now = Date.now();
      const windowStart: number = snap.data()?.windowStart ?? 0;
      const count: number = now - windowStart < 60 * 60 * 1000 ? (snap.data()?.count ?? 0) : 0;
      if (count >= FOR_TONIGHT_MAX_PER_HOUR) return false;
      tx.set(limitRef, { windowStart: count === 0 ? now : windowStart, count: count + 1 });
      return true;
    });
    if (!allowed) {
      throw new HttpsError('resource-exhausted', 'too-many-requests', { reason: 'too-many-requests' });
    }
    const result = await generateTemporaryIdeas(coupleId, overrides);
    if (!result) throw new HttpsError('not-found', 'Couple not found');
    return { ideas: result.ideas, generatedBy: result.generatedBy };
  }
);

const FOR_TONIGHT_MAX_PER_HOUR = 8;

// ── TEMPORARY (pre-launch, admin only): sync the idea library into Firestore
// and ensure every library idea has a cover, reusing existing ones first.
// Delete after the library backfill has run. Guarded by admin uid + token.
const ADMIN_UID = '1RTxZHUV1NbvNlFsXhwl5LeEgFw1';
const LIBRARY_SYNC_TOKEN = 'us-library-sync-2026-09-28';
export const adminSyncIdeaLibrary = onCall(
  { region: 'europe-west1', secrets: ['OPENAI_API_KEY'], timeoutSeconds: 540, memory: '512MiB' },
  async (request) => {
    if (!request.auth || request.auth.uid !== ADMIN_UID) {
      throw new HttpsError('permission-denied', 'admin only');
    }
    if (request.data?.token !== LIBRARY_SYNC_TOKEN) {
      throw new HttpsError('permission-denied', 'bad token');
    }
    const dryRun = request.data?.dryRun !== false;
    const maxNewImages = Math.min(Number(request.data?.maxNewImages ?? 0) || 0, 80);
    const firestore = admin.firestore();
    const deps = { firestore, bucket: admin.storage().bucket(), openai: new OpenAI({ apiKey: process.env.OPENAI_API_KEY }) };
    const out = { dryRun, docsWritten: 0, alreadyOk: 0, repaired: 0, generated: 0, failed: 0, wouldGenerate: [] as string[], errors: [] as string[] };
    let budget = maxNewImages;
    for (const idea of IDEA_LIBRARY) {
      if (!dryRun) {
        await firestore.collection('ideas').doc(idea.id).set(libraryIdeaDoc(idea), { merge: true });
        out.docsWritten++;
      }
      const source = { titleNo: idea.titleNo, titleEn: idea.titleEn, categoryNo: idea.categoryNo, categoryEn: idea.categoryEn, metaNo: idea.durationNo, metaEn: idea.durationEn, descriptionNo: idea.descNo, descriptionEn: idea.descEn, effort: idea.effort };
      if (dryRun) {
        const snap = await firestore.collection('ideas').doc(idea.id).get();
        const url = snap.data()?.coverImageUrl;
        if (typeof url === 'string' && url.startsWith('http')) { out.alreadyOk++; continue; }
        const [exists] = await deps.bucket.file(`ideas/${idea.id}/cover.jpg`).exists();
        if (exists) { out.repaired++; continue; }
        out.wouldGenerate.push(idea.id);
        continue;
      }
      const res = await resolveCoverForIdea(deps, source, idea.id, { allowGenerate: budget > 0 });
      if (res.outcome === 'generated') { budget--; out.generated++; }
      else if (res.outcome === 'already-ok') out.alreadyOk++;
      else if (res.outcome === 'repaired') out.repaired++;
      else { out.failed++; out.errors.push(`${idea.id}: ${res.error}`); }
    }
    console.log(`[librarySync] ${JSON.stringify({ ...out, wouldGenerate: out.wouldGenerate.length })}`);
    return out;
  }
);

// Callable: fully delete the caller's account. Runs with the Admin SDK so it
// can delete the Auth user WITHOUT a recent re-login. Ordering: Storage files
// and Firestore data first (idempotent), then the Auth account last, so a
// failure never leaves an orphaned login with its data already gone.
// Deleting your account dissolves the couple entirely: any partner is
// disconnected (their coupleId cleared) and the couple doc, subcollections,
// files and invite are removed.
export const deleteAccount = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const uid = request.auth.uid;

    // 1–3. Storage (users/{uid}/ and couples/{coupleId}/), the couple and the
    //      Firestore user doc — see coupleLifecycle.ts. Residual Storage
    //      failures are logged there and returned as warnings, never hidden.
    const { warnings } = await deleteUserData(admin.firestore(), admin.storage().bucket(), uid);
    if (warnings.length > 0) {
      console.error(`[lifecycle] deleteAccount finished with warnings: ${warnings.join(',')}`);
    }

    // 4. Delete the Auth account LAST. If this throws, the account still
    //    exists and the client can retry; the data steps above are idempotent.
    try {
      await admin.auth().deleteUser(uid);
    } catch {
      throw new HttpsError('internal', 'Could not delete account. Please try again.');
    }

    return { success: true, warnings };
  }
);

// Callable: create (or reuse) a pairing invite for the caller.
// Server-side on purpose (see pairing.ts): the caller's current relationship
// is validated with the Admin SDK — an ACTIVE couple rejects, a stale
// reference (couple gone / not a member / ended) is cleared — and the
// pending couple + invite are created atomically. The client never lists
// invites (the code is a shared secret).
export const createInvite = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const r = await createInviteTx(admin.firestore(), request.auth.uid);
    if (r.clearedStale) console.log('[pairing] createInvite cleared a stale coupleId');
    return { code: r.code, coupleId: r.coupleId };
  }
);

// Callable: join a pending couple by invite code. The code is the ONLY
// client input; the couple, inviter and both relationships are derived and
// validated server-side in one transaction, and the invite is consumed in
// the same commit (see pairing.ts). Failures carry details.reason:
// invalid-code | invite-expired | own-invite | already-paired |
// inviter-already-paired.
export const joinCouple = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const r = await joinCoupleTx(admin.firestore(), request.auth.uid, request.data?.code);
    if (r.cleared.joiner || r.cleared.inviter) {
      console.log(`[pairing] joinCouple cleared stale coupleId joiner=${r.cleared.joiner} inviter=${r.cleared.inviter}`);
    }
    return { coupleId: r.coupleId };
  }
);

// Callable: unilateral disconnect. Either partner can dissolve the couple
// immediately (no consent needed). Auth-gated; caller must be a member.
export const disconnectPartner = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const coupleId: unknown = request.data?.coupleId;
    if (typeof coupleId !== 'string' || !coupleId) {
      throw new HttpsError('invalid-argument', 'coupleId is required');
    }
    const coupleSnap = await admin.firestore().collection('couples').doc(coupleId).get();
    if (!coupleSnap.exists) {
      throw new HttpsError('not-found', 'Couple not found');
    }
    const members: string[] = coupleSnap.data()?.members ?? [];
    if (!members.includes(request.auth.uid)) {
      throw new HttpsError('permission-denied', 'Not a member of this couple');
    }
    await dissolveCouple(admin.firestore(), admin.storage().bucket(), coupleId);
    return { success: true };
  }
);

// Firestore trigger: safety net for couple Storage. dissolveCouple() is the
// primary cleanup path (files first, then the document); this re-runs the
// SAME idempotent helper after the document is gone, so a couple deleted by
// any other route (Console, script, a partial earlier run) never leaves
// chat images or memories behind. Zero files → no-op.
export const onCoupleDeleted = onDocumentDeleted(
  { document: 'couples/{coupleId}', region: 'europe-west1' },
  async (event) => {
    const coupleId: string = event.params.coupleId;
    try {
      await cleanupCoupleStorage(admin.storage().bucket(), coupleId);
    } catch (e) {
      console.error('[storageCleanup] onCoupleDeleted failed', (e as { code?: unknown })?.code ?? 'unknown');
    }
  }
);

// ── callOpenAI validation + rate limiting ────────────────────────────────────
const OPENAI_MAX_MESSAGES = 30;
const OPENAI_MAX_CONTENT_CHARS = 4000;   // per message
const OPENAI_MAX_TOTAL_CHARS = 12000;    // across all messages
const OPENAI_ALLOWED_ROLES = ['system', 'user', 'assistant'];
const OPENAI_WINDOW_MS = 10 * 60 * 1000; // 10 minutes
const OPENAI_MAX_CALLS = 20;             // per window per user

function validateMessages(messages: unknown): OpenAI.Chat.ChatCompletionMessageParam[] {
  if (!Array.isArray(messages) || messages.length === 0) {
    throw new HttpsError('invalid-argument', 'messages must be a non-empty array');
  }
  if (messages.length > OPENAI_MAX_MESSAGES) {
    throw new HttpsError('invalid-argument', `messages must not exceed ${OPENAI_MAX_MESSAGES} items`);
  }
  let total = 0;
  for (const m of messages) {
    if (typeof m !== 'object' || m === null) {
      throw new HttpsError('invalid-argument', 'each message must be an object');
    }
    const { role, content } = m as Record<string, unknown>;
    if (typeof role !== 'string' || !OPENAI_ALLOWED_ROLES.includes(role)) {
      throw new HttpsError('invalid-argument', 'each message.role must be system, user, or assistant');
    }
    if (typeof content !== 'string' || content.length === 0) {
      throw new HttpsError('invalid-argument', 'each message.content must be a non-empty string');
    }
    if (content.length > OPENAI_MAX_CONTENT_CHARS) {
      throw new HttpsError('invalid-argument', `message.content must not exceed ${OPENAI_MAX_CONTENT_CHARS} characters`);
    }
    total += content.length;
  }
  if (total > OPENAI_MAX_TOTAL_CHARS) {
    throw new HttpsError('invalid-argument', `total message content must not exceed ${OPENAI_MAX_TOTAL_CHARS} characters`);
  }
  return messages as OpenAI.Chat.ChatCompletionMessageParam[];
}

// Per-user sliding-window counter. Stored in `rateLimits` (no security rule →
// clients cannot read/write it). Throws resource-exhausted when over quota.
async function enforceOpenAIRateLimit(uid: string): Promise<void> {
  const ref = admin.firestore().collection('rateLimits').doc(`openai_${uid}`);
  await admin.firestore().runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    const now = Date.now();
    const windowStart: number = snap.exists ? (snap.data()?.windowStart ?? 0) : 0;
    const count: number = snap.exists ? (snap.data()?.count ?? 0) : 0;
    if (now - windowStart > OPENAI_WINDOW_MS) {
      txn.set(ref, { windowStart: now, count: 1 });
    } else if (count >= OPENAI_MAX_CALLS) {
      throw new HttpsError('resource-exhausted', 'Rate limit exceeded. Please try again later.');
    } else {
      txn.set(ref, { windowStart, count: count + 1 });
    }
  });
}

// Callable proxy for OpenAI — keeps the API key out of the client binary.
export const callOpenAI = onCall(
  { region: 'europe-west1', secrets: ['OPENAI_API_KEY'] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const maxTokens: unknown = request.data?.maxTokens;
    if (typeof maxTokens !== 'number' || maxTokens < 1 || maxTokens > 1000) {
      throw new HttpsError('invalid-argument', 'maxTokens must be a number between 1 and 1000');
    }
    const messages = validateMessages(request.data?.messages);

    // Validate first (cheap, rejects malformed input without touching quota),
    // then meter, then call OpenAI — so quota only counts real API calls.
    await enforceOpenAIRateLimit(request.auth.uid);

    const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      max_tokens: maxTokens,
      messages,
    });
    return { reply: completion.choices[0].message.content ?? '' };
  }
);

// ─── Relationship notifications ──────────────────────────────────────────────

// Max 3 partner messages per sender per Oslo day, and at least 30 minutes
// between sends. Stored in `rateLimits` (no security rule → client-inaccessible),
// same pattern as enforceOpenAIRateLimit above.
const PARTNER_TARGET_ERROR: Record<
  PartnerTargetFailure,
  { code: 'unauthenticated' | 'invalid-argument' | 'not-found' | 'failed-precondition' | 'permission-denied'; message: string }
> = {
  'unauthenticated': { code: 'unauthenticated', message: 'Login required' },
  'invalid-template': { code: 'invalid-argument', message: 'Unknown templateId' },
  'user-not-found': { code: 'not-found', message: 'User not found' },
  'no-couple': { code: 'failed-precondition', message: 'No partner connected' },
  'couple-not-found': { code: 'not-found', message: 'Couple not found' },
  'not-a-member': { code: 'permission-denied', message: 'Not a member of this couple' },
  'no-partner': { code: 'failed-precondition', message: 'No partner connected' },
};

// The daily bucket is the SENDER's own local calendar day — it is their quota.
// Senders on an old build with no timeZone fall back to the UTC day, so partner
// messaging keeps working for everyone (its security is unchanged).
async function enforcePartnerRateLimit(
  uid: string,
  now: Date,
  timeZone: unknown,
): Promise<void> {
  const local = localParts(now, timeZone);
  const day = local?.day ?? now.toISOString().slice(0, 10);
  const nowMs = now.getTime();
  const ref = admin.firestore().collection('rateLimits').doc(`partner_${uid}`);
  await admin.firestore().runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    const decision = partnerRateDecision(
      snap.exists ? snap.data() : undefined,
      day,
      nowMs,
    );
    if (!decision.allowed) {
      throw new HttpsError(
        'resource-exhausted',
        decision.reason === 'too-soon'
          ? 'Please wait a little before sending another message.'
          : 'Daily message limit reached. Try again tomorrow.',
      );
    }
    txn.set(ref, decision.next);
  });
}

/// Send a predefined message to the authenticated user's partner.
///
/// The client supplies ONLY a templateId. Sender identity, coupleId, partner
/// uid, the partner's FCM token, the sender's display name and the recipient's
/// language are all derived server-side. A client can neither name a recipient
/// nor supply copy.
export const sendPartnerNotification = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const senderId = request.auth.uid;

    const templateId: unknown = request.data?.templateId;
    if (!isPartnerTemplateId(templateId)) {
      throw new HttpsError('invalid-argument', 'Unknown templateId');
    }

    const firestore = admin.firestore();
    const senderSnap = await firestore.collection('users').doc(senderId).get();
    const senderData = senderSnap.exists ? senderSnap.data() : undefined;
    const senderCoupleId = typeof senderData?.coupleId === 'string' ? senderData.coupleId : '';
    const coupleSnap = senderCoupleId
      ? await firestore.collection('couples').doc(senderCoupleId).get()
      : undefined;

    const target = resolvePartnerTarget(
      senderId,
      senderData,
      coupleSnap?.exists ? coupleSnap.data() : undefined,
    );
    if (!target.ok) {
      throw new HttpsError(
        PARTNER_TARGET_ERROR[target.reason].code,
        PARTNER_TARGET_ERROR[target.reason].message,
      );
    }
    const { partnerId, coupleId } = target;

    // Recipient opt-out is personal and authoritative.
    const partnerSnap = await firestore.collection('users').doc(partnerId).get();
    if (partnerSnap.data()?.partnerMessagesEnabled === false) {
      // Not an error for the sender — the message is simply not delivered.
      return { success: true, delivered: false };
    }

    // Meter only after every guard has passed, so rejected calls cost no quota.
    await enforcePartnerRateLimit(senderId, new Date(), senderData?.timeZone);

    const senderName: string = senderSnap.data()?.name
      ?? senderSnap.data()?.displayName
      ?? 'Partneren din';
    const isNorwegian = (partnerSnap.data()?.language ?? 'no') !== 'en';

    // sendToUser no-ops when the recipient has no token — missing/expired
    // tokens must not fail the caller.
    try {
      await sendToUser(
        partnerId,
        partnerMessageTitle(isNorwegian),
        partnerMessageBody(templateId, senderName, isNorwegian),
        { type: 'partner_message', templateId, coupleId },
      );
    } catch (err) {
      // Never log tokens. Log the shape of the failure only.
      console.error(
        `sendPartnerNotification: FCM delivery failed for couple ${coupleId}`,
        err instanceof Error ? err.message : 'unknown error',
      );
      return { success: true, delivered: false };
    }

    return { success: true, delivered: true };
  }
);

/// Latest `lastDone` (ms) across the given activity ids, or 0 if never logged.
function latestLastDone(
  docs: admin.firestore.QueryDocumentSnapshot[],
  ids: readonly string[],
): number {
  let latest = 0;
  for (const doc of docs) {
    if (!ids.includes(doc.id)) continue;
    const ts = doc.data()?.lastDone;
    if (ts instanceof admin.firestore.Timestamp) {
      latest = Math.max(latest, ts.toMillis());
    }
  }
  return latest;
}

/// Hourly. Each run evaluates every couple and delivers to a user only when it
/// is REMINDER_HOUR (19:00) in that user's OWN timezone, so users in different
/// countries are notified at their own local evening rather than all at once.
///
/// Running hourly plus the per-user local-day guard means a user can still only
/// receive one automatic reminder per local day: the first run that matches
/// their local 19:00 writes lastReminderDay inside the transaction, and the
/// remaining 23 runs that day are no-ops for them.
export const relationshipReminderScheduler = onSchedule(
  { schedule: '0 * * * *', timeZone: 'Etc/UTC', region: 'europe-west1' },
  async () => {
    const firestore = admin.firestore();
    const now = new Date();
    const nowMs = now.getTime();

    const couples = await firestore.collection('couples').get();
    let sent = 0;
    let failed = 0;
    let skippedNotRolledOut = 0;
    let skippedWrongHour = 0;

    for (const coupleDoc of couples.docs) {
      try {
        const members: string[] = coupleDoc.data()?.members ?? [];
        if (members.length === 0) continue;

        // Only read the couple's activity log if at least one member is
        // actually due right now — most hours, nobody is.
        let qualityTimeLastDoneMs = -1;
        let dateLastDoneMs = -1;

        for (const uid of members) {
          const userSnap = await firestore.collection('users').doc(uid).get();
          if (!userSnap.exists) continue;
          const userData = userSnap.data();

          // Rollout gate: requires BOTH the client version marker and a valid
          // IANA timezone. Checked here to avoid a pointless transaction, and
          // again inside chooseReminderType as defence in depth.
          if (!isRolloutEligible(userData)) {
            skippedNotRolledOut++;
            continue;
          }

          // Every date/time decision below is made in THIS user's timezone.
          const local = localParts(now, userData?.timeZone);
          if (local === null) {
            // isRolloutEligible already validated it; this is belt-and-braces.
            skippedNotRolledOut++;
            continue;
          }
          if (local.hour !== REMINDER_HOUR) {
            skippedWrongHour++;
            continue;
          }

          if (qualityTimeLastDoneMs < 0) {
            const lastTimeSnap = await coupleDoc.ref.collection('lastTime').get();
            qualityTimeLastDoneMs = latestLastDone(lastTimeSnap.docs, QUALITY_TIME_ACTIVITIES);
            dateLastDoneMs = latestLastDone(lastTimeSnap.docs, DATE_ACTIVITIES);
          }

          const prefs = readReminderPrefs(userData);
          const stateRef = firestore.collection('rateLimits').doc(`relationship_${uid}`);

          // The decision and the state write share one transaction, so two
          // overlapping scheduler runs cannot both send to the same user.
          const chosen = await firestore.runTransaction(async (txn) => {
            const stateSnap = await txn.get(stateRef);
            const state: ReminderState = stateSnap.exists ? stateSnap.data() ?? {} : {};

            const type = chooseReminderType({
              rolloutEligible: true,
              nowMs,
              localDay: local.day,
              localHour: local.hour,
              isSunday: local.weekday === 0,
              qualityTimeLastDoneMs,
              dateLastDoneMs,
              state,
              prefs,
            });
            if (type === null) return null;

            txn.set(stateRef, reminderStatePatch(type, nowMs, local.day), { merge: true });
            return type;
          });

          if (chosen === null) continue;

          const isNorwegian = (userData?.language ?? 'no') !== 'en';
          await sendToUser(
            uid,
            reminderTitle(chosen, isNorwegian),
            reminderBody(chosen, isNorwegian),
            { type: 'relationship_reminder', reminderType: chosen, coupleId: coupleDoc.id },
          );
          sent++;
        }
      } catch (err) {
        failed++;
        console.error(
          `relationshipReminderScheduler: couple ${coupleDoc.id} failed`,
          err instanceof Error ? err.message : 'unknown error',
        );
      }
    }

    console.log(
      `Relationship reminders @${now.toISOString()}: sent ${sent}, `
      + `${skippedWrongHour} not local 19:00, `
      + `${skippedNotRolledOut} skipped (client not rolled out), `
      + `${failed} couple(s) failed`,
    );
  }
);


// ─── Partner chat ────────────────────────────────────────────────────────────

/// Fan-out for a new chat message: bump the recipient's server-owned unread
/// counter, refresh the last-message preview, and push.
///
/// The recipient is resolved from the couple's CURRENT members — never from
/// anything on the message the client wrote. Messages themselves are written
/// directly by the client (so they queue offline); this trigger only reacts.
export const onChatMessageCreated = onDocumentCreated(
  { document: 'couples/{coupleId}/messages/{messageId}', region: 'europe-west1' },
  async (event) => {
    const data = event.data?.data();
    const coupleId: string = event.params.coupleId;
    const messageId: string = event.params.messageId;
    if (!isFanoutableMessage(data)) return;

    const firestore = admin.firestore();
    const coupleSnap = await firestore.collection('couples').doc(coupleId).get();
    if (!coupleSnap.exists) return;
    const members: unknown = coupleSnap.data()?.members;

    const senderId = data!.senderId as string;
    const recipientId = resolveChatRecipient(senderId, members);
    if (!recipientId) return;

    const chat = firestore.collection('couples').doc(coupleId).collection('chat');
    const now = admin.firestore.FieldValue.serverTimestamp();

    // Server-owned state. Rules forbid clients from writing meta at all and
    // from writing anything but unread:0 to their own read doc.
    await Promise.all([
      chat.doc(`read_${recipientId}`).set(
        { unread: admin.firestore.FieldValue.increment(1) },
        { merge: true },
      ),
      chat.doc('meta').set({
        lastMessageAt: now,
        lastMessagePreview: metaPreview(data!),
        lastMessageSenderId: senderId,
        lastMessageType: data!.type,
      }, { merge: true }),
    ]);

    // Push, in the recipient's language, with the sender's display name.
    const [senderSnap, recipientSnap] = await Promise.all([
      firestore.collection('users').doc(senderId).get(),
      firestore.collection('users').doc(recipientId).get(),
    ]);
    const isNorwegian = (recipientSnap.data()?.language ?? 'no') !== 'en';
    const senderName: string = senderSnap.data()?.displayName ?? senderSnap.data()?.name ?? '';

    let body: string;
    if (data!.type === 'text') {
      body = messagePreview(data!.text as string);
    } else if (data!.type === 'image') {
      body = chatImageBody(senderName, isNorwegian);
    } else {
      const idea = data!.idea as { titleNo?: string; titleEn?: string };
      const title = (isNorwegian ? idea.titleNo : idea.titleEn) || idea.titleNo || idea.titleEn || '';
      body = chatIdeaBody(senderName, title, isNorwegian);
    }

    try {
      await sendToUser(
        recipientId,
        chatMessageTitle(senderName, isNorwegian),
        body,
        chatPushData(coupleId, messageId),
      );
    } catch (err) {
      // Never log message content or tokens.
      console.error(
        `onChatMessageCreated: push failed for couple ${coupleId}:`,
        err instanceof Error ? err.message : 'unknown error',
      );
    }
  }
);

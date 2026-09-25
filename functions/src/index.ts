import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { randomBytes } from 'crypto';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { generateForCouple, getWeekNumber } from './generateWeeklyIdeas';
import OpenAI from 'openai';
import {
  isPartnerTemplateId,
  partnerMessageBody,
  partnerMessageTitle,
  reminderBody,
  reminderTitle,
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

// Fully dissolves a couple: unlinks every member (coupleId -> null), deletes
// any pending invite, deletes the couple's Storage files, and recursively
// deletes the couple doc + subcollections. Best-effort on each sub-step.
// Shared by deleteAccount and disconnectPartner.
async function dissolveCouple(coupleId: string): Promise<void> {
  const firestore = admin.firestore();
  const bucket = admin.storage().bucket();
  const coupleRef = firestore.collection('couples').doc(coupleId);
  const coupleSnap = await coupleRef.get();
  if (!coupleSnap.exists) return;

  const members: string[] = coupleSnap.data()?.members ?? [];
  const inviteCode: string | undefined = coupleSnap.data()?.inviteCode ?? undefined;

  // Unlink every member so both partners return to the solo/invite screen.
  await Promise.all(
    members.map((m) =>
      firestore.collection('users').doc(m).update({ coupleId: null }).catch(() => {})
    )
  );
  if (inviteCode) {
    await firestore.collection('invites').doc(inviteCode).delete().catch(() => {});
  }
  await bucket.deleteFiles({ prefix: `couples/${coupleId}/` }).catch(() => {});
  await firestore.recursiveDelete(coupleRef);
}

// Callable: fully delete the caller's account. Runs with the Admin SDK so it
// can delete the Auth user WITHOUT a recent re-login. Ordering: Storage files
// and Firestore data first (best-effort), then the Auth account last, so a
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
    const firestore = admin.firestore();
    const bucket = admin.storage().bucket();
    const warnings: string[] = [];

    // Look up the couple before deleting the user doc.
    let coupleId: string | undefined;
    try {
      const userSnap = await firestore.collection('users').doc(uid).get();
      coupleId = userSnap.data()?.coupleId ?? undefined;
    } catch { warnings.push('read-user'); }

    // 1. Delete the user's Storage files (avatar, etc.).
    try {
      await bucket.deleteFiles({ prefix: `users/${uid}/` });
    } catch { warnings.push('storage-user'); }

    // 2. Dissolve the couple (unlinks every member, deletes the couple doc +
    //    subcollections, its invite, and its Storage files).
    if (coupleId) {
      try {
        await dissolveCouple(coupleId);
      } catch { warnings.push('couple'); }
    }

    // 3. Delete the Firestore user doc (and any subcollections).
    try {
      await firestore.recursiveDelete(firestore.collection('users').doc(uid));
    } catch { warnings.push('firestore-user'); }

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
// Runs server-side so the "reuse existing invite" lookup can query the invites
// collection with the Admin SDK — the client can no longer list/query invites
// (see firestore.rules). Creates the pending couple + invite docs atomically.
export const createInvite = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login required');
    }
    const uid = request.auth.uid;
    const firestore = admin.firestore();

    // Reuse an existing pending invite for this user, if any.
    const existing = await firestore
      .collection('invites')
      .where('fromUserId', '==', uid)
      .limit(1)
      .get();
    if (!existing.empty) {
      const doc = existing.docs[0];
      const coupleId: string = doc.data().coupleId ?? '';
      return { code: doc.id, coupleId };
    }

    // Generate a unique 8-char code. Charset excludes O/0/I/1 (32 chars, which
    // divides 256 evenly, so `byte % 32` has no modulo bias).
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code: string | null = null;
    for (let attempt = 0; attempt < 5; attempt++) {
      const bytes = randomBytes(8);
      let candidate = '';
      for (let i = 0; i < 8; i++) candidate += alphabet[bytes[i] % alphabet.length];
      const snap = await firestore.collection('invites').doc(candidate).get();
      if (!snap.exists) { code = candidate; break; }
    }
    if (!code) {
      throw new HttpsError('resource-exhausted', 'Could not generate a unique invite code. Try again.');
    }

    // Atomically create the pending couple doc and the invite doc.
    const coupleRef = firestore.collection('couples').doc();
    const batch = firestore.batch();
    batch.set(coupleRef, {
      members: [uid],
      status: 'pending',
      inviteCode: code,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.set(firestore.collection('invites').doc(code), {
      fromUserId: uid,
      coupleId: coupleRef.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return { code, coupleId: coupleRef.id };
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
    await dissolveCouple(coupleId);
    return { success: true };
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

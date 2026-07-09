import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { randomBytes } from 'crypto';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { generateForCouple, getWeekNumber } from './generateWeeklyIdeas';
import OpenAI from 'openai';

admin.initializeApp();

// Scheduled: every Sunday at 18:00 Oslo time
export const generateWeeklyIdeasScheduled = onSchedule(
  { schedule: '0 18 * * 0', timeZone: 'Europe/Oslo', region: 'europe-west1' },
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

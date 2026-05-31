import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { generateForCouple, getWeekNumber } from './generateWeeklyIdeas';

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

// On-demand callable: triggered from app when weeklyIdeas is missing or stale
export const generateWeeklyIdeasNow = onCall(
  { region: 'europe-west1' },
  async (request) => {
    const coupleId: unknown = request.data?.coupleId;
    if (typeof coupleId !== 'string' || !coupleId) {
      throw new HttpsError('invalid-argument', 'coupleId is required');
    }
    await generateForCouple(coupleId);
    return { success: true };
  }
);

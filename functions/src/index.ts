import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { generateForCouple, getWeekNumber } from './generateWeeklyIdeas';

admin.initializeApp();

// Scheduled: every Sunday at 18:00 Oslo time
export const generateWeeklyIdeasScheduled = onSchedule(
  { schedule: '0 18 * * 0', timeZone: 'Europe/Oslo', region: 'europe-west1' },
  async () => {
    const snap = await admin.firestore()
      .collection('couples')
      .where('subscriptionTier', 'in', ['premium', 'free'])
      .get();

    const results = await Promise.allSettled(
      snap.docs.map((doc) => generateForCouple(doc.id))
    );
    const failed = results.filter((r) => r.status === 'rejected').length;
    console.log(`Week ${getWeekNumber()}: generated for ${snap.size} couples (${failed} failed)`);
  }
);

// Firestore trigger: sends FCM to partner when an idea request is created
export const onIdeaRequestCreated = onDocumentCreated(
  { document: 'couples/{coupleId}/ideaRequests/{requestId}', region: 'europe-west1' },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const coupleId: string = event.params.coupleId;
    const requestId: string = event.params.requestId;
    const senderName: string = data.senderName ?? 'Din partner';
    const ideaTitle: string = data.ideaTitle ?? '';

    const coupleSnap = await admin.firestore().collection('couples').doc(coupleId).get();
    if (!coupleSnap.exists) return;

    const tokens: string[] = [coupleSnap.data()!.fcmToken1, coupleSnap.data()!.fcmToken2].filter(
      (t): t is string => typeof t === 'string' && t.length > 0
    );
    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `${senderName} delte en idé`,
        body: `"${ideaTitle}" — trykk for å svare`,
      },
      data: { type: 'idea_request', coupleId, requestId },
    });
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

import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
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

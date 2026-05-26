import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import OpenAI from 'openai';

admin.initializeApp();
const db = admin.firestore();

// Set via: firebase functions:secrets:set OPENAI_API_KEY
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// ─── Types ───────────────────────────────────────────────────────────────────

interface IdeaObject {
  title: string;
  category: string;
  meta: string;
  cardColor: string;
  tagColor: string;
  tagTextColor: string;
  iconName: string;
  description: string;
}

interface CoupleContext {
  name1: string;
  name2: string;
  city: string;
  duration: string;
  batteryLevel: number;
  moodLabel: string;
  season: string;
  lastTimeSummary: string;
  recentIdeas: string;
}

// ─── Main generation logic ───────────────────────────────────────────────────

async function generateForCouple(coupleId: string): Promise<void> {
  const coupleRef = db.collection('couples').doc(coupleId);
  const coupleSnap = await coupleRef.get();
  if (!coupleSnap.exists) {
    console.warn(`Couple ${coupleId} not found — skipping`);
    return;
  }
  const data = coupleSnap.data()!;
  const subscriptionTier: string = data.subscriptionTier ?? 'free';

  const ctx = await buildContext(coupleId, data);
  const weekNumber = getWeekNumber();

  let ideas: IdeaObject[];
  let generatedBy: 'ai' | 'curated';

  if (subscriptionTier === 'premium') {
    const prompt = buildPrompt(ctx);
    ideas = await callOpenAI(prompt);
    generatedBy = 'ai';

    // FCM: notify both partners
    const tokens: string[] = [data.fcmToken1, data.fcmToken2].filter(
      (t): t is string => typeof t === 'string' && t.length > 0
    );
    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: 'Nye ideer for uken',
          body: 'Vi har hentet frem 5 ideer til dere to denne uken',
        },
        data: { type: 'weekly_ideas', coupleId },
      });
    }
  } else {
    ideas = getCuratedIdeas(ctx.batteryLevel);
    generatedBy = 'curated';
  }

  // Archive current doc before overwriting
  const currentRef = coupleRef.collection('weeklyIdeas').doc('current');
  const currentSnap = await currentRef.get();
  if (currentSnap.exists) {
    await coupleRef.collection('weeklyIdeasHistory').add(currentSnap.data()!);
  }

  await currentRef.set({
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    weekNumber,
    generatedBy,
    ideas,
  });
}

async function buildContext(
  coupleId: string,
  coupleData: admin.firestore.DocumentData
): Promise<CoupleContext> {
  const name1: string = coupleData.name1 ?? 'Noah';
  const name2: string = coupleData.name2 ?? 'Sarah';
  const city: string = coupleData.city ?? 'Oslo';
  const batteryLevel: number = coupleData.batteryLevel ?? 72;
  const togetherSince: admin.firestore.Timestamp | null =
    coupleData.togetherSince ?? null;

  const duration = formatDuration(togetherSince);
  const season = currentSeason();
  const moodLabel = batteryMoodLabel(batteryLevel);

  // Last-time activities
  const lastTimeSnap = await db
    .collection('couples').doc(coupleId)
    .collection('lastTime').get();
  const lastTimeSummary = lastTimeSnap.docs.length > 0
    ? lastTimeSnap.docs
        .map((d) => `- ${d.id}: ${d.data().daysAgo ?? '?'} dager siden`)
        .join('\n')
    : 'Ingen aktiviteter registrert ennå.';

  // Recent ideas — last 3 history entries
  const historySnap = await db
    .collection('couples').doc(coupleId)
    .collection('weeklyIdeasHistory')
    .orderBy('generatedAt', 'desc')
    .limit(3)
    .get();
  const recentTitles = historySnap.docs.flatMap((d) => {
    const ideas: IdeaObject[] = d.data().ideas ?? [];
    return ideas.map((i) => i.title);
  });
  const recentIdeas = recentTitles.length > 0
    ? recentTitles.join(', ')
    : 'Ingen nylige ideer.';

  return { name1, name2, city, duration, batteryLevel, moodLabel, season, lastTimeSummary, recentIdeas };
}

// ─── OpenAI ──────────────────────────────────────────────────────────────────

function buildPrompt(ctx: CoupleContext): string {
  return `You are a warm, creative assistant helping a couple called ${ctx.name1} and ${ctx.name2} who live in ${ctx.city}.
They have been together for ${ctx.duration}.
Their relationship battery is at ${ctx.batteryLevel}% (${ctx.moodLabel}).
Current season: ${ctx.season}.

Recent activities they've done together:
${ctx.lastTimeSummary}

Ideas they've already seen recently:
${ctx.recentIdeas}

Generate exactly 5 fresh, specific date ideas for this week.
Each idea should feel personal and achievable.

Rules:
- Vary the categories: mix indoor, outdoor, quick, longer
- Reference their city naturally in at least 1–2 ideas
- Match energy to battery level (low = cosy/simple, high = adventurous)
- Avoid anything they've done in the last 2 weeks
- Keep titles short (2–4 words max)
- Norwegian language

Return valid JSON array only, no other text:
[
  {
    "title": "Kort + te",
    "category": "Minidate",
    "meta": "20 min · bare dere to",
    "cardColor": "#FAECE7",
    "tagColor": "#F5C4B3",
    "tagTextColor": "#712B13",
    "iconName": "coffee_outlined",
    "description": "Sett dere ned uten telefoner..."
  }
]

Card color options (pick fitting one per idea):
Minidate/cosy: #FAECE7 tag #F5C4B3/#712B13
Outdoor/active: #EAF3DE tag #C0DD97/#27500A
Home/longer: #FAEEDA tag #FAC775/#633806
Talk/connect: #E1F5EE tag #9FE1CB/#085041
Creative/fun: #FBEAF0 tag #F4C0D1/#72243E

Icon options:
coffee_outlined, directions_walk_outlined, tv_outlined,
style_outlined, local_cafe_outlined, restaurant_outlined,
park_outlined, sports_esports_outlined, music_note_outlined,
kitchen_outlined, beach_access_outlined, hiking_outlined,
casino_outlined, theater_comedy_outlined, palette_outlined`;
}

async function callOpenAI(prompt: string): Promise<IdeaObject[]> {
  const required = ['title', 'category', 'meta', 'cardColor', 'tagColor', 'tagTextColor', 'iconName', 'description'];

  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const response = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.8,
        max_tokens: 1500,
      });

      const content = response.choices[0]?.message?.content ?? '';
      const parsed: unknown = JSON.parse(content);

      if (!Array.isArray(parsed) || parsed.length !== 5) {
        throw new Error(`Expected 5 ideas, got ${Array.isArray(parsed) ? parsed.length : 'non-array'}`);
      }

      const ideas = parsed as Record<string, unknown>[];
      for (const idea of ideas) {
        for (const field of required) {
          if (!(field in idea)) throw new Error(`Missing field: ${field}`);
        }
      }

      return ideas as unknown as IdeaObject[];
    } catch (err) {
      console.error(`OpenAI attempt ${attempt + 1} failed:`, err);
      if (attempt === 1) {
        console.warn('Falling back to curated ideas after OpenAI failure');
        return getCuratedIdeas(72);
      }
    }
  }
  return getCuratedIdeas(72);
}

// ─── Curated fallback ────────────────────────────────────────────────────────

function getCuratedIdeas(batteryLevel: number): IdeaObject[] {
  const low = batteryLevel < 60;
  return [
    {
      title: low ? 'Kosekveldsfilm' : 'Ny restaurant',
      category: low ? 'Hjemme' : 'Ute',
      meta: low ? '2 timer · hjemme' : '2 timer · middag ute',
      cardColor: low ? '#FAEEDA' : '#EAF3DE',
      tagColor: low ? '#FAC775' : '#C0DD97',
      tagTextColor: low ? '#633806' : '#27500A',
      iconName: low ? 'tv_outlined' : 'restaurant_outlined',
      description: low
        ? 'Velg en film fra ønskelisten, legg fra dere telefonene og kos dere.'
        : 'Finn en restaurant dere aldri har prøvd. La den andre bestille for deg.',
    },
    {
      title: 'Kveldstur',
      category: 'Ute',
      meta: '30 min · uten telefoner',
      cardColor: '#EAF3DE',
      tagColor: '#C0DD97',
      tagTextColor: '#27500A',
      iconName: 'directions_walk_outlined',
      description: 'En rolig tur rundt kvartalet. Telefoner i lomma, bare prat og frisk luft.',
    },
    {
      title: 'Spørsmålskort',
      category: 'Minidate',
      meta: '20 min · i sofaen',
      cardColor: '#FAECE7',
      tagColor: '#F5C4B3',
      tagTextColor: '#712B13',
      iconName: 'coffee_outlined',
      description: 'Bruk en app eller skriv spørsmål på lapper. Finn ut noe nytt om hverandre.',
    },
    {
      title: 'Lag mat',
      category: 'Hjemme',
      meta: '1 time · lage noe nytt',
      cardColor: '#FAEEDA',
      tagColor: '#FAC775',
      tagTextColor: '#633806',
      iconName: 'kitchen_outlined',
      description: 'Velg en oppskrift ingen av dere har prøvd. Jobb sammen og ha det gøy.',
    },
    {
      title: 'Del en sang',
      category: 'Koble til',
      meta: '30 min · prat + musikk',
      cardColor: '#E1F5EE',
      tagColor: '#9FE1CB',
      tagTextColor: '#085041',
      iconName: 'music_note_outlined',
      description: 'Del en sang som betyr noe nå. Fortell hvorfor. La dem gjøre det samme.',
    },
  ];
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatDuration(ts: admin.firestore.Timestamp | null): string {
  if (!ts) return 'en stund';
  const months = Math.floor(
    (Date.now() - ts.toMillis()) / (30 * 24 * 60 * 60 * 1000)
  );
  const years = Math.floor(months / 12);
  const rem = months % 12;
  if (years > 0) return rem > 0 ? `${years} år og ${rem} måneder` : `${years} år`;
  return `${months} måneder`;
}

function currentSeason(): string {
  const m = new Date().getMonth();
  if (m >= 2 && m <= 4) return 'vår';
  if (m >= 5 && m <= 7) return 'sommer';
  if (m >= 8 && m <= 10) return 'høst';
  return 'vinter';
}

function batteryMoodLabel(pct: number): string {
  if (pct >= 80) return 'høy energi';
  if (pct >= 65) return 'god stemning';
  if (pct >= 50) return 'trenger en gnist';
  return 'trenger litt ekstra';
}

function getWeekNumber(): number {
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 1);
  return Math.ceil(
    ((now.getTime() - start.getTime()) / 86_400_000 + start.getDay() + 1) / 7
  );
}

// ─── Exports ─────────────────────────────────────────────────────────────────

// Scheduled: every Sunday at 18:00 Oslo time
export const generateWeeklyIdeasScheduled = onSchedule(
  { schedule: '0 18 * * 0', timeZone: 'Europe/Oslo', region: 'europe-west1' },
  async () => {
    const snap = await db
      .collection('couples')
      .where('subscriptionTier', 'in', ['premium', 'free'])
      .get();

    const results = await Promise.allSettled(
      snap.docs.map((doc) => generateForCouple(doc.id))
    );

    const failed = results.filter((r) => r.status === 'rejected').length;
    console.log(`Generated for ${snap.size} couples (${failed} failed)`);
  }
);

// On-demand callable: triggered when couple first subscribes to premium
export const generateWeeklyIdeas = onCall(
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

import * as admin from 'firebase-admin';
import OpenAI from 'openai';

// Set key via: firebase functions:secrets:set OPENAI_API_KEY
// Then access in v2 functions via: process.env.OPENAI_API_KEY
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const db = admin.firestore;

// ─── Types ───────────────────────────────────────────────────────────────────

export interface IdeaObject {
  title: string;
  category: string;
  meta: string;
  cardColor: string;
  tagColor: string;
  tagTextColor: string;
  iconName: string;
  description: string;
}

// ─── Main entry ──────────────────────────────────────────────────────────────

export async function generateForCouple(coupleId: string): Promise<void> {
  const firestore = db();
  const coupleRef = firestore.collection('couples').doc(coupleId);
  const coupleSnap = await coupleRef.get();
  if (!coupleSnap.exists) {
    console.warn(`Couple ${coupleId} not found — skipping`);
    return;
  }
  const data = coupleSnap.data()!;
  const subscriptionTier: string = data.subscriptionTier ?? 'free';

  const ctx = await buildContext(firestore, coupleId, data);
  const weekNumber = getWeekNumber();

  let ideas: IdeaObject[];
  let generatedBy: 'ai' | 'curated';

  if (subscriptionTier === 'premium') {
    ideas = await callOpenAI(buildPrompt(ctx));
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
          body: '5 nye ideer klare for dere to denne uken',
        },
        data: { type: 'weekly_ideas', coupleId },
      });
    }
  } else {
    // Free: score /ideas collection by season, battery, and recency
    ideas = await getCuratedIdeas(firestore, coupleId, ctx.batteryLevel, ctx.season);
    generatedBy = 'curated';
  }

  await coupleRef.collection('weeklyIdeas').doc('current').set({
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    weekNumber,
    generatedBy,
    ideas,
  });
}

// ─── Context gathering ───────────────────────────────────────────────────────

interface LifestyleData {
  weekdayTime: string;
  weekendTime: string;
  preference: string;
  parentMode: boolean;
  bedtimeWeekday?: string;
  bedtimeWeekend?: string;
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
  lifestyle: LifestyleData | null;
}

async function buildContext(
  firestore: admin.firestore.Firestore,
  coupleId: string,
  coupleData: admin.firestore.DocumentData
): Promise<CoupleContext> {
  const name1: string = coupleData.name1 ?? 'Noah';
  const name2: string = coupleData.name2 ?? 'Sarah';
  const city: string = coupleData.city ?? 'Oslo';
  const batteryLevel: number = coupleData.batteryLevel ?? 72;
  const togetherSince: admin.firestore.Timestamp | null = coupleData.togetherSince ?? null;

  const season = currentSeason();

  // Last-time activities
  const lastTimeSnap = await firestore
    .collection('couples').doc(coupleId)
    .collection('lastTime').get();
  const lastTimeSummary = lastTimeSnap.docs.length > 0
    ? lastTimeSnap.docs
        .map((d) => `- ${d.id}: ${d.data().daysAgo ?? '?'} dager siden`)
        .join('\n')
    : 'Ingen aktiviteter registrert ennå.';

  // Recent ideas — last 3 generated sets
  const recentSnap = await firestore
    .collection('couples').doc(coupleId)
    .collection('weeklyIdeasHistory')
    .orderBy('generatedAt', 'desc')
    .limit(3)
    .get();
  const recentTitles = recentSnap.docs.flatMap((d) =>
    ((d.data().ideas ?? []) as IdeaObject[]).map((i) => i.title)
  );
  const recentIdeas = recentTitles.length > 0
    ? recentTitles.join(', ')
    : 'Ingen nylige ideer.';

  // Lifestyle preferences
  const lifestyleSnap = await firestore
    .collection('couples').doc(coupleId)
    .collection('lifestyle').doc('data').get();
  const lifestyle: LifestyleData | null = lifestyleSnap.exists
    ? (lifestyleSnap.data() as LifestyleData)
    : null;

  return {
    name1,
    name2,
    city,
    duration: formatDuration(togetherSince),
    batteryLevel,
    moodLabel: batteryMoodLabel(batteryLevel),
    season,
    lastTimeSummary,
    recentIdeas,
    lifestyle,
  };
}

// ─── OpenAI ──────────────────────────────────────────────────────────────────

function buildLifestyleContext(lifestyle: LifestyleData | null): string {
  if (!lifestyle) return '';
  const weekdayMap: Record<string, string> = {
    under30: 'under 30 minutter',
    '30to60': '30–60 minutter',
    '2plus': '2+ timer',
  };
  const weekendMap: Record<string, string> = {
    little: 'litt tid (1–2 timer)',
    halfday: 'halv dag',
    fullday: 'hel dag',
  };
  const preferenceMap: Record<string, string> = {
    home: 'hjemme',
    out: 'ute',
    both: 'begge deler (hjemme og ute)',
  };
  const lines = [
    `Tilgjengelig tid hverdager: ${weekdayMap[lifestyle.weekdayTime] ?? lifestyle.weekdayTime}`,
    `Tilgjengelig tid helger: ${weekendMap[lifestyle.weekendTime] ?? lifestyle.weekendTime}`,
    `Preferanse: ${preferenceMap[lifestyle.preference] ?? lifestyle.preference}`,
    `Foreldremodus: ${lifestyle.parentMode ? 'ja' : 'nei'}`,
  ];
  if (lifestyle.parentMode) {
    if (lifestyle.bedtimeWeekday) lines.push(`Leggetid hverdager: ${lifestyle.bedtimeWeekday}`);
    if (lifestyle.bedtimeWeekend) lines.push(`Leggetid helger: ${lifestyle.bedtimeWeekend}`);
  }
  return '\n' + lines.join('\n');
}

function buildPrompt(ctx: CoupleContext): string {
  return `You are a warm creative assistant helping a couple called ${ctx.name1} and ${ctx.name2} who live in ${ctx.city}.
Together for ${ctx.duration}. Relationship battery: ${ctx.batteryLevel}% (${ctx.moodLabel}).
Season: ${ctx.season}.${buildLifestyleContext(ctx.lifestyle)}

Recent activities: ${ctx.lastTimeSummary}
Ideas seen recently: ${ctx.recentIdeas}

Generate exactly 5 fresh date ideas for this week.
Rules:
- Mix indoor/outdoor/quick/longer
- Reference their city in 1-2 ideas naturally
- Match energy to battery (low = cosy, high = adventurous)
- Avoid anything done in last 2 weeks
- Titles max 4 words
- Norwegian language

Return ONLY valid JSON, no other text:
[
  {
    "title": "Kort + te",
    "category": "Minidate",
    "meta": "20 min · bare dere to",
    "cardColor": "#FAECE7",
    "tagColor": "#F5C4B3",
    "tagTextColor": "#712B13",
    "iconName": "coffee_outlined",
    "description": "Sett dere ned uten telefoner og trekk et kort hver."
  }
]

Color options per category:
Minidate/cosy:   cardColor #FAECE7 tagColor #F5C4B3 tagText #712B13
Outdoor/active:  cardColor #EAF3DE tagColor #C0DD97 tagText #27500A
Home/longer:     cardColor #FAEEDA tagColor #FAC775 tagText #633806
Talk/connect:    cardColor #E1F5EE tagColor #9FE1CB tagText #085041
Creative/fun:    cardColor #FBEAF0 tagColor #F4C0D1 tagText #72243E

Icon options:
coffee_outlined, directions_walk_outlined, tv_outlined,
style_outlined, local_cafe_outlined, restaurant_outlined,
park_outlined, sports_esports_outlined, music_note_outlined,
kitchen_outlined, hiking_outlined, casino_outlined,
palette_outlined, theater_comedy_outlined`;
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
      if (attempt === 1) return getHardcodedFallback();
    }
  }
  return getHardcodedFallback();
}

// ─── Free tier: scored curation ──────────────────────────────────────────────

async function getCuratedIdeas(
  firestore: admin.firestore.Firestore,
  coupleId: string,
  batteryLevel: number,
  season: string
): Promise<IdeaObject[]> {
  // Fetch lastTime to know what to avoid
  const lastTimeSnap = await firestore
    .collection('couples').doc(coupleId)
    .collection('lastTime').get();
  const recentIds = new Set(
    lastTimeSnap.docs
      .filter((d) => (d.data().daysAgo ?? 99) <= 14)
      .map((d) => d.id)
  );

  const ideasSnap = await firestore.collection('ideas').get();
  const scored = ideasSnap.docs.map((d) => {
    const data = d.data();
    let score = 0;
    if (!recentIds.has(d.id)) score += 3;
    if (data.season === season || !data.season) score += 1;
    if (batteryLevel < 60 && data.effort === 'low') score += 2;
    if (batteryLevel >= 70 && data.effort === 'high') score += 2;
    return { data, score };
  });

  scored.sort((a, b) => b.score - a.score);
  const top5 = scored.slice(0, 5).map((s) => s.data as IdeaObject);
  return top5.length === 5 ? top5 : getHardcodedFallback();
}

// ─── Hardcoded fallback ───────────────────────────────────────────────────────

function getHardcodedFallback(): IdeaObject[] {
  return [
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
      description: 'Trekk spørsmål fra en app. Finn ut noe nytt om hverandre i kveld.',
    },
    {
      title: 'Lag mat',
      category: 'Hjemme',
      meta: '1 time · ny oppskrift',
      cardColor: '#FAEEDA',
      tagColor: '#FAC775',
      tagTextColor: '#633806',
      iconName: 'kitchen_outlined',
      description: 'Velg en oppskrift ingen av dere har prøvd. Jobb sammen og ha det gøy.',
    },
    {
      title: 'Del en sang',
      category: 'Koble til',
      meta: '30 min · musikk + prat',
      cardColor: '#E1F5EE',
      tagColor: '#9FE1CB',
      tagTextColor: '#085041',
      iconName: 'music_note_outlined',
      description: 'Del en sang som betyr noe for deg nå. Fortell hvorfor. La dem gjøre det samme.',
    },
    {
      title: 'Tegn hverandre',
      category: 'Kreativt',
      meta: '20 min · papir + blyant',
      cardColor: '#FBEAF0',
      tagColor: '#F4C0D1',
      tagTextColor: '#72243E',
      iconName: 'palette_outlined',
      description: 'Sett en timer på 10 minutter og tegn den andre. Ingen regel om å være flink.',
    },
  ];
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatDuration(ts: admin.firestore.Timestamp | null): string {
  if (!ts) return 'en stund';
  const months = Math.floor((Date.now() - ts.toMillis()) / (30 * 24 * 60 * 60 * 1000));
  const years = Math.floor(months / 12);
  const rem = months % 12;
  if (years > 0) return rem > 0 ? `${years} år og ${rem} måneder` : `${years} år`;
  return `${months} måneder`;
}

export function currentSeason(): string {
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

export function getWeekNumber(): number {
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 1);
  return Math.ceil(
    ((now.getTime() - start.getTime()) / 86_400_000 + start.getDay() + 1) / 7
  );
}

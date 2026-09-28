import * as admin from 'firebase-admin';
import OpenAI from 'openai';
import { ensureCoverImages, isImageGenEnabledFor, type CoverImageResult } from './ideaImages';
import {
  applyOverrides,
  deriveCoupleProfile,
  legacyPrefsFromMain,
  lifestyleContextLines,
  normalizeUserPrefs,
  preferredEffort,
  type CoupleProfile,
  type SessionOverrides,
} from './preferences';

// Set key via: firebase functions:secrets:set OPENAI_API_KEY
// Instantiated lazily inside callOpenAI so module load never crashes without the key.

const db = admin.firestore;

/// How a weekly set was produced. 'fallback' means OpenAI failed and the
/// hardcoded list was served — it must never be reported as 'ai'.
export type GeneratedBy = 'ai' | 'curated' | 'fallback';

/// Control-flow marker for "images intentionally not generated" — not an error.
class SkipImages extends Error {}

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
  titleNo?: string;
  titleEn?: string;
  categoryNo?: string;
  categoryEn?: string;
  metaNo?: string;
  metaEn?: string;
  descriptionNo?: string;
  descriptionEn?: string;
  season?: string;
  effort?: string;
}

// ─── Main entry ──────────────────────────────────────────────────────────────

/// Summary of what a run did, so callers (and the pre-launch test trigger) can
/// report accurate numbers instead of inferring them from logs.
export interface GenerationSummary {
  coupleId: string;
  subscriptionTier: string;
  generatedBy: GeneratedBy | null;
  /// True when OpenAI failed and the hardcoded fallback list was served.
  usedFallback: boolean;
  titles: string[];
  archivedTo: string | null;
  images: CoverImageResult | null;
  imageError: string | null;
}

export async function generateForCouple(coupleId: string): Promise<GenerationSummary> {
  const summary: GenerationSummary = {
    coupleId,
    subscriptionTier: 'unknown',
    generatedBy: null,
    usedFallback: false,
    titles: [],
    archivedTo: null,
    images: null,
    imageError: null,
  };
  const firestore = db();
  const coupleRef = firestore.collection('couples').doc(coupleId);
  const coupleSnap = await coupleRef.get();
  if (!coupleSnap.exists) {
    console.warn(`Couple ${coupleId} not found — skipping`);
    return summary;
  }
  const data = coupleSnap.data()!;
  const subscriptionTier: string = data.subscriptionTier ?? 'free';
  summary.subscriptionTier = subscriptionTier;

  const ctx = await buildContext(firestore, coupleId, data, null);
  const weekNumber = getWeekNumber();
  console.log(
    `generateForCouple: profile source=${ctx.profile.source} `
    + `time=${ctx.profile.availableTime} parent=${ctx.profile.isParent} care=${ctx.profile.childcareState} `
    + `locations=${ctx.profile.locations.map((l) => `${l.id}:${l.weight}`).join(',')}`,
  );

  let ideas: IdeaObject[];
  let generatedBy: GeneratedBy;

  if (subscriptionTier === 'premium') {
    // callOpenAI reports whether the hardcoded fallback was served, so a
    // failed OpenAI call is never mislabelled as AI content.
    const aiResult = await callOpenAI(buildPrompt(ctx));
    ideas = aiResult.ideas;
    generatedBy = aiResult.usedFallback ? 'fallback' : 'ai';
    summary.usedFallback = aiResult.usedFallback;

    // Premium only, and only for couples on the image rollout allowlist, so a
    // paid image call can never be triggered by organic traffic during testing.
    // Never throws — a failed image must not cost the couple their weekly ideas.
    try {
      const members: string[] = data.members ?? [];
      // Pre-launch diagnostic: makes the uid -> couple -> tier mapping visible
      // in the logs without any client-side inspection. Read-only.
      console.log(
        `ideaImages diagnostic: couple ${coupleId} tier=${subscriptionTier} `
        + `members=${JSON.stringify(members)} `
        + `allowlisted=${isImageGenEnabledFor(members)}`,
      );
      // Never buy cover images for fallback content: if OpenAI could not
      // produce the ideas, paying for images of them is wasted spend.
      if (aiResult.usedFallback) {
        console.log(`ideaImages: couple ${coupleId} served fallback ideas — image step skipped`);
        throw new SkipImages();
      }
      if (!isImageGenEnabledFor(members)) {
        console.log(`ideaImages: couple ${coupleId} has no allowlisted member — skipped`);
        throw new SkipImages();
      }
      summary.images = await ensureCoverImages(
        {
          firestore,
          bucket: admin.storage().bucket(),
          openai: new OpenAI({ apiKey: process.env.OPENAI_API_KEY }),
        },
        ideas,
        coupleId,
      );
    } catch (err) {
      if (!(err instanceof SkipImages)) {
        summary.imageError = err instanceof Error ? err.message : 'unknown error';
        console.error(
          `generateForCouple: cover image step failed for ${coupleId}:`,
          summary.imageError,
        );
      }
    }

    // FCM: notify both partners — tokens live on user docs, not the couple doc
    const members: string[] = data.members ?? [];
    const userSnaps = await Promise.all(
      members.map((uid) => firestore.collection('users').doc(uid).get())
    );
    const tokens: string[] = userSnaps
      .map((s) => s.data()?.fcmToken)
      .filter((t): t is string => typeof t === 'string' && t.length > 0);
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
    ideas = await getCuratedIdeas(firestore, coupleId, ctx.batteryLevel, ctx.season, preferredEffort(ctx.profile));
    generatedBy = 'curated';
  }

  // Archive the outgoing set BEFORE overwriting it. buildContext() has always
  // read weeklyIdeasHistory to steer the prompt away from recent repeats, but
  // nothing ever wrote that collection — so the anti-repetition context was
  // permanently empty. Writing it here makes the existing read work.
  try {
    const currentRef = coupleRef.collection('weeklyIdeas').doc('current');
    const previous = await currentRef.get();
    if (previous.exists) {
      const prev = previous.data() ?? {};
      const archiveId = `week_${prev.weekNumber ?? 'unknown'}_${previous.updateTime?.toMillis() ?? Date.now()}`;
      summary.archivedTo = `couples/${coupleId}/weeklyIdeasHistory/${archiveId}`;
      await coupleRef.collection('weeklyIdeasHistory').doc(archiveId).set({
        generatedAt: prev.generatedAt ?? admin.firestore.FieldValue.serverTimestamp(),
        weekNumber: prev.weekNumber ?? null,
        generatedBy: prev.generatedBy ?? null,
        ideas: prev.ideas ?? [],
      });
      await pruneHistory(coupleRef);
    }
  } catch (err) {
    // Archiving is best-effort: never block this week's ideas on it.
    console.error(
      `generateForCouple: history archive failed for ${coupleId}:`,
      err instanceof Error ? err.message : 'unknown error',
    );
  }

  await coupleRef.collection('weeklyIdeas').doc('current').set({
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    weekNumber,
    generatedBy,
    ideas,
  });

  summary.generatedBy = generatedBy;
  summary.titles = ideas.map((i) => (i.titleNo ?? '').trim() || i.title || '');
  return summary;
}

/// "For tonight": a TEMPORARY recommendation set for one request. Reuses the
/// same context, profile derivation, prompt and curation as the weekly run,
/// with the per-session overrides applied — but writes nothing: the weekly
/// set, its history and everyone's preferences stay exactly as they are.
/// No cover images and no push either; the result is returned to the caller
/// and discarded when they close it.
export interface TemporaryIdeasResult {
  ideas: IdeaObject[];
  generatedBy: GeneratedBy;
  profile: CoupleProfile;
}

export async function generateTemporaryIdeas(
  coupleId: string,
  overrides: SessionOverrides | null,
): Promise<TemporaryIdeasResult | null> {
  const firestore = db();
  const coupleSnap = await firestore.collection('couples').doc(coupleId).get();
  if (!coupleSnap.exists) return null;
  const data = coupleSnap.data()!;
  const subscriptionTier: string = data.subscriptionTier ?? 'free';
  const ctx = await buildContext(firestore, coupleId, data, overrides);
  console.log(
    `generateTemporaryIdeas: couple=${coupleId} tier=${subscriptionTier} overridden=${ctx.profile.overridden} `
    + `time=${ctx.profile.availableTime} care=${ctx.profile.childcareState} `
    + `locations=${ctx.profile.locations.map((l) => l.id).join(',')}`,
  );
  if (subscriptionTier === 'premium') {
    const ai = await callOpenAI(buildPrompt(ctx));
    return { ideas: ai.ideas, generatedBy: ai.usedFallback ? 'fallback' : 'ai', profile: ctx.profile };
  }
  const ideas = await getCuratedIdeas(firestore, coupleId, ctx.batteryLevel, ctx.season, preferredEffort(ctx.profile));
  return { ideas, generatedBy: 'curated', profile: ctx.profile };
}

/// Keep a bounded window of recent weeks — buildContext() only reads the last
/// 3, so anything older is dead weight.
const HISTORY_KEEP = 8;

async function pruneHistory(
  coupleRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const snap = await coupleRef
    .collection('weeklyIdeasHistory')
    .orderBy('generatedAt', 'desc')
    .offset(HISTORY_KEEP)
    .get();
  if (snap.empty) return;
  const batch = coupleRef.firestore.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

// ─── Context gathering ───────────────────────────────────────────────────────

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
  profile: CoupleProfile;
}

async function buildContext(
  firestore: admin.firestore.Firestore,
  coupleId: string,
  coupleData: admin.firestore.DocumentData,
  overrides: SessionOverrides | null,
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

  // Preferences: per-user raw answers (settings/prefs_{uid}) derived into one
  // couple profile; legacy settings/main is the fallback for RC1 couples;
  // defaults only when neither exists. Every field is optional.
  const settings = firestore.collection('couples').doc(coupleId).collection('settings');
  const members: string[] = Array.isArray(coupleData.members)
    ? coupleData.members.filter((m: unknown): m is string => typeof m === 'string')
    : [];
  const [mainSnap, ...prefSnaps] = await Promise.all([
    settings.doc('main').get(),
    ...members.map((uid) => settings.doc(`prefs_${uid}`).get()),
  ]);
  const users = prefSnaps.map((s) => (s.exists ? normalizeUserPrefs(s.data() ?? {}) : null));
  const legacy = mainSnap.exists ? legacyPrefsFromMain(mainSnap.data() ?? {}) : null;
  const profile = applyOverrides(deriveCoupleProfile(users, legacy), overrides);

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
    profile,
  };
}

// ─── OpenAI ──────────────────────────────────────────────────────────────────

function buildLifestyleContext(profile: CoupleProfile): string {
  return '\n' + lifestyleContextLines(profile).join('\n');
}

function buildPrompt(ctx: CoupleContext): string {
  return `You are a warm creative assistant helping a couple called ${ctx.name1} and ${ctx.name2} who live in ${ctx.city}.
Together for ${ctx.duration}. Relationship battery: ${ctx.batteryLevel}% (${ctx.moodLabel}).
Season: ${ctx.season}.${buildLifestyleContext(ctx.profile)}

Recent activities: ${ctx.lastTimeSummary}
Ideas seen recently: ${ctx.recentIdeas}

Generate exactly 5 fresh date ideas for this week.
Rules:
- Mix indoor/outdoor/quick/longer
- Reference their city in 1-2 ideas naturally
- Match energy to battery (low = cosy, high = adventurous)
- Avoid anything done in last 2 weeks
- Respect the available time and the parent/childcare situation above; if a line starts with "I KVELD" it describes tonight only and outranks the usual preferences
- Prefer the places they like; places both prefer come first
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

export interface OpenAIIdeasResult {
  ideas: IdeaObject[];
  usedFallback: boolean;
}

async function callOpenAI(prompt: string): Promise<OpenAIIdeasResult> {
  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
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
      return { ideas: ideas as unknown as IdeaObject[], usedFallback: false };
    } catch (err) {
      console.error(
        `OpenAI attempt ${attempt + 1} failed: `
        + `${err instanceof Error ? err.message : 'unknown error'}`,
      );
      if (attempt === 1) return { ideas: getHardcodedFallback(), usedFallback: true };
    }
  }
  return { ideas: getHardcodedFallback(), usedFallback: true };
}

// ─── Free tier: scored curation ──────────────────────────────────────────────

async function getCuratedIdeas(
  firestore: admin.firestore.Firestore,
  coupleId: string,
  batteryLevel: number,
  season: string,
  effortNudge: 'low' | 'high' | null = null,
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
  const scored = ideasSnap.docs
    .filter((d) => {
      const data = d.data();
      return (typeof data.title === 'string' && data.title.length > 0) ||
             (typeof data.titleNo === 'string' && data.titleNo.length > 0);
    })
    .map((d) => {
      const data = d.data();
      let score = 0;
      if (!recentIds.has(d.id)) score += 3;
      if (data.season === season || !data.season) score += 1;
      if (batteryLevel < 60 && data.effort === 'low') score += 2;
      if (batteryLevel >= 70 && data.effort === 'high') score += 2;
      // Time available (derived couple profile / "For tonight"): a few hours
      // favours low-effort ideas, a whole day favours high-effort ones.
      if (effortNudge && data.effort === effortNudge) score += 2;
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
      title: 'Kveldstur', titleNo: 'Kveldstur', titleEn: 'Evening walk',
      category: 'Ute', categoryNo: 'Ute', categoryEn: 'Outside',
      meta: '30 min · uten telefoner', metaNo: '30 min · uten telefoner', metaEn: '30 min · no phones',
      cardColor: '#EAF3DE', tagColor: '#C0DD97', tagTextColor: '#27500A',
      iconName: 'directions_walk_outlined',
      description: 'En rolig tur rundt kvartalet. Telefoner i lomma, bare prat og frisk luft.',
      descriptionNo: 'En rolig tur rundt kvartalet. Telefoner i lomma, bare prat og frisk luft.',
      descriptionEn: 'A quiet walk around the block. Phones in pockets, just talk and fresh air.',
    },
    {
      title: 'Spørsmålskort', titleNo: 'Spørsmålskort', titleEn: 'Question cards',
      category: 'Minidate', categoryNo: 'Minidate', categoryEn: 'Mini-date',
      meta: '20 min · i sofaen', metaNo: '20 min · i sofaen', metaEn: '20 min · on the couch',
      cardColor: '#FAECE7', tagColor: '#F5C4B3', tagTextColor: '#712B13',
      iconName: 'coffee_outlined',
      description: 'Trekk spørsmål fra en app. Finn ut noe nytt om hverandre i kveld.',
      descriptionNo: 'Trekk spørsmål fra en app. Finn ut noe nytt om hverandre i kveld.',
      descriptionEn: 'Draw questions from an app. Find out something new about each other tonight.',
    },
    {
      title: 'Lag mat', titleNo: 'Lag mat', titleEn: 'Cook together',
      category: 'Hjemme', categoryNo: 'Hjemme', categoryEn: 'At home',
      meta: '1 time · ny oppskrift', metaNo: '1 time · ny oppskrift', metaEn: '1 hour · new recipe',
      cardColor: '#FAEEDA', tagColor: '#FAC775', tagTextColor: '#633806',
      iconName: 'kitchen_outlined',
      description: 'Velg en oppskrift ingen av dere har prøvd. Jobb sammen og ha det gøy.',
      descriptionNo: 'Velg en oppskrift ingen av dere har prøvd. Jobb sammen og ha det gøy.',
      descriptionEn: 'Choose a recipe no one has tried. Work together and have fun.',
    },
    {
      title: 'Del en sang', titleNo: 'Del en sang', titleEn: 'Share a song',
      category: 'Koble til', categoryNo: 'Koble til', categoryEn: 'Connect',
      meta: '30 min · musikk + prat', metaNo: '30 min · musikk + prat', metaEn: '30 min · music + talk',
      cardColor: '#E1F5EE', tagColor: '#9FE1CB', tagTextColor: '#085041',
      iconName: 'music_note_outlined',
      description: 'Del en sang som betyr noe for deg nå. Fortell hvorfor. La dem gjøre det samme.',
      descriptionNo: 'Del en sang som betyr noe for deg nå. Fortell hvorfor. La dem gjøre det samme.',
      descriptionEn: 'Share a song that means something to you right now. Say why. Let them do the same.',
    },
    {
      title: 'Tegn hverandre', titleNo: 'Tegn hverandre', titleEn: 'Draw each other',
      category: 'Kreativt', categoryNo: 'Kreativt', categoryEn: 'Creative',
      meta: '20 min · papir + blyant', metaNo: '20 min · papir + blyant', metaEn: '20 min · pen + paper',
      cardColor: '#FBEAF0', tagColor: '#F4C0D1', tagTextColor: '#72243E',
      iconName: 'palette_outlined',
      description: 'Sett en timer på 10 minutter og tegn den andre. Ingen regel om å være flink.',
      descriptionNo: 'Sett en timer på 10 minutter og tegn den andre. Ingen regel om å være flink.',
      descriptionEn: 'Set a timer for 10 minutes and draw each other. No rule about being good.',
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

#!/usr/bin/env node
// Seed 50 bilingual date ideas into /ideas Firestore collection.
// Auth: uses Firebase CLI's stored OAuth tokens — no service account key needed.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

// ─── Auth setup ──────────────────────────────────────────────────────────────

function buildAdcFile() {
  const configPath = path.join(
    os.homedir(), '.config', 'configstore', 'firebase-tools.json'
  );
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const tokens = config.tokens;
  if (!tokens || !tokens.refresh_token) {
    throw new Error('No Firebase CLI tokens found. Run `firebase login` first.');
  }
  const api = require('/usr/local/lib/node_modules/firebase-tools/lib/api.js');
  const adcObj = {
    type: 'authorized_user',
    client_id: api.clientId ? api.clientId() : '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: api.clientSecret(),
    refresh_token: tokens.refresh_token,
  };
  const tmpFile = path.join(os.tmpdir(), 'us_app_adc.json');
  fs.writeFileSync(tmpFile, JSON.stringify(adcObj));
  return tmpFile;
}

const adcPath = buildAdcFile();
process.env.GOOGLE_APPLICATION_CREDENTIALS = adcPath;

// ─── Firebase Admin ───────────────────────────────────────────────────────────

const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'us-app-4bf30',
});
const db = admin.firestore();

// ─── Helpers ──────────────────────────────────────────────────────────────────

function toId(norwegianTitle) {
  return norwegianTitle
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9æøå]+/g, '_')
    .replace(/^_|_$/g, '');
}

// ─── Category color palettes ──────────────────────────────────────────────────

const COLORS = {
  Hjemme:    { cardColor: '#FFF8F0', tagColor: '#FAECE7', tagTextColor: '#993C1D' },
  Ute:       { cardColor: '#EAF3DE', tagColor: '#C0DD97', tagTextColor: '#27500A' },
  Romantisk: { cardColor: '#FBEAF0', tagColor: '#F4C0D1', tagTextColor: '#72243E' },
  Aktiv:     { cardColor: '#E6F1FB', tagColor: '#B5D4F4', tagTextColor: '#0C447C' },
  Sosialt:   { cardColor: '#FAEEDA', tagColor: '#FAC775', tagTextColor: '#633806' },
};

// ─── 50 ideas ─────────────────────────────────────────────────────────────────

const IDEAS = [
  {
    titleNo: 'Lag mat sammen', titleEn: 'Cook together',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Velg en ny oppskrift og lag den sammen',
    descriptionEn: 'Pick a new recipe and cook it together',
    iconName: 'restaurant_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Kveldstur', titleEn: 'Evening walk',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '30 min', metaEn: '30 min',
    descriptionNo: 'En rolig tur i nabolaget uten telefoner',
    descriptionEn: 'A quiet walk around the neighborhood without phones',
    iconName: 'directions_walk_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Filmkveld', titleEn: 'Movie night',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '2 timer', metaEn: '2 hours',
    descriptionNo: 'Velg en film ingen av dere har sett',
    descriptionEn: 'Pick a movie neither of you have seen',
    iconName: 'movie_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Frokost på seng', titleEn: 'Breakfast in bed',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '30 min', metaEn: '30 min',
    descriptionNo: 'Overrask partneren med frokost på sengen',
    descriptionEn: 'Surprise your partner with breakfast in bed',
    iconName: 'coffee_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Piknik i parken', titleEn: 'Picnic in the park',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '1-2 timer', metaEn: '1-2 hours',
    descriptionNo: 'Pakk en kurv og finn et fint sted ute',
    descriptionEn: 'Pack a basket and find a nice spot outside',
    iconName: 'park_outlined', season: 'sommer', effort: 'medium',
  },
  {
    titleNo: 'Brettspillkveld', titleEn: 'Board game night',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1-2 timer', metaEn: '1-2 hours',
    descriptionNo: 'Finn frem et brettspill og konkurrer',
    descriptionEn: 'Get out a board game and compete',
    iconName: 'casino_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Sykkeltur', titleEn: 'Bike ride',
    categoryNo: 'Aktiv', categoryEn: 'Active',
    metaNo: '1-2 timer', metaEn: '1-2 hours',
    descriptionNo: 'Utforsk nye stier eller nabolag på sykkel',
    descriptionEn: 'Explore new trails or neighborhoods by bike',
    iconName: 'pedal_bike_outlined', season: 'sommer', effort: 'medium',
  },
  {
    titleNo: 'Solnedgangstur', titleEn: 'Sunset walk',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '45 min', metaEn: '45 min',
    descriptionNo: 'Gå ut og se solnedgangen sammen',
    descriptionEn: 'Go out and watch the sunset together',
    iconName: 'wb_twilight_outlined', season: 'sommer', effort: 'low',
  },
  {
    titleNo: 'Kafé-date', titleEn: 'Café date',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Besøk en ny kafé dere ikke har prøvd',
    descriptionEn: "Visit a new café you haven't tried",
    iconName: 'local_cafe_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Hjemmespa', titleEn: 'Home spa',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Lag en spa-opplevelse hjemme med masker og massasje',
    descriptionEn: 'Create a spa experience at home with masks and massage',
    iconName: 'spa_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Bake noe godt', titleEn: 'Bake something sweet',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1-2 timer', metaEn: '1-2 hours',
    descriptionNo: 'Bak kake, boller eller cookies sammen',
    descriptionEn: 'Bake a cake, buns or cookies together',
    iconName: 'bakery_dining_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Stjernetitting', titleEn: 'Stargazing',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '45 min', metaEn: '45 min',
    descriptionNo: 'Finn et mørkt sted og se på stjernene',
    descriptionEn: 'Find a dark spot and look at the stars',
    iconName: 'star_outlined', season: 'sommer', effort: 'low',
  },
  {
    titleNo: 'Dansing i stua', titleEn: 'Dance in the living room',
    categoryNo: 'Romantisk', categoryEn: 'Romantic',
    metaNo: '20 min', metaEn: '20 min',
    descriptionNo: 'Sett på musikk og dans sammen',
    descriptionEn: 'Put on music and dance together',
    iconName: 'music_note_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Skriv brev til hverandre', titleEn: 'Write letters to each other',
    categoryNo: 'Romantisk', categoryEn: 'Romantic',
    metaNo: '30 min', metaEn: '30 min',
    descriptionNo: 'Skriv et kjærlighetsbrev og les det høyt',
    descriptionEn: 'Write a love letter and read it out loud',
    iconName: 'mail_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Fottur i naturen', titleEn: 'Hike in nature',
    categoryNo: 'Aktiv', categoryEn: 'Active',
    metaNo: '2-3 timer', metaEn: '2-3 hours',
    descriptionNo: 'Finn en ny tursti og utforsk sammen',
    descriptionEn: 'Find a new trail and explore together',
    iconName: 'hiking_outlined', season: null, effort: 'high',
  },
  {
    titleNo: 'Spill 20 spørsmål', titleEn: 'Play 20 questions',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '30 min', metaEn: '30 min',
    descriptionNo: 'Still hverandre spørsmål dere aldri har stilt',
    descriptionEn: "Ask each other questions you've never asked",
    iconName: 'quiz_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Restaurantbesøk', titleEn: 'Restaurant visit',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '2 timer', metaEn: '2 hours',
    descriptionNo: 'Prøv en restaurant dere aldri har vært på',
    descriptionEn: "Try a restaurant you've never been to",
    iconName: 'dinner_dining_outlined', season: null, effort: 'high',
  },
  {
    titleNo: 'Morgenyoga', titleEn: 'Morning yoga',
    categoryNo: 'Aktiv', categoryEn: 'Active',
    metaNo: '30 min', metaEn: '30 min',
    descriptionNo: 'Start dagen med yoga sammen',
    descriptionEn: 'Start the day with yoga together',
    iconName: 'self_improvement_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Puslespill sammen', titleEn: 'Puzzle together',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1-2 timer', metaEn: '1-2 hours',
    descriptionNo: 'Start et puslespill og jobb på det sammen',
    descriptionEn: 'Start a puzzle and work on it together',
    iconName: 'extension_outlined', season: 'vinter', effort: 'low',
  },
  {
    titleNo: 'Spontan roadtrip', titleEn: 'Spontaneous road trip',
    categoryNo: 'Aktiv', categoryEn: 'Active',
    metaNo: '3-4 timer', metaEn: '3-4 hours',
    descriptionNo: 'Kjør til et sted dere aldri har vært',
    descriptionEn: "Drive somewhere you've never been",
    iconName: 'directions_car_outlined', season: null, effort: 'high',
  },
  {
    titleNo: 'Grillkveld', titleEn: 'BBQ evening',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '2 timer', metaEn: '2 hours',
    descriptionNo: 'Tenn grillen og lag noe godt ute',
    descriptionEn: 'Fire up the grill and cook something nice outside',
    iconName: 'outdoor_grill_outlined', season: 'sommer', effort: 'medium',
  },
  {
    titleNo: 'Bokklubb for to', titleEn: 'Book club for two',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Les samme bok og diskuter den sammen',
    descriptionEn: 'Read the same book and discuss it together',
    iconName: 'menu_book_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Tegn hverandre', titleEn: 'Draw each other',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '30 min', metaEn: '30 min',
    descriptionNo: 'Tegn portrett av hverandre og sammenlign',
    descriptionEn: 'Draw portraits of each other and compare',
    iconName: 'brush_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Karaoke hjemme', titleEn: 'Karaoke at home',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Syng favorittlåtene deres sammen',
    descriptionEn: 'Sing your favorite songs together',
    iconName: 'mic_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Besøk et museum', titleEn: 'Visit a museum',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '2 timer', metaEn: '2 hours',
    descriptionNo: 'Utforsk et museum eller galleri sammen',
    descriptionEn: 'Explore a museum or gallery together',
    iconName: 'museum_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Telefonfri kveld', titleEn: 'Phone-free evening',
    categoryNo: 'Romantisk', categoryEn: 'Romantic',
    metaNo: '3 timer', metaEn: '3 hours',
    descriptionNo: 'Legg bort telefonene og vær til stede',
    descriptionEn: 'Put away the phones and be present',
    iconName: 'smartphone_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Planlegg en drømmereise', titleEn: 'Plan a dream trip',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Planlegg en ferie dere drømmer om',
    descriptionEn: 'Plan a vacation you dream about',
    iconName: 'flight_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Lystig løpetur', titleEn: 'Fun run',
    categoryNo: 'Aktiv', categoryEn: 'Active',
    metaNo: '30 min', metaEn: '30 min',
    descriptionNo: 'Løp sammen i et rolig tempo',
    descriptionEn: 'Run together at an easy pace',
    iconName: 'directions_run_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Taco fredag', titleEn: 'Taco Friday',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Lag taco med alle toppinger fra bunnen av',
    descriptionEn: 'Make tacos with all toppings from scratch',
    iconName: 'lunch_dining_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Gå på konsert', titleEn: 'Go to a concert',
    categoryNo: 'Sosialt', categoryEn: 'Social',
    metaNo: '3 timer', metaEn: '3 hours',
    descriptionNo: 'Finn en konsert og opplev live musikk',
    descriptionEn: 'Find a concert and experience live music',
    iconName: 'music_note_outlined', season: null, effort: 'high',
  },
  {
    titleNo: 'Kortspillkveld', titleEn: 'Card game night',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Spill kort med en god drikke',
    descriptionEn: 'Play cards with a nice drink',
    iconName: 'style_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Handletur sammen', titleEn: 'Shopping trip together',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '2 timer', metaEn: '2 hours',
    descriptionNo: 'Gå rundt i butikker uten noe mål',
    descriptionEn: 'Browse shops without any goal',
    iconName: 'shopping_bag_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Lær noe nytt', titleEn: 'Learn something new',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Se en tutorial og lær en ferdighet sammen',
    descriptionEn: 'Watch a tutorial and learn a skill together',
    iconName: 'school_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Hagevandring', titleEn: 'Garden stroll',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Besøk en botanisk hage eller parker',
    descriptionEn: 'Visit a botanical garden or parks',
    iconName: 'local_florist_outlined', season: 'vår', effort: 'low',
  },
  {
    titleNo: 'Is i sola', titleEn: 'Ice cream in the sun',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '30 min', metaEn: '30 min',
    descriptionNo: 'Kjøp is og nyt sola sammen',
    descriptionEn: 'Buy ice cream and enjoy the sun together',
    iconName: 'icecream_outlined', season: 'sommer', effort: 'low',
  },
  {
    titleNo: 'Lage sushi', titleEn: 'Make sushi',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1.5 timer', metaEn: '1.5 hours',
    descriptionNo: 'Prøv å lage sushi hjemme for første gang',
    descriptionEn: 'Try making sushi at home for the first time',
    iconName: 'ramen_dining_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Badetur', titleEn: 'Swimming trip',
    categoryNo: 'Aktiv', categoryEn: 'Active',
    metaNo: '2 timer', metaEn: '2 hours',
    descriptionNo: 'Dra til stranden eller et badested',
    descriptionEn: 'Head to the beach or a swimming spot',
    iconName: 'pool_outlined', season: 'sommer', effort: 'medium',
  },
  {
    titleNo: 'Husprosjekt sammen', titleEn: 'Home project together',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '2 timer', metaEn: '2 hours',
    descriptionNo: 'Fiks noe i huset eller dekorer et rom',
    descriptionEn: 'Fix something at home or decorate a room',
    iconName: 'build_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Podcast-date', titleEn: 'Podcast date',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Lytt til en podcast sammen og diskuter',
    descriptionEn: 'Listen to a podcast together and discuss',
    iconName: 'podcasts_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Klatring', titleEn: 'Climbing',
    categoryNo: 'Aktiv', categoryEn: 'Active',
    metaNo: '2 timer', metaEn: '2 hours',
    descriptionNo: 'Prøv innendørs klatring sammen',
    descriptionEn: 'Try indoor climbing together',
    iconName: 'terrain_outlined', season: null, effort: 'high',
  },
  {
    titleNo: 'Middag ved stearinlys', titleEn: 'Candlelight dinner',
    categoryNo: 'Romantisk', categoryEn: 'Romantic',
    metaNo: '2 timer', metaEn: '2 hours',
    descriptionNo: 'Dekk bordet fint og lag en spesiell middag',
    descriptionEn: 'Set the table nicely and make a special dinner',
    iconName: 'dining_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Varm sjokolade og teppe', titleEn: 'Hot cocoa and blankets',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Lag varm sjokolade og kos dere under et teppe',
    descriptionEn: 'Make hot cocoa and cozy up under a blanket',
    iconName: 'coffee_outlined', season: 'vinter', effort: 'low',
  },
  {
    titleNo: 'Fototur', titleEn: 'Photo walk',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Gå tur og ta bilder av ting dere synes er fine',
    descriptionEn: 'Walk around and take photos of things you find beautiful',
    iconName: 'camera_alt_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Spill videospill', titleEn: 'Play video games',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1-2 timer', metaEn: '1-2 hours',
    descriptionNo: 'Spill et co-op spill sammen',
    descriptionEn: 'Play a co-op game together',
    iconName: 'sports_esports_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Vinsmakingskveld', titleEn: 'Wine tasting night',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Kjøp tre viner og vurder dem sammen',
    descriptionEn: 'Buy three wines and rate them together',
    iconName: 'wine_bar_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Gå på marked', titleEn: 'Visit a market',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '1-2 timer', metaEn: '1-2 hours',
    descriptionNo: 'Utforsk et loppemarked eller matmarked',
    descriptionEn: 'Explore a flea market or food market',
    iconName: 'storefront_outlined', season: null, effort: 'medium',
  },
  {
    titleNo: 'Meditasjon sammen', titleEn: 'Meditation together',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '15 min', metaEn: '15 min',
    descriptionNo: 'Sitt stille og mediter sammen',
    descriptionEn: 'Sit quietly and meditate together',
    iconName: 'self_improvement_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Skiskøyting', titleEn: 'Ice skating',
    categoryNo: 'Aktiv', categoryEn: 'Active',
    metaNo: '1-2 timer', metaEn: '1-2 hours',
    descriptionNo: 'Dra på skøytebanen og ha det gøy',
    descriptionEn: 'Go to the ice rink and have fun',
    iconName: 'ice_skating_outlined', season: 'vinter', effort: 'medium',
  },
  {
    titleNo: 'Skriv drømmeliste', titleEn: 'Write a dream list',
    categoryNo: 'Romantisk', categoryEn: 'Romantic',
    metaNo: '30 min', metaEn: '30 min',
    descriptionNo: 'Skriv en liste med ting dere vil gjøre sammen',
    descriptionEn: 'Write a list of things you want to do together',
    iconName: 'checklist_outlined', season: null, effort: 'low',
  },
  {
    titleNo: 'Soloppgangstur', titleEn: 'Sunrise walk',
    categoryNo: 'Ute', categoryEn: 'Outside',
    metaNo: '1 time', metaEn: '1 hour',
    descriptionNo: 'Stå opp tidlig og se soloppgangen sammen',
    descriptionEn: 'Wake up early and watch the sunrise together',
    iconName: 'wb_sunny_outlined', season: 'sommer', effort: 'low',
  },
];

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const ideasRef = db.collection('ideas');

  // Step 5: Delete broken image-only docs (no title or titleNo).
  console.log('Scanning /ideas for image-only collision docs to remove...');
  const allSnap = await ideasRef.get();
  const toDelete = allSnap.docs.filter((doc) => {
    const d = doc.data();
    const hasTitle = (typeof d.title === 'string' && d.title.length > 0) ||
                     (typeof d.titleNo === 'string' && d.titleNo.length > 0);
    return !hasTitle;
  });

  if (toDelete.length > 0) {
    const delBatch = db.batch();
    toDelete.forEach((doc) => delBatch.delete(doc.ref));
    await delBatch.commit();
    console.log(`Deleted ${toDelete.length} broken image-only doc(s): ${toDelete.map(d => d.id).join(', ')}`);
  } else {
    console.log('No broken docs found.');
  }

  // Step 6: Batch-write all 50 ideas.
  const batch = db.batch();
  const written = [];
  const skipped = [];

  for (const idea of IDEAS) {
    const id = toId(idea.titleNo);
    const palette = COLORS[idea.categoryNo];
    if (!palette) {
      skipped.push(`${id} (unknown category: ${idea.categoryNo})`);
      continue;
    }
    const doc = {
      titleNo: idea.titleNo,
      titleEn: idea.titleEn,
      categoryNo: idea.categoryNo,
      categoryEn: idea.categoryEn,
      metaNo: idea.metaNo,
      metaEn: idea.metaEn,
      descriptionNo: idea.descriptionNo,
      descriptionEn: idea.descriptionEn,
      cardColor: palette.cardColor,
      tagColor: palette.tagColor,
      tagTextColor: palette.tagTextColor,
      iconName: idea.iconName,
      season: idea.season,
      effort: idea.effort,
    };
    batch.set(ideasRef.doc(id), doc);
    written.push(id);
  }

  await batch.commit();
  console.log(`\n✓ Written ${written.length} ideas:`);
  written.forEach((id) => console.log(`  · ${id}`));
  if (skipped.length > 0) {
    console.log(`\n⚠ Skipped ${skipped.length}: ${skipped.join(', ')}`);
  }
  console.log('\nDone.');
}

main().catch((err) => {
  console.error('Error:', err.message || err);
  process.exit(1);
});

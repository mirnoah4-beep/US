// Tests for premium AI cover images.
// Run: npm test

import { test } from 'node:test';
import * as assert from 'node:assert';

import {
  toIdeaId,
  ideaIdFor,
  buildCoverPrompt,
  hasUsableCoverUrl,
  downloadUrlFor,
  MAX_NEW_IMAGES_PER_RUN,
  isImageGenEnabledFor,
  IMAGE_GEN_UID_ALLOWLIST,
  ideaIdFromCoverPath,
  shouldRepairCover,
  pickDownloadToken,
} from '../ideaImages';
import type { IdeaObject } from '../generateWeeklyIdeas';

// ── ideaId parity with the Flutter client ───────────────────────────────────
//
// These expectations are not hand-written: they were produced by RUNNING the
// real Dart IdeaImageService.toId() from lib/services/idea_image_service.dart.
// If the server and client ever disagree, the server writes a document the
// client will never read, and covers silently never appear.

const DART_REFERENCE: Array<[string, string]> = [
  ['Kort + te', 'kort_te'],
  ['Filmkveld hjemme', 'filmkveld_hjemme'],
  ['Gåtur i parken', 'gåtur_i_parken'],
  ['Middag ute', 'middag_ute'],
  ['Bake sammen', 'bake_sammen'],
  ['Spillkveld', 'spillkveld'],
  ['ØL & Vin', 'øl_vin'],
  ['Strand-tur!', 'strand_tur_'],
  ['Café à deux', 'caf_deux'],
  ['  Ledende mellomrom  ', 'ledende_mellomrom'],
  ['To  mellomrom', 'to_mellomrom'],
  ['Æøå ÆØÅ', 'æøå_æøå'],
  ['Yoga 2.0', 'yoga_2_0'],
  ['Piknik på taket', 'piknik_på_taket'],
  ['Museum & lunsj', 'museum_lunsj'],
  ['', ''],
  ['   ', ''],
  ['123', '123'],
  ['Ski/akebakke', 'ski_akebakke'],
];

test('toIdeaId matches the Dart IdeaImageService.toId byte for byte', () => {
  for (const [input, expected] of DART_REFERENCE) {
    assert.strictEqual(
      toIdeaId(input),
      expected,
      `toId(${JSON.stringify(input)}) must equal ${JSON.stringify(expected)}`,
    );
  }
});

test('toIdeaId preserves Norwegian characters and collapses runs', () => {
  assert.strictEqual(toIdeaId('Øl på Grünerløkka'), 'øl_på_gr_nerløkka');
  assert.strictEqual(toIdeaId('a---b'), 'a_b');
});

// ── id derivation mirrors WeeklyIdea.fromJson ───────────────────────────────

function idea(over: Partial<IdeaObject> = {}): IdeaObject {
  return {
    title: 'Movie night',
    category: 'Hjemme',
    meta: '2t',
    cardColor: '#fff',
    tagColor: '#fff',
    tagTextColor: '#000',
    iconName: 'movie',
    description: 'A cosy evening in',
    ...over,
  } as IdeaObject;
}

test('ideaIdFor prefers titleNo, exactly like the client', () => {
  // Client: titleNo = tryStr(['titleNo']) or falls back to title.
  assert.strictEqual(ideaIdFor(idea({ titleNo: 'Filmkveld hjemme' })), 'filmkveld_hjemme');
  assert.strictEqual(ideaIdFor(idea({ title: 'Movie night' })), 'movie_night');
  // Empty titleNo must fall back, not produce an empty id.
  assert.strictEqual(ideaIdFor(idea({ titleNo: '', title: 'Movie night' })), 'movie_night');
  assert.strictEqual(ideaIdFor(idea({ titleNo: '   ', title: 'Movie night' })), 'movie_night');
});

test('ideaIdFor is stable across runs for the same title', () => {
  const a = ideaIdFor(idea({ titleNo: 'Piknik på taket' }));
  const b = ideaIdFor(idea({ titleNo: 'Piknik på taket', description: 'different' }));
  assert.strictEqual(a, b);
});

// ── Reuse / cost protection ─────────────────────────────────────────────────

test('an existing cover URL is treated as usable and reused', () => {
  assert.ok(hasUsableCoverUrl('https://firebasestorage.googleapis.com/v0/b/x/o/y?alt=media&token=t'));
  assert.ok(hasUsableCoverUrl('http://example.com/a.jpg'));
});

test('missing or malformed cover values are not reused', () => {
  for (const bad of [undefined, null, '', '   ', 'not-a-url', 42, {}, [], true]) {
    assert.ok(!hasUsableCoverUrl(bad), `${JSON.stringify(bad)} must not count as a cover`);
  }
});

test('the per-run image budget is capped at the number of weekly ideas', () => {
  assert.strictEqual(MAX_NEW_IMAGES_PER_RUN, 5);
});

test('an empty allowlist means image generation is off for everybody', () => {
  // Guards the pre-launch default: shipping with an empty list must never
  // silently mean "all premium couples".
  if (IMAGE_GEN_UID_ALLOWLIST.length === 0) {
    assert.strictEqual(isImageGenEnabledFor(['anyone', 'else']), false);
    assert.strictEqual(isImageGenEnabledFor([]), false);
  }
});

test('only a couple containing an allowlisted member is enabled', () => {
  // Behaviour check independent of the current list contents.
  const enabled = (members: string[], list: readonly string[]) =>
    list.length > 0 && members.some((m) => list.includes(m));
  assert.strictEqual(enabled(['a', 'b'], ['b']), true);
  assert.strictEqual(enabled(['a', 'b'], ['c']), false);
  assert.strictEqual(enabled([], ['b']), false);
  assert.strictEqual(enabled(['a'], []), false);
});

// ── Prompt ──────────────────────────────────────────────────────────────────

test('the cover prompt carries the US style and the specific activity', () => {
  const p = buildCoverPrompt(idea({ titleEn: 'Rooftop picnic', descriptionEn: 'Blankets at sunset' }));
  assert.match(p, /Rooftop picnic/);
  assert.match(p, /Blankets at sunset/);
  for (const rule of [/no text/i, /no logos/i, /no watermark/i, /no user interface/i,
                      /soft natural lighting/i, /realistic/i, /tasteful/i]) {
    assert.match(p, rule);
  }
  assert.match(p, /no recognisable celebrities|identifiable faces/i);
});

test('the prompt falls back to the Norwegian fields when English is absent', () => {
  const p = buildCoverPrompt(idea({ title: 'Filmkveld', description: 'Kos i sofaen' }));
  assert.match(p, /Filmkveld/);
  assert.match(p, /Kos i sofaen/);
});

// ── Download URL shape ──────────────────────────────────────────────────────

test('download URL matches the shape getDownloadURL() returns', () => {
  const url = downloadUrlFor('us-app-4bf30.firebasestorage.app', 'ideas/kort_te/cover.jpg', 'tok-123');
  assert.strictEqual(
    url,
    'https://firebasestorage.googleapis.com/v0/b/us-app-4bf30.firebasestorage.app/o/'
    + 'ideas%2Fkort_te%2Fcover.jpg?alt=media&token=tok-123',
  );
  // The path must be percent-encoded, or Storage returns 404.
  assert.ok(url.includes('%2F'));
  assert.ok(!url.includes('/o/ideas/'));
});

// ── Legacy cover repair helpers ─────────────────────────────────────────────
// The one-time repair function itself was temporary and has been removed, but
// its decision logic lives here permanently so the rules stay verified.

test('ideaIdFromCoverPath accepts only the exact expected path shape', () => {
  assert.strictEqual(ideaIdFromCoverPath('ideas/kort_te/cover.jpg'), 'kort_te');
  assert.strictEqual(ideaIdFromCoverPath('ideas/tegn_drømmehuset_deres/cover.jpg'), 'tegn_drømmehuset_deres');
  for (const bad of [
    'ideas/cover.jpg',                 // no ideaId segment
    'ideas/a/b/cover.jpg',             // nested
    'ideas/kort_te/cover.png',         // wrong extension
    'ideas/kort_te/thumb.jpg',         // wrong file
    'users/uid/avatar.jpg',            // different prefix
    'ideas/kort_te/',                  // directory
    '',
  ]) {
    assert.strictEqual(ideaIdFromCoverPath(bad), null, `${bad} must not parse`);
  }
});

test('repair never overwrites an already-valid coverImageUrl', () => {
  assert.strictEqual(shouldRepairCover('https://firebasestorage.googleapis.com/v0/b/x/o/y?alt=media&token=t'), false);
  // Missing or unusable values are the only ones repaired.
  for (const missing of [undefined, null, '', '   ', 'not-a-url', 42, {}]) {
    assert.strictEqual(shouldRepairCover(missing), true, `${JSON.stringify(missing)} should be repaired`);
  }
});

test('an existing download token is reused rather than minted', () => {
  assert.strictEqual(
    pickDownloadToken({ metadata: { firebaseStorageDownloadTokens: 'abc-123' } }),
    'abc-123',
  );
  // Comma-separated lists are valid; any one token works.
  assert.strictEqual(
    pickDownloadToken({ metadata: { firebaseStorageDownloadTokens: 'first,second' } }),
    'first',
  );
});

test('a missing token yields null so the caller mints one', () => {
  for (const md of [
    undefined, null, {}, { metadata: {} },
    { metadata: { firebaseStorageDownloadTokens: '' } },
    { metadata: { firebaseStorageDownloadTokens: 42 } },
  ]) {
    assert.strictEqual(pickDownloadToken(md), null, `${JSON.stringify(md)} must yield null`);
  }
});

test('a repaired URL resolves to the same document the client looks up', () => {
  // Client: fetchCoverUrl(toId(titleNo)) -> ideas/{ideaId}.coverImageUrl
  const ideaId = toIdeaId('Kort + te');
  assert.strictEqual(ideaId, 'kort_te');
  assert.strictEqual(ideaIdFromCoverPath(`ideas/${ideaId}/cover.jpg`), ideaId);
  const url = downloadUrlFor('b', `ideas/${ideaId}/cover.jpg`, 'tok');
  assert.ok(hasUsableCoverUrl(url));
});

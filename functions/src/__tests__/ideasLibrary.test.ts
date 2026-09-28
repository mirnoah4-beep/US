// Library invariants + the parent-mode rule. Run: npm test
import { test } from 'node:test';
import * as assert from 'node:assert';
import { readFileSync } from 'fs';
import { join } from 'path';
import { IDEA_LIBRARY, ideaAllowedForProfile, parentModeRuleLines, libraryIdeaDoc } from '../ideasLibrary';

test('library: 45+ unique ideas, 20+ per main filter, bilingual, valid slugs', () => {
  assert.ok(IDEA_LIBRARY.length >= 45);
  assert.strictEqual(new Set(IDEA_LIBRARY.map((i) => i.id)).size, IDEA_LIBRARY.length);
  for (const f of ['10min', 'home', 'out'] as const) {
    assert.ok(IDEA_LIBRARY.filter((i) => i.filters.includes(f)).length >= 20, f);
  }
  for (const i of IDEA_LIBRARY) {
    for (const k of ['titleNo', 'titleEn', 'descNo', 'descEn', 'durationNo', 'durationEn', 'categoryNo', 'categoryEn'] as const) {
      assert.ok(i[k].trim().length > 0, `${i.id}.${k}`);
    }
    assert.match(i.id, /^[a-z0-9æøå_]+$/);
    assert.ok(['low', 'medium', 'high'].includes(i.effort), i.id);
    assert.ok(!(i.parentFriendly && i.requiresKidFree), `${i.id} cannot be both`);
  }
});

test('the JSON the client bundles is the very same file', () => {
  const onDisk = JSON.parse(readFileSync(join(__dirname, '..', '..', 'src', 'ideasLibrary.json'), 'utf8'));
  assert.strictEqual(onDisk.length, IDEA_LIBRARY.length);
  assert.deepStrictEqual(onDisk.map((i: { id: string }) => i.id), IDEA_LIBRARY.map((i) => i.id));
});

test('parent-mode rule: usual → parent-friendly only; kid-free → couple-only allowed; untagged docs excluded for parents', () => {
  const kidsHome = { isParent: true, childcareState: 'kidsHome' as const };
  const kidFree = { isParent: true, childcareState: 'kidFree' as const };
  const notParent = { isParent: false, childcareState: 'kidFree' as const };
  const friendly = { parentFriendly: true, requiresKidFree: false };
  const couplesOnly = { parentFriendly: false, requiresKidFree: true };
  const untagged = {};
  assert.ok(ideaAllowedForProfile(friendly, kidsHome));
  assert.ok(!ideaAllowedForProfile(couplesOnly, kidsHome));
  assert.ok(!ideaAllowedForProfile(untagged, kidsHome));
  assert.ok(ideaAllowedForProfile(friendly, kidFree));
  assert.ok(ideaAllowedForProfile(couplesOnly, kidFree));
  assert.ok(!ideaAllowedForProfile(untagged, kidFree));
  assert.ok(ideaAllowedForProfile(untagged, notParent) && ideaAllowedForProfile(couplesOnly, notParent));
  // Enough parent-friendly ideas per filter for a parent to browse.
  const usual = IDEA_LIBRARY.filter((i) => ideaAllowedForProfile(i, kidsHome));
  assert.ok(usual.filter((i) => i.filters.includes('10min')).length >= 20);
  assert.ok(usual.filter((i) => i.filters.includes('home')).length >= 20);
  assert.ok(usual.filter((i) => i.filters.includes('out')).length >= 15);
  assert.strictEqual(IDEA_LIBRARY.filter((i) => ideaAllowedForProfile(i, kidFree)).length, IDEA_LIBRARY.length);
});

test('prompt rule lines follow the situation', () => {
  assert.deepStrictEqual(parentModeRuleLines({ isParent: false, childcareState: 'kidFree' }), []);
  assert.ok(parentModeRuleLines({ isParent: true, childcareState: 'kidsHome' }).join(' ').includes('FORELDREMODUS'));
  assert.ok(parentModeRuleLines({ isParent: true, childcareState: 'kidFree' }).join(' ').includes('barnefrie'));
});

test('library docs carry the IdeaObject shape + tags and never a cover url', () => {
  const d = libraryIdeaDoc(IDEA_LIBRARY[0]);
  for (const k of ['title', 'category', 'meta', 'cardColor', 'tagColor', 'tagTextColor', 'iconName', 'description', 'titleNo', 'titleEn', 'effort', 'parentFriendly', 'requiresKidFree', 'library']) {
    assert.ok(k in d, k);
  }
  assert.ok(!('coverImageUrl' in d));
});

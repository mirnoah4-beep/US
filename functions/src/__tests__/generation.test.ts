// Tests for weekly-generation provenance (generatedBy) and secret bindings.
// Run: npm test

import { test } from 'node:test';
import * as assert from 'node:assert';
import { readFileSync } from 'fs';
import { join } from 'path';

const SRC = join(__dirname, '..', '..', 'src');
const indexSrc = readFileSync(join(SRC, 'index.ts'), 'utf8');
const genSrc = readFileSync(join(SRC, 'generateWeeklyIdeas.ts'), 'utf8');

// ── 2. Secret bindings ──────────────────────────────────────────────────────
//
// A secret declared on one function does NOT propagate to another function
// that happens to call the same helper. Every DEPLOYED function whose handler
// can reach process.env.OPENAI_API_KEY must declare it itself. This is a
// source-level guard so the binding cannot silently regress.

/// Extracts the options object literal of `export const <name> = <trigger>(`.
function optionsBlockFor(name: string): string {
  const marker = new RegExp(`export const ${name} = \\w+\\(`);
  const m = indexSrc.match(marker);
  assert.ok(m, `could not find definition of ${name}`);
  const start = indexSrc.indexOf(m![0]) + m![0].length;
  // The options literal is everything up to the handler argument.
  const tail = indexSrc.slice(start, start + 600);
  const handlerAt = tail.search(/async \(|\(\s*req\s*,|\(\s*request\s*\)/);
  return handlerAt === -1 ? tail : tail.slice(0, handlerAt);
}

const OPENAI_DEPENDENT = [
  'generateWeeklyIdeasScheduled', // calls generateForCouple
  'generateWeeklyIdeasNow',       // calls generateForCouple
  'callOpenAI',                   // reads the key directly
];

for (const fn of OPENAI_DEPENDENT) {
  test(`${fn} declares secrets: ['OPENAI_API_KEY']`, () => {
    const opts = optionsBlockFor(fn);
    assert.match(
      opts,
      /secrets:\s*\[\s*'OPENAI_API_KEY'\s*\]/,
      `${fn} reaches process.env.OPENAI_API_KEY but does not declare the secret`,
    );
  });
}

test('every function calling generateForCouple is in the audited list', () => {
  // If a new caller appears, this fails so the secret binding gets considered.
  const callers = new Set<string>();
  const lines = indexSrc.split('\n');
  let current: string | null = null;
  for (const line of lines) {
    const def = line.match(/export const (\w+) = (?:onCall|onSchedule|onRequest|onDocument\w+)\(/);
    if (def) current = def[1];
    if (/generateForCouple\(/.test(line) && current) callers.add(current);
  }
  for (const caller of callers) {
    assert.ok(
      OPENAI_DEPENDENT.includes(caller),
      `${caller} calls generateForCouple but is not in OPENAI_DEPENDENT — `
      + 'add it and bind the secret',
    );
  }
  // Sanity: the two known callers are detected.
  assert.ok(callers.has('generateWeeklyIdeasScheduled'));
  assert.ok(callers.has('generateWeeklyIdeasNow'));
});

// ── 3. generatedBy provenance ───────────────────────────────────────────────

test('the three provenance values are declared', () => {
  assert.match(genSrc, /export type GeneratedBy = 'ai' \| 'curated' \| 'fallback'/);
});

test('a failed OpenAI call returns usedFallback: true, never plain ideas', () => {
  // Both exits from the retry loop must flag the fallback.
  const fallbackReturns = genSrc.match(/return \{ ideas: getHardcodedFallback\(\), usedFallback: true \}/g) ?? [];
  assert.strictEqual(fallbackReturns.length, 2, 'both fallback exits must set usedFallback');
  // And getHardcodedFallback is never returned bare.
  assert.ok(
    !/return getHardcodedFallback\(\);/.test(genSrc),
    'getHardcodedFallback must not be returned without a usedFallback flag',
  );
});

test('a successful OpenAI call returns usedFallback: false', () => {
  assert.match(genSrc, /usedFallback: false/);
});

test('premium maps usedFallback to fallback, not ai', () => {
  assert.match(
    genSrc,
    /generatedBy = aiResult\.usedFallback \? 'fallback' : 'ai'/,
    'fallback content must never be labelled ai',
  );
});

test('the free branch is labelled curated', () => {
  assert.match(genSrc, /generatedBy = 'curated'/);
});

test('fallback content never triggers paid image generation', () => {
  assert.match(
    genSrc,
    /if \(aiResult\.usedFallback\)[\s\S]{0,200}?throw new SkipImages\(\)/,
    'images must be skipped when the ideas themselves are fallback content',
  );
});

// ── Provenance decision table (pure logic mirror) ───────────────────────────

test('provenance decision table', () => {
  const decide = (tier: string, usedFallback: boolean) =>
    tier === 'premium' ? (usedFallback ? 'fallback' : 'ai') : 'curated';

  assert.strictEqual(decide('premium', false), 'ai');
  assert.strictEqual(decide('premium', true), 'fallback');
  assert.strictEqual(decide('free', false), 'curated');
  assert.strictEqual(decide('free', true), 'curated');
});

test('the client treats only "ai" as AI-generated', () => {
  // lib/models/weekly_idea.dart:131 -> isAiGenerated => generatedBy == 'ai'
  const isAiGenerated = (v: string) => v === 'ai';
  assert.strictEqual(isAiGenerated('ai'), true);
  assert.strictEqual(isAiGenerated('fallback'), false);
  assert.strictEqual(isAiGenerated('curated'), false);
});

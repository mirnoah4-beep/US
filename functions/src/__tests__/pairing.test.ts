// Pure pairing rules — no Firestore. The transaction itself is covered by
// __rules__/pairing.emulator.test.ts.
// Run: npm test

import { test } from 'node:test';
import * as assert from 'node:assert';

import {
  normalizeInviteCode,
  coupleIdOf,
  classifyRelationship,
  membersOf,
  generateInviteCode,
  INVITE_ALPHABET,
  pairingError,
} from '../pairing';

test('invite codes: whitespace/case tolerant, legacy 6-digit and current 8-char accepted', () => {
  assert.strictEqual(normalizeInviteCode(' wzfx szp2 '), 'WZFXSZP2');
  assert.strictEqual(normalizeInviteCode('465604'), '465604');
  for (const bad of ['', 'ABC', 'ABCDEFGHI', 'AB-CDEFG', 'abc/def', 42, null, undefined, {}]) {
    assert.strictEqual(normalizeInviteCode(bad), null, JSON.stringify(bad));
  }
});

test('coupleId: missing field and null are the same thing', () => {
  assert.strictEqual(coupleIdOf(undefined), null);
  assert.strictEqual(coupleIdOf({}), null);
  assert.strictEqual(coupleIdOf({ coupleId: null }), null);
  assert.strictEqual(coupleIdOf({ coupleId: '' }), null);
  assert.strictEqual(coupleIdOf({ coupleId: 42 }), null);
  assert.strictEqual(coupleIdOf({ coupleId: 'c1' }), 'c1');
});

test('classification: only an existing ACTIVE couple containing the uid is "active"', () => {
  assert.deepStrictEqual(classifyRelationship('a', null, null), { kind: 'none' });
  assert.deepStrictEqual(classifyRelationship('a', 'c1', { exists: false }), { kind: 'stale', coupleId: 'c1', reason: 'missing' });
  assert.deepStrictEqual(classifyRelationship('a', 'c1', { exists: true, members: ['b', 'x'], status: 'active' }), { kind: 'stale', coupleId: 'c1', reason: 'not-member' });
  assert.deepStrictEqual(classifyRelationship('a', 'c1', { exists: true, members: ['a', 'b'], status: 'ended' }), { kind: 'stale', coupleId: 'c1', reason: 'not-active' });
  assert.deepStrictEqual(classifyRelationship('a', 'c1', { exists: true, members: ['a'], status: 'pending' }), { kind: 'stale', coupleId: 'c1', reason: 'not-active' });
  assert.deepStrictEqual(classifyRelationship('a', 'c1', { exists: true, members: ['a', 'b'], status: 'active' }), { kind: 'active', coupleId: 'c1' });
});

test('classification: a reference to the TARGET pending couple is never stale', () => {
  assert.deepStrictEqual(classifyRelationship('a', 'target', { exists: true, members: ['a'], status: 'pending' }, 'target'), { kind: 'none' });
  assert.deepStrictEqual(classifyRelationship('a', 'target', null, 'target'), { kind: 'none' });
  // …but a reference to a DIFFERENT pending couple is stale, not active.
  assert.strictEqual(classifyRelationship('a', 'other', { exists: true, members: ['a'], status: 'pending' }, 'target').kind, 'stale');
});

test('members: malformed arrays never yield members', () => {
  assert.deepStrictEqual(membersOf({ exists: true, members: ['a', 42, '', null, 'b'] }), ['a', 'b']);
  assert.deepStrictEqual(membersOf({ exists: true, members: 'a,b' }), []);
  assert.deepStrictEqual(membersOf(null), []);
});

test('generated codes use the unambiguous alphabet and are 8 chars', () => {
  for (let i = 0; i < 200; i++) {
    const c = generateInviteCode();
    assert.strictEqual(c.length, 8);
    assert.ok([...c].every((ch) => INVITE_ALPHABET.includes(ch)), c);
    assert.ok(!/[O0I1]/.test(c));
  }
  assert.strictEqual(generateInviteCode(Buffer.from([0, 1, 2, 3, 4, 5, 6, 7])), 'ABCDEFGH');
});

test('pairing errors carry the reason in details and a precise code', () => {
  const e = pairingError('inviter-already-paired');
  assert.strictEqual(e.code, 'failed-precondition');
  assert.deepStrictEqual(e.details, { reason: 'inviter-already-paired' });
  assert.strictEqual(pairingError('invalid-code').code, 'not-found');
});

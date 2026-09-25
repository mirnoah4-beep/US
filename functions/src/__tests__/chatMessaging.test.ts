// Unit tests for the partner-chat fan-out helpers.
// Run: npm test

import { test } from 'node:test';
import * as assert from 'node:assert';

import {
  resolveChatRecipient,
  isFanoutableMessage,
  messagePreview,
  metaPreview,
  chatPushData,
  PREVIEW_MAX_CHARS,
} from '../chatMessaging';
import { chatMessageTitle, chatIdeaBody } from '../notificationStrings';

const A = 'uidA';
const B = 'uidB';

// ── Recipient resolution (never from client data) ───────────────────────────

test('recipient is the other current member', () => {
  assert.strictEqual(resolveChatRecipient(A, [A, B]), B);
  assert.strictEqual(resolveChatRecipient(B, [A, B]), A);
});

test('a sender who is not a current member gets no fan-out', () => {
  // e.g. a message written just before disconnectPartner removed them.
  assert.strictEqual(resolveChatRecipient('former', [A, B]), null);
});

test('solo couple (no partner yet) resolves to nobody', () => {
  assert.strictEqual(resolveChatRecipient(A, [A]), null);
});

test('malformed membership data never yields a recipient', () => {
  for (const members of [undefined, null, 'A,B', {}, [null, 42], []]) {
    assert.strictEqual(resolveChatRecipient(A, members), null, JSON.stringify(members));
  }
  for (const sender of [undefined, null, '', 42]) {
    assert.strictEqual(resolveChatRecipient(sender, [A, B]), null, JSON.stringify(sender));
  }
});

// ── Fan-out eligibility ─────────────────────────────────────────────────────

test('only well-formed text and idea messages fan out', () => {
  assert.ok(isFanoutableMessage({ type: 'text', text: 'hei' }));
  assert.ok(isFanoutableMessage({ type: 'idea', idea: { titleNo: 'Filmkveld' } }));
  assert.ok(isFanoutableMessage({ type: 'idea', idea: { titleEn: 'Movie night' } }));

  assert.ok(!isFanoutableMessage(undefined));
  assert.ok(!isFanoutableMessage({ type: 'text', text: '   ' }));
  assert.ok(!isFanoutableMessage({ type: 'text', text: 42 }));
  assert.ok(!isFanoutableMessage({ type: 'idea', idea: {} }));
  assert.ok(!isFanoutableMessage({ type: 'sticker', text: 'x' }));
  assert.ok(!isFanoutableMessage({ text: 'no type' }));
});

// ── Previews ────────────────────────────────────────────────────────────────

test('preview collapses whitespace and truncates with an ellipsis', () => {
  assert.strictEqual(messagePreview('hei   der\n\nkjære'), 'hei der kjære');
  const long = 'a'.repeat(500);
  const p = messagePreview(long);
  assert.strictEqual(p.length, PREVIEW_MAX_CHARS);
  assert.ok(p.endsWith('…'));
  assert.strictEqual(messagePreview('short'), 'short');
});

test('preview never leaks a full long message', () => {
  const secret = 'x'.repeat(2000);
  assert.ok(messagePreview(secret).length < 200);
});

test('meta preview prefers Norwegian idea title, falls back to English', () => {
  assert.strictEqual(metaPreview({ type: 'idea', idea: { titleNo: 'Filmkveld', titleEn: 'Movie' } }), 'Filmkveld');
  assert.strictEqual(metaPreview({ type: 'idea', idea: { titleEn: 'Movie' } }), 'Movie');
  assert.strictEqual(metaPreview({ type: 'text', text: 'hallo' }), 'hallo');
  assert.strictEqual(metaPreview({ type: 'other' }), '');
});

// ── Push payload ────────────────────────────────────────────────────────────

test('push data routes on chat_message and carries only ids', () => {
  const d = chatPushData('c1', 'm1');
  assert.deepStrictEqual(d, { type: 'chat_message', coupleId: 'c1', messageId: 'm1' });
  // No message text on the data payload — it comes from Firestore.
  assert.ok(!('text' in d));
});

// ── Localised copy ──────────────────────────────────────────────────────────

test('chat push copy uses the recipient language and a safe name fallback', () => {
  assert.strictEqual(chatMessageTitle('Adel', true), 'Adel');
  assert.strictEqual(chatMessageTitle('  ', true), 'Partneren din');
  assert.strictEqual(chatMessageTitle('', false), 'Your partner');
  assert.strictEqual(chatIdeaBody('Adel', 'Filmkveld', true), 'Adel delte en idé: Filmkveld');
  assert.strictEqual(chatIdeaBody('Adel', 'Movie night', false), 'Adel shared an idea: Movie night');
});

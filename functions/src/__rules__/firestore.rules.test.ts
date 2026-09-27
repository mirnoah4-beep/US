// Firestore security rules tests for partner chat.
//
// Runs against the Firestore EMULATOR with the real firestore.rules file:
//   npm run test:rules
// (Deliberately not part of `npm test`, which must stay emulator-free.)

import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'fs';
import { join } from 'path';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  type RulesTestEnvironment,
  type RulesTestContext,
} from '@firebase/rules-unit-testing';
import { serverTimestamp, Timestamp, deleteField, doc, setDoc, getDoc, updateDoc, deleteDoc, collection, getDocs, query, orderBy, limit } from 'firebase/firestore';

const PROJECT = 'us-app-4bf30';
const RULES = readFileSync(join(__dirname, '..', '..', '..', 'firestore.rules'), 'utf8');

const A = 'uidA';
const B = 'uidB';
const OUTSIDER = 'uidX';
const COUPLE = 'c1';

let env: RulesTestEnvironment;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: RULES },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Seed the couple with the Admin (rules-bypassing) context.
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'couples', COUPLE), { members: [A, B], status: 'active' });
    await setDoc(doc(db, 'users', A), { coupleId: COUPLE });
    await setDoc(doc(db, 'users', B), { coupleId: COUPLE });
    await setDoc(doc(db, 'users', OUTSIDER), { coupleId: null });
  });
});

const dbAs = (uid: string | null) =>
  uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();

const msgRef = (db: ReturnType<typeof dbAs>, id = 'm1') =>
  doc(db, 'couples', COUPLE, 'messages', id);

const validText = (senderId: string, text = 'hei') => ({
  senderId,
  type: 'text',
  text,
  createdAt: serverTimestamp(),
  clientTs: Date.now(),
});

const validIdea = (senderId: string) => ({
  senderId,
  type: 'idea',
  idea: {
    titleNo: 'Filmkveld', titleEn: 'Movie night',
    categoryNo: 'Hjemme', categoryEn: 'Home',
    metaNo: '2t', metaEn: '2h',
    descriptionNo: 'Kos', descriptionEn: 'Cosy',
    coverImageUrl: 'https://example.com/c.jpg',
  },
  createdAt: serverTimestamp(),
  clientTs: Date.now(),
});

// ── Create ──────────────────────────────────────────────────────────────────

test('a member can send a valid text message', async () => {
  await assertSucceeds(setDoc(msgRef(dbAs(A)), validText(A)));
});

test('a member can send a valid idea message', async () => {
  await assertSucceeds(setDoc(msgRef(dbAs(B)), validIdea(B)));
});

test('an outsider cannot send', async () => {
  await assertFails(setDoc(msgRef(dbAs(OUTSIDER)), validText(OUTSIDER)));
});

test('unauthenticated cannot send', async () => {
  await assertFails(setDoc(msgRef(dbAs(null)), validText(A)));
});

test('a member cannot impersonate the partner', async () => {
  // A is authenticated but claims senderId B.
  await assertFails(setDoc(msgRef(dbAs(A)), validText(B)));
});

test('empty text is rejected', async () => {
  await assertFails(setDoc(msgRef(dbAs(A)), validText(A, '')));
});

test('text over 2000 characters is rejected', async () => {
  await assertFails(setDoc(msgRef(dbAs(A)), validText(A, 'x'.repeat(2001))));
  await assertSucceeds(setDoc(msgRef(dbAs(A), 'ok'), validText(A, 'x'.repeat(2000))));
});

test('non-string text is rejected', async () => {
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validText(A), text: 42 }));
});

test('unknown message type is rejected', async () => {
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validText(A), type: 'sticker' }));
});

test('extra / protected fields are rejected', async () => {
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validText(A), readBy: [B] }));
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validText(A), unread: 99 }));
});

test('a backdated createdAt is rejected', async () => {
  await assertFails(setDoc(msgRef(dbAs(A)), {
    ...validText(A),
    createdAt: Timestamp.fromDate(new Date('2020-01-01')),
  }));
});

test('missing clientTs is rejected', async () => {
  const m = validText(A) as Record<string, unknown>;
  delete m.clientTs;
  await assertFails(setDoc(msgRef(dbAs(A)), m));
});

test('idea message with a missing required field is rejected', async () => {
  const m = validIdea(A);
  delete (m.idea as Record<string, unknown>).titleEn;
  await assertFails(setDoc(msgRef(dbAs(A)), m));
});

test('idea message with an unexpected nested key is rejected', async () => {
  const m = validIdea(A);
  (m.idea as Record<string, unknown>).script = '<img onerror>';
  await assertFails(setDoc(msgRef(dbAs(A)), m));
});

// ── Read ────────────────────────────────────────────────────────────────────

test('both members can read; outsider and unauthenticated cannot', async () => {
  await setDoc(msgRef(dbAs(A)), validText(A));
  await assertSucceeds(getDoc(msgRef(dbAs(A))));
  await assertSucceeds(getDoc(msgRef(dbAs(B))));
  await assertFails(getDoc(msgRef(dbAs(OUTSIDER))));
  await assertFails(getDoc(msgRef(dbAs(null))));
});

test('members can run the paginated list query', async () => {
  await setDoc(msgRef(dbAs(A)), validText(A));
  const q = query(collection(dbAs(B), 'couples', COUPLE, 'messages'), orderBy('createdAt', 'desc'), limit(30));
  await assertSucceeds(getDocs(q));
  const qx = query(collection(dbAs(OUTSIDER), 'couples', COUPLE, 'messages'), orderBy('createdAt', 'desc'), limit(30));
  await assertFails(getDocs(qx));
});

test('a former partner loses read AND write access the moment they are removed', async () => {
  await setDoc(msgRef(dbAs(B)), validText(B));
  // Simulate disconnectPartner: B removed from members (Admin write).
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await updateDoc(doc(ctx.firestore(), 'couples', COUPLE), { members: [A] });
  });
  await assertFails(getDoc(msgRef(dbAs(B))));
  await assertFails(setDoc(msgRef(dbAs(B), 'm2'), validText(B)));
  // A, still a member, is unaffected.
  await assertSucceeds(getDoc(msgRef(dbAs(A))));
});

// ── Immutability ────────────────────────────────────────────────────────────

test('messages cannot be edited or deleted, even by their author', async () => {
  await setDoc(msgRef(dbAs(A)), validText(A));
  await assertFails(updateDoc(msgRef(dbAs(A)), { text: 'edited' }));
  await assertFails(updateDoc(msgRef(dbAs(B)), { text: 'edited by partner' }));
  await assertFails(deleteDoc(msgRef(dbAs(A))));
  await assertFails(deleteDoc(msgRef(dbAs(B))));
});

// ── Read state ──────────────────────────────────────────────────────────────

const readRef = (db: ReturnType<typeof dbAs>, uid: string) =>
  doc(db, 'couples', COUPLE, 'chat', `read_${uid}`);

test('a member can reset their OWN unread to 0', async () => {
  await assertSucceeds(setDoc(readRef(dbAs(A), A), { lastReadAt: serverTimestamp(), unread: 0 }));
});

test('a member cannot touch the partner read doc', async () => {
  await assertFails(setDoc(readRef(dbAs(A), B), { lastReadAt: serverTimestamp(), unread: 0 }));
});

test('a member cannot fabricate an unread count', async () => {
  await assertFails(setDoc(readRef(dbAs(A), A), { lastReadAt: serverTimestamp(), unread: 5 }));
  await assertFails(setDoc(readRef(dbAs(A), A), { lastReadAt: serverTimestamp(), unread: -1 }));
});

test('read doc accepts only the two allowed keys', async () => {
  await assertFails(setDoc(readRef(dbAs(A), A), { lastReadAt: serverTimestamp(), unread: 0, extra: 1 }));
  await assertFails(setDoc(readRef(dbAs(A), A), { unread: 0 }));
});

test('both members can read both read docs (for the "seen" indicator)', async () => {
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await setDoc(doc(ctx.firestore(), 'couples', COUPLE, 'chat', `read_${B}`), { lastReadAt: Timestamp.now(), unread: 3 });
  });
  await assertSucceeds(getDoc(readRef(dbAs(A), B)));
  await assertFails(getDoc(readRef(dbAs(OUTSIDER), B)));
});

test('chat/meta is read-only for clients', async () => {
  const meta = (uid: string) => doc(dbAs(uid), 'couples', COUPLE, 'chat', 'meta');
  await assertFails(setDoc(meta(A), { lastMessagePreview: 'forged' }));
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await setDoc(doc(ctx.firestore(), 'couples', COUPLE, 'chat', 'meta'), { lastMessagePreview: 'ok' });
  });
  await assertSucceeds(getDoc(meta(A)));
  await assertFails(getDoc(doc(dbAs(OUTSIDER), 'couples', COUPLE, 'chat', 'meta')));
});

// ── The generic subcollection grant must NOT leak into chat ─────────────────

test('other subcollections still work for members (carve-out did not over-restrict)', async () => {
  await assertSucceeds(setDoc(doc(dbAs(A), 'couples', COUPLE, 'lastTime', 'walk'), { lastDone: serverTimestamp() }));
  await assertFails(setDoc(doc(dbAs(OUTSIDER), 'couples', COUPLE, 'lastTime', 'walk'), { lastDone: serverTimestamp() }));
});

// ── Typing state (chat/typing_{uid}) ────────────────────────────────────────

const typingRef = (db: ReturnType<typeof dbAs>, uid: string) =>
  doc(db, 'couples', COUPLE, 'chat', `typing_${uid}`);

test('a member can write their OWN typing state', async () => {
  await assertSucceeds(setDoc(typingRef(dbAs(A), A), { isTyping: true, updatedAt: serverTimestamp() }));
  await assertSucceeds(setDoc(typingRef(dbAs(A), A), { isTyping: false, updatedAt: serverTimestamp() }));
});

test('a member cannot spoof the partner typing state', async () => {
  await assertFails(setDoc(typingRef(dbAs(A), B), { isTyping: true, updatedAt: serverTimestamp() }));
});

test('an outsider cannot read or write typing state', async () => {
  await setDoc(typingRef(dbAs(A), A), { isTyping: true, updatedAt: serverTimestamp() });
  await assertFails(getDoc(typingRef(dbAs(OUTSIDER), A)));
  await assertFails(setDoc(typingRef(dbAs(OUTSIDER), OUTSIDER), { isTyping: true, updatedAt: serverTimestamp() }));
});

test('typing updatedAt must be the server time (no faking freshness)', async () => {
  await assertFails(setDoc(typingRef(dbAs(A), A), { isTyping: true, updatedAt: Timestamp.fromDate(new Date(Date.now() + 3_600_000)) }));
  await assertFails(setDoc(typingRef(dbAs(A), A), { isTyping: true, updatedAt: Timestamp.now() }));
});

test('typing doc accepts only isTyping:bool + updatedAt', async () => {
  await assertFails(setDoc(typingRef(dbAs(A), A), { isTyping: 'yes', updatedAt: serverTimestamp() }));
  await assertFails(setDoc(typingRef(dbAs(A), A), { isTyping: true, updatedAt: serverTimestamp(), text: 'draft leak' }));
  await assertFails(setDoc(typingRef(dbAs(A), A), { isTyping: true }));
});

test('the partner can read my typing state; a removed partner cannot', async () => {
  await setDoc(typingRef(dbAs(A), A), { isTyping: true, updatedAt: serverTimestamp() });
  await assertSucceeds(getDoc(typingRef(dbAs(B), A)));
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await updateDoc(doc(ctx.firestore(), 'couples', COUPLE), { members: [A] });
  });
  await assertFails(getDoc(typingRef(dbAs(B), A)));
  await assertFails(setDoc(typingRef(dbAs(B), B), { isTyping: true, updatedAt: serverTimestamp() }));
});

// ── Heart reactions (chat/hearts_{uid}) ─────────────────────────────────────

const heartsRef = (db: ReturnType<typeof dbAs>, uid: string) =>
  doc(db, 'couples', COUPLE, 'chat', `hearts_${uid}`);

test('a member can add and then remove their OWN heart', async () => {
  await setDoc(msgRef(dbAs(B)), validText(B));
  await assertSucceeds(setDoc(heartsRef(dbAs(A), A), { m1: true }, { merge: true }));
  await assertSucceeds(setDoc(heartsRef(dbAs(A), A), { m1: deleteField() }, { merge: true }));
});

test('a member cannot add or remove the partner heart', async () => {
  await env.withSecurityRulesDisabled(async (ctx: RulesTestContext) => {
    await setDoc(doc(ctx.firestore(), 'couples', COUPLE, 'chat', `hearts_${B}`), { m1: true });
  });
  await assertFails(setDoc(heartsRef(dbAs(A), B), { m2: true }, { merge: true }));
  await assertFails(setDoc(heartsRef(dbAs(A), B), { m1: deleteField() }, { merge: true }));
});

test('heart values must be exactly true', async () => {
  await assertFails(setDoc(heartsRef(dbAs(A), A), { m1: false }, { merge: true }));
  await assertFails(setDoc(heartsRef(dbAs(A), A), { m1: 'heart' }, { merge: true }));
  await assertFails(setDoc(heartsRef(dbAs(A), A), { m1: 1 }, { merge: true }));
});

test('only one heart may change per write', async () => {
  await assertFails(setDoc(heartsRef(dbAs(A), A), { m1: true, m2: true }, { merge: true }));
  await setDoc(heartsRef(dbAs(A), A), { m1: true }, { merge: true });
  await assertFails(setDoc(heartsRef(dbAs(A), A), { m2: true, m3: true }, { merge: true }));
  await assertSucceeds(setDoc(heartsRef(dbAs(A), A), { m2: true }, { merge: true }));
});

test('hearts docs cannot be deleted or read by outsiders', async () => {
  await setDoc(heartsRef(dbAs(A), A), { m1: true }, { merge: true });
  await assertFails(deleteDoc(heartsRef(dbAs(A), A)));
  await assertFails(getDoc(heartsRef(dbAs(OUTSIDER), A)));
  await assertSucceeds(getDoc(heartsRef(dbAs(B), A)));
});

test('reacting never touches the message: messages stay immutable', async () => {
  await setDoc(msgRef(dbAs(B)), validText(B));
  await setDoc(heartsRef(dbAs(A), A), { m1: true }, { merge: true });
  // Any attempt to write a reaction ONTO the message is still denied.
  await assertFails(updateDoc(msgRef(dbAs(A)), { hearts: [A] }));
  await assertFails(updateDoc(msgRef(dbAs(A)), { text: 'edited' }));
  // And the message content is exactly what B wrote.
  const snap = await getDoc(msgRef(dbAs(A)));
  if (snap.data()?.text !== 'hei' || snap.data()?.senderId !== B) throw new Error('message mutated');
});

test('read_{uid} rules are unchanged by the new shapes', async () => {
  // Typing/hearts shapes must not be accepted under the read_ id, and vice versa.
  await assertFails(setDoc(readRef(dbAs(A), A), { isTyping: true, updatedAt: serverTimestamp() }));
  await assertFails(setDoc(typingRef(dbAs(A), A), { lastReadAt: serverTimestamp(), unread: 0 }));
  await assertFails(setDoc(heartsRef(dbAs(A), A), { lastReadAt: serverTimestamp(), unread: 0 }));
  await assertSucceeds(setDoc(readRef(dbAs(A), A), { lastReadAt: serverTimestamp(), unread: 0 }));
});

// ── Image messages ──────────────────────────────────────────────────────────

const validImage = (senderId: string, path = `couples/${COUPLE}/chatImages/m1.jpg`) => ({
  senderId,
  type: 'image',
  storagePath: path,
  width: 1024,
  height: 768,
  createdAt: serverTimestamp(),
  clientTs: Date.now(),
});

test('a member can send a valid image message', async () => {
  await assertSucceeds(setDoc(msgRef(dbAs(A)), validImage(A)));
  // Dimensions are optional.
  const m = validImage(A) as Record<string, unknown>;
  delete m.width; delete m.height;
  await assertSucceeds(setDoc(msgRef(dbAs(A), 'm2'), m));
});

test('an image message cannot reference another couple\'s folder', async () => {
  await assertFails(setDoc(msgRef(dbAs(A)), validImage(A, 'couples/otherCouple/chatImages/m1.jpg')));
  await assertFails(setDoc(msgRef(dbAs(A)), validImage(A, `couples/${COUPLE}/memories/m1.jpg`)));
  await assertFails(setDoc(msgRef(dbAs(A)), validImage(A, 'https://example.com/x.jpg')));
  await assertFails(setDoc(msgRef(dbAs(A)), validImage(A, `couples/${COUPLE}/chatImages/../m1.jpg`)));
});

test('image message shape is validated', async () => {
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validImage(A), storagePath: 42 }));
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validImage(A), width: '1024' }));
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validImage(A), width: 0 }));
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validImage(A), height: 99999 }));
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validImage(A), text: 'sneaky' }));
  await assertFails(setDoc(msgRef(dbAs(A)), { ...validImage(A), imageUrl: 'https://x' }));
});

test('image messages obey the same sender/outsider/immutability rules', async () => {
  await assertFails(setDoc(msgRef(dbAs(A)), validImage(B)));            // impersonation
  await assertFails(setDoc(msgRef(dbAs(OUTSIDER)), validImage(OUTSIDER)));
  await setDoc(msgRef(dbAs(A)), validImage(A));
  await assertFails(updateDoc(msgRef(dbAs(A)), { storagePath: `couples/${COUPLE}/chatImages/other.jpg` }));
  await assertFails(deleteDoc(msgRef(dbAs(B))));
  await assertSucceeds(getDoc(msgRef(dbAs(B))));
  await assertFails(getDoc(msgRef(dbAs(OUTSIDER))));
});

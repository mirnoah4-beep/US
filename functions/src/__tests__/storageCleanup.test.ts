// Unit tests for the Storage cleanup helper — pure accounting over a fake
// bucket. The emulator suite (__rules__/lifecycle.emulator.test.ts) proves the
// same guarantees against real Storage + Firestore emulators.
// Run: npm test

import { test } from 'node:test';
import * as assert from 'node:assert';

import {
  isValidStorageId,
  couplePrefix,
  userPrefix,
  cleanupPrefix,
  cleanupCoupleStorage,
  countObjects,
  errorCodesOf,
  allNotFound,
  formatCleanupLog,
  type CleanupBucket,
} from '../storageCleanup';

// ── Fake bucket ─────────────────────────────────────────────────────────────

class FakeBucket implements CleanupBucket {
  objects = new Set<string>();
  /// Object names whose delete fails with the given code, once per attempt.
  failing = new Map<string, string>();
  deleteCalls: Array<{ prefix: string; force: boolean }> = [];
  listCalls = 0;

  constructor(names: string[] = []) { names.forEach((n) => this.objects.add(n)); }

  async getFiles(q: { prefix: string; autoPaginate?: boolean; pageToken?: string; maxResults?: number }):
      Promise<[unknown[], ...unknown[]]> {
    this.listCalls++;
    assert.strictEqual(q.autoPaginate, false, 'listing must be paginated explicitly');
    const all = [...this.objects].filter((n) => n.startsWith(q.prefix)).sort();
    const start = q.pageToken ? Number(q.pageToken) : 0;
    const size = q.maxResults ?? all.length;
    const page = all.slice(start, start + size);
    const next = start + size < all.length ? { pageToken: String(start + size) } : null;
    return [page.map((name) => ({ name })), next];
  }

  async deleteFiles(q: { prefix: string; force: boolean }): Promise<void> {
    this.deleteCalls.push(q);
    const errors: Array<{ code: string }> = [];
    for (const n of [...this.objects]) {
      if (!n.startsWith(q.prefix)) continue;
      const code = this.failing.get(n);
      if (code) {
        this.failing.delete(n);          // fails once, succeeds on the retry
        if (!q.force) throw { code };
        errors.push({ code });
        continue;
      }
      this.objects.delete(n);
    }
    if (errors.length) throw errors;
  }
}

// ── Id validation / prefix construction ─────────────────────────────────────

test('ids: uids and Firestore auto-ids pass; anything path-like is rejected', () => {
  assert.ok(isValidStorageId('1RTxZHUV1NbvNlFsXhwl5LeEgFw1'));
  assert.ok(isValidStorageId('FWirUm6CcAQ1hdka1rpa'));
  assert.ok(isValidStorageId('c1'));
  for (const bad of ['', ' ', 'a/b', '..', '.', 'c1/', '/c1', 'a b', 'a.b', '*', 'x'.repeat(129), 42, null, undefined]) {
    assert.ok(!isValidStorageId(bad), JSON.stringify(bad));
  }
});

test('prefixes are exact and end with a slash', async () => {
  assert.strictEqual(couplePrefix('c1'), 'couples/c1/');
  assert.strictEqual(userPrefix('u1'), 'users/u1/');
  assert.throws(() => couplePrefix('c1/'));
  assert.throws(() => couplePrefix(''));
  assert.throws(() => userPrefix('../c1'));
  await assert.rejects(() => cleanupPrefix(new FakeBucket(), 'couples/c1'), /end with/);
});

// ── Isolation ───────────────────────────────────────────────────────────────

test('couple A cleanup cannot touch couple B', async () => {
  const b = new FakeBucket([
    'couples/A/chatImages/m1.jpg', 'couples/A/memories/d1.jpg',
    'couples/B/chatImages/m1.jpg', 'couples/B/memories/d1.jpg',
  ]);
  const r = await cleanupCoupleStorage(b, 'A');
  assert.deepStrictEqual([r.listed, r.deleted, r.failed], [2, 2, 0]);
  assert.deepStrictEqual([...b.objects].sort(), ['couples/B/chatImages/m1.jpg', 'couples/B/memories/d1.jpg']);
  assert.deepStrictEqual(b.deleteCalls, [{ prefix: 'couples/A/', force: true }]);
});

test('c1/ cannot match c10/', async () => {
  const b = new FakeBucket(['couples/c1/chatImages/a.jpg', 'couples/c10/chatImages/a.jpg', 'couples/c100/memories/x.jpg']);
  const r = await cleanupCoupleStorage(b, 'c1');
  assert.deepStrictEqual([r.listed, r.deleted, r.failed], [1, 1, 0]);
  assert.deepStrictEqual([...b.objects].sort(), ['couples/c10/chatImages/a.jpg', 'couples/c100/memories/x.jpg']);
});

test('a users/ prefix never reaches couples/ and vice versa', async () => {
  const b = new FakeBucket(['users/u1/avatar.jpg', 'couples/u1/chatImages/a.jpg']);
  await cleanupPrefix(b, userPrefix('u1'));
  assert.deepStrictEqual([...b.objects], ['couples/u1/chatImages/a.jpg']);
});

// ── Idempotency ─────────────────────────────────────────────────────────────

test('empty prefix succeeds without a delete call', async () => {
  const b = new FakeBucket(['couples/other/chatImages/a.jpg']);
  const r = await cleanupCoupleStorage(b, 'nothing');
  assert.deepStrictEqual(r, { prefix: 'couples/nothing/', listed: 0, deleted: 0, failed: 0, errorCodes: [] });
  assert.strictEqual(b.deleteCalls.length, 0);
});

test('repeated cleanup succeeds', async () => {
  const b = new FakeBucket(['couples/c1/chatImages/a.jpg']);
  const first = await cleanupCoupleStorage(b, 'c1');
  const second = await cleanupCoupleStorage(b, 'c1');
  assert.deepStrictEqual([first.listed, first.deleted], [1, 1]);
  assert.deepStrictEqual([second.listed, second.deleted, second.failed], [0, 0, 0]);
});

// ── Pagination ──────────────────────────────────────────────────────────────

test('listing paginates through more than one page', async () => {
  const names = Array.from({ length: 2500 }, (_, i) => `couples/c1/chatImages/m${i}.jpg`);
  const b = new FakeBucket([...names, 'couples/c2/chatImages/x.jpg']);
  assert.strictEqual(await countObjects(b, 'couples/c1/'), 2500);
  assert.strictEqual(b.listCalls, 3);       // 1000 + 1000 + 500
  const r = await cleanupCoupleStorage(b, 'c1');
  assert.deepStrictEqual([r.listed, r.deleted, r.failed], [2500, 2500, 0]);
  assert.strictEqual(b.objects.size, 1);
});

// ── Failure surfacing ───────────────────────────────────────────────────────

test('force: one failing object never aborts the rest, and is retried once', async () => {
  const b = new FakeBucket(['couples/c1/chatImages/a.jpg', 'couples/c1/chatImages/b.jpg', 'couples/c1/memories/c.jpg']);
  b.failing.set('couples/c1/chatImages/b.jpg', 'ECONNRESET');
  const r = await cleanupCoupleStorage(b, 'c1');
  assert.deepStrictEqual([r.listed, r.deleted, r.failed], [3, 3, 0]);
  assert.deepStrictEqual(r.errorCodes, ['ECONNRESET']);
  assert.strictEqual(b.deleteCalls.length, 2);
  assert.ok(b.deleteCalls.every((c) => c.force));
});

test('persistent failures are surfaced as a residue, never swallowed', async () => {
  const b = new FakeBucket(['couples/c1/chatImages/a.jpg', 'couples/c1/chatImages/b.jpg']);
  // Fails on both attempts.
  const stubborn = 'couples/c1/chatImages/b.jpg';
  b.deleteFiles = async (q) => {
    b.deleteCalls.push(q);
    for (const n of [...b.objects]) if (n.startsWith(q.prefix) && n !== stubborn) b.objects.delete(n);
    throw [{ code: 403 }];
  };
  const r = await cleanupCoupleStorage(b, 'c1');
  assert.deepStrictEqual([r.listed, r.deleted, r.failed], [2, 1, 1]);
  assert.deepStrictEqual(r.errorCodes, ['403']);
});

test('404s from a concurrent delete count as already gone', async () => {
  const b = new FakeBucket(['couples/c1/chatImages/a.jpg']);
  b.deleteFiles = async (q) => {
    b.deleteCalls.push(q);
    b.objects.clear();
    throw [{ code: 404 }, { code: 404 }];
  };
  const r = await cleanupCoupleStorage(b, 'c1');
  assert.deepStrictEqual([r.listed, r.deleted, r.failed, r.errorCodes], [1, 1, 0, []]);
  assert.strictEqual(b.deleteCalls.length, 1);
});

test('error codes are reduced to distinct codes; arrays and singles alike', () => {
  assert.deepStrictEqual(errorCodesOf([{ code: 403 }, { code: '403' }, { code: 'ECONNRESET' }, {}, null]), ['403', 'ECONNRESET', 'unknown']);
  assert.deepStrictEqual(errorCodesOf(new Error('boom')), ['Error']);
  assert.ok(allNotFound([{ code: 404 }]));
  assert.ok(!allNotFound([{ code: 404 }, { code: 500 }]));
});

test('the log line carries counts and codes only — never object names', async () => {
  const b = new FakeBucket(['couples/c1/chatImages/SECRET_NAME.jpg']);
  const r = await cleanupPrefix(b, couplePrefix('c1'));
  const line = formatCleanupLog('couple', r);
  assert.ok(line.includes('listed=1') && line.includes('deleted=1') && line.includes('failed=0'));
  assert.ok(!line.includes('SECRET_NAME'));
  assert.ok(!JSON.stringify(r).includes('SECRET_NAME'));
});

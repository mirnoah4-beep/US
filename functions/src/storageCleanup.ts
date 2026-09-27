// Authoritative, idempotent Storage cleanup for the two prefixes the app
// owns per entity:
//
//   couples/{coupleId}/   (chatImages/*, memories/*, anything else couple-scoped)
//   users/{uid}/          (avatar and any other per-user files)
//
// Runs with the Admin SDK only — the client never has a broad delete grant
// (see storage.rules). The prefix is always built here from a validated id;
// callers pass a server-derived id, never a client-supplied path.
//
// Guarantees:
//   * exact-prefix: the trailing slash means `couples/c1/` can never match
//     `couples/c10/`;
//   * idempotent: an empty prefix (or a second run) is a clean no-op;
//   * paginated: listing/deleting streams every page of the prefix;
//   * force: one bad object never aborts the rest; 404s count as already gone;
//   * private: results and logs carry counts and error CODES only — never
//     object names, image bytes or chat contents.

/// Firebase Auth uids and Firestore auto-ids are alphanumeric; `_`/`-` are
/// tolerated for custom-provider uids. No `/`, `.`, whitespace or empties —
/// so an id can never widen or escape its prefix.
const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export function isValidStorageId(id: unknown): id is string {
  return typeof id === 'string' && ID_PATTERN.test(id);
}

export function couplePrefix(coupleId: string): string {
  if (!isValidStorageId(coupleId)) throw new Error('invalid coupleId');
  return `couples/${coupleId}/`;
}

export function userPrefix(uid: string): string {
  if (!isValidStorageId(uid)) throw new Error('invalid uid');
  return `users/${uid}/`;
}

export interface CleanupResult {
  prefix: string;
  /// Objects found under the prefix before deleting.
  listed: number;
  /// Objects that are gone afterwards (deleted now, or already gone).
  deleted: number;
  /// Objects still present after the retry — surfaced, never swallowed.
  failed: number;
  /// Distinct error codes seen (e.g. "403", "ECONNRESET"); never names.
  errorCodes: string[];
}

/// The slice of @google-cloud/storage `Bucket` this module touches — kept as
/// an interface so the pure accounting can be unit-tested with a fake.
export interface CleanupBucket {
  getFiles(query: {
    prefix: string;
    autoPaginate?: boolean;
    pageToken?: string;
    maxResults?: number;
  }): Promise<[unknown[], ...unknown[]]>;
  deleteFiles(query: { prefix: string; force: boolean }): Promise<void>;
}

/// Counts every object under [prefix], page by page (never autoPaginate —
/// a huge prefix must not be buffered in memory).
export async function countObjects(bucket: CleanupBucket, prefix: string): Promise<number> {
  let total = 0;
  let pageToken: string | undefined;
  do {
    const [files, nextQuery] = await bucket.getFiles({
      prefix,
      autoPaginate: false,
      maxResults: 1000,
      ...(pageToken ? { pageToken } : {}),
    });
    total += files.length;
    const next = nextQuery as { pageToken?: unknown } | null | undefined;
    pageToken = typeof next?.pageToken === 'string' ? next.pageToken : undefined;
  } while (pageToken);
  return total;
}

/// Reduces whatever `deleteFiles({ force: true })` threw (an array of
/// per-object errors, or a single error) to distinct codes.
export function errorCodesOf(thrown: unknown): string[] {
  const list = Array.isArray(thrown) ? thrown : [thrown];
  const codes = new Set<string>();
  for (const e of list) {
    const anyE = e as { code?: unknown; name?: unknown } | null | undefined;
    const code = anyE?.code ?? anyE?.name;
    codes.add(typeof code === 'string' || typeof code === 'number' ? String(code) : 'unknown');
  }
  return [...codes].sort();
}

/// True when every error is a 404 — the objects were already gone, which is
/// success for an idempotent delete.
export function allNotFound(thrown: unknown): boolean {
  return errorCodesOf(thrown).every((c) => c === '404');
}

/// Deletes exactly [prefix]. Never throws on per-object failures: the result
/// carries the residue so the caller can surface it.
export async function cleanupPrefix(bucket: CleanupBucket, prefix: string): Promise<CleanupResult> {
  if (!prefix.endsWith('/')) throw new Error('prefix must end with /');
  const errorCodes = new Set<string>();
  const listed = await countObjects(bucket, prefix);
  if (listed === 0) {
    return { prefix, listed: 0, deleted: 0, failed: 0, errorCodes: [] };
  }

  // Two passes: the second catches transient per-object failures from the
  // first. force:true keeps one bad object from aborting the batch.
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      await bucket.deleteFiles({ prefix, force: true });
      break;
    } catch (thrown) {
      if (allNotFound(thrown)) break;
      for (const c of errorCodesOf(thrown)) errorCodes.add(c);
    }
  }

  const failed = await countObjects(bucket, prefix);
  return {
    prefix,
    listed,
    deleted: listed - failed,
    failed,
    errorCodes: [...errorCodes].sort(),
  };
}

/// One log line per cleanup, counts and codes only.
export function formatCleanupLog(label: string, r: CleanupResult): string {
  const codes = r.errorCodes.length ? ` codes=${r.errorCodes.join(',')}` : '';
  return `[storageCleanup] ${label} prefix=${r.prefix} listed=${r.listed} deleted=${r.deleted} failed=${r.failed}${codes}`;
}

export async function cleanupCoupleStorage(bucket: CleanupBucket, coupleId: string): Promise<CleanupResult> {
  const r = await cleanupPrefix(bucket, couplePrefix(coupleId));
  (r.failed > 0 ? console.error : console.log)(formatCleanupLog('couple', r));
  return r;
}

export async function cleanupUserStorage(bucket: CleanupBucket, uid: string): Promise<CleanupResult> {
  const r = await cleanupPrefix(bucket, userPrefix(uid));
  (r.failed > 0 ? console.error : console.log)(formatCleanupLog('user', r));
  return r;
}

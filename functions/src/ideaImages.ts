// AI cover images for PREMIUM weekly ideas.
//
// Deliberately built on the image architecture the Flutter client already uses
// rather than a parallel one:
//   - the client calls IdeaImageService.fetchCoverUrl(ideaId)
//   - which reads  ideas/{ideaId}.coverImageUrl
//   - where ideaId = IdeaImageService.toId(idea.titleNo)
//   - and the existing admin upload path is ideas/{ideaId}/cover.jpg
// So a server-generated cover is indistinguishable from an admin-uploaded one,
// and no client change is needed to display it.

import type { Bucket } from '@google-cloud/storage';
import { randomUUID } from 'crypto';
import type OpenAI from 'openai';
import type { IdeaObject } from './generateWeeklyIdeas';

/// Hard ceiling on NEW images per couple per generation run. There are only
/// ever 5 ideas, so this can never be exceeded in normal operation — it exists
/// so a future bug cannot turn into a runaway image bill.
export const MAX_NEW_IMAGES_PER_RUN = 5;

/// Pre-launch rollout allowlist for AI cover generation, keyed by MEMBER UID.
///
/// Keyed by uid rather than coupleId on purpose: a uid is obtainable from the
/// Firebase CLI (`firebase auth:export`), whereas the CLI cannot read Firestore
/// documents, so resolving a coupleId would need credentials this project does
/// not have. The couple's members are already loaded when generation runs, so
/// a uid gate needs no extra read.
///
/// EMPTY means the feature is off for everybody — premium included. Image
/// generation costs real money per call, so it stays opt-in until the
/// single-couple test has passed.
export const IMAGE_GEN_UID_ALLOWLIST: readonly string[] = [
  '1RTxZHUV1NbvNlFsXhwl5LeEgFw1', // mirnoah4@gmail.com — pre-launch test account
];

/// True when this couple may have AI covers generated, i.e. at least one member
/// is on the pre-launch allowlist. Premium is checked separately by the caller;
/// this is only the rollout gate.
export function isImageGenEnabledFor(members: readonly string[]): boolean {
  if (IMAGE_GEN_UID_ALLOWLIST.length === 0) return false;
  return members.some((uid) => IMAGE_GEN_UID_ALLOWLIST.includes(uid));
}

const IMAGE_MODEL = 'gpt-image-1';
const IMAGE_SIZE = '1024x1024';

/// Bumped when the style below changes, so we can tell which covers came from
/// which visual identity. Does NOT trigger regeneration on its own.
export const IMAGE_PROMPT_VERSION = 1;

/// Exact port of IdeaImageService.toId() in lib/services/idea_image_service.dart:
///   title.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9æøå]+'), '_')
/// It must stay byte-identical or the server writes a document the client will
/// never look up.
export function toIdeaId(title: string): string {
  return title.toLowerCase().trim().replace(/[^a-z0-9æøå]+/g, '_');
}

/// The client resolves titleNo as `titleNo` when non-empty, else `title`
/// (WeeklyIdea.fromJson). Mirror that exactly to derive the same id.
export function ideaIdFor(idea: CoverPromptSource): string {
  const titleNo = (idea.titleNo ?? '').trim();
  const base = titleNo.length > 0 ? titleNo : (idea.title ?? '');
  return toIdeaId(base);
}

/// Anything that can describe an idea: a weekly IdeaObject or a raw
/// ideas/{ideaId} Firestore document. Both share these field names.
export interface CoverPromptSource {
  title?: string;
  titleNo?: string;
  titleEn?: string;
  category?: string;
  categoryNo?: string;
  categoryEn?: string;
  meta?: string;
  metaNo?: string;
  metaEn?: string;
  description?: string;
  descriptionNo?: string;
  descriptionEn?: string;
  season?: string;
  effort?: string;
}

function firstNonEmpty(...values: Array<unknown>): string {
  for (const v of values) {
    if (typeof v === 'string' && v.trim().length > 0) return v.trim();
  }
  return '';
}

/// The single place the US visual identity for idea covers is defined.
/// Change the style here and every future cover follows — weekly premium
/// generation and the ideas-library backfill both go through this.
export function buildCoverPrompt(idea: CoverPromptSource): string {
  const subject = firstNonEmpty(idea.titleEn, idea.title, idea.titleNo);
  const detail = firstNonEmpty(idea.descriptionEn, idea.description, idea.descriptionNo);
  const category = firstNonEmpty(idea.categoryEn, idea.category, idea.categoryNo);
  const meta = firstNonEmpty(idea.metaEn, idea.meta, idea.metaNo);
  const season = firstNonEmpty(idea.season);
  const effort = firstNonEmpty(idea.effort);

  return [
    'Warm lifestyle editorial photograph for a couples date-planning app card.',
    `The scene shows this specific activity: ${subject}.`,
    detail ? `Context: ${detail}` : '',
    category ? `Category: ${category}.` : '',
    meta ? `Rough scale: ${meta}.` : '',
    season ? `Season: ${season}.` : '',
    effort ? `Effort level: ${effort}.` : '',
    'Style: intimate but natural couple activity, cozy, modern, premium,',
    'soft natural lighting, realistic, tasteful, shallow depth of field,',
    'muted warm colour palette.',
    'Absolutely no text, no lettering, no logos, no watermark, no user interface elements.',
    'No close-up identifiable faces and no recognisable celebrities —',
    'prefer wider framing, from behind, or partially out of frame.',
  ].filter((s) => s.length > 0).join(' ');
}

export interface CoverImageDeps {
  firestore: FirebaseFirestore.Firestore;
  bucket: Bucket;
  openai: OpenAI;
}

export interface CoverImageResult {
  reused: number;
  generated: number;
  failed: number;
  /// ideaId -> url, for the ones this run resolved.
  urls: Record<string, string>;
  /// Per-idea failure reasons, so a failure is diagnosable without log spelunking.
  errors: string[];
}

/// True when a stored value is a usable cover URL.
export function hasUsableCoverUrl(value: unknown): value is string {
  return typeof value === 'string' && value.startsWith('http');
}

export type CoverOutcome = 'already-ok' | 'repaired' | 'generated' | 'failed';

export interface CoverResolution {
  ideaId: string;
  outcome: CoverOutcome;
  url: string | null;
  error: string | null;
}

/// Resolves a cover for ONE idea, in strict cheapest-first order:
///   1. a usable coverImageUrl in Firestore      -> 'already-ok' (free)
///   2. an existing ideas/{ideaId}/cover.jpg     -> 'repaired'   (free)
///   3. otherwise, generate one                  -> 'generated'  (costs money)
///
/// Step 2 matters twice over: it is what the ideas-library backfill needs, and
/// it also stops the weekly path from paying to overwrite an image that is
/// already sitting in Storage.
///
/// Never throws — the caller gets 'failed' with a reason.
export async function resolveCoverForIdea(
  deps: CoverImageDeps,
  idea: CoverPromptSource,
  ideaId: string,
  opts: { allowGenerate: boolean },
): Promise<CoverResolution> {
  const base: CoverResolution = { ideaId, outcome: 'failed', url: null, error: null };
  if (!ideaId) return { ...base, error: 'empty ideaId' };

  try {
    const docRef = deps.firestore.collection('ideas').doc(ideaId);
    const snap = await docRef.get();
    const existing = snap.data()?.coverImageUrl;

    // 1. Already linked — never overwrite a valid URL.
    if (hasUsableCoverUrl(existing)) {
      return { ...base, outcome: 'already-ok', url: existing };
    }

    // 2. Image already in Storage — link it instead of regenerating.
    const path = `ideas/${ideaId}/cover.jpg`;
    const file = deps.bucket.file(path);
    const [exists] = await file.exists();
    if (exists) {
      const [md] = await file.getMetadata();
      let token = pickDownloadToken(md);
      if (token === null) {
        token = randomUUID();
        await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
      }
      const url = downloadUrlFor(deps.bucket.name, path, token);
      await docRef.set({ coverImageUrl: url, coverRepairedAt: new Date() }, { merge: true });
      return { ...base, outcome: 'repaired', url };
    }

    // 3. Nothing exists — generate, if the caller permits spending.
    if (!opts.allowGenerate) {
      return { ...base, error: 'no cover and generation not permitted' };
    }
    const url = await generateAndUpload(deps, idea, ideaId);
    return { ...base, outcome: 'generated', url };
  } catch (err) {
    return { ...base, error: err instanceof Error ? err.message : 'unknown error' };
  }
}

/// Ensures every idea has a cover image, reusing any that already exists.
///
/// Never throws: image generation must not be able to fail the weekly ideas
/// generation. Every per-idea failure is logged and counted, and the run
/// continues with the remaining ideas.
export async function ensureCoverImages(
  deps: CoverImageDeps,
  ideas: IdeaObject[],
  coupleId: string,
): Promise<CoverImageResult> {
  const result: CoverImageResult = { reused: 0, generated: 0, failed: 0, urls: {}, errors: [] };
  let budget = MAX_NEW_IMAGES_PER_RUN;

  for (const idea of ideas) {
    const ideaId = ideaIdFor(idea);
    // Spend the budget before the attempt, so a throw cannot retry it.
    const allowGenerate = budget > 0;
    const res = await resolveCoverForIdea(deps, idea, ideaId, { allowGenerate });

    if (res.outcome === 'generated') {
      budget--;
      result.generated++;
      result.urls[ideaId] = res.url!;
    } else if (res.outcome === 'repaired' || res.outcome === 'already-ok') {
      // Both are free reuse from the caller's point of view.
      result.reused++;
      result.urls[ideaId] = res.url!;
    } else {
      result.failed++;
      result.errors.push(`${ideaId || '<no id>'}: ${res.error ?? 'unknown'}`);
      console.error(
        `ideaImages: cover failed for ${ideaId} (couple ${coupleId}): ${res.error}`,
      );
    }
  }

  console.log(
    `ideaImages couple ${coupleId}: reused ${result.reused}, `
    + `generated ${result.generated}, failed ${result.failed}`,
  );
  return result;
}

/// Exactly one generation attempt — no retry loop, by design.
async function generateAndUpload(
  deps: CoverImageDeps,
  idea: CoverPromptSource,
  ideaId: string,
): Promise<string> {
  const prompt = buildCoverPrompt(idea);

  const response = await deps.openai.images.generate({
    model: IMAGE_MODEL,
    prompt,
    size: IMAGE_SIZE,
    n: 1,
  });

  const first = response.data?.[0];
  let buffer: Buffer;
  if (first?.b64_json) {
    buffer = Buffer.from(first.b64_json, 'base64');
  } else if (first?.url) {
    const res = await fetch(first.url);
    if (!res.ok) throw new Error(`image download failed: HTTP ${res.status}`);
    buffer = Buffer.from(await res.arrayBuffer());
  } else {
    throw new Error('image response contained neither b64_json nor url');
  }

  // Same Storage path the admin upload flow uses, so nothing else changes.
  const path = `ideas/${ideaId}/cover.jpg`;
  const token = randomUUID();
  const file = deps.bucket.file(path);
  await file.save(buffer, {
    resumable: false,
    contentType: 'image/jpeg',
    metadata: {
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=31536000',
      // Produces the same tokened URL shape as the client's getDownloadURL().
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });

  const url = downloadUrlFor(deps.bucket.name, path, token);

  await deps.firestore.collection('ideas').doc(ideaId).set({
    coverImageUrl: url,
    generatedBy: 'ai',
    imageModel: IMAGE_MODEL,
    imagePromptVersion: IMAGE_PROMPT_VERSION,
    imagePrompt: prompt,
    createdAt: new Date(),
  }, { merge: true });

  return url;
}

/// Extracts an existing Firebase download token from object metadata, if the
/// object already has one (objects uploaded by the client SDK do).
/// Returns null when the object has no token and one must be minted.
export function pickDownloadToken(metadata: unknown): string | null {
  const nested = (metadata as { metadata?: Record<string, unknown> } | null)?.metadata;
  const raw = nested?.firebaseStorageDownloadTokens;
  if (typeof raw !== 'string' || raw.length === 0) return null;
  // The field may hold a comma-separated list; any one of them works.
  const first = raw.split(',')[0]?.trim();
  return first && first.length > 0 ? first : null;
}

/// Decides whether a legacy Storage cover should be linked into Firestore.
/// Never overwrites an already-valid coverImageUrl.
export function shouldRepairCover(existingUrl: unknown): boolean {
  return !hasUsableCoverUrl(existingUrl);
}

/// Derives the ideaId from a Storage object path, or null if the path is not
/// exactly the expected `ideas/{ideaId}/cover.jpg` shape.
export function ideaIdFromCoverPath(path: string): string | null {
  const m = path.match(/^ideas\/([^/]+)\/cover\.jpg$/);
  return m ? m[1] : null;
}

/// The public download URL format Firebase Storage serves for a tokened object.
/// Matches what FirebaseStorage.getDownloadURL() returns on the client, so the
/// existing Storage rules (which only gate direct SDK reads) are unaffected.
export function downloadUrlFor(bucket: string, path: string, token: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/`
    + `${encodeURIComponent(path)}?alt=media&token=${token}`;
}

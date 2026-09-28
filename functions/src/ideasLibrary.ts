// The date-idea library shared with the Flutter client (same JSON file is a
// Flutter asset) plus the parent-mode rule both sides apply identically.

import type { CoupleProfile } from './preferences';
import raw from './ideasLibrary.json';

export type IdeaFilter = '10min' | 'home' | 'out' | 'talk' | 'food';

export interface LibraryIdea {
  id: string;
  titleNo: string; titleEn: string;
  subtitleNo: string; subtitleEn: string;
  descNo: string; descEn: string;
  durationNo: string; durationEn: string;
  categoryNo: string; categoryEn: string;
  filters: IdeaFilter[];
  icon: string;
  colorIndex: number;
  parentFriendly: boolean;
  requiresKidFree: boolean;
  effort: 'low' | 'medium' | 'high';
}

export const IDEA_LIBRARY: readonly LibraryIdea[] = raw as LibraryIdea[];

/// Minimal shape the rule needs — a library idea or a raw ideas/{id} doc.
export interface ParentTagged {
  parentFriendly?: unknown;
  requiresKidFree?: unknown;
}

/// Parent-mode rule (mirrors lib/models/idea_library.dart `ideaAllowed`):
///   * not a parent → everything;
///   * parent, usual situation (kids home) → only parentFriendly === true;
///   * parent, kid-free session → parentFriendly OR requiresKidFree.
/// A document without tags is treated as NOT parent-friendly (conservative).
export function ideaAllowedForProfile(idea: ParentTagged, profile: Pick<CoupleProfile, 'isParent' | 'childcareState'>): boolean {
  if (!profile.isParent) return true;
  if (idea.parentFriendly === true) return true;
  return profile.childcareState === 'kidFree' && idea.requiresKidFree === true;
}

/// The prompt lines that make the AI respect the same rule. Norwegian, like
/// the rest of the ideas prompt.
export function parentModeRuleLines(profile: Pick<CoupleProfile, 'isParent' | 'childcareState'>): string[] {
  if (!profile.isParent) return [];
  if (profile.childcareState === 'kidFree') {
    return [
      'De er foreldre, men er barnefrie denne gangen (barnevakt): foreldrevennlige ideer er fortsatt fine, og ideer som krever full frihet (kveld ute, restaurant, konsert, aktivitet i byen) er også tillatt.',
    ];
  }
  return [
    'FORELDREMODUS: Alle fem ideene MÅ være foreldrevennlige – mulige med barn i nærheten eller etter leggetid, hjemme eller nær hjemmet, enkle å få til med lite tid, og realistiske for slitne foreldre.',
    'Ingen ideer som forutsetter barnevakt eller full frihet (kveld ute, restaurant, konsert, reise).',
  ];
}

/// The Firestore document written for each library idea so the curated tier
/// draws from the same library (IdeaObject shape + tags). Never includes the
/// cover URL — that is owned by the image pipeline.
export function libraryIdeaDoc(i: LibraryIdea): Record<string, unknown> {
  const palette = PALETTES[i.colorIndex % PALETTES.length];
  return {
    title: i.titleNo,
    titleNo: i.titleNo, titleEn: i.titleEn,
    category: i.categoryNo, categoryNo: i.categoryNo, categoryEn: i.categoryEn,
    meta: i.durationNo, metaNo: i.durationNo, metaEn: i.durationEn,
    description: i.descNo, descriptionNo: i.descNo, descriptionEn: i.descEn,
    subtitleNo: i.subtitleNo, subtitleEn: i.subtitleEn,
    iconName: i.icon,
    cardColor: palette.card, tagColor: palette.tag, tagTextColor: palette.tagText,
    effort: i.effort,
    filters: i.filters,
    parentFriendly: i.parentFriendly,
    requiresKidFree: i.requiresKidFree,
    library: true,
    libraryVersion: LIBRARY_VERSION,
  };
}

export const LIBRARY_VERSION = 1;

// Same palette family the Ideas screen uses (card / tag / tag text).
const PALETTES = [
  { card: '#FAECE7', tag: '#F5C4B3', tagText: '#712B13' },
  { card: '#EAF3DE', tag: '#C0DD97', tagText: '#27500A' },
  { card: '#FAEEDA', tag: '#FAC775', tagText: '#633806' },
  { card: '#E1F5EE', tag: '#9FE1CB', tagText: '#085041' },
  { card: '#FBEAF0', tag: '#F4C0D1', tagText: '#72243E' },
  { card: '#EAF0FA', tag: '#B9CDF2', tagText: '#1F3A6B' },
  { card: '#F1EAFA', tag: '#D3BFF2', tagText: '#3F2470' },
];

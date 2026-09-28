// Server-side notification copy, NO + EN.
//
// These strings are resolved on the server, not the client, because FCM
// messages must render correctly when the recipient's app is backgrounded or
// terminated — a data-only message localized in Dart would display nothing in
// exactly the case that matters. The recipient's language comes from
// `users/{uid}.language`, mirrored there by LanguageProvider.
//
// Follows the existing `isNorwegian` convention used by formatPlanDate().

/// Partner message templates the client may request by id.
/// The client sends ONLY the id — never the copy, never a recipient.
export const PARTNER_TEMPLATE_IDS = [
  'miss_us_time',
  'tonight',
  'date_soon',
  'time_with_you',
] as const;

export type PartnerTemplateId = (typeof PARTNER_TEMPLATE_IDS)[number];

export function isPartnerTemplateId(value: unknown): value is PartnerTemplateId {
  return typeof value === 'string'
    && (PARTNER_TEMPLATE_IDS as readonly string[]).includes(value);
}

/// Rendered in the RECIPIENT's language, with the sender's display name.
export function partnerMessageBody(
  templateId: PartnerTemplateId,
  senderName: string,
  isNorwegian: boolean,
): string {
  switch (templateId) {
    case 'miss_us_time':
      return isNorwegian
        ? `${senderName} savner litt oss-tid ❤️`
        : `${senderName} misses your time together ❤️`;
    case 'tonight':
      return isNorwegian
        ? `${senderName} spør: skal dere finne på noe sammen i kveld? ❤️`
        : `${senderName} asks: want to do something together tonight? ❤️`;
    case 'date_soon':
      return isNorwegian
        ? `${senderName} har lyst på en liten date snart ❤️`
        : `${senderName} would love a little date soon ❤️`;
    case 'time_with_you':
      return isNorwegian
        ? `${senderName} har lyst på litt tid sammen med deg ❤️`
        : `${senderName} wants some time together with you ❤️`;
  }
}

export function partnerMessageTitle(isNorwegian: boolean): string {
  return isNorwegian ? 'Melding fra partneren din' : 'Message from your partner';
}

/// Automatic relationship reminders.
export type ReminderType = 'date' | 'quality_time' | 'weekly';

export function reminderTitle(type: ReminderType, isNorwegian: boolean): string {
  switch (type) {
    case 'date':
      return isNorwegian ? 'Tid for en date?' : 'Time for a date?';
    case 'quality_time':
      return isNorwegian ? 'Litt oss-tid?' : 'A little time together?';
    case 'weekly':
      return isNorwegian ? 'Hvordan har uka vært?' : 'How has your week been?';
  }
}

export function reminderBody(type: ReminderType, isNorwegian: boolean): string {
  switch (type) {
    case 'date':
      return isNorwegian
        ? 'Kanskje det er på tide med en liten date? ❤️'
        : 'Maybe it is time for a little date? ❤️';
    case 'quality_time':
      return isNorwegian
        ? 'Har dere hatt litt tid sammen i det siste? ❤️'
        : 'Have you had some time together lately? ❤️';
    case 'weekly':
      return isNorwegian
        ? 'Hvordan har uka vært for dere? Kanskje dere skal planlegge litt oss-tid ❤️'
        : 'How has your week been? Maybe plan some time together ❤️';
  }
}

/// Partner chat push copy, in the recipient's language.
export function chatMessageTitle(senderName: string, isNorwegian: boolean): string {
  const name = senderName.trim().length > 0
    ? senderName.trim()
    : (isNorwegian ? 'Partneren din' : 'Your partner');
  return name;
}

export function chatIdeaBody(
  senderName: string,
  ideaTitle: string,
  isNorwegian: boolean,
): string {
  const name = senderName.trim().length > 0
    ? senderName.trim()
    : (isNorwegian ? 'Partneren din' : 'Your partner');
  return isNorwegian
    ? `${name} delte en idé: ${ideaTitle}`
    : `${name} shared an idea: ${ideaTitle}`;
}

/// Image message push body. Deliberately content-free: no path, no URL, no
/// dimensions — the image is fetched through Storage rules by the app.
export function chatImageBody(senderName: string, isNorwegian: boolean): string {
  const name = senderName.trim().length > 0
    ? senderName.trim()
    : (isNorwegian ? 'Partneren din' : 'Your partner');
  return isNorwegian ? `${name} sendte et bilde 📷` : `${name} sent a photo 📷`;
}

/// "Oss mot problemet" pushes, in the recipient's language. Never any
/// content from the talk — only who and what stage.
export type MediationPush = 'invite' | 'reminder' | 'nudge' | 'summary' | 'round';
export function mediationTitle(kind: MediationPush, senderName: string, isNorwegian: boolean): string {
  const name = senderName.trim().length > 0 ? senderName.trim() : (isNorwegian ? 'Partneren din' : 'Your partner');
  switch (kind) {
    case 'invite': return isNorwegian ? `${name} vil gjerne snakke om noe` : `${name} would like to talk about something`;
    case 'reminder': return isNorwegian ? 'Klar for en liten prat?' : 'Ready for a little talk?';
    case 'nudge': return isNorwegian ? `${name} venter på deg` : `${name} is waiting for you`;
    case 'summary': return isNorwegian ? 'Oppsummeringen er klar' : 'Your summary is ready';
    case 'round': return isNorwegian ? 'Et nytt forslag venter' : 'A new suggestion is waiting';
  }
}
export function mediationBody(kind: MediationPush, isNorwegian: boolean): string {
  switch (kind) {
    case 'invite': return isNorwegian ? 'Oss mot problemet – 5 minutter, hver for dere først.' : 'Us vs. the problem – 5 minutes, privately first.';
    case 'reminder': return isNorwegian ? 'Dere avtalte å ta praten nå. Svar når det passer.' : 'You planned to have the talk now. Answer when it suits you.';
    case 'nudge': return isNorwegian ? 'Svarene dine er det eneste som mangler.' : 'Your answers are the only thing missing.';
    case 'summary': return isNorwegian ? 'Se hva dere har felles, og prøv en liten avtale.' : 'See what you have in common and try a small agreement.';
    case 'round': return isNorwegian ? 'Forslaget er justert ut fra det dere svarte.' : 'The suggestion was adjusted based on your answers.';
  }
}

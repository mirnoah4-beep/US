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

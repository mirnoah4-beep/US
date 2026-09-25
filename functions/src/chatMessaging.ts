// Pure helpers for the partner-chat fan-out (onChatMessageCreated).
//
// Kept free of firebase-admin so every rule below is unit-testable. The
// trigger in index.ts owns the I/O; this file owns the decisions.

export type ChatMessageType = 'text' | 'idea';

export interface ChatMessageData {
  senderId?: unknown;
  type?: unknown;
  text?: unknown;
  idea?: { titleNo?: unknown; titleEn?: unknown } | unknown;
}

/// Maximum characters of message text carried into a push notification body.
export const PREVIEW_MAX_CHARS = 120;

/// Resolves who should be notified for a message, purely from the couple's
/// current membership. The sender must be a current member (a message written
/// by someone who has since been removed must not fan out), and the recipient
/// is whoever else is in the couple. Never derived from client-supplied data.
export function resolveChatRecipient(
  senderId: unknown,
  members: unknown,
): string | null {
  if (typeof senderId !== 'string' || senderId.length === 0) return null;
  if (!Array.isArray(members)) return null;
  const uids = members.filter((m): m is string => typeof m === 'string' && m.length > 0);
  if (!uids.includes(senderId)) return null;
  const recipient = uids.find((m) => m !== senderId);
  return recipient ?? null;
}

/// True when a stored message has a shape we are willing to fan out.
export function isFanoutableMessage(data: ChatMessageData | undefined): boolean {
  if (!data) return false;
  if (data.type === 'text') {
    return typeof data.text === 'string' && data.text.trim().length > 0;
  }
  if (data.type === 'idea') {
    const idea = data.idea as { titleNo?: unknown; titleEn?: unknown } | undefined;
    return !!idea && (typeof idea.titleNo === 'string' || typeof idea.titleEn === 'string');
  }
  return false;
}

/// Collapses whitespace and truncates for a notification body. Never returns
/// the full text of a long message to the lock screen.
export function messagePreview(text: string, max = PREVIEW_MAX_CHARS): string {
  const collapsed = text.replace(/\s+/g, ' ').trim();
  if (collapsed.length <= max) return collapsed;
  return `${collapsed.slice(0, max - 1).trimEnd()}…`;
}

/// The last-message preview stored on chat/meta, in the RECIPIENT-neutral
/// form (the client localises the idea case itself).
export function metaPreview(data: ChatMessageData): string {
  if (data.type === 'text' && typeof data.text === 'string') {
    return messagePreview(data.text, 80);
  }
  if (data.type === 'idea') {
    const idea = data.idea as { titleNo?: unknown; titleEn?: unknown } | undefined;
    const title = [idea?.titleNo, idea?.titleEn].find((t) => typeof t === 'string' && t.length > 0);
    return typeof title === 'string' ? title : '';
  }
  return '';
}

/// The data payload carried on the push. Deliberately minimal: the client
/// routes on `type` and opens the chat; the message itself comes from
/// Firestore, never from the push.
export function chatPushData(coupleId: string, messageId: string): Record<string, string> {
  return { type: 'chat_message', coupleId, messageId };
}

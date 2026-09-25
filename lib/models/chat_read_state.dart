import 'chat_message.dart';

/// Pure read-receipt logic for 1:1 chat, kept free of Firestore and widgets so
/// the race conditions can be unit-tested directly.
///
/// Model: each member has a single watermark, `chat/read_{uid}.lastReadAt`,
/// plus a server-owned `unread` counter. The two are RELATED but SEPARATE:
///   - the counter drives the tab badge and is incremented by a Cloud Function
///     (so it can lag behind the message itself);
///   - the watermark drives the partner's "Seen" and is written by the reader
///     the moment a server-confirmed incoming message is on screen.
/// Gating the watermark on the counter would lose exactly the case where the
/// message arrives while the chat is already open and the increment has not
/// landed yet — so the two are decided independently here.

/// Delivery state shown under the sender's NEWEST outgoing message only.
enum OutgoingStatus { sending, sent, seen }

/// Status of one outgoing message given the partner's read watermark.
///
/// A message counts as seen once the partner's watermark is at or after its
/// server timestamp. A locally pending message can never be seen, and can
/// never act as a boundary, because it has no server time yet.
OutgoingStatus outgoingStatusFor(ChatMessage m, DateTime? partnerLastReadAt) {
  final at = m.createdAt;
  if (m.isPending || at == null) return OutgoingStatus.sending;
  if (partnerLastReadAt != null && !partnerLastReadAt.isBefore(at)) {
    return OutgoingStatus.seen;
  }
  return OutgoingStatus.sent;
}

/// Index of the newest message sent by [myUid] in a newest-first list, or -1.
/// Only this message carries a status label.
int newestOutgoingIndex(List<ChatMessage> newestFirst, String myUid) =>
    newestFirst.indexWhere((m) => m.isMine(myUid));

/// The read boundary the current user should advance their watermark to:
/// the server timestamp of the newest server-confirmed INCOMING message that
/// is newer than [myLastReadAt]. Null when there is nothing new to mark.
///
/// Pending (local-only) messages are skipped: they have no server time, and
/// an incoming message is never pending on the recipient's device anyway.
DateTime? unreadBoundary({
  required List<ChatMessage> newestFirst,
  required String myUid,
  required DateTime? myLastReadAt,
}) {
  for (final m in newestFirst) {
    if (m.isMine(myUid)) continue;
    final at = m.createdAt;
    if (m.isPending || at == null) continue;
    // Newest-first: the first confirmed incoming message IS the boundary.
    if (myLastReadAt == null || at.isAfter(myLastReadAt)) return at;
    return null;
  }
  return null;
}

/// Whether to write `read_{uid}` right now.
///
/// Writes happen only while the chat is REALLY visible (tab active AND app in
/// the foreground). Two independent triggers can justify a write:
///   1. [boundary] is newer than the last boundary we already wrote for —
///      this is the read receipt, and it does not care about [unread];
///   2. the server-owned [unread] counter is non-zero and no write is in
///      flight — this clears the badge (e.g. the increment landed after we
///      had already advanced the watermark).
bool shouldMarkRead({
  required bool tabVisible,
  required bool foreground,
  required DateTime? boundary,
  required int unread,
  required DateTime? lastMarkedBoundary,
  required bool inFlight,
}) {
  if (!tabVisible || !foreground) return false;
  if (boundary != null &&
      (lastMarkedBoundary == null || boundary.isAfter(lastMarkedBoundary))) {
    return true;
  }
  if (unread > 0 && !inFlight) return true;
  return false;
}

/// Tolerant parse of the server-owned counter (absent, int, or double).
int parseUnreadField(Object? raw) {
  if (raw is num) return raw < 0 ? 0 : raw.toInt();
  return 0;
}

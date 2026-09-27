import 'chat_message.dart';

/// Pure presentation logic for the chat thread: message grouping, bubble
/// corner shapes, group timestamps, the header "read the chat …" label, and
/// the typing indicator's freshness/throttle rules. No Flutter, no Firestore,
/// so all of it is unit-testable.

// ── Grouping ────────────────────────────────────────────────────────────────

/// Consecutive messages closer than this are visually joined.
const Duration groupGap = Duration(seconds: 60);

enum GroupPosition { single, first, middle, last }

/// Two messages belong to one visual group only when ALL hold: same sender,
/// both plain text (structured cards always stand alone), same local
/// calendar day, and at most [groupGap] apart.
bool sameGroup(ChatMessage a, ChatMessage b) {
  if (a.senderId != b.senderId) return false;
  if (a.type != ChatMessageType.text || b.type != ChatMessageType.text) return false;
  if (isDifferentDay(a.sortTime, b.sortTime)) return false;
  return a.sortTime.difference(b.sortTime).abs() <= groupGap;
}

/// Position of message [i] within its group, for a NEWEST-FIRST list.
/// "first" is the oldest message of the group (top of the bubble stack),
/// "last" the newest (bottom, where the timestamp/receipt goes).
GroupPosition groupPositionAt(List<ChatMessage> newestFirst, int i) {
  final m = newestFirst[i];
  final older = i + 1 < newestFirst.length ? newestFirst[i + 1] : null;
  final newer = i - 1 >= 0 ? newestFirst[i - 1] : null;
  final joinsOlder = older != null && sameGroup(m, older);
  final joinsNewer = newer != null && sameGroup(m, newer);
  if (!joinsOlder && !joinsNewer) return GroupPosition.single;
  if (!joinsOlder) return GroupPosition.first;
  if (!joinsNewer) return GroupPosition.last;
  return GroupPosition.middle;
}

/// The group's single timestamp (or the read receipt) sits under its newest
/// message only.
bool showsGroupFooter(GroupPosition pos) =>
    pos == GroupPosition.single || pos == GroupPosition.last;

/// Vertical gap BELOW a message (i.e. between it and the newer one).
double gapBelow(GroupPosition pos) =>
    (pos == GroupPosition.first || pos == GroupPosition.middle) ? 4 : 10;

/// Corner radii for a bubble. Outer corners stay 20; the corners on the
/// sender's side that face a grouped neighbour flatten to 6, so a group reads
/// as one joined column while the far side keeps its full rounding.
({double topLeft, double topRight, double bottomLeft, double bottomRight})
    bubbleCorners({required bool mine, required GroupPosition pos}) {
  const outer = 20.0;
  const joined = 6.0;
  final joinsAbove = pos == GroupPosition.middle || pos == GroupPosition.last;
  final joinsBelow = pos == GroupPosition.first || pos == GroupPosition.middle;
  final top = joinsAbove ? joined : outer;
  final bottom = joinsBelow ? joined : outer;
  return mine
      ? (topLeft: outer, topRight: top, bottomLeft: outer, bottomRight: bottom)
      : (topLeft: top, topRight: outer, bottomLeft: bottom, bottomRight: outer);
}

/// `HH:mm`, local time, zero-padded.
String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// ── Header: "read the chat …" ───────────────────────────────────────────────

enum ReadRecencyKind { justNow, minutes, hours }

/// A neutral, non-presence description of the partner's read watermark.
/// Null when absent or older than a day — the header then shows nothing.
/// This is deliberately NOT "online": it only says when they last read.
({ReadRecencyKind kind, int value})? readRecency(DateTime? lastReadAt, DateTime now) {
  if (lastReadAt == null) return null;
  final d = now.difference(lastReadAt);
  if (d.isNegative) return (kind: ReadRecencyKind.justNow, value: 0);
  if (d < const Duration(minutes: 1)) return (kind: ReadRecencyKind.justNow, value: 0);
  if (d < const Duration(hours: 1)) return (kind: ReadRecencyKind.minutes, value: d.inMinutes);
  if (d < const Duration(hours: 24)) return (kind: ReadRecencyKind.hours, value: d.inHours);
  return null;
}

// ── Typing ──────────────────────────────────────────────────────────────────

/// A typing doc older than this is treated as "not typing" no matter what it
/// says — a crashed or offline phone must never leave a stuck indicator.
const Duration typingStaleAfter = Duration(seconds: 5);

/// Minimum spacing between refresh writes while the user keeps typing.
const Duration typingRefreshEvery = Duration(milliseconds: 2500);

/// Reader-side rule: render only for a live, recent `true`.
bool typingIsFresh({
  required bool isTyping,
  required DateTime? updatedAt,
  required DateTime now,
}) {
  if (!isTyping || updatedAt == null) return false;
  return now.difference(updatedAt) <= typingStaleAfter;
}

/// Writer-side throttle. Decides, per composer change, whether a Firestore
/// write is warranted: always on a true↔false transition, otherwise a
/// refresh at most every [typingRefreshEvery] while still typing. Never
/// writes on plain keystrokes in between.
class TypingThrottle {
  TypingThrottle({this.refreshEvery = typingRefreshEvery});

  final Duration refreshEvery;
  bool _lastSentState = false;
  DateTime? _lastWriteAt;

  bool get lastSentState => _lastSentState;

  /// Returns true when the caller should write `typing` now.
  bool shouldWrite(bool typing, DateTime now) {
    if (typing != _lastSentState) {
      _lastSentState = typing;
      _lastWriteAt = now;
      return true;
    }
    if (!typing) return false;
    final last = _lastWriteAt;
    if (last == null || now.difference(last) >= refreshEvery) {
      _lastWriteAt = now;
      return true;
    }
    return false;
  }

  /// Forget everything (couple change, dispose).
  void reset() {
    _lastSentState = false;
    _lastWriteAt = null;
  }
}

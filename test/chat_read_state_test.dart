// Read-receipt correctness, including the counter-vs-watermark race.
// Pure logic — no Firestore, no widgets.

import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/models/chat_message.dart';
import 'package:us_app/models/chat_read_state.dart';

const me = 'uidA';
const partner = 'uidB';

final t0 = DateTime(2026, 9, 26, 20, 0);
DateTime at(int min) => t0.add(Duration(minutes: min));

ChatMessage msg(String id, {required String from, DateTime? createdAt, int? clientTs}) =>
    ChatMessage(
      id: id,
      senderId: from,
      type: ChatMessageType.text,
      text: id,
      idea: null,
      createdAt: createdAt,
      clientTs: clientTs ?? createdAt?.millisecondsSinceEpoch ?? 0,
    );

void main() {
  group('unreadBoundary (recipient side)', () {
    test('1. incoming confirmed message + unread=0 + chat visible → still marks read', () {
      // The counter is irrelevant here: the boundary comes from the message.
      final messages = [msg('in1', from: partner, createdAt: at(5))];
      final boundary = unreadBoundary(newestFirst: messages, myUid: me, myLastReadAt: at(1));
      expect(boundary, at(5));
      expect(
        shouldMarkRead(
          tabVisible: true, foreground: true, boundary: boundary,
          unread: 0, lastMarkedBoundary: null, inFlight: false,
        ),
        isTrue,
        reason: 'unread=0 must not block the read receipt',
      );
    });

    test('2. incoming message + chat hidden → no read write', () {
      final messages = [msg('in1', from: partner, createdAt: at(5))];
      final boundary = unreadBoundary(newestFirst: messages, myUid: me, myLastReadAt: null);
      expect(boundary, isNotNull);
      expect(
        shouldMarkRead(
          tabVisible: false, foreground: true, boundary: boundary,
          unread: 3, lastMarkedBoundary: null, inFlight: false,
        ),
        isFalse,
      );
    });

    test('3. app backgrounded → no read write even on the chat tab', () {
      final messages = [msg('in1', from: partner, createdAt: at(5))];
      final boundary = unreadBoundary(newestFirst: messages, myUid: me, myLastReadAt: null);
      expect(
        shouldMarkRead(
          tabVisible: true, foreground: false, boundary: boundary,
          unread: 3, lastMarkedBoundary: null, inFlight: false,
        ),
        isFalse,
      );
    });

    test('6. pending/local incoming messages are never a boundary', () {
      final messages = [
        msg('pending', from: partner, createdAt: null, clientTs: at(9).millisecondsSinceEpoch),
        msg('in1', from: partner, createdAt: at(5)),
      ];
      // The pending one is skipped; the confirmed one is the boundary.
      expect(unreadBoundary(newestFirst: messages, myUid: me, myLastReadAt: at(1)), at(5));
      // And with only a pending message, there is nothing to mark.
      expect(unreadBoundary(newestFirst: [messages.first], myUid: me, myLastReadAt: null), isNull);
    });

    test('my own messages never move my watermark', () {
      final messages = [msg('mine', from: me, createdAt: at(9))];
      expect(unreadBoundary(newestFirst: messages, myUid: me, myLastReadAt: null), isNull);
    });

    test('already-read incoming message is not re-marked', () {
      final messages = [msg('in1', from: partner, createdAt: at(5))];
      expect(unreadBoundary(newestFirst: messages, myUid: me, myLastReadAt: at(5)), isNull);
      expect(unreadBoundary(newestFirst: messages, myUid: me, myLastReadAt: at(6)), isNull);
    });

    test('newest-first: the boundary is the NEWEST confirmed incoming message', () {
      final messages = [
        msg('mine', from: me, createdAt: at(8)),
        msg('in2', from: partner, createdAt: at(7)),
        msg('in1', from: partner, createdAt: at(3)),
      ];
      expect(unreadBoundary(newestFirst: messages, myUid: me, myLastReadAt: at(1)), at(7));
    });
  });

  group('shouldMarkRead dedup guards', () {
    test('the same boundary is written once, even across repeated emissions', () {
      final b = at(5);
      expect(
        shouldMarkRead(tabVisible: true, foreground: true, boundary: b, unread: 0,
            lastMarkedBoundary: b, inFlight: false),
        isFalse,
        reason: 'boundary already written for',
      );
      expect(
        shouldMarkRead(tabVisible: true, foreground: true, boundary: at(6), unread: 0,
            lastMarkedBoundary: b, inFlight: true),
        isTrue,
        reason: 'a NEWER boundary always wins, even mid-flight',
      );
    });

    test('9. counter still clears the badge on its own (unread>0, nothing newer)', () {
      // The Cloud Function increment landed AFTER the watermark was advanced.
      expect(
        shouldMarkRead(tabVisible: true, foreground: true, boundary: null, unread: 2,
            lastMarkedBoundary: at(5), inFlight: false),
        isTrue,
      );
      // …but not while a reset is already in flight.
      expect(
        shouldMarkRead(tabVisible: true, foreground: true, boundary: null, unread: 2,
            lastMarkedBoundary: at(5), inFlight: true),
        isFalse,
      );
    });

    test('nothing to do → no write', () {
      expect(
        shouldMarkRead(tabVisible: true, foreground: true, boundary: null, unread: 0,
            lastMarkedBoundary: null, inFlight: false),
        isFalse,
      );
    });
  });

  group('outgoingStatusFor (sender side)', () {
    test('4. partner watermark BEFORE my message → Sent', () {
      final m = msg('out', from: me, createdAt: at(10));
      expect(outgoingStatusFor(m, at(9)), OutgoingStatus.sent);
    });

    test('5. partner watermark equal/after my message → Seen', () {
      final m = msg('out', from: me, createdAt: at(10));
      expect(outgoingStatusFor(m, at(10)), OutgoingStatus.seen);
      expect(outgoingStatusFor(m, at(11)), OutgoingStatus.seen);
    });

    test('6. pending outgoing message → Sending, regardless of watermark', () {
      final m = msg('out', from: me, createdAt: null, clientTs: at(10).millisecondsSinceEpoch);
      expect(outgoingStatusFor(m, at(99)), OutgoingStatus.sending);
    });

    test('7. server-confirmed outgoing, partner never read → Sent', () {
      final m = msg('out', from: me, createdAt: at(10));
      expect(outgoingStatusFor(m, null), OutgoingStatus.sent);
    });

    test('8. only the newest outgoing message gets a status label', () {
      final messages = [
        msg('in2', from: partner, createdAt: at(12)),
        msg('out2', from: me, createdAt: at(11)),
        msg('out1', from: me, createdAt: at(10)),
      ];
      final idx = newestOutgoingIndex(messages, me);
      expect(idx, 1);
      expect(messages[idx].id, 'out2');
      // No outgoing message at all → -1.
      expect(newestOutgoingIndex([messages.first], me), -1);
    });
  });

  group('9. unread badge parsing', () {
    test('tolerates absent, int, double and negative values', () {
      expect(parseUnreadField(null), 0);
      expect(parseUnreadField(3), 3);
      expect(parseUnreadField(2.0), 2);
      expect(parseUnreadField(-1), 0);
      expect(parseUnreadField('5'), 0);
    });
  });

  test('end-to-end race: message lands while chat open, counter lags, then catches up', () {
    // t=5: partner message arrives; my watermark is t=1; unread is still 0.
    final messages = [msg('in1', from: partner, createdAt: at(5))];
    var lastMarked = <DateTime?>[null][0];
    var inFlight = false;
    var writes = 0;

    void tick({required int unread}) {
      final b = unreadBoundary(newestFirst: messages, myUid: me, myLastReadAt: at(1));
      if (shouldMarkRead(tabVisible: true, foreground: true, boundary: b, unread: unread,
          lastMarkedBoundary: lastMarked, inFlight: inFlight)) {
        if (b != null) lastMarked = b;
        inFlight = true;
        writes++;
      }
    }

    tick(unread: 0);   // read receipt fires immediately — this is the fix
    tick(unread: 0);   // duplicate emission → deduped
    expect(writes, 1);

    inFlight = false;  // write acked
    tick(unread: 0);   // still deduped by lastMarkedBoundary
    expect(writes, 1);

    tick(unread: 1);   // late Cloud Function increment → badge reset write
    expect(writes, 2);
  });
}

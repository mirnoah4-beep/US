// Grouping, corners, timestamps, header recency and typing rules — pure.

import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/models/chat_grouping.dart';
import 'package:us_app/models/chat_message.dart';

const me = 'uidA';
const partner = 'uidB';
final t0 = DateTime(2026, 9, 26, 20, 0);
DateTime at(int sec) => t0.add(Duration(seconds: sec));

ChatMessage txt(String id, {required String from, required DateTime at, bool pending = false}) =>
    ChatMessage(
      id: id, senderId: from, type: ChatMessageType.text, text: id, idea: null,
      createdAt: pending ? null : at, clientTs: at.millisecondsSinceEpoch,
    );

ChatMessage ideaMsg(String id, {required String from, required DateTime at}) => ChatMessage(
      id: id, senderId: from, type: ChatMessageType.idea, text: '',
      idea: const ChatIdea(
        titleNo: 'x', titleEn: 'x', categoryNo: '', categoryEn: '',
        metaNo: '', metaEn: '', descriptionNo: '', descriptionEn: '',
      ),
      createdAt: at, clientTs: at.millisecondsSinceEpoch,
    );

void main() {
  group('sameGroup', () {
    test('2. same sender within 60 s groups', () {
      expect(sameGroup(txt('a', from: me, at: at(0)), txt('b', from: me, at: at(60))), isTrue);
    });
    test('3. > 60 s starts a new group', () {
      expect(sameGroup(txt('a', from: me, at: at(0)), txt('b', from: me, at: at(61))), isFalse);
    });
    test('4. different sender breaks the group', () {
      expect(sameGroup(txt('a', from: me, at: at(0)), txt('b', from: partner, at: at(5))), isFalse);
    });
    test('5. different local day breaks the group even if close in time', () {
      final lateNight = DateTime(2026, 9, 26, 23, 59, 40);
      final justAfterMidnight = DateTime(2026, 9, 27, 0, 0, 10);
      expect(sameGroup(txt('a', from: me, at: lateNight), txt('b', from: me, at: justAfterMidnight)), isFalse);
    });
    test('6b. an image message never groups with text or other images', () {
      ChatMessage img(String id, DateTime at) => ChatMessage(
            id: id, senderId: me, type: ChatMessageType.image, text: '', idea: null,
            createdAt: at, clientTs: at.millisecondsSinceEpoch,
            storagePath: 'couples/c/chatImages/$id.jpg',
          );
      expect(sameGroup(txt('a', from: me, at: at(0)), img('i', at(5))), isFalse);
      expect(sameGroup(img('i', at(0)), img('j', at(5))), isFalse);
    });
    test('6. a structured idea message never groups with text', () {
      expect(sameGroup(txt('a', from: me, at: at(0)), ideaMsg('i', from: me, at: at(5))), isFalse);
      expect(sameGroup(ideaMsg('i', from: me, at: at(0)), ideaMsg('j', from: me, at: at(5))), isFalse);
    });
  });

  group('groupPositionAt (newest-first)', () {
    // Oldest→newest: a(0) b(20) c(40) all mine, then partner d(50), then mine e(200)
    final list = [
      txt('e', from: me, at: at(200)),
      txt('d', from: partner, at: at(50)),
      txt('c', from: me, at: at(40)),
      txt('b', from: me, at: at(20)),
      txt('a', from: me, at: at(0)),
    ];

    test('7. first / middle / last / single positions', () {
      expect(groupPositionAt(list, 4), GroupPosition.first);   // a — oldest of a,b,c
      expect(groupPositionAt(list, 3), GroupPosition.middle);  // b
      expect(groupPositionAt(list, 2), GroupPosition.last);    // c — newest of the group
      expect(groupPositionAt(list, 1), GroupPosition.single);  // d — partner, alone
      expect(groupPositionAt(list, 0), GroupPosition.single);  // e — 150 s later
    });

    test('8. exactly one footer (timestamp/receipt) per group', () {
      final footers = List.generate(list.length, (i) => showsGroupFooter(groupPositionAt(list, i)));
      // a,b,c → only c; d → yes; e → yes  ⇒ 3 groups, 3 footers.
      expect(footers, [true, true, true, false, false]);
    });

    test('spacing is tight inside a group and wider between groups', () {
      expect(gapBelow(GroupPosition.first), 4);
      expect(gapBelow(GroupPosition.middle), 4);
      expect(gapBelow(GroupPosition.last), 10);
      expect(gapBelow(GroupPosition.single), 10);
    });
  });

  group('bubbleCorners', () {
    test('sent bubbles flatten right-side connecting corners only', () {
      final first = bubbleCorners(mine: true, pos: GroupPosition.first);
      expect((first.topLeft, first.topRight, first.bottomLeft, first.bottomRight), (20, 20, 20, 6));
      final middle = bubbleCorners(mine: true, pos: GroupPosition.middle);
      expect((middle.topLeft, middle.topRight, middle.bottomLeft, middle.bottomRight), (20, 6, 20, 6));
      final last = bubbleCorners(mine: true, pos: GroupPosition.last);
      expect((last.topLeft, last.topRight, last.bottomLeft, last.bottomRight), (20, 6, 20, 20));
    });
    test('received bubbles flatten left-side connecting corners only', () {
      final middle = bubbleCorners(mine: false, pos: GroupPosition.middle);
      expect((middle.topLeft, middle.topRight, middle.bottomLeft, middle.bottomRight), (6, 20, 6, 20));
    });
    test('single bubbles keep all four outer corners', () {
      for (final mine in [true, false]) {
        final c = bubbleCorners(mine: mine, pos: GroupPosition.single);
        expect([c.topLeft, c.topRight, c.bottomLeft, c.bottomRight], everyElement(20));
      }
    });
  });

  test('hhmm zero-pads', () {
    expect(hhmm(DateTime(2026, 1, 1, 9, 5)), '09:05');
    expect(hhmm(DateTime(2026, 1, 1, 20, 41)), '20:41');
  });

  group('readRecency (header subtitle — not presence)', () {
    final now = DateTime(2026, 9, 26, 21, 0);
    test('buckets', () {
      expect(readRecency(now.subtract(const Duration(seconds: 20)), now)!.kind, ReadRecencyKind.justNow);
      final m = readRecency(now.subtract(const Duration(minutes: 5)), now)!;
      expect((m.kind, m.value), (ReadRecencyKind.minutes, 5));
      final h = readRecency(now.subtract(const Duration(hours: 3, minutes: 10)), now)!;
      expect((h.kind, h.value), (ReadRecencyKind.hours, 3));
    });
    test('absent or older than a day → omitted', () {
      expect(readRecency(null, now), isNull);
      expect(readRecency(now.subtract(const Duration(hours: 25)), now), isNull);
    });
    test('clock skew (future watermark) reads as just now, never crashes', () {
      expect(readRecency(now.add(const Duration(seconds: 2)), now)!.kind, ReadRecencyKind.justNow);
    });
  });

  group('typing', () {
    final now = DateTime(2026, 9, 26, 21, 0);

    test('17. stale typing state is treated as not typing', () {
      expect(typingIsFresh(isTyping: true, updatedAt: now.subtract(const Duration(seconds: 2)), now: now), isTrue);
      expect(typingIsFresh(isTyping: true, updatedAt: now.subtract(const Duration(seconds: 6)), now: now), isFalse);
      expect(typingIsFresh(isTyping: true, updatedAt: null, now: now), isFalse);
      expect(typingIsFresh(isTyping: false, updatedAt: now, now: now), isFalse);
    });

    test('14/15. throttle: one write on start, no per-keystroke writes, refresh every ~2.5 s', () {
      final th = TypingThrottle();
      var writes = 0;
      void key(int ms) {
        if (th.shouldWrite(true, now.add(Duration(milliseconds: ms)))) writes++;
      }
      key(0);      // start → write
      key(100); key(300); key(700); key(1200); key(2000);   // keystrokes → none
      expect(writes, 1);
      key(2600);   // ≥ 2.5 s since last write → refresh
      expect(writes, 2);
      key(2700); key(4000);
      expect(writes, 2);
      key(5200);   // next refresh
      expect(writes, 3);
      // ~30 s of continuous typing costs about a dozen writes, not hundreds.
      for (var ms = 5300; ms <= 30000; ms += 150) {
        key(ms);
      }
      expect(writes, lessThanOrEqualTo(13));
    });

    test('18. clearing/leaving writes false once, and only if true was sent', () {
      final th = TypingThrottle();
      expect(th.shouldWrite(false, now), isFalse, reason: 'never typed → nothing to clear');
      expect(th.shouldWrite(true, now), isTrue);
      expect(th.shouldWrite(false, now.add(const Duration(milliseconds: 50))), isTrue);
      expect(th.shouldWrite(false, now.add(const Duration(milliseconds: 60))), isFalse);
      expect(th.lastSentState, isFalse);
    });

    test('reset forgets state so a new couple starts clean', () {
      final th = TypingThrottle()..shouldWrite(true, now);
      th.reset();
      expect(th.lastSentState, isFalse);
      expect(th.shouldWrite(true, now.add(const Duration(seconds: 1))), isTrue);
    });
  });
}

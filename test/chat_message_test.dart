// Pure unit tests for the chat model and paging merge — no Firestore needed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/models/chat_message.dart';

ChatMessage msg(String id, {DateTime? at, int? clientTs, String sender = 'a'}) => ChatMessage(
      id: id,
      senderId: sender,
      type: ChatMessageType.text,
      text: id,
      idea: null,
      createdAt: at,
      clientTs: clientTs ?? at?.millisecondsSinceEpoch ?? 0,
    );

void main() {
  group('ChatMessage.fromMap', () {
    test('parses a text message with a server timestamp', () {
      final at = DateTime(2026, 9, 25, 20, 0);
      final m = ChatMessage.fromMap('m1', {
        'senderId': 'a',
        'type': 'text',
        'text': 'hei',
        'createdAt': Timestamp.fromDate(at),
        'clientTs': at.millisecondsSinceEpoch,
      })!;
      expect(m.type, ChatMessageType.text);
      expect(m.text, 'hei');
      expect(m.createdAt, at);
      expect(m.isPending, isFalse);
      expect(m.isMine('a'), isTrue);
      expect(m.isMine('b'), isFalse);
    });

    test('a pending write (no server timestamp) sorts by the device clock', () {
      final m = ChatMessage.fromMap('m1', {
        'senderId': 'a',
        'type': 'text',
        'text': 'hei',
        'createdAt': null,
        'clientTs': 1_700_000_000_000,
      })!;
      expect(m.isPending, isTrue);
      expect(m.sortTime, DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000));
    });

    test('parses an idea message and round-trips the idea map', () {
      const idea = ChatIdea(
        titleNo: 'Filmkveld', titleEn: 'Movie night',
        categoryNo: 'Hjemme', categoryEn: 'Home',
        metaNo: '2t', metaEn: '2h',
        descriptionNo: 'Kos', descriptionEn: 'Cosy',
        coverImageUrl: 'https://x/y.jpg',
      );
      final m = ChatMessage.fromMap('m2', {
        'senderId': 'b',
        'type': 'idea',
        'idea': idea.toMap(),
        'createdAt': Timestamp.now(),
        'clientTs': 1,
      })!;
      expect(m.type, ChatMessageType.idea);
      expect(m.idea!.titleNo, 'Filmkveld');
      expect(m.idea!.coverImageUrl, 'https://x/y.jpg');
      expect(m.idea!.title(true), 'Filmkveld');
      expect(m.idea!.title(false), 'Movie night');
    });

    test('idea toMap never emits an empty coverImageUrl key (rules forbid junk)', () {
      const idea = ChatIdea(
        titleNo: 'a', titleEn: 'b', categoryNo: 'c', categoryEn: 'd',
        metaNo: 'e', metaEn: 'f', descriptionNo: 'g', descriptionEn: 'h',
      );
      expect(idea.toMap().containsKey('coverImageUrl'), isFalse);
      expect(idea.toMap().keys.toSet(), {
        'titleNo', 'titleEn', 'categoryNo', 'categoryEn',
        'metaNo', 'metaEn', 'descriptionNo', 'descriptionEn',
      });
    });

    test('rejects malformed documents instead of throwing', () {
      expect(ChatMessage.fromMap('x', null), isNull);
      expect(ChatMessage.fromMap('x', {'type': 'text', 'text': 'no sender'}), isNull);
      expect(ChatMessage.fromMap('x', {'senderId': 'a', 'type': 'sticker'}), isNull);
      expect(ChatMessage.fromMap('x', {'senderId': '', 'type': 'text'}), isNull);
    });

    test('language pick falls back to the other language when one is empty', () {
      const idea = ChatIdea(
        titleNo: '', titleEn: 'Only English', categoryNo: 'K', categoryEn: '',
        metaNo: '', metaEn: '', descriptionNo: '', descriptionEn: '',
      );
      expect(idea.title(true), 'Only English');
      expect(idea.category(false), 'K');
    });
  });

  group('mergeMessages', () {
    final t0 = DateTime(2026, 9, 25, 10);
    DateTime at(int min) => t0.add(Duration(minutes: min));

    test('dedupes by id and orders newest first', () {
      final live = [msg('c', at: at(3)), msg('b', at: at(2))];
      final older = [msg('b', at: at(2)), msg('a', at: at(1))];
      final out = mergeMessages(live, older);
      expect(out.map((m) => m.id).toList(), ['c', 'b', 'a']);
    });

    test('prefers the acknowledged copy over a pending one', () {
      final pending = msg('p', at: null, clientTs: at(5).millisecondsSinceEpoch);
      final acked = msg('p', at: at(5));
      expect(mergeMessages([acked], [pending]).single.isPending, isFalse);
      expect(mergeMessages([pending], [acked]).single.isPending, isFalse);
    });

    test('a pending message slots in by device time, not at the end', () {
      final live = [
        msg('new', at: null, clientTs: at(10).millisecondsSinceEpoch),
        msg('older', at: at(9)),
        msg('oldest', at: at(1)),
      ];
      expect(mergeMessages(live, const []).map((m) => m.id).toList(), ['new', 'older', 'oldest']);
    });

    test('equal timestamps get a deterministic order', () {
      final a = msg('a', at: at(1));
      final b = msg('b', at: at(1));
      final first = mergeMessages([a, b], const []).map((m) => m.id).toList();
      final second = mergeMessages([b, a], const []).map((m) => m.id).toList();
      expect(first, second);
    });
  });

  test('isDifferentDay compares local calendar days', () {
    expect(isDifferentDay(DateTime(2026, 9, 25, 23, 59), DateTime(2026, 9, 26, 0, 1)), isTrue);
    expect(isDifferentDay(DateTime(2026, 9, 25, 1), DateTime(2026, 9, 25, 23)), isFalse);
  });
}

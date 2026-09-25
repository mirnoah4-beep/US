import 'package:cloud_firestore/cloud_firestore.dart';

/// Message kinds the launch MVP supports. The server and the security rules
/// reject anything else, so this enum is the whole vocabulary.
enum ChatMessageType { text, idea }

/// A weekly/library idea shared into the chat. Carries enough to render a
/// compact card and a detail sheet without a second lookup.
class ChatIdea {
  final String titleNo;
  final String titleEn;
  final String categoryNo;
  final String categoryEn;
  final String metaNo;
  final String metaEn;
  final String descriptionNo;
  final String descriptionEn;
  final String? coverImageUrl;

  const ChatIdea({
    required this.titleNo,
    required this.titleEn,
    required this.categoryNo,
    required this.categoryEn,
    required this.metaNo,
    required this.metaEn,
    required this.descriptionNo,
    required this.descriptionEn,
    this.coverImageUrl,
  });

  String title(bool no) => _pick(no, titleNo, titleEn);
  String category(bool no) => _pick(no, categoryNo, categoryEn);
  String meta(bool no) => _pick(no, metaNo, metaEn);
  String description(bool no) => _pick(no, descriptionNo, descriptionEn);

  static String _pick(bool no, String a, String b) =>
      no ? (a.isNotEmpty ? a : b) : (b.isNotEmpty ? b : a);

  /// Exactly the key set the security rules allow — nothing else may be sent.
  Map<String, dynamic> toMap() => {
        'titleNo': titleNo,
        'titleEn': titleEn,
        'categoryNo': categoryNo,
        'categoryEn': categoryEn,
        'metaNo': metaNo,
        'metaEn': metaEn,
        'descriptionNo': descriptionNo,
        'descriptionEn': descriptionEn,
        if (coverImageUrl != null && coverImageUrl!.isNotEmpty)
          'coverImageUrl': coverImageUrl,
      };

  static ChatIdea? fromMap(Object? raw) {
    if (raw is! Map) return null;
    String s(String k) => (raw[k] as String?) ?? '';
    final cover = raw['coverImageUrl'];
    return ChatIdea(
      titleNo: s('titleNo'),
      titleEn: s('titleEn'),
      categoryNo: s('categoryNo'),
      categoryEn: s('categoryEn'),
      metaNo: s('metaNo'),
      metaEn: s('metaEn'),
      descriptionNo: s('descriptionNo'),
      descriptionEn: s('descriptionEn'),
      coverImageUrl: cover is String && cover.isNotEmpty ? cover : null,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final ChatMessageType type;
  final String text;
  final ChatIdea? idea;

  /// Server timestamp. Null while the write is still pending locally
  /// (offline / not yet acknowledged) — use [sortTime] for ordering.
  final DateTime? createdAt;

  /// Device clock at send time. Makes a pending message sort correctly next
  /// to acknowledged ones instead of jumping once the server stamps it.
  final int clientTs;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.text,
    required this.idea,
    required this.createdAt,
    required this.clientTs,
  });

  bool get isPending => createdAt == null;
  bool isMine(String uid) => senderId == uid;

  /// Stable ordering key: the server time once known, else the device time.
  DateTime get sortTime =>
      createdAt ?? DateTime.fromMillisecondsSinceEpoch(clientTs);

  /// Pure parser so it can be unit-tested without a Firestore instance.
  static ChatMessage? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final senderId = data['senderId'];
    if (senderId is! String || senderId.isEmpty) return null;

    final rawType = data['type'];
    final type = rawType == 'idea'
        ? ChatMessageType.idea
        : rawType == 'text'
            ? ChatMessageType.text
            : null;
    if (type == null) return null;

    final ts = data['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : null;
    final rawClientTs = data['clientTs'];
    final clientTs = rawClientTs is num
        ? rawClientTs.toInt()
        : (createdAt?.millisecondsSinceEpoch ?? 0);

    return ChatMessage(
      id: id,
      senderId: senderId,
      type: type,
      text: (data['text'] as String?) ?? '',
      idea: type == ChatMessageType.idea ? ChatIdea.fromMap(data['idea']) : null,
      createdAt: createdAt,
      clientTs: clientTs,
    );
  }

  static ChatMessage? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data());
}

/// Merges the live newest page with any older pages the user has scrolled
/// into. Dedupes by id (a message can appear in both once the live window
/// shifts), preferring the acknowledged copy, and returns newest-first.
List<ChatMessage> mergeMessages(
  Iterable<ChatMessage> live,
  Iterable<ChatMessage> older,
) {
  final byId = <String, ChatMessage>{};
  for (final m in older) {
    byId[m.id] = m;
  }
  for (final m in live) {
    final existing = byId[m.id];
    // Keep whichever copy has the server timestamp.
    if (existing == null || existing.isPending || !m.isPending) byId[m.id] = m;
  }
  final out = byId.values.toList()
    ..sort((a, b) {
      final c = b.sortTime.compareTo(a.sortTime);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
  return out;
}

/// True when [a] and [b] fall on different local calendar days — used to
/// decide where a date separator goes.
bool isDifferentDay(DateTime a, DateTime b) =>
    a.year != b.year || a.month != b.month || a.day != b.day;

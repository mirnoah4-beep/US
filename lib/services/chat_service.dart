import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';

/// Firestore access for partner chat.
///
/// Messages are written directly by the client so they queue offline; the
/// `onChatMessageCreated` Cloud Function handles unread counts, the
/// last-message preview and the push. Every shape here mirrors what
/// firestore.rules accepts — an extra key is a rejected write.
class ChatService {
  ChatService._();

  static final _db = FirebaseFirestore.instance;

  /// Hard cap enforced by the rules as well; the UI blocks earlier.
  static const int maxTextLength = 2000;

  /// One page of history. Small enough to stay cheap, large enough that a
  /// normal evening's conversation fits on the first load.
  static const int pageSize = 30;

  static CollectionReference<Map<String, dynamic>> messagesRef(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('messages');

  static DocumentReference<Map<String, dynamic>> readRef(String coupleId, String uid) =>
      _db.collection('couples').doc(coupleId).collection('chat').doc('read_$uid');

  /// The live window: newest [pageSize] messages. This is the ONLY listener on
  /// the messages collection; older pages are fetched once and cached.
  static Query<Map<String, dynamic>> newestQuery(String coupleId) =>
      messagesRef(coupleId).orderBy('createdAt', descending: true).limit(pageSize);

  static Future<QuerySnapshot<Map<String, dynamic>>> fetchOlder(
    String coupleId,
    DocumentSnapshot<Map<String, dynamic>> after,
  ) =>
      messagesRef(coupleId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(after)
          .limit(pageSize)
          .get();

  static Future<void> sendText(String coupleId, String uid, String text) =>
      messagesRef(coupleId).doc().set({
        'senderId': uid,
        'type': 'text',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'clientTs': DateTime.now().millisecondsSinceEpoch,
      });

  static Future<void> sendIdea(String coupleId, String uid, ChatIdea idea) =>
      messagesRef(coupleId).doc().set({
        'senderId': uid,
        'type': 'idea',
        'idea': idea.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'clientTs': DateTime.now().millisecondsSinceEpoch,
      });

  /// Resets the caller's own unread counter. The rules only ever allow
  /// `unread: 0` from a client — the count itself is server-owned.
  static Future<void> markRead(String coupleId, String uid) =>
      readRef(coupleId, uid).set({
        'lastReadAt': FieldValue.serverTimestamp(),
        'unread': 0,
      });
}

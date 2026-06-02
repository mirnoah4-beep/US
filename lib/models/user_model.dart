import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String? coupleId;
  final String language;
  final String? fcmToken;
  final DateTime? createdAt;
  final bool needsEmailVerification;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.coupleId,
    this.language = 'no',
    this.fcmToken,
    this.createdAt,
    this.needsEmailVerification = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      avatarUrl: d['avatarUrl'] as String?,
      coupleId: d['coupleId'] as String?,
      language: d['language'] as String? ?? 'no',
      fcmToken: d['fcmToken'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      needsEmailVerification: d['needsEmailVerification'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'avatarUrl': avatarUrl,
    'coupleId': coupleId,
    'language': language,
    'fcmToken': fcmToken,
    'createdAt': FieldValue.serverTimestamp(),
  };

  UserModel copyWith({
    String? displayName,
    String? email,
    String? avatarUrl,
    String? coupleId,
    String? language,
    String? fcmToken,
  }) =>
      UserModel(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        coupleId: coupleId ?? this.coupleId,
        language: language ?? this.language,
        fcmToken: fcmToken ?? this.fcmToken,
        createdAt: createdAt,
      );
}

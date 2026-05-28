import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String code;
  final String fromUserId;
  final String coupleId;
  final DateTime? createdAt;

  const InviteModel({
    required this.code,
    required this.fromUserId,
    required this.coupleId,
    this.createdAt,
  });

  factory InviteModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return InviteModel(
      code: doc.id,
      fromUserId: d['fromUserId'] as String? ?? '',
      coupleId: d['coupleId'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

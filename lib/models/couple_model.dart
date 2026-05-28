import 'package:cloud_firestore/cloud_firestore.dart';

class CoupleModel {
  final String id;
  final List<String> members;
  final String status; // "pending" | "active"
  final String? inviteCode;
  final DateTime? createdAt;

  const CoupleModel({
    required this.id,
    required this.members,
    required this.status,
    this.inviteCode,
    this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';

  String partnerIdFor(String userId) =>
      members.firstWhere((id) => id != userId, orElse: () => '');

  factory CoupleModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawMembers = d['members'] as List<dynamic>? ?? [];
    return CoupleModel(
      id: doc.id,
      members: rawMembers.map((e) => e.toString()).toList(),
      status: d['status'] as String? ?? 'pending',
      inviteCode: d['inviteCode'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

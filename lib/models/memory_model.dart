import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryModel {
  final String id;
  final String activity;
  final String note;
  final String? imageUrl;
  final DateTime createdAt;
  final String createdBy;

  const MemoryModel({
    required this.id,
    required this.activity,
    required this.note,
    this.imageUrl,
    required this.createdAt,
    required this.createdBy,
  });

  factory MemoryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MemoryModel(
      id: doc.id,
      activity: d['activity'] as String? ?? '',
      note: d['note'] as String? ?? '',
      imageUrl: d['imageUrl'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] as String? ?? '',
    );
  }
}

class MemoryPrompt {
  final String planId;
  final String activity;
  const MemoryPrompt({required this.planId, required this.activity});
}

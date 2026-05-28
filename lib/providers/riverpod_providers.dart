import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/couple_model.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userProvider = StreamProvider<UserModel?>((ref) {
  final auth = ref.watch(authStateProvider);
  final uid = auth.valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
});

final coupleProvider = StreamProvider<CoupleModel?>((ref) {
  final user = ref.watch(userProvider).valueOrNull;
  final coupleId = user?.coupleId;
  if (coupleId == null || coupleId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('couples')
      .doc(coupleId)
      .snapshots()
      .map((doc) => doc.exists ? CoupleModel.fromFirestore(doc) : null);
});

final settingsProvider = StreamProvider<SettingsModel?>((ref) {
  final couple = ref.watch(coupleProvider).valueOrNull;
  if (couple == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('couples')
      .doc(couple.id)
      .collection('settings')
      .doc('main')
      .snapshots()
      .map((doc) => doc.exists ? SettingsModel.fromFirestore(doc) : null);
});

final lastTimeStreamProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>?>((ref) {
  final couple = ref.watch(coupleProvider).valueOrNull;
  if (couple == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('couples')
      .doc(couple.id)
      .collection('lastTime')
      .snapshots();
});

final weeklyPlanStreamProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>?>((ref) {
  final couple = ref.watch(coupleProvider).valueOrNull;
  if (couple == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('couples')
      .doc(couple.id)
      .collection('weeklyPlan')
      .orderBy('date')
      .snapshots();
});

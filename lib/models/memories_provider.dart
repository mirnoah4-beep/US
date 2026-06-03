import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_model.dart';
import '../services/firestore_service.dart';

class MemoriesProvider extends ChangeNotifier {
  List<MemoryModel> _memories = [];
  MemoryPrompt? _pendingPrompt;
  bool _initialized = false;
  bool _subscribed = false;
  String _coupleId = '';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _memoriesSub;

  List<MemoryModel> get memories => _memories;
  MemoryPrompt? get pendingPrompt => _pendingPrompt;
  bool get initialized => _initialized;
  int get streakCount => _memories.length;

  void init(String coupleId) {
    if (_subscribed && coupleId == _coupleId) return;
    _coupleId = coupleId;
    _subscribed = true;

    _memoriesSub?.cancel();
    _memoriesSub = FirestoreService.memoriesStream(coupleId).listen((snap) {
      _memories = snap.docs
          .map((d) => MemoryModel.fromFirestore(d))
          .toList();
      _initialized = true;
      notifyListeners();
    });

    _checkPendingPrompt(coupleId);
  }

  Future<void> _checkPendingPrompt(String coupleId) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList('memory_prompted_plans') ?? [];

    final now = DateTime.now();
    final cutoff = Timestamp.fromDate(
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    try {
      final snap = await FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('weeklyPlan')
          .where('status', isEqualTo: 'confirmed')
          .where('date', isLessThanOrEqualTo: cutoff)
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      for (final doc in snap.docs) {
        if (dismissed.contains(doc.id)) continue;
        final activity = doc.data()['activity'] as String? ?? '';
        if (activity.isEmpty) continue;
        _pendingPrompt = MemoryPrompt(planId: doc.id, activity: activity);
        notifyListeners();
        return;
      }
    } catch (_) {}
  }

  Future<void> dismissPrompt(String planId) async {
    _pendingPrompt = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList('memory_prompted_plans') ?? [];
    if (!dismissed.contains(planId)) {
      dismissed.add(planId);
      await prefs.setStringList('memory_prompted_plans', dismissed);
    }
  }

  @override
  void dispose() {
    _memoriesSub?.cancel();
    super.dispose();
  }
}

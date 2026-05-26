import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'weekly_idea.dart';

class WeeklyIdeasProvider extends ChangeNotifier {
  WeeklyIdeasDoc? _doc;
  bool _loading = false;
  bool _generationPending = false;
  String? _coupleId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  WeeklyIdeasDoc? get doc => _doc;
  bool get loading => _loading;
  List<WeeklyIdea> get ideas => _doc?.ideas ?? [];
  bool get isAiGenerated => _doc?.isAiGenerated ?? false;

  // Call once from the HomeScreen widget tree.
  Future<void> init(String coupleId) async {
    if (_coupleId == coupleId && _sub != null) return;
    _coupleId = coupleId;
    _sub?.cancel();

    try {
      _sub = FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('weeklyIdeas')
          .doc('current')
          .snapshots()
          .listen(
            _onSnapshot,
            onError: (Object e) {
              debugPrint('WeeklyIdeasProvider stream error: $e');
              _loading = false;
              notifyListeners();
            },
          );
    } catch (e) {
      // Firebase not yet initialized — feature unavailable until config added
      debugPrint('WeeklyIdeasProvider: Firebase unavailable: $e');
    }
  }

  void _onSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists || snap.data() == null) {
      _triggerGenerationIfNeeded();
      return;
    }

    final newDoc = WeeklyIdeasDoc.fromFirestore(snap.data()!);
    _doc = newDoc;
    if (!newDoc.isStale) _loading = false;
    notifyListeners();

    if (newDoc.isStale) _triggerGenerationIfNeeded();
  }

  void _triggerGenerationIfNeeded() {
    if (_generationPending || _coupleId == null) return;
    _generationPending = true;
    _generateIdeas(_coupleId!);
  }

  Future<void> _generateIdeas(String coupleId) async {
    _loading = true;
    notifyListeners();
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('generateWeeklyIdeasNow');
      await callable.call({'coupleId': coupleId});
      // Firestore stream picks up the new doc automatically
    } catch (e) {
      debugPrint('WeeklyIdeasProvider generation failed: $e');
      _loading = false;
      notifyListeners();
    } finally {
      _generationPending = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

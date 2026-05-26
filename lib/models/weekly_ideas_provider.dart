import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'weekly_idea.dart';

// Shown immediately while Firebase loads or when unavailable.
final _kStaticFallback = WeeklyIdeasDoc(
  generatedAt: DateTime.now(),
  weekNumber: 0,
  generatedBy: 'curated',
  ideas: const [
    WeeklyIdea(
      title: 'Kort + te',
      category: 'Minidate',
      meta: '20 min · bare dere to',
      cardColor: Color(0xFFFAECE7),
      tagColor: Color(0xFFF5C4B3),
      tagTextColor: Color(0xFF712B13),
      icon: Icons.coffee_outlined,
      description: 'Sett dere ned uten telefoner og trekk et kort hver.',
    ),
    WeeklyIdea(
      title: 'Kveldstur',
      category: 'Ute',
      meta: '30 min · uten telefoner',
      cardColor: Color(0xFFEAF3DE),
      tagColor: Color(0xFFC0DD97),
      tagTextColor: Color(0xFF27500A),
      icon: Icons.directions_walk_outlined,
      description: 'En rolig tur rundt kvartalet. Bare prat og frisk luft.',
    ),
    WeeklyIdea(
      title: 'Lag mat',
      category: 'Hjemme',
      meta: '1 time · ny oppskrift',
      cardColor: Color(0xFFFAEEDA),
      tagColor: Color(0xFFFAC775),
      tagTextColor: Color(0xFF633806),
      icon: Icons.kitchen_outlined,
      description: 'Velg en oppskrift ingen har prøvd. Jobb sammen og ha det gøy.',
    ),
    WeeklyIdea(
      title: 'Del en sang',
      category: 'Koble til',
      meta: '30 min · musikk + prat',
      cardColor: Color(0xFFE1F5EE),
      tagColor: Color(0xFF9FE1CB),
      tagTextColor: Color(0xFF085041),
      icon: Icons.music_note_outlined,
      description: 'Del en sang som betyr noe nå. Fortell hvorfor.',
    ),
    WeeklyIdea(
      title: 'Tegn hverandre',
      category: 'Kreativt',
      meta: '20 min · papir + blyant',
      cardColor: Color(0xFFFBEAF0),
      tagColor: Color(0xFFF4C0D1),
      tagTextColor: Color(0xFF72243E),
      icon: Icons.palette_outlined,
      description: 'Sett en timer på 10 minutter og tegn den andre.',
    ),
  ],
);

class WeeklyIdeasProvider extends ChangeNotifier {
  WeeklyIdeasDoc? _doc = _kStaticFallback;
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

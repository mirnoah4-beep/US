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
      buttonColor: Color(0xFFC1544A),
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
      buttonColor: Color(0xFF3B6D11),
    ),
    WeeklyIdea(
      title: 'Lag mat',
      category: 'Hjemme',
      meta: '1 time · ny oppskrift',
      cardColor: Color(0xFFFAEEDA),
      tagColor: Color(0xFFFAC775),
      tagTextColor: Color(0xFF633806),
      icon: Icons.tv_outlined,
      description: 'Velg en oppskrift ingen har prøvd. Jobb sammen og ha det gøy.',
      buttonColor: Color(0xFF854F0B),
    ),
    WeeklyIdea(
      title: 'Del en sang',
      category: 'Koble til',
      meta: '30 min · musikk + prat',
      cardColor: Color(0xFFE1F5EE),
      tagColor: Color(0xFF9FE1CB),
      tagTextColor: Color(0xFF085041),
      icon: Icons.style_outlined,
      description: 'Del en sang som betyr noe nå. Fortell hvorfor.',
      buttonColor: Color(0xFF0F6E56),
    ),
    WeeklyIdea(
      title: 'Tegn hverandre',
      category: 'Kreativt',
      meta: '20 min · papir + blyant',
      cardColor: Color(0xFFFBEAF0),
      tagColor: Color(0xFFF4C0D1),
      tagTextColor: Color(0xFF72243E),
      icon: Icons.local_cafe_outlined,
      description: 'Sett en timer på 10 minutter og tegn den andre.',
      buttonColor: Color(0xFF993556),
    ),
  ],
);

enum IdeaSendState { idle, waiting, accepted, declined }

class IncomingIdeaRequest {
  final String requestId;
  final String senderName;
  final String ideaTitle;
  final String ideaMeta;
  final String ideaDescription;
  final String ideaCategory;
  final String? coverImageUrl;

  const IncomingIdeaRequest({
    required this.requestId,
    required this.senderName,
    required this.ideaTitle,
    required this.ideaMeta,
    required this.ideaDescription,
    required this.ideaCategory,
    this.coverImageUrl,
  });

  factory IncomingIdeaRequest.fromFirestore(String id, Map<String, dynamic> data) {
    return IncomingIdeaRequest(
      requestId: id,
      senderName: data['senderName'] as String? ?? 'Din partner',
      ideaTitle: data['ideaTitle'] as String? ?? '',
      ideaMeta: data['ideaMeta'] as String? ?? '',
      ideaDescription: data['ideaDescription'] as String? ?? '',
      ideaCategory: data['ideaCategory'] as String? ?? '',
      coverImageUrl: data['coverImageUrl'] as String?,
    );
  }
}

class WeeklyIdeasProvider extends ChangeNotifier {
  WeeklyIdeasDoc? _doc = _kStaticFallback;
  bool _loading = false;
  bool _generationPending = false;
  String? _coupleId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  IdeaSendState _sendState = IdeaSendState.idle;
  WeeklyIdea? _sentIdea;
  String? _pendingRequestId;
  String? _sendError;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _requestSub;
  IncomingIdeaRequest? _incomingRequest;
  int _pendingIncomingCount = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingSub;

  WeeklyIdeasDoc? get doc => _doc;
  bool get loading => _loading;
  List<WeeklyIdea> get ideas => _doc?.ideas ?? [];
  bool get isAiGenerated => _doc?.isAiGenerated ?? false;
  IdeaSendState get sendState => _sendState;
  WeeklyIdea? get sentIdea => _sentIdea;
  String? get sendError => _sendError;
  IncomingIdeaRequest? get incomingRequest => _incomingRequest;
  int get pendingIncomingCount => _pendingIncomingCount;

  void clearSendError() { _sendError = null; }

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

  Future<void> sendIdea(
    WeeklyIdea idea,
    String coupleId,
    String userId,
    String senderName, {
    String partnerId = '',
    String? coverImageUrl,
  }) async {
    // Guard: abort if no linked partner.
    if (partnerId.isEmpty) {
      _sendState = IdeaSendState.idle;
      _sentIdea = null;
      _pendingRequestId = null;
      _sendError = 'noPartner';
      notifyListeners();
      return;
    }

    _sentIdea = idea;
    _sendState = IdeaSendState.waiting;
    notifyListeners();
    try {
      final ref = FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('ideaRequests')
          .doc();
      _pendingRequestId = ref.id;
      await ref.set({
        'ideaTitle': idea.title,
        'ideaMeta': idea.meta,
        'ideaDescription': idea.description,
        'ideaCategory': idea.category,
        'senderName': senderName,
        'sentBy': userId,
        'recipientId': partnerId,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      _requestSub?.cancel();
      _requestSub = ref.snapshots().listen(_onRequestSnapshot, onError: (_) {});
    } catch (e) {
      _sendState = IdeaSendState.idle;
      _sentIdea = null;
      _pendingRequestId = null;
      _sendError = 'networkError';
      debugPrint('sendIdea failed: $e');
      notifyListeners();
    }
  }

  void _onRequestSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return;
    final data = snap.data()!;
    final status = data['status'] as String?;

    // Auto-expire pending requests older than 24 hours
    if (status == 'pending') {
      final sentAt = data['sentAt'] as Timestamp?;
      if (sentAt != null) {
        final age = DateTime.now().difference(sentAt.toDate());
        if (age.inHours >= 24) {
          snap.reference.update({'status': 'expired'}).catchError((_) {});
          _sendState = IdeaSendState.idle;
          _requestSub?.cancel();
          _requestSub = null;
          notifyListeners();
          return;
        }
      }
    }

    if (status == 'accepted') {
      _sendState = IdeaSendState.accepted;
      _requestSub?.cancel();
      _requestSub = null;
      notifyListeners();
    } else if (status == 'declined') {
      _sendState = IdeaSendState.declined;
      _requestSub?.cancel();
      _requestSub = null;
      notifyListeners();
    } else if (status == 'expired') {
      _sendState = IdeaSendState.idle;
      _requestSub?.cancel();
      _requestSub = null;
      notifyListeners();
    }
  }

  void resetSendState() {
    _sendState = IdeaSendState.idle;
    _sentIdea = null;
    _pendingRequestId = null;
    _sendError = null;
    _requestSub?.cancel();
    _requestSub = null;
    notifyListeners();
  }

  Future<void> cancelPendingIdea(String coupleId) async {
    final docId = _pendingRequestId;
    resetSendState();
    if (docId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('couples')
            .doc(coupleId)
            .collection('ideaRequests')
            .doc(docId)
            .delete();
      } catch (e) {
        debugPrint('cancelPendingIdea failed: $e');
      }
    }
  }

  Future<void> respondToRequest(String coupleId, String requestId, bool accepted) async {
    _incomingRequest = null;
    notifyListeners();
    try {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('ideaRequests')
          .doc(requestId)
          .update({'status': accepted ? 'accepted' : 'declined'});
    } catch (e) {
      debugPrint('respondToRequest failed: $e');
    }
  }

  String? _incomingUserId;

  Future<void> checkIncomingRequests(String coupleId, String userId) async {
    _incomingSub?.cancel();
    _incomingUserId = userId;
    debugPrint('=== checkIncomingRequests called coupleId=$coupleId userId=$userId');
    try {
      // Single-field query avoids composite index requirement.
      // Filter out own requests client-side in _onIncomingSnapshot.
      _incomingSub = FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('ideaRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(_onIncomingSnapshot, onError: (Object e) {
            debugPrint('=== INCOMING STREAM ERROR: $e');
          });
    } catch (e) {
      debugPrint('=== checkIncomingRequests THREW: $e');
    }
  }

  void _onIncomingSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    debugPrint('=== INCOMING SNAPSHOT fired: ${snap.docs.length} total pending docs');
    // Filter out requests sent by the current user (client-side to avoid composite index).
    final incoming = snap.docs
        .where((d) => (d.data()['sentBy'] as String?) != _incomingUserId)
        .toList();
    debugPrint('=== INCOMING after filter: ${incoming.length} docs for userId=$_incomingUserId');

    final prevCount = _pendingIncomingCount;
    _pendingIncomingCount = incoming.length;

    if (incoming.isEmpty) {
      final changed = _incomingRequest != null || prevCount != 0;
      _incomingRequest = null;
      if (changed) notifyListeners();
      return;
    }

    final doc = incoming.first;
    final newReq = IncomingIdeaRequest.fromFirestore(doc.id, doc.data());
    if (newReq.requestId != _incomingRequest?.requestId ||
        prevCount != _pendingIncomingCount) {
      _incomingRequest = newReq;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _requestSub?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }
}

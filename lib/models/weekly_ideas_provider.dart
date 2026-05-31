import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'weekly_idea.dart';
import '../services/idea_image_service.dart';

// Shown immediately while Firebase loads or when unavailable.
final _kStaticFallback = WeeklyIdeasDoc(
  generatedAt: DateTime.now(),
  weekNumber: 0,
  generatedBy: 'curated',
  ideas: const [
    WeeklyIdea(
      titleNo: 'Kort + te',
      titleEn: 'Cards + tea',
      categoryNo: 'Minidate',
      categoryEn: 'Mini-date',
      metaNo: '20 min · bare dere to',
      metaEn: '20 min · just you two',
      cardColor: Color(0xFFFAECE7),
      tagColor: Color(0xFFF5C4B3),
      tagTextColor: Color(0xFF712B13),
      icon: Icons.coffee_outlined,
      descriptionNo: 'Sett dere ned uten telefoner og trekk et kort hver.',
      descriptionEn: 'Sit down without phones and draw a card each.',
      buttonColor: Color(0xFFC1544A),
    ),
    WeeklyIdea(
      titleNo: 'Kveldstur',
      titleEn: 'Evening walk',
      categoryNo: 'Ute',
      categoryEn: 'Outside',
      metaNo: '30 min · uten telefoner',
      metaEn: '30 min · no phones',
      cardColor: Color(0xFFEAF3DE),
      tagColor: Color(0xFFC0DD97),
      tagTextColor: Color(0xFF27500A),
      icon: Icons.directions_walk_outlined,
      descriptionNo: 'En rolig tur rundt kvartalet. Bare prat og frisk luft.',
      descriptionEn: 'A quiet walk around the block. Just talk and fresh air.',
      buttonColor: Color(0xFF3B6D11),
    ),
    WeeklyIdea(
      titleNo: 'Lag mat',
      titleEn: 'Cook together',
      categoryNo: 'Hjemme',
      categoryEn: 'At home',
      metaNo: '1 time · ny oppskrift',
      metaEn: '1 hour · new recipe',
      cardColor: Color(0xFFFAEEDA),
      tagColor: Color(0xFFFAC775),
      tagTextColor: Color(0xFF633806),
      icon: Icons.tv_outlined,
      descriptionNo: 'Velg en oppskrift ingen har prøvd. Jobb sammen og ha det gøy.',
      descriptionEn: 'Choose a recipe no one has tried. Work together and have fun.',
      buttonColor: Color(0xFF854F0B),
    ),
    WeeklyIdea(
      titleNo: 'Del en sang',
      titleEn: 'Share a song',
      categoryNo: 'Koble til',
      categoryEn: 'Connect',
      metaNo: '30 min · musikk + prat',
      metaEn: '30 min · music + talk',
      cardColor: Color(0xFFE1F5EE),
      tagColor: Color(0xFF9FE1CB),
      tagTextColor: Color(0xFF085041),
      icon: Icons.style_outlined,
      descriptionNo: 'Del en sang som betyr noe nå. Fortell hvorfor.',
      descriptionEn: 'Share a song that means something right now. Say why.',
      buttonColor: Color(0xFF0F6E56),
    ),
    WeeklyIdea(
      titleNo: 'Tegn hverandre',
      titleEn: 'Draw each other',
      categoryNo: 'Kreativt',
      categoryEn: 'Creative',
      metaNo: '20 min · papir + blyant',
      metaEn: '20 min · pen + paper',
      cardColor: Color(0xFFFBEAF0),
      tagColor: Color(0xFFF4C0D1),
      tagTextColor: Color(0xFF72243E),
      icon: Icons.local_cafe_outlined,
      descriptionNo: 'Sett en timer på 10 minutter og tegn den andre.',
      descriptionEn: 'Set a timer for 10 minutes and draw each other.',
      buttonColor: Color(0xFF993556),
    ),
  ],
);

enum IdeaSendState { idle, waiting, accepted, declined }

class IncomingIdeaRequest {
  final String requestId;
  final String senderName;
  final String ideaTitleNo;
  final String ideaTitleEn;
  final String ideaMetaNo;
  final String ideaMetaEn;
  final String ideaDescriptionNo;
  final String ideaDescriptionEn;
  final String ideaCategoryNo;
  final String ideaCategoryEn;
  final String? coverImageUrl;
  final DateTime? proposedAt;

  const IncomingIdeaRequest({
    required this.requestId,
    required this.senderName,
    required this.ideaTitleNo,
    required this.ideaTitleEn,
    required this.ideaMetaNo,
    required this.ideaMetaEn,
    required this.ideaDescriptionNo,
    required this.ideaDescriptionEn,
    required this.ideaCategoryNo,
    required this.ideaCategoryEn,
    this.coverImageUrl,
    this.proposedAt,
  });

  String ideaTitle(bool isNorwegian) => isNorwegian
      ? (ideaTitleNo.isNotEmpty ? ideaTitleNo : ideaTitleEn)
      : (ideaTitleEn.isNotEmpty ? ideaTitleEn : ideaTitleNo);

  String ideaMeta(bool isNorwegian) => isNorwegian
      ? (ideaMetaNo.isNotEmpty ? ideaMetaNo : ideaMetaEn)
      : (ideaMetaEn.isNotEmpty ? ideaMetaEn : ideaMetaNo);

  String ideaDescription(bool isNorwegian) => isNorwegian
      ? (ideaDescriptionNo.isNotEmpty ? ideaDescriptionNo : ideaDescriptionEn)
      : (ideaDescriptionEn.isNotEmpty ? ideaDescriptionEn : ideaDescriptionNo);

  String ideaCategory(bool isNorwegian) => isNorwegian
      ? (ideaCategoryNo.isNotEmpty ? ideaCategoryNo : ideaCategoryEn)
      : (ideaCategoryEn.isNotEmpty ? ideaCategoryEn : ideaCategoryNo);

  factory IncomingIdeaRequest.fromFirestore(String id, Map<String, dynamic> data) {
    final legacyTitle = data['ideaTitle'] as String? ?? '';
    return IncomingIdeaRequest(
      requestId: id,
      senderName: data['senderName'] as String? ?? 'Din partner',
      ideaTitleNo: data['ideaTitleNo'] as String? ?? legacyTitle,
      ideaTitleEn: data['ideaTitleEn'] as String? ?? legacyTitle,
      ideaMetaNo: data['ideaMetaNo'] as String? ?? data['ideaMeta'] as String? ?? '',
      ideaMetaEn: data['ideaMetaEn'] as String? ?? data['ideaMeta'] as String? ?? '',
      ideaDescriptionNo: data['ideaDescriptionNo'] as String? ?? data['ideaDescription'] as String? ?? '',
      ideaDescriptionEn: data['ideaDescriptionEn'] as String? ?? data['ideaDescription'] as String? ?? '',
      ideaCategoryNo: data['ideaCategoryNo'] as String? ?? data['ideaCategory'] as String? ?? '',
      ideaCategoryEn: data['ideaCategoryEn'] as String? ?? data['ideaCategory'] as String? ?? '',
      coverImageUrl: data['coverImageUrl'] as String?,
      proposedAt: (data['proposedAt'] as Timestamp?)?.toDate(),
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
  DateTime? _acceptedPlanDate;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _requestSub;
  IncomingIdeaRequest? _incomingRequest;
  int _pendingIncomingCount = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingSub;

  bool _initialized = false;

  WeeklyIdeasDoc? get doc => _doc;
  bool get loading => _loading;
  bool get initialized => _initialized;
  List<WeeklyIdea> get ideas => _doc?.ideas ?? [];
  bool get isAiGenerated => _doc?.isAiGenerated ?? false;
  IdeaSendState get sendState => _sendState;
  WeeklyIdea? get sentIdea => _sentIdea;
  String? get sendError => _sendError;
  DateTime? get acceptedPlanDate => _acceptedPlanDate;
  IncomingIdeaRequest? get incomingRequest => _incomingRequest;
  int get pendingIncomingCount => _pendingIncomingCount;

  void clearSendError() { _sendError = null; }

  // Call once coupleId is known — idempotent.
  Future<void> init(String coupleId) async {
    if (_coupleId == coupleId && _sub != null) return;
    _coupleId = coupleId;
    _initialized = false;
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
              _initialized = true;
              notifyListeners();
            },
          );
    } catch (e) {
      debugPrint('WeeklyIdeasProvider: Firebase unavailable: $e');
      _initialized = true;
      notifyListeners();
    }
  }

  void _onSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists || snap.data() == null) {
      if (!_initialized) {
        _initialized = true;
        notifyListeners();
      }
      _triggerGenerationIfNeeded();
      return;
    }

    final newDoc = WeeklyIdeasDoc.fromFirestore(snap.data()!);
    _doc = newDoc;
    // Fetch all cover URLs in parallel BEFORE notifying so carousel cards
    // sync-seed _imageUrl immediately and never render without a URL.
    _prefetchImageUrls(newDoc.ideas.take(4).toList()).whenComplete(() {
      _initialized = true;
      if (!newDoc.isStale) _loading = false;
      notifyListeners();
    });

    if (newDoc.isStale) _triggerGenerationIfNeeded();
  }

  Future<void> _prefetchImageUrls(List<WeeklyIdea> ideas) => Future.wait(
        ideas.map((idea) => IdeaImageService.fetchCoverUrl(
            IdeaImageService.toId(idea.titleNo))),
      );

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
    DateTime? proposedAt,
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
        'ideaTitle': idea.titleNo.isNotEmpty ? idea.titleNo : idea.titleEn,
        'ideaTitleNo': idea.titleNo,
        'ideaTitleEn': idea.titleEn,
        'ideaCategoryNo': idea.categoryNo,
        'ideaCategoryEn': idea.categoryEn,
        'ideaMetaNo': idea.metaNo,
        'ideaMetaEn': idea.metaEn,
        'ideaDescriptionNo': idea.descriptionNo,
        'ideaDescriptionEn': idea.descriptionEn,
        'senderName': senderName,
        'sentBy': userId,
        'recipientId': partnerId,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (proposedAt != null) 'proposedAt': Timestamp.fromDate(proposedAt),
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
      _acceptedPlanDate = (data['acceptedAt'] as Timestamp?)?.toDate();
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
    _acceptedPlanDate = null;
    _requestSub?.cancel();
    _requestSub = null;
    notifyListeners();
  }

  Future<bool> cancelForReplacement(String coupleId) async {
    final docId = _pendingRequestId;
    if (docId == null) {
      resetSendState();
      return true;
    }
    try {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('ideaRequests')
          .doc(docId)
          .update({'status': 'cancelled'});
      resetSendState();
      return true;
    } catch (e) {
      debugPrint('cancelForReplacement failed: $e');
      return false;
    }
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

  Future<void> respondToRequest(
    String coupleId,
    String requestId,
    bool accepted, {
    DateTime? planDate,
  }) async {
    _incomingRequest = null;
    notifyListeners();
    try {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('ideaRequests')
          .doc(requestId)
          .update({
        'status': accepted ? 'accepted' : 'declined',
        if (accepted && planDate != null)
          'acceptedAt': Timestamp.fromDate(planDate),
      });
    } catch (e) {
      debugPrint('respondToRequest failed: $e');
    }
  }

  Future<void> checkOutgoingRequests(String coupleId, String userId) async {
    if (_sendState != IdeaSendState.idle) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('ideaRequests')
          .where('status', whereIn: ['pending', 'accepted'])
          .get();

      final outgoing = snap.docs
          .where((d) => (d.data()['sentBy'] as String?) == userId)
          .toList();

      if (outgoing.isEmpty) return;

      final pendingDocs = outgoing.where((d) => d.data()['status'] == 'pending').toList();
      final acceptedDocs = outgoing.where((d) => d.data()['status'] == 'accepted').toList();

      if (pendingDocs.isNotEmpty) {
        final doc = pendingDocs.first;
        final data = doc.data();

        final sentAt = data['sentAt'] as Timestamp?;
        if (sentAt != null && DateTime.now().difference(sentAt.toDate()).inHours >= 24) {
          doc.reference.update({'status': 'expired'}).catchError((_) {});
          return;
        }

        _pendingRequestId = doc.id;
        _sentIdea = _ideaFromRequestData(data);
        _sendState = IdeaSendState.waiting;
        _requestSub?.cancel();
        _requestSub = doc.reference.snapshots().listen(_onRequestSnapshot, onError: (_) {});
        notifyListeners();
      } else if (acceptedDocs.isNotEmpty) {
        final doc = acceptedDocs.first;
        final data = doc.data();
        final acceptedAt = (data['acceptedAt'] as Timestamp?)?.toDate();
        final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
        final refTime = acceptedAt ?? sentAt;
        if (refTime != null && DateTime.now().difference(refTime).inHours >= 2) return;
        _pendingRequestId = doc.id;
        _sentIdea = _ideaFromRequestData(data);
        _acceptedPlanDate = acceptedAt;
        _sendState = IdeaSendState.accepted;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('checkOutgoingRequests failed: $e');
    }
  }

  WeeklyIdea _ideaFromRequestData(Map<String, dynamic> data) {
    final legacyTitle = data['ideaTitle'] as String? ?? '';
    return WeeklyIdea(
      titleNo: data['ideaTitleNo'] as String? ?? legacyTitle,
      titleEn: data['ideaTitleEn'] as String? ?? legacyTitle,
      categoryNo: data['ideaCategoryNo'] as String? ?? data['ideaCategory'] as String? ?? '',
      categoryEn: data['ideaCategoryEn'] as String? ?? data['ideaCategory'] as String? ?? '',
      metaNo: data['ideaMetaNo'] as String? ?? data['ideaMeta'] as String? ?? '',
      metaEn: data['ideaMetaEn'] as String? ?? data['ideaMeta'] as String? ?? '',
      descriptionNo: data['ideaDescriptionNo'] as String? ?? data['ideaDescription'] as String? ?? '',
      descriptionEn: data['ideaDescriptionEn'] as String? ?? data['ideaDescription'] as String? ?? '',
      cardColor: const Color(0xFFFAF7F4),
      tagColor: const Color(0xFFE5DDD5),
      tagTextColor: const Color(0xFF6B5B55),
      icon: Icons.star_outline_rounded,
    );
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

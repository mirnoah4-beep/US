import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/mediation.dart';

/// Client side of "Oss mot problemet". Every state change goes through a
/// server callable; the only client write is the caller's own private
/// draft (rules: owner-only, draft:true, kind gated by the talk's stage).
class MediationService {
  static final _db = FirebaseFirestore.instance;
  static HttpsCallable _fn(String name) =>
      FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable(name);

  static CollectionReference<Map<String, dynamic>> collection(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('mediations');

  static Stream<List<Mediation>> stream(String coupleId) => collection(coupleId)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map(Mediation.fromDoc).whereType<Mediation>().toList());

  static DocumentReference<Map<String, dynamic>> draftRef(String coupleId, String mediationId, String uid) =>
      collection(coupleId).doc(mediationId).collection('private').doc(uid);

  static Stream<MediationDraft> draftStream(String coupleId, String mediationId, String uid) =>
      draftRef(coupleId, mediationId, uid).snapshots().map((d) => MediationDraft.fromMap(d.data()));

  /// Saves the caller's own draft — only the keys of its kind + draft:true;
  /// the rules reject anything else and any kind that does not match the stage.
  static Future<void> saveDraft(String coupleId, String mediationId, String uid, MediationDraft d) =>
      draftRef(coupleId, mediationId, uid).set({
        ...d.toMap(),
        'draft': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<String> create(String coupleId, String category) async {
    final r = await _fn('mediationCreate').call<Map<String, dynamic>>({'coupleId': coupleId, 'category': category});
    return r.data['mediationId'] as String;
  }

  /// Initiator: topic + wish → invitation. Returns true when flagged (safety).
  static Future<bool> submitTopic(String coupleId, String mediationId) => _flagged('mediationSubmitTopic', coupleId, mediationId);

  static Future<void> rephraseInvitation(String coupleId, String mediationId) =>
      _fn('mediationRephraseInvitation').call({'coupleId': coupleId, 'mediationId': mediationId});

  static Future<void> approveInvitation(String coupleId, String mediationId) =>
      _fn('mediationApproveInvitation').call({'coupleId': coupleId, 'mediationId': mediationId});

  static Future<void> respond(String coupleId, String mediationId, String timing) =>
      _fn('mediationRespond').call({'coupleId': coupleId, 'mediationId': mediationId, 'timing': timing});

  /// Partner: view + need → round 1. Returns true when flagged (safety).
  static Future<bool> submitAnswer(String coupleId, String mediationId) => _flagged('mediationSubmitAnswer', coupleId, mediationId);

  /// Either partner, once per round. Returns true when flagged (safety).
  static Future<bool> submitFeedback(String coupleId, String mediationId) => _flagged('mediationSubmitFeedback', coupleId, mediationId);

  static Future<bool> _flagged(String fn, String coupleId, String mediationId) async {
    final r = await _fn(fn).call<Map<String, dynamic>>({'coupleId': coupleId, 'mediationId': mediationId});
    return r.data['flagged'] == true;
  }

  static Future<void> retryGeneration(String coupleId, String mediationId) =>
      _fn('mediationRetryGeneration').call({'coupleId': coupleId, 'mediationId': mediationId});

  static Future<void> nudge(String coupleId, String mediationId) =>
      _fn('mediationNudge').call({'coupleId': coupleId, 'mediationId': mediationId});

  static Future<void> editAgreement(String coupleId, String mediationId, String shared, String mine) =>
      _fn('mediationEditAgreement').call({'coupleId': coupleId, 'mediationId': mediationId, 'shared': shared, 'mine': mine});

  static Future<bool> accept(String coupleId, String mediationId, String hash) async {
    final r = await _fn('mediationAccept').call<Map<String, dynamic>>({'coupleId': coupleId, 'mediationId': mediationId, 'hash': hash});
    return r.data['active'] == true;
  }

  static Future<void> setState(String coupleId, String mediationId, String state) =>
      _fn('mediationSetState').call({'coupleId': coupleId, 'mediationId': mediationId, 'state': state});

  /// Server `details.reason` of a failed callable, or null.
  static String? reasonOf(Object e) {
    if (e is FirebaseFunctionsException) {
      final d = e.details;
      if (d is Map && d['reason'] is String) return d['reason'] as String;
      return e.code;
    }
    return null;
  }
}

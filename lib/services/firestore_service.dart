import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/couple_model.dart';
import '../models/invite_model.dart';
import '../models/join_result.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ── Users ──────────────────────────────────────────────────────────────────

  static DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      _db.collection('users').doc(uid);

  static Future<void> ensureUserDoc(User user, {bool needsEmailVerification = false}) async {
    final snap = await userRef(user.uid).get();
    if (!snap.exists) await createUser(user, needsEmailVerification: needsEmailVerification);
  }

  static Future<void> createUser(User user, {bool needsEmailVerification = false}) =>
      userRef(user.uid).set({
        'uid': user.uid,
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'avatarUrl': user.photoURL,
        'coupleId': null,
        'language': 'no',
        'fcmToken': null,
        'createdAt': FieldValue.serverTimestamp(),
        'needsEmailVerification': needsEmailVerification,
      });

  static Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      userRef(uid).update(data);

  static Future<void> saveFcmToken(String uid, String token) =>
      userRef(uid).set({'fcmToken': token}, SetOptions(merge: true));

  static Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) =>
      userRef(uid).snapshots();

  // ── Couples ────────────────────────────────────────────────────────────────

  static DocumentReference<Map<String, dynamic>> coupleRef(String coupleId) =>
      _db.collection('couples').doc(coupleId);

  static DocumentReference<Map<String, dynamic>> settingsRef(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('settings').doc('main');

  static Future<void> createCoupleSettings(String coupleId) =>
      settingsRef(coupleId).set({
        'parentMode': false,
        'bedtimeWeekday': '20:00',
        'bedtimeWeekend': '21:00',
        'weekdayTime': '30to60',
        'weekendTime': 'halfday',
        'preference': 'both',
        'quietHours': false,
        'eveningReminderEnabled': true,
        'eveningReminderTime': '20:00',
        'eveningReminderDays': '0111011',
        'weeklyPlanEnabled': true,
        'weeklyPlanTime': '18:00',
        'newIdeasEnabled': true,
        'momentsThisMonth': 0,
      }, SetOptions(merge: true));

  static Stream<DocumentSnapshot<Map<String, dynamic>>> settingsStream(String coupleId) =>
      settingsRef(coupleId).snapshots();

  static Future<void> updateSettings(String coupleId, Map<String, dynamic> data) =>
      settingsRef(coupleId).update(data);

  // ── Invites ────────────────────────────────────────────────────────────────

  /// Creates (or reuses) a pairing invite for the current user via the
  /// `createInvite` Cloud Function. Returns (code, coupleId).
  ///
  /// Server-side on purpose: the "reuse existing invite" step is a query over
  /// the invites collection, and the security rules now deny client-side
  /// list/query on invites (the code is a shared secret). The [userId] argument
  /// is ignored — the function derives the caller from the auth context — but is
  /// kept so the call site in couple_setup_screen stays unchanged.
  static Future<({String code, String coupleId})> createInvite(
      String userId) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('createInvite');
    final result = await callable.call();
    final code = result.data['code'] as String?;
    final coupleId = result.data['coupleId'] as String?;
    if (code == null || coupleId == null) {
      throw Exception('createInvite returned an invalid response.');
    }
    return (code: code, coupleId: coupleId);
  }

  /// Joins a couple via an invite [code]. Returns a [JoinResult].
  /// Uses a transaction so all reads and writes are atomic.
  static Future<JoinResult> joinByCode(
      String code, String currentUserId) async {
    try {
      return await _db.runTransaction<JoinResult>((txn) async {
        // 1. Read the invite.
        final inviteSnap =
            await txn.get(_db.collection('invites').doc(code));
        if (!inviteSnap.exists) {
          return const JoinFailure(JoinFailureReason.invalidCode);
        }
        final invite = InviteModel.fromFirestore(inviteSnap);

        // 2. Block self-join.
        if (invite.fromUserId == currentUserId) {
          return const JoinFailure(JoinFailureReason.ownInvite);
        }

        // 3. Verify the couple is still pending.
        final coupleSnap =
            await txn.get(_db.collection('couples').doc(invite.coupleId));
        if (!coupleSnap.exists ||
            coupleSnap.data()?['status'] != 'pending') {
          return const JoinFailure(JoinFailureReason.inviteExpired);
        }

        // 4. All valid — commit the join atomically. We no longer read the
        //    inviter's user doc (the rules forbid reading a stranger's
        //    profile). The "inviter already partnered" case is enforced
        //    server-side: the rules only permit setting the inviter's coupleId
        //    when it is currently null, so if the inviter is already in a
        //    couple the update below is rejected and the transaction aborts
        //    (surfaced as alreadyPartnered in the catch).
        debugPrint('[joinByCode] reads passed — committing writes');
        txn.update(_db.collection('couples').doc(invite.coupleId), {
          'members': FieldValue.arrayUnion([currentUserId]),
          'status': 'active',
          'inviteCode': null,
        });
        txn.update(
            _db.collection('users').doc(currentUserId),
            {'coupleId': invite.coupleId});
        txn.update(
            _db.collection('users').doc(invite.fromUserId),
            {'coupleId': invite.coupleId});
        // Invite cleanup is handled by the onCoupleActivated Cloud Function
        // (deletes /invites/{inviteCode} when the couple flips to 'active'),
        // so the joiner no longer needs delete permission on the invite.

        return JoinSuccess(invite.coupleId);
      });
    } catch (e) {
      // Do not log the raw exception in release — it can contain the invite
      // code / couple path. Keep detail for local debugging only.
      if (kDebugMode) debugPrint('[joinByCode] transaction failed: $e');
      if (e is FirebaseException && e.code == 'permission-denied') {
        // On an otherwise-valid join the only write the rules can reject is the
        // inviter's coupleId update (blocked when the inviter is already in a
        // couple). Map it to alreadyPartnered rather than a generic error.
        return const JoinFailure(JoinFailureReason.alreadyPartnered);
      }
      return JoinFailure(JoinFailureReason.networkError, e.toString());
    }
  }

  /// Cancels a pending invite. Deletes the invite doc and the pending
  /// couple doc atomically. Only the [userId] who created the invite
  /// can cancel it (enforced by security rules on the server and
  /// by a guard here on the client).
  static Future<void> cancelInvite(String code, String userId) {
    return _db.runTransaction((txn) async {
      final inviteSnap =
          await txn.get(_db.collection('invites').doc(code));
      if (!inviteSnap.exists) return;
      final invite = InviteModel.fromFirestore(inviteSnap);
      if (invite.fromUserId != userId) return;
      txn.delete(_db.collection('invites').doc(code));
      txn.delete(_db.collection('couples').doc(invite.coupleId));
    });
  }

  static Future<void> updateStreakRecord(String coupleId, int record) =>
      coupleRef(coupleId).update({'streakRecord': record});

  /// Streams the couple document. Emits null when the doc is deleted
  /// (e.g. after a cancel) so callers can react accordingly.
  static Stream<CoupleModel?> watchCouple(String coupleId) {
    return _db.collection('couples').doc(coupleId).snapshots().map(
          (snap) => snap.exists ? CoupleModel.fromFirestore(snap) : null,
        );
  }

  // ── LastTime ───────────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> lastTimeRef(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('lastTime');

  static Future<void> logActivity(String coupleId, String activityId) async {
    final batch = _db.batch();
    batch.set(
      lastTimeRef(coupleId).doc(activityId),
      {'lastDone': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    batch.update(settingsRef(coupleId), {
      'momentsThisMonth': FieldValue.increment(1),
    });
    await batch.commit();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> lastTimeStream(String coupleId) =>
      lastTimeRef(coupleId).snapshots();

  // ── Relationship dates ─────────────────────────────────────────────────────

  static Future<void> setTogetherSince(String coupleId, DateTime date) =>
      coupleRef(coupleId).update({'togetherSince': Timestamp.fromDate(date)});

  // ── WeeklyPlan ─────────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> weeklyPlanRef(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('weeklyPlan');

  static Future<String> addPlan({
    required String coupleId,
    required String activity,
    required DateTime date,
    required String sentBy,
    String status = 'pending',
  }) async {
    final ref = weeklyPlanRef(coupleId).doc();
    await ref.set({
      'activity': activity,
      'date': Timestamp.fromDate(date),
      'status': status,
      'sentBy': sentBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> confirmPlan(String coupleId, String planId) =>
      weeklyPlanRef(coupleId).doc(planId).update({'status': 'confirmed'});

  static Future<void> deletePlan(String coupleId, String planId) =>
      weeklyPlanRef(coupleId).doc(planId).delete();

  static Stream<QuerySnapshot<Map<String, dynamic>>> weeklyPlanStream(String coupleId) =>
      weeklyPlanRef(coupleId).orderBy('date').snapshots();

  // ── Memories ────────────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> memoriesRef(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('memories');

  static Stream<QuerySnapshot<Map<String, dynamic>>> memoriesStream(String coupleId) =>
      memoriesRef(coupleId).orderBy('createdAt', descending: true).snapshots();

  static Future<String> addMemory({
    required String coupleId,
    required String activity,
    required String note,
    required String createdBy,
  }) async {
    final ref = memoriesRef(coupleId).doc();
    await ref.set({
      'activity': activity,
      'note': note,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> updateMemoryImageUrl(
    String coupleId,
    String docId,
    String url,
  ) =>
      memoriesRef(coupleId).doc(docId).update({'imageUrl': url});

  static Future<void> updateMemory(
    String coupleId,
    String docId, {
    String? note,
    String? imageUrl,
  }) {
    final data = <String, dynamic>{};
    if (note != null) data['note'] = note;
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    return memoriesRef(coupleId).doc(docId).update(data);
  }

  static Future<void> deleteMemory(String coupleId, String docId) =>
      memoriesRef(coupleId).doc(docId).delete();

}

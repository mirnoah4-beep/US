import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Creates an invite for [userId]. Returns (code, coupleId).
  /// If the user already has a pending invite, returns the existing code.
  static Future<({String code, String coupleId})> createInvite(
      String userId) async {
    // Re-use existing pending invite for this user.
    final existing = await _db
        .collection('invites')
        .where('fromUserId', isEqualTo: userId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final existingCoupleId = doc.data()['coupleId'] as String? ?? '';
      return (code: doc.id, coupleId: existingCoupleId);
    }

    // Generate a unique 8-char alphanumeric code (up to 5 attempts).
    // Character set excludes confusing glyphs (O, 0, I, 1).
    const inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    String? code;
    for (int attempt = 0; attempt < 5; attempt++) {
      final candidate = List.generate(
        8,
        (_) => inviteAlphabet[rng.nextInt(inviteAlphabet.length)],
      ).join();
      final snap = await _db.collection('invites').doc(candidate).get();
      if (!snap.exists) {
        code = candidate;
        break;
      }
    }
    if (code == null) {
      throw Exception('Could not generate a unique invite code. Try again.');
    }

    // Atomically create the pending couple doc and the invite doc.
    final coupleRef = _db.collection('couples').doc();
    final batch = _db.batch();

    batch.set(coupleRef, {
      'members': [userId],
      'status': 'pending',
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_db.collection('invites').doc(code), {
      'fromUserId': userId,
      'coupleId': coupleRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return (code: code, coupleId: coupleRef.id);
  }

  /// Joins a couple via an invite [code]. Returns a [JoinResult].
  /// Uses a transaction so all reads and writes are atomic.
  static Future<JoinResult> joinByCode(
      String code, String currentUserId) async {
    try {
      return await _db.runTransaction<JoinResult>((txn) async {
        // 1. Read the invite.
        final invitePath = 'invites/$code';
        debugPrint('[joinByCode] reading $invitePath');
        final inviteSnap =
            await txn.get(_db.collection('invites').doc(code));
        debugPrint('[joinByCode] read ok: $invitePath exists=${inviteSnap.exists}');
        if (!inviteSnap.exists) {
          return const JoinFailure(JoinFailureReason.invalidCode);
        }
        final invite = InviteModel.fromFirestore(inviteSnap);

        // 2. Block self-join.
        if (invite.fromUserId == currentUserId) {
          return const JoinFailure(JoinFailureReason.ownInvite);
        }

        // 3. Verify the couple is still pending.
        final couplePath = 'couples/${invite.coupleId}';
        debugPrint('[joinByCode] reading $couplePath');
        final coupleSnap =
            await txn.get(_db.collection('couples').doc(invite.coupleId));
        debugPrint('[joinByCode] read ok: $couplePath status=${coupleSnap.data()?['status']}');
        if (!coupleSnap.exists ||
            coupleSnap.data()?['status'] != 'pending') {
          return const JoinFailure(JoinFailureReason.inviteExpired);
        }

        // 4. Check the inviter does not already have an active different couple.
        final fromUserPath = 'users/${invite.fromUserId}';
        debugPrint('[joinByCode] reading $fromUserPath');
        final fromUserSnap =
            await txn.get(_db.collection('users').doc(invite.fromUserId));
        debugPrint('[joinByCode] read ok: $fromUserPath coupleId=${fromUserSnap.data()?['coupleId']}');
        final fromCoupleId =
            fromUserSnap.data()?['coupleId'] as String?;
        if (fromCoupleId != null &&
            fromCoupleId.isNotEmpty &&
            fromCoupleId != invite.coupleId) {
          return const JoinFailure(JoinFailureReason.alreadyPartnered);
        }

        // 5. All valid — commit the join atomically.
        debugPrint('[joinByCode] all reads passed — committing writes');
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
      debugPrint('[joinByCode] FAILED: $e');
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

  static Future<void> requestDisconnect(String coupleId, String userId) =>
      coupleRef(coupleId).update({'disconnectRequestedBy': userId});

  static Future<void> clearDisconnectRequest(String coupleId) =>
      coupleRef(coupleId).update({'disconnectRequestedBy': null});

  /// Ends the couple relationship atomically.
  /// Sets status to 'ended' and clears coupleId on both user docs.
  static Future<void> disconnectCouple({
    required String coupleId,
    required String currentUserId,
    required String partnerId,
  }) {
    return _db.runTransaction((txn) async {
      txn.update(coupleRef(coupleId), {
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
      txn.update(userRef(currentUserId), {'coupleId': null});
      if (partnerId.isNotEmpty) {
        txn.update(userRef(partnerId), {'coupleId': null});
      }
    });
  }

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

  static Future<void> deleteUserData(String uid, String? coupleId) async {
    await userRef(uid).delete();

    if (coupleId == null || coupleId.isEmpty) return;

    final cRef = _db.collection('couples').doc(coupleId);
    final coupleSnap = await cRef.get();
    if (!coupleSnap.exists) return;

    final members = List<String>.from(coupleSnap.data()?['members'] ?? []);

    if (members.length <= 1) {
      final inviteCode = coupleSnap.data()?['inviteCode'] as String?;
      if (inviteCode != null) {
        await _db.collection('invites').doc(inviteCode).delete().catchError((_) {});
      }
      const subcollections = ['weeklyIdeas', 'weeklyPlan', 'ideaRequests', 'lastTime', 'settings', 'memories'];
      for (final sub in subcollections) {
        final snap = await cRef.collection(sub).get();
        if (snap.docs.isEmpty) continue;
        final batch = _db.batch();
        for (final doc in snap.docs) batch.delete(doc.reference);
        await batch.commit();
      }
      await cRef.delete();
    } else {
      await cRef.update({'members': FieldValue.arrayRemove([uid])});
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/couple_model.dart';
import '../models/couple_preferences.dart';
import '../models/invite_model.dart';
import '../models/join_result.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ── Users ──────────────────────────────────────────────────────────────────

  static DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      _db.collection('users').doc(uid);

  /// Creates the user document on first login. On later logins it only
  /// self-heals a document that has NO `coupleId` key at all (older builds
  /// could create one via a merge write before [createUser] ran): the key is
  /// added as null. An existing coupleId — valid or not — is never touched
  /// here; relationship validity is the server's call (joinCouple /
  /// createInvite).
  static Future<void> ensureUserDoc(User user, {bool needsEmailVerification = false}) async {
    final snap = await userRef(user.uid).get();
    if (!snap.exists) {
      await createUser(user, needsEmailVerification: needsEmailVerification);
      return;
    }
    if (!(snap.data() ?? const {}).containsKey('coupleId')) {
      await userRef(user.uid).set({'coupleId': null}, SetOptions(merge: true));
    }
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

  /// Mirrors the UI language onto the user doc so server-sent FCM can be
  /// rendered in the RECIPIENT's language. Best-effort: a failure here must
  /// never block a language change, but it is reported rather than swallowed.
  static Future<void> saveLanguage(String language) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await userRef(uid).set({'language': language}, SetOptions(merge: true));
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st, reason: 'saveLanguage');
    }
  }

  /// Detects the device's current IANA timezone (e.g. 'Europe/Oslo',
  /// 'America/New_York') and mirrors it onto the user doc.
  ///
  /// The server needs this to know when 19:00 is for this person. It is read
  /// from the platform, never derived from language or country — several
  /// countries span multiple zones. Returns the identifier, or null if the
  /// platform could not supply one.
  static Future<String?> detectTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final identifier = info.identifier;
      // Reject anything that is not a real IANA region id — the server applies
      // the same rule, since a bare offset cannot follow DST.
      if (identifier.isEmpty) return null;
      if (!identifier.contains('/') && identifier != 'UTC') return null;
      return identifier;
    } catch (e, st) {
      await FirebaseCrashlytics.instance
          .recordError(e, st, reason: 'detectTimeZone');
      return null;
    }
  }

  /// Persists the detected IANA timezone for the signed-in user.
  static Future<void> saveTimeZone(String timeZone) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await userRef(uid).set({'timeZone': timeZone}, SetOptions(merge: true));
    } catch (e, st) {
      await FirebaseCrashlytics.instance
          .recordError(e, st, reason: 'saveTimeZone');
    }
  }

  /// Per-user notification preferences. Personal by design — a partner must
  /// never be able to change what the other person receives.
  static Future<void> updateNotificationPrefs(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await userRef(uid).set(data, SetOptions(merge: true));
  }

  /// Sends a predefined message to the signed-in user's partner.
  ///
  /// Only the templateId travels to the server; recipient, sender identity and
  /// FCM token are all resolved server-side by `sendPartnerNotification`.
  /// Throws [FirebaseFunctionsException] so callers can show a real message.
  static Future<bool> sendPartnerNotification(String templateId) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('sendPartnerNotification');
    final result = await callable.call<Map<String, dynamic>>({'templateId': templateId});
    return result.data['delivered'] as bool? ?? false;
  }

  /// Repairs a missing users/{uid}.coupleId from the server-authoritative
  /// couples.members relation. This is intentionally server-side: H3 security
  /// rules forbid clients from assigning themselves to arbitrary couples.
  ///
  /// Returns true only when an ACTIVE couple link was restored. Legitimately
  /// solo users get false and remain in the solo experience.
  static Future<bool> recoverCoupleLink() async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('recoverCoupleLink');
    final result = await callable.call<Map<String, dynamic>>();
    return result.data['recovered'] as bool? ?? false;
  }

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

  // ── Per-user preferences (settings/prefs_{uid}) ──────────────────────────

  static DocumentReference<Map<String, dynamic>> prefsRef(String coupleId, String uid) =>
      _db.collection('couples').doc(coupleId).collection('settings').doc('prefs_$uid');

  /// True when THIS user has completed their own onboarding for this couple.
  /// The legacy couple-level `onboardingDone` is deliberately not consulted —
  /// it only records that *someone* finished.
  static Future<bool> hasOwnPreferences(String coupleId, String uid) async =>
      (await prefsRef(coupleId, uid).get()).exists;

  /// Saves the caller's raw answers to their OWN prefs doc, then refreshes
  /// the legacy couple-level summary on settings/main so RC1 clients (and
  /// the server fallback) keep seeing a sensible value. The partner's raw
  /// answers are never touched; the summary is derived from both.
  static Future<void> saveUserPreferences(
    String coupleId,
    String uid,
    UserPrefs mine, {
    required List<String> members,
  }) async {
    await prefsRef(coupleId, uid).set({
      ...mine.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    });
    final partnerIds = members.where((m) => m != uid);
    final partnerPrefs = await Future.wait(partnerIds.map((m) async =>
        UserPrefs.fromMap((await prefsRef(coupleId, m).get()).data())));
    final mainSnap = await settingsRef(coupleId).get();
    final profile = deriveCoupleProfile([mine, ...partnerPrefs]);
    await settingsRef(coupleId).set(
      legacySummaryFor(profile, existingMain: mainSnap.data()),
      SetOptions(merge: true),
    );
  }

  /// The derived couple profile: both prefs docs when present, legacy
  /// settings/main as fallback, defaults otherwise. Read-only.
  static Future<CoupleProfile> loadCoupleProfile(String coupleId, List<String> members) async {
    final results = await Future.wait([
      settingsRef(coupleId).get(),
      ...members.map((m) => prefsRef(coupleId, m).get()),
    ]);
    final main = results.first.data();
    final users = results.skip(1).map((d) => UserPrefs.fromMap(d.data())).toList();
    return deriveCoupleProfile(users, legacy: UserPrefs.fromLegacyMain(main));
  }

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

  /// Joins a couple via an invite [code] through the `joinCouple` callable.
  ///
  /// Server-authoritative: the code is the only input; the function verifies
  /// the invite, the pending couple, that neither side already has an
  /// ACTIVE partner (a stale coupleId is cleared server-side), and consumes
  /// the invite in the same transaction. The [currentUserId] argument is
  /// ignored — the server derives the caller from the auth context — and is
  /// kept so the call site stays unchanged.
  static Future<JoinResult> joinByCode(
      String code, String currentUserId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('joinCouple');
      final result = await callable.call<Map<String, dynamic>>({'code': code});
      final coupleId = result.data['coupleId'] as String?;
      if (coupleId == null || coupleId.isEmpty) {
        return const JoinFailure(JoinFailureReason.networkError);
      }
      return JoinSuccess(coupleId);
    } on FirebaseFunctionsException catch (e) {
      final reason = mapPairingError(code: e.code, details: e.details);
      if (reason == JoinFailureReason.networkError) {
        // Only unexpected failures are worth a crash report; the structured
        // reasons are ordinary user outcomes. No code or uid is attached.
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current, reason: 'joinCouple');
      }
      return JoinFailure(reason);
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'joinCouple');
      return const JoinFailure(JoinFailureReason.networkError);
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

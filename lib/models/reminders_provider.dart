import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class RemindersProvider extends ChangeNotifier {
  bool eveningEnabled = true;
  TimeOfDay eveningTime = const TimeOfDay(hour: 20, minute: 0);
  List<bool> eveningDays = [false, true, true, true, false, true, true];
  bool weeklyPlanEnabled = true;
  TimeOfDay weeklyPlanTime = const TimeOfDay(hour: 18, minute: 0);
  bool newIdeasEnabled = true;

  // ── Per-user notification preferences (users/{uid}) ─────────────────────
  // Deliberately NOT couple-level: notification preferences are personal, and
  // one partner must never be able to toggle the other's notifications.
  bool smartRemindersEnabled = true;
  bool qualityTimeReminderEnabled = true;
  bool dateReminderEnabled = true;
  bool weeklyRelationshipReminderEnabled = true;
  bool partnerMessagesEnabled = true;

  /// The IANA timezone the server will use for this user, shown in settings.
  String? timeZone;

  String? _coupleId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  RemindersProvider() {
    _listenToAuth();
  }

  void _listenToAuth() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _sub?.cancel();
        _coupleId = null;
      } else {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snap) {
          final data = snap.data();
          final coupleId = data?['coupleId'] as String? ?? '';
          if (coupleId.isNotEmpty && coupleId != _coupleId) {
            _coupleId = coupleId;
            _subscribeSettings(coupleId);
          }
          // Per-user notification preferences live on the user doc. The UI
          // shows the intended defaults; the server treats absent fields as
          // OFF until _ensureRolloutInitialized() persists them.
          smartRemindersEnabled = data?['smartRemindersEnabled'] as bool? ?? true;
          qualityTimeReminderEnabled = data?['qualityTimeReminderEnabled'] as bool? ?? true;
          dateReminderEnabled = data?['dateReminderEnabled'] as bool? ?? true;
          weeklyRelationshipReminderEnabled =
              data?['weeklyRelationshipReminderEnabled'] as bool? ?? true;
          partnerMessagesEnabled = data?['partnerMessagesEnabled'] as bool? ?? true;
          timeZone = data?['timeZone'] as String?;
          notifyListeners();
          _ensureRolloutInitialized(data);
        }, onError: (Object e, StackTrace st) {
          FirebaseCrashlytics.instance
              .recordError(e, st, reason: 'RemindersProvider user stream');
        });
      }
    });
  }

  void _subscribeSettings(String coupleId) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('settings')
        .doc('main')
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final d = snap.data()!;
      eveningEnabled = d['eveningReminderEnabled'] as bool? ?? true;
      eveningTime = _parseTime(d['eveningReminderTime'] as String?, const TimeOfDay(hour: 20, minute: 0));
      final edStr = d['eveningReminderDays'] as String? ?? '0111011';
      if (edStr.length == 7) {
        eveningDays = edStr.split('').map((c) => c == '1').toList();
      }
      weeklyPlanEnabled = d['weeklyPlanEnabled'] as bool? ?? true;
      weeklyPlanTime = _parseTime(d['weeklyPlanTime'] as String?, const TimeOfDay(hour: 18, minute: 0));
      newIdeasEnabled = d['newIdeasEnabled'] as bool? ?? true;
      notifyListeners();
    });
  }

  TimeOfDay _parseTime(String? s, TimeOfDay fallback) {
    if (s == null) return fallback;
    final parts = s.split(':');
    if (parts.length != 2) return fallback;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute,
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save(Map<String, dynamic> data) async {
    final coupleId = _coupleId;
    if (coupleId == null || coupleId.isEmpty) return;
    await FirestoreService.updateSettings(coupleId, data);
  }

  void setEveningEnabled(bool v) {
    eveningEnabled = v;
    notifyListeners();
    _save({'eveningReminderEnabled': v});
    if (v) {
      NotificationService().scheduleEveningNotifications(
        days: eveningDays,
        hour: eveningTime.hour,
        minute: eveningTime.minute,
        title: 'Tid til dere to?',
        body: 'En liten idé venter — ta en titt når dere har et øyeblikk.',
      );
    } else {
      NotificationService().cancelEveningNotifications();
    }
  }

  void setEveningTime(TimeOfDay t) {
    eveningTime = t;
    notifyListeners();
    _save({'eveningReminderTime': _fmt(t)});
    if (eveningEnabled) {
      NotificationService().scheduleEveningNotifications(
        days: eveningDays,
        hour: t.hour,
        minute: t.minute,
        title: 'Tid til dere to?',
        body: 'En liten idé venter — ta en titt når dere har et øyeblikk.',
      );
    }
  }

  void toggleEveningDay(int i) {
    eveningDays = List<bool>.from(eveningDays)..[i] = !eveningDays[i];
    notifyListeners();
    _save({'eveningReminderDays': eveningDays.map((b) => b ? '1' : '0').join()});
    if (eveningEnabled) {
      NotificationService().scheduleEveningNotifications(
        days: eveningDays,
        hour: eveningTime.hour,
        minute: eveningTime.minute,
        title: 'Tid til dere to?',
        body: 'En liten idé venter — ta en titt når dere har et øyeblikk.',
      );
    }
  }

  void setWeeklyPlanEnabled(bool v) {
    weeklyPlanEnabled = v;
    notifyListeners();
    _save({'weeklyPlanEnabled': v});
    if (v) {
      NotificationService().scheduleWeeklyPlanNotification(
        hour: weeklyPlanTime.hour,
        minute: weeklyPlanTime.minute,
        title: 'Planlegg uken',
        body: 'Ta 10 minutter i kveld og planlegg uken sammen.',
      );
    } else {
      NotificationService().cancelWeeklyPlanNotification();
    }
  }

  void setWeeklyPlanTime(TimeOfDay t) {
    weeklyPlanTime = t;
    notifyListeners();
    _save({'weeklyPlanTime': _fmt(t)});
    if (weeklyPlanEnabled) {
      NotificationService().scheduleWeeklyPlanNotification(
        hour: t.hour,
        minute: t.minute,
        title: 'Planlegg uken',
        body: 'Ta 10 minutter i kveld og planlegg uken sammen.',
      );
    }
  }

  void setNewIdeasEnabled(bool v) {
    newIdeasEnabled = v;
    notifyListeners();
    _save({'newIdeasEnabled': v});
  }

  // ── Rollout gate ────────────────────────────────────────────────────────

  /// Bumped when the client gains the ability to handle a new automatic
  /// reminder payload. Must match RELATIONSHIP_REMINDERS_VERSION in
  /// functions/src/relationshipReminders.ts.
  static const int kRelationshipRemindersVersion = 1;

  bool _rolloutWriteInFlight = false;

  /// Announces to the server that THIS build understands the
  /// `relationship_reminder` FCM payload, and persists the intended defaults
  /// explicitly so the server never has to infer them from missing fields.
  ///
  /// Until this runs, relationshipReminderScheduler skips the user entirely —
  /// which is what keeps older installs from receiving a payload they cannot
  /// route.
  Future<void> _ensureRolloutInitialized(Map<String, dynamic>? data) async {
    if (_rolloutWriteInFlight) return;

    // The device timezone can change (travel, DST-region move, OS setting), so
    // re-check it on every launch and write only when it actually differs.
    final stored = data?['timeZone'] as String?;
    final detected = await FirestoreService.detectTimeZone();
    if (detected != null && detected != stored) {
      await FirestoreService.saveTimeZone(detected);
    }

    final version = data?['relationshipRemindersVersion'];
    if (version is int && version >= kRelationshipRemindersVersion) return;

    // Without a resolvable timezone the server cannot know when this user's
    // 19:00 is, so do not claim rollout readiness yet — the user stays
    // ineligible rather than being guessed at.
    if (detected == null && stored == null) return;

    _rolloutWriteInFlight = true;
    try {
      await FirestoreService.updateNotificationPrefs({
        'relationshipRemindersVersion': kRelationshipRemindersVersion,
        // Persist explicit values rather than relying on server defaults.
        'smartRemindersEnabled': data?['smartRemindersEnabled'] as bool? ?? true,
        'qualityTimeReminderEnabled': data?['qualityTimeReminderEnabled'] as bool? ?? true,
        'dateReminderEnabled': data?['dateReminderEnabled'] as bool? ?? true,
        'weeklyRelationshipReminderEnabled':
            data?['weeklyRelationshipReminderEnabled'] as bool? ?? true,
        'partnerMessagesEnabled': data?['partnerMessagesEnabled'] as bool? ?? true,
        if (detected != null) 'timeZone': detected,
      });
    } catch (e, st) {
      await FirebaseCrashlytics.instance
          .recordError(e, st, reason: 'relationshipRemindersRollout');
    } finally {
      _rolloutWriteInFlight = false;
    }
  }

  // ── Per-user notification preferences ───────────────────────────────────

  Future<void> _saveUserPref(Map<String, dynamic> data) async {
    try {
      await FirestoreService.updateNotificationPrefs(data);
    } catch (e, st) {
      await FirebaseCrashlytics.instance
          .recordError(e, st, reason: 'saveNotificationPref');
    }
  }

  void setSmartRemindersEnabled(bool v) {
    smartRemindersEnabled = v;
    notifyListeners();
    _saveUserPref({'smartRemindersEnabled': v});
  }

  void setQualityTimeReminderEnabled(bool v) {
    qualityTimeReminderEnabled = v;
    notifyListeners();
    _saveUserPref({'qualityTimeReminderEnabled': v});
  }

  void setDateReminderEnabled(bool v) {
    dateReminderEnabled = v;
    notifyListeners();
    _saveUserPref({'dateReminderEnabled': v});
  }

  void setWeeklyRelationshipReminderEnabled(bool v) {
    weeklyRelationshipReminderEnabled = v;
    notifyListeners();
    _saveUserPref({'weeklyRelationshipReminderEnabled': v});
  }

  void setPartnerMessagesEnabled(bool v) {
    partnerMessagesEnabled = v;
    notifyListeners();
    _saveUserPref({'partnerMessagesEnabled': v});
  }

  String get formattedEveningTime => _fmt(eveningTime);
  String get formattedWeeklyPlanTime => _fmt(weeklyPlanTime);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

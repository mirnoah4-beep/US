import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          final coupleId = snap.data()?['coupleId'] as String? ?? '';
          if (coupleId.isNotEmpty && coupleId != _coupleId) {
            _coupleId = coupleId;
            _subscribeSettings(coupleId);
          }
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

  String get formattedEveningTime => _fmt(eveningTime);
  String get formattedWeeklyPlanTime => _fmt(weeklyPlanTime);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

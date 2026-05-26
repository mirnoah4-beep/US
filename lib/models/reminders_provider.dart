import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class RemindersProvider extends ChangeNotifier {
  bool eveningEnabled = true;
  TimeOfDay eveningTime = const TimeOfDay(hour: 20, minute: 0);
  // Ma Ti On To Fr Lø Sø — default: Ti On To Lø Sø selected
  List<bool> eveningDays = [false, true, true, true, false, true, true];
  bool weeklyPlanEnabled = true;
  TimeOfDay weeklyPlanTime = const TimeOfDay(hour: 18, minute: 0);
  bool newIdeasEnabled = true;

  RemindersProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    // TODO: replace with Firestore when backend ready
    final prefs = await SharedPreferences.getInstance();
    eveningEnabled = prefs.getBool('eveningEnabled') ?? true;
    eveningTime = _parseTime(
        prefs.getString('eveningTime'), const TimeOfDay(hour: 20, minute: 0));
    final edStr = prefs.getString('eveningDays') ?? '0111011';
    if (edStr.length == 7) {
      eveningDays = edStr.split('').map((c) => c == '1').toList();
    }
    weeklyPlanEnabled = prefs.getBool('weeklyPlanEnabled') ?? true;
    weeklyPlanTime = _parseTime(
        prefs.getString('weeklyPlanTime'), const TimeOfDay(hour: 18, minute: 0));
    newIdeasEnabled = prefs.getBool('newIdeasEnabled') ?? true;
    notifyListeners();
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

  Future<void> _save() async {
    // TODO: replace with Firestore when backend ready
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eveningEnabled', eveningEnabled);
    await prefs.setString('eveningTime', _fmt(eveningTime));
    await prefs.setString('eveningDays', eveningDays.map((b) => b ? '1' : '0').join());
    await prefs.setBool('weeklyPlanEnabled', weeklyPlanEnabled);
    await prefs.setString('weeklyPlanTime', _fmt(weeklyPlanTime));
    await prefs.setBool('newIdeasEnabled', newIdeasEnabled);
  }

  void setEveningEnabled(bool v) {
    eveningEnabled = v;
    notifyListeners();
    _save();
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
    _save();
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
    _save();
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
    _save();
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
    _save();
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
    _save();
    // TODO: connect to FCM when backend ready
  }

  String get formattedEveningTime => _fmt(eveningTime);
  String get formattedWeeklyPlanTime => _fmt(weeklyPlanTime);
}

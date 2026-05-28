import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsModel {
  final bool parentMode;
  final String bedtimeWeekday;
  final String bedtimeWeekend;
  final String weekdayTime;
  final String weekendTime;
  final String preference;
  final bool quietHours;
  final bool eveningReminderEnabled;
  final String eveningReminderTime;
  final String eveningReminderDays;
  final bool weeklyPlanEnabled;
  final String weeklyPlanTime;
  final bool newIdeasEnabled;
  final int momentsThisMonth;

  const SettingsModel({
    this.parentMode = false,
    this.bedtimeWeekday = '20:00',
    this.bedtimeWeekend = '21:00',
    this.weekdayTime = '30to60',
    this.weekendTime = 'halfday',
    this.preference = 'both',
    this.quietHours = false,
    this.eveningReminderEnabled = true,
    this.eveningReminderTime = '20:00',
    this.eveningReminderDays = '0111011',
    this.weeklyPlanEnabled = true,
    this.weeklyPlanTime = '18:00',
    this.newIdeasEnabled = true,
    this.momentsThisMonth = 0,
  });

  factory SettingsModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SettingsModel(
      parentMode: d['parentMode'] as bool? ?? false,
      bedtimeWeekday: d['bedtimeWeekday'] as String? ?? '20:00',
      bedtimeWeekend: d['bedtimeWeekend'] as String? ?? '21:00',
      weekdayTime: d['weekdayTime'] as String? ?? '30to60',
      weekendTime: d['weekendTime'] as String? ?? 'halfday',
      preference: d['preference'] as String? ?? 'both',
      quietHours: d['quietHours'] as bool? ?? false,
      eveningReminderEnabled: d['eveningReminderEnabled'] as bool? ?? true,
      eveningReminderTime: d['eveningReminderTime'] as String? ?? '20:00',
      eveningReminderDays: d['eveningReminderDays'] as String? ?? '0111011',
      weeklyPlanEnabled: d['weeklyPlanEnabled'] as bool? ?? true,
      weeklyPlanTime: d['weeklyPlanTime'] as String? ?? '18:00',
      newIdeasEnabled: d['newIdeasEnabled'] as bool? ?? true,
      momentsThisMonth: d['momentsThisMonth'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'parentMode': parentMode,
    'bedtimeWeekday': bedtimeWeekday,
    'bedtimeWeekend': bedtimeWeekend,
    'weekdayTime': weekdayTime,
    'weekendTime': weekendTime,
    'preference': preference,
    'quietHours': quietHours,
    'eveningReminderEnabled': eveningReminderEnabled,
    'eveningReminderTime': eveningReminderTime,
    'eveningReminderDays': eveningReminderDays,
    'weeklyPlanEnabled': weeklyPlanEnabled,
    'weeklyPlanTime': weeklyPlanTime,
    'newIdeasEnabled': newIdeasEnabled,
    'momentsThisMonth': momentsThisMonth,
  };

  SettingsModel copyWith({
    bool? parentMode,
    bool? quietHours,
    bool? eveningReminderEnabled,
    String? eveningReminderTime,
    String? eveningReminderDays,
    bool? weeklyPlanEnabled,
    String? weeklyPlanTime,
    bool? newIdeasEnabled,
    String? weekdayTime,
    String? weekendTime,
    String? preference,
  }) =>
      SettingsModel(
        parentMode: parentMode ?? this.parentMode,
        bedtimeWeekday: bedtimeWeekday,
        bedtimeWeekend: bedtimeWeekend,
        weekdayTime: weekdayTime ?? this.weekdayTime,
        weekendTime: weekendTime ?? this.weekendTime,
        preference: preference ?? this.preference,
        quietHours: quietHours ?? this.quietHours,
        eveningReminderEnabled: eveningReminderEnabled ?? this.eveningReminderEnabled,
        eveningReminderTime: eveningReminderTime ?? this.eveningReminderTime,
        eveningReminderDays: eveningReminderDays ?? this.eveningReminderDays,
        weeklyPlanEnabled: weeklyPlanEnabled ?? this.weeklyPlanEnabled,
        weeklyPlanTime: weeklyPlanTime ?? this.weeklyPlanTime,
        newIdeasEnabled: newIdeasEnabled ?? this.newIdeasEnabled,
        momentsThisMonth: momentsThisMonth,
      );
}

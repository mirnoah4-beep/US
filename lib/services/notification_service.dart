// TODO: Platform setup required before notifications work:
//
//   Android — android/app/src/main/AndroidManifest.xml:
//     <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//     <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//     Inside <application>:
//       <receiver android:exported="false"
//         android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
//       <receiver android:exported="false"
//         android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
//         <intent-filter>
//           <action android:name="android.intent.action.BOOT_COMPLETED"/>
//           <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
//         </intent-filter>
//       </receiver>
//
//   iOS — ios/Runner/Info.plist: no extra keys needed for local notifications
//   iOS — call requestPermissions() once (done in init() below)

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/push_routing.dart';

// Evening reminder IDs: 100–106 (one per weekday, Ma=100 … Sø=106)
const _kEveningBaseId = 100;
// Weekly planning ID: 200
const _kWeeklyPlanId = 200;

const _kEveningChannelId = 'evening_reminder';
const _kEveningChannelName = 'Kveldsreminder';
const _kWeeklyChannelId = 'weekly_plan';
const _kWeeklyChannelName = 'Ukentlig planlegging';
const _kIdeaChannelId = kChannelIdeas;
const _kIdeaChannelName = 'Idéforespørsler';

/// Localised names for the push channels, passed in by the caller (the
/// service itself is language-agnostic).
class PushChannelNames {
  final String chat;
  final String mediation;
  final String reminders;
  final String general;
  const PushChannelNames({required this.chat, required this.mediation, required this.reminders, required this.general});
  static const norwegian = PushChannelNames(chat: 'Meldinger', mediation: 'Oss mot problemet', reminders: 'Påminnelser', general: 'Varsler');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  PushChannelNames _names = PushChannelNames.norwegian;
  void Function(Map<String, dynamic> data)? _onTap;

  /// [onTap] receives the decoded push data when the user taps a local
  /// notification — the same map a background push tap delivers.
  Future<void> init({PushChannelNames? channelNames, void Function(Map<String, dynamic> data)? onTap}) async {
    if (channelNames != null) _names = channelNames;
    if (onTap != null) _onTap = onTap;
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (r) => _onTap?.call(decodePushPayload(r.payload)),
    );
    // Create Android notification channels (no-op on iOS / older Android)
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    for (final ch in [
      AndroidNotificationChannel(kChannelChat, _names.chat, importance: Importance.high),
      AndroidNotificationChannel(kChannelMediation, _names.mediation, importance: Importance.high),
      AndroidNotificationChannel(kChannelReminders, _names.reminders, importance: Importance.high),
      AndroidNotificationChannel(kChannelGeneral, _names.general, importance: Importance.defaultImportance),
      const AndroidNotificationChannel(_kIdeaChannelId, _kIdeaChannelName, importance: Importance.high),
      const AndroidNotificationChannel(_kEveningChannelId, _kEveningChannelName, importance: Importance.high),
      const AndroidNotificationChannel(_kWeeklyChannelId, _kWeeklyChannelName, importance: Importance.defaultImportance),
    ]) {
      await androidPlugin?.createNotificationChannel(ch);
    }
    _initialized = true;
  }

  String _channelName(String id) => switch (id) {
        kChannelChat => _names.chat,
        kChannelMediation => _names.mediation,
        kChannelReminders => _names.reminders,
        kChannelIdeas => _kIdeaChannelName,
        _ => _names.general,
      };

  /// Show an FCM message as a local heads-up notification (foreground only),
  /// on the channel its `type` belongs to, carrying the data as tap payload.
  Future<void> showFcmMessage(RemoteMessage message) async {
    if (!_initialized) await init();
    final n = message.notification;
    if (n == null) return;
    final channel = pushChannelFor(message.data['type'] as String?);
    await _plugin.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          _channelName(channel),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: encodePushPayload(message.data),
    );
  }

  // Schedule one repeating notification per selected weekday at eveningTime.
  // Flutter day index: Ma=0, Ti=1, On=2, To=3, Fr=4, Lø=5, Sø=6
  // DateTime.weekday:  Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7
  Future<void> scheduleEveningNotifications({
    required List<bool> days,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await cancelEveningNotifications();
    // TODO: uncomment when timezone package is initialized in main.dart:
    //   tz.initializeTimeZones();
    //   tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    //
    // for (var i = 0; i < 7; i++) {
    //   if (!days[i]) continue;
    //   final weekday = i + 1; // Ma(0) → 1(Mon) … Sø(6) → 7(Sun)
    //   await _plugin.zonedSchedule(
    //     _kEveningBaseId + i,
    //     title,
    //     body,
    //     _nextWeekdayTime(weekday, hour, minute),
    //     NotificationDetails(
    //       android: AndroidNotificationDetails(
    //         _kEveningChannelId,
    //         _kEveningChannelName,
    //         importance: Importance.high,
    //         priority: Priority.high,
    //       ),
    //       iOS: const DarwinNotificationDetails(),
    //     ),
    //     matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    //     androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    //   );
    // }
  }

  Future<void> cancelEveningNotifications() async {
    for (var i = 0; i < 7; i++) {
      await _plugin.cancel(_kEveningBaseId + i);
    }
  }

  Future<void> scheduleWeeklyPlanNotification({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await cancelWeeklyPlanNotification();
    // TODO: uncomment when timezone package is initialized:
    //
    // await _plugin.zonedSchedule(
    //   _kWeeklyPlanId,
    //   title,
    //   body,
    //   _nextWeekdayTime(DateTime.sunday, hour, minute),
    //   NotificationDetails(
    //     android: AndroidNotificationDetails(
    //       _kWeeklyChannelId,
    //       _kWeeklyChannelName,
    //       importance: Importance.defaultImportance,
    //       priority: Priority.defaultPriority,
    //     ),
    //     iOS: const DarwinNotificationDetails(),
    //   ),
    //   matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    //   androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    // );
  }

  Future<void> cancelWeeklyPlanNotification() async {
    await _plugin.cancel(_kWeeklyPlanId);
  }

  // tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
  //   final now = tz.TZDateTime.now(tz.local);
  //   var candidate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  //   while (candidate.weekday != weekday || candidate.isBefore(now)) {
  //     candidate = candidate.add(const Duration(days: 1));
  //   }
  //   return candidate;
  // }
}

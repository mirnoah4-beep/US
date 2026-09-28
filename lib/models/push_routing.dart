import 'dart:convert';

/// Pure routing rules for push notifications — no Flutter, no Firebase, so
/// the foreground/background behaviour is unit-testable.
///
/// The server's data payload always carries `type`; everything else is ids.

/// Android notification channel ids (created by NotificationService.init).
const kChannelChat = 'chat';
const kChannelMediation = 'mediation';
const kChannelReminders = 'reminders';
const kChannelIdeas = 'idea_requests';
/// Fallback for background pushes that name no channel (manifest default).
const kChannelGeneral = 'general';

/// Which channel a push of this [type] belongs to.
String pushChannelFor(String? type) => switch (type) {
      'chat_message' => kChannelChat,
      'mediation' => kChannelMediation,
      'idea_request' || 'idea_accepted' => kChannelIdeas,
      'relationship_reminder' || 'plan_something' || 'plan_cancelled' || 'partner_message' => kChannelReminders,
      _ => kChannelGeneral,
    };

/// FCM shows nothing while the app is in the foreground; these types must be
/// rendered by the app itself as a local heads-up notification.
bool showsForegroundNotification(String? type) => type == 'mediation' || type == 'chat_message';

/// Round-trips the push data through the local-notification payload string,
/// so a tap on a foreground notification reaches the same handler as a tap
/// on a background push. Only string values survive (ids and type).
String encodePushPayload(Map<String, dynamic> data) =>
    jsonEncode({for (final e in data.entries) if (e.value is String) e.key: e.value});

Map<String, dynamic> decodePushPayload(String? payload) {
  if (payload == null || payload.isEmpty) return const {};
  try {
    final v = jsonDecode(payload);
    if (v is Map) return {for (final e in v.entries) e.key.toString(): e.value};
  } catch (_) {}
  return const {};
}

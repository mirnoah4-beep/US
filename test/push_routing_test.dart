// Foreground/background push routing: which types the app must render
// itself, which Android channel each lands on, and the tap payload
// round-trip that makes a foreground tap identical to a background tap.
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/l10n/strings.dart';
import 'package:us_app/models/push_routing.dart';

void main() {
  test('only chat and mediation pushes are rendered by the app in the foreground', () {
    expect(showsForegroundNotification('mediation'), isTrue);
    expect(showsForegroundNotification('chat_message'), isTrue);
    for (final t in ['plan_cancelled', 'idea_request', 'idea_accepted', 'relationship_reminder', 'plan_something', 'partner_message', null, '']) {
      expect(showsForegroundNotification(t), isFalse, reason: '$t');
    }
  });

  test('every push type maps to a named channel; unknown types fall back to general', () {
    expect(pushChannelFor('chat_message'), kChannelChat);
    expect(pushChannelFor('mediation'), kChannelMediation);
    expect(pushChannelFor('idea_request'), kChannelIdeas);
    expect(pushChannelFor('idea_accepted'), kChannelIdeas);
    for (final t in ['relationship_reminder', 'plan_something', 'plan_cancelled', 'partner_message']) {
      expect(pushChannelFor(t), kChannelReminders, reason: t);
    }
    expect(pushChannelFor('something_new'), kChannelGeneral);
    expect(pushChannelFor(null), kChannelGeneral);
    // The manifest default for background pushes is the general channel.
    expect(kChannelGeneral, 'general');
  });

  test('tap payload round-trips the ids and type; non-string values are dropped; garbage is tolerated', () {
    final data = {'type': 'mediation', 'coupleId': 'c1', 'mediationId': 'm1', 'kind': 'invite', 'count': 3};
    final decoded = decodePushPayload(encodePushPayload(data));
    expect(decoded, {'type': 'mediation', 'coupleId': 'c1', 'mediationId': 'm1', 'kind': 'invite'});
    expect(decodePushPayload(null), isEmpty);
    expect(decodePushPayload(''), isEmpty);
    expect(decodePushPayload('not json'), isEmpty);
    expect(decodePushPayload('[1,2]'), isEmpty);
  });

  test('channel names exist in NO and EN', () {
    const no = AppStrings(isNorwegian: true);
    const en = AppStrings(isNorwegian: false);
    expect(no.notifChannelChat, 'Meldinger'); expect(en.notifChannelChat, 'Messages');
    expect(no.notifChannelMediation, 'Oss mot problemet'); expect(en.notifChannelMediation, 'Us vs. the problem');
    expect(no.notifChannelReminders, 'Påminnelser'); expect(en.notifChannelReminders, 'Reminders');
    expect(no.notifChannelGeneral, 'Varsler'); expect(en.notifChannelGeneral, 'Notifications');
  });
}

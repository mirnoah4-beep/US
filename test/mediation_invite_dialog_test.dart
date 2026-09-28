// The auto-opened mediation dialog: keyed once per talk + actionable state,
// never for the initiator's own draft, never when nothing awaits the user;
// renders the NO/EN copy and quotes only the neutral invitation.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/l10n/strings.dart';
import 'package:us_app/models/mediation.dart';
import 'package:us_app/widgets/mediation_invite_dialog.dart';

Mediation at(String status, {int round = 0, int revision = 1, Map<String, dynamic>? answered, Map<String, dynamic>? accepts}) =>
    Mediation.fromMap('m1', {
      'category': 'chores', 'initiatorUid': 'A', 'partnerUid': 'B', 'status': status, 'round': round,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 28)),
      'invitation': {'texts': {'no': 'Hei Liv – vil du snakke om husarbeid?', 'en': 'Hi Liv – shall we talk about chores?'}, 'rephrases': 0},
      'rounds': {'$round': {'texts': {}, 'answered': answered ?? {}, 'feedback': {}}},
      'agreement': {'revision': revision, 'hash': 'h', 'texts': {}, 'accepts': accepts ?? {}},
    })!;

void main() {
  test('key exists only when the talk awaits the user; the initiator\'s own draft never opens a dialog', () {
    expect(mediationDialogKey(at('invited'), 'B'), 'm1:invited:0:1');
    expect(mediationDialogKey(at('invited'), 'A'), isNull);
    expect(mediationDialogKey(at('invitationDraft'), 'A'), isNull, reason: 'initiator is writing it');
    expect(mediationDialogKey(at('drafting'), 'B'), isNull);
    expect(mediationDialogKey(at('answering'), 'B'), 'm1:answering:0:1');
    expect(mediationDialogKey(at('round', round: 1), 'A'), 'm1:round:1:1');
    expect(mediationDialogKey(at('round', round: 1, answered: {'A': true}), 'A'), isNull, reason: 'already answered');
    expect(mediationDialogKey(at('agreement'), 'B'), 'm1:agreement:0:1');
    expect(mediationDialogKey(at('agreement', accepts: {'B': {'hash': 'h'}}), 'B'), isNull);
    expect(mediationDialogKey(at('active'), 'B'), isNull);
    expect(mediationDialogKey(at('invited'), ''), isNull);
  });

  test('a genuinely new step yields a new key; the same step does not', () {
    expect(mediationDialogKey(at('round', round: 1), 'B'), isNot(equals(mediationDialogKey(at('round', round: 2), 'B'))));
    expect(mediationDialogKey(at('round', round: 1), 'B'), mediationDialogKey(at('round', round: 1), 'B'));
    expect(mediationDialogKey(at('agreement', revision: 1), 'B'), isNot(equals(mediationDialogKey(at('agreement', revision: 2), 'B'))));
  });

  testWidgets('dialog shows the copy, quotes only the neutral invitation, and "Not now" closes it', (tester) async {
    const s = AppStrings(isNorwegian: true);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => TextButton(
        onPressed: () => showDialog<void>(
          context: ctx,
          builder: (_) => const MediationInviteDialog(s: s, partnerName: 'Liv', invitation: 'Hei – vil du snakke om husarbeid?', mediationId: 'm1'),
        ),
        child: const Text('open'),
      )),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('💬 Liv vil løse noe sammen'), findsOneWidget);
    expect(find.textContaining('Det er noe Liv gjerne vil snakke med deg om'), findsOneWidget);
    expect(find.text('Hei – vil du snakke om husarbeid?'), findsOneWidget);
    expect(find.text('Se samtalen'), findsOneWidget);
    await tester.tap(find.text('Ikke nå'));
    await tester.pumpAndSettle();
    expect(find.text('Se samtalen'), findsNothing);
  });

  test('EN copy', () {
    const en = AppStrings(isNorwegian: false);
    expect(en.medInviteDialogTitle('Liv'), 'Liv wants to work something out');
    expect(en.medInviteDialogBody('Liv'), "There's something Liv would like to talk through with you. Open it when you're ready.");
    expect(en.medInviteDialogNotNow, 'Not now');
    expect(en.medInviteDialogOpen, 'Open conversation');
  });
}

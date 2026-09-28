// Client model of "Oss mot problemet" (asymmetric flow): tolerant parsing,
// own-language pick, rounds + hidden feedback, current-hash acceptance,
// draft kinds, status helpers, and NO/EN strings.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/l10n/strings.dart';
import 'package:us_app/models/mediation.dart';

Map<String, dynamic> doc({String status = 'round', int round = 1, String hash = 'h2', Map<String, dynamic>? accepts, Map<String, dynamic>? answered, Map<String, dynamic>? feedback}) => {
      'category': 'chores', 'initiatorUid': 'A', 'partnerUid': 'B', 'status': status, 'timing': 'tonight', 'round': round,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 28)),
      'invitation': {'texts': {'no': 'Hei Liv', 'en': 'Hi Liv'}, 'rephrases': 2, 'langs': ['no', 'en']},
      'rounds': {
        '1': {
          'texts': {
            'no': {'sameTeam': 'Samme lag', 'different': 'Ulikt', 'needs': {'A': 'A trenger', 'B': 'B trenger'}, 'proposal': 'Prøv'},
            'en': {'sameTeam': 'Same team', 'different': 'Different', 'needs': {'A': 'A needs', 'B': 'B needs'}, 'proposal': 'Try'},
          },
          'answered': answered ?? {'A': true},
          'feedback': feedback ?? {},
        },
        '2': {
          'texts': {'no': {'sameTeam': 'Samme lag', 'different': 'Ulikt', 'needs': {'A': 'a', 'B': 'b'}, 'proposal': 'Prøv v2'}},
          'whatChanged': {'no': 'Justert'},
          'answered': {}, 'feedback': {},
        },
      },
      'agreement': {
        'revision': 2, 'hash': hash,
        'texts': {'no': {'shared': 'Vi prøver', 'perPartner': {'A': 'A gjør', 'B': 'B gjør'}}},
        'accepts': accepts ?? {'A': {'hash': 'h2', 'at': Timestamp.now()}, 'B': {'hash': 'h1', 'at': Timestamp.now()}},
      },
    };

void main() {
  test('parses a round doc; each partner reads their own language; falls back when missing', () {
    final m = Mediation.fromMap('m1', doc())!;
    expect(m.status, 'round');
    expect(m.isOpen, isTrue);
    expect(m.round, 1);
    expect(m.invitationFor('en'), 'Hi Liv');
    expect(m.rephrases, 2);
    expect(m.canRephrase, isTrue);
    expect(m.currentRound!.textsFor('en')!.needs['B'], 'B needs');
    expect(m.currentRound!.textsFor('no')!.sameTeam, 'Samme lag');
    expect(m.rounds[2]!.textsFor('en')!.proposal, 'Prøv v2', reason: 'only NO exists → fallback');
    expect(m.rounds[2]!.whatChangedFor('en'), 'Justert');
    expect(m.agreementFor('en')!.shared, 'Vi prøver', reason: 'only NO exists → fallback');
    expect(m.otherUid('A'), 'B');
    expect(m.isInitiator('A'), isTrue);
    expect(m.isInitiator('B'), isFalse);
  });

  test('feedback visibility: answered flags are visible, choices only once both answered', () {
    final one = Mediation.fromMap('m', doc())!.currentRound!;
    expect(one.hasAnswered('A'), isTrue);
    expect(one.hasAnswered('B'), isFalse);
    expect(one.feedback, isEmpty, reason: 'nothing to show before both answered');
    final both = Mediation.fromMap('m', doc(answered: {'A': true, 'B': true}, feedback: {'A': 'almost', 'B': 'happy'}))!.currentRound!;
    expect(both.feedback, {'A': 'almost', 'B': 'happy'});
  });

  test('acceptance counts only for the CURRENT hash', () {
    final m = Mediation.fromMap('m1', doc(status: 'agreement'))!;
    expect(m.hasAccepted('A'), isTrue);
    expect(m.hasAccepted('B'), isFalse, reason: 'B accepted an older revision');
    expect(m.agreementRevision, 2);
    expect(m.agreementHash, 'h2');
    expect(m.hasAgreement, isTrue);
  });

  test('status helpers and tolerant parsing', () {
    expect(Mediation.fromMap('x', doc(status: 'active'))!.isActive, isTrue);
    expect(Mediation.fromMap('x', doc(status: 'agreement'))!.isOpen, isTrue);
    expect(Mediation.fromMap('x', doc(status: 'unresolved'))!.isUnresolved, isTrue);
    expect(Mediation.fromMap('x', doc(status: 'unresolved'))!.isOpen, isFalse);
    expect(Mediation.fromMap('x', doc(status: 'paused'))!.isOpen, isFalse);
    expect(Mediation.fromMap('x', doc(status: 'expired'))!.isOpen, isFalse);
    expect(Mediation.fromMap('x', doc(round: 3))!.isLastRound, isTrue);
    expect(Mediation.fromMap('x', null), isNull);
    expect(Mediation.fromMap('x', {'status': 'invited'}), isNull, reason: 'members required');
    final minimal = Mediation.fromMap('x', {'initiatorUid': 'A', 'partnerUid': 'B'})!;
    expect(minimal.status, 'drafting');
    expect(minimal.rounds, isEmpty);
    expect(minimal.currentRound, isNull);
    expect(minimal.invitationFor('no'), isNull);
    expect(minimal.closingNoteFor('no'), isNull);
    expect(minimal.hasAgreement, isFalse);
    final closed = Mediation.fromMap('x', {'initiatorUid': 'A', 'partnerUid': 'B', 'status': 'unresolved', 'closingNote': {'no': 'Greit', 'en': 'Fine'}})!;
    expect(closed.closingNoteFor('en'), 'Fine');
  });

  test('awaitsAction: who the talk is waiting on, per status', () {
    Mediation at(String status, {Map<String, dynamic>? answered, Map<String, dynamic>? accepts}) =>
        Mediation.fromMap('m', doc(status: status, answered: answered, accepts: accepts))!;
    expect(at('drafting').awaitsAction('A'), isFalse, reason: 'still writing, nothing pending');
    expect(at('invitationDraft').awaitsAction('A'), isTrue, reason: 'initiator must approve');
    expect(at('invitationDraft').awaitsAction('B'), isFalse, reason: 'partner knows nothing yet');
    expect(at('invited').awaitsAction('B'), isTrue);
    expect(at('invited').awaitsAction('A'), isFalse);
    expect(at('answering').awaitsAction('B'), isTrue);
    expect(at('round').awaitsAction('A'), isFalse, reason: 'A already answered round 1');
    expect(at('round').awaitsAction('B'), isTrue);
    expect(at('round', answered: {'A': true, 'B': true}).awaitsAction('B'), isFalse);
    expect(at('agreement').awaitsAction('A'), isFalse, reason: 'A accepted the current hash');
    expect(at('agreement').awaitsAction('B'), isTrue, reason: 'B accepted an older revision');
    for (final st in ['active', 'unresolved', 'paused', 'closed', 'expired', 'generationFailed']) {
      expect(at(st).awaitsAction('A'), isFalse, reason: st);
      expect(at(st).awaitsAction('B'), isFalse, reason: st);
    }
    expect(const AppStrings(isNorwegian: true).medWaitingOnYou('Liv'), 'Liv venter på deg');
    expect(const AppStrings(isNorwegian: false).medWaitingOnYou('Liv'), 'Liv is waiting for you');
  });

  test('draft kinds: parsing, completeness and the exact keys written per kind', () {
    expect(MediationDraft.fromMap(null).kind, '');
    final t = MediationDraft.fromMap({'kind': 'topic', 'topic': 'a', 'wish': 'b', 'draft': true});
    expect(t.topicComplete, isTrue);
    expect(t.locked, isFalse);
    expect(t.toMap(), {'kind': 'topic', 'topic': 'a', 'wish': 'b'});
    final a = MediationDraft.fromMap({'kind': 'answer', 'view': 'v', 'need': '', 'draft': false});
    expect(a.answerComplete, isFalse);
    expect(a.locked, isTrue);
    expect(a.toMap().keys, ['kind', 'view', 'need']);
    const f = MediationDraft(kind: 'feedback', round: 2, feedback: 'almost', addition: 'x');
    expect(f.feedbackComplete, isTrue);
    expect(f.toMap(), {'kind': 'feedback', 'round': 2, 'feedback': 'almost', 'addition': 'x'});
    expect(const MediationDraft(kind: 'feedback', feedback: 'no').feedbackComplete, isFalse);
    expect(const MediationDraft().toMap(), isEmpty);
  });

  test('every mediation string exists in NO and EN and differs (except shared labels)', () {
    const no = AppStrings(isNorwegian: true);
    const en = AppStrings(isNorwegian: false);
    final pairs = <String, (String, String)>{
      'title': (no.medTitle, en.medTitle), 'intro': (no.medIntro, en.medIntro),
      'topicQ': (no.medTopicQ, en.medTopicQ), 'wishQ': (no.medWishQ, en.medWishQ), 'topicPrivate': (no.medTopicPrivate, en.medTopicPrivate),
      'makeInvitation': (no.medMakeInvitation, en.medMakeInvitation), 'onlyThis': (no.medInvitationOnlyThis('Liv'), en.medInvitationOnlyThis('Liv')),
      'sendTo': (no.medSendTo('Liv'), en.medSendTo('Liv')), 'rephrase': (no.medRephrase(1, 3), en.medRephrase(1, 3)),
      'viewQ': (no.medViewQ, en.medViewQ), 'needQ': (no.medNeedQ, en.medNeedQ), 'submit': (no.medSubmit, en.medSubmit),
      'sameTeam': (no.medSameTeam, en.medSameTeam), 'different': (no.medDifferent, en.medDifferent),
      'proposal': (no.medProposal, en.medProposal), 'whatChanged': (no.medWhatChanged, en.medWhatChanged),
      'happy': (no.medHappy, en.medHappy), 'almost': (no.medAlmost, en.medAlmost), 'additionQ': (no.medAdditionQ, en.medAdditionQ),
      'additionPrivate': (no.medAdditionPrivate, en.medAdditionPrivate), 'roundOf': (no.medRoundOf(2, 3), en.medRoundOf(2, 3)),
      'lastRound': (no.medLastRoundHint, en.medLastRoundHint), 'unresolved': (no.medUnresolvedTitle, en.medUnresolvedTitle),
      'hold': (no.medHoldToAccept, en.medHoldToAccept), 'deal': (no.medDealDone, en.medDealDone),
      'paused': (no.medPaused, en.medPaused), 'safetyTitle': (no.medSafetyTitle, en.medSafetyTitle),
      'safetyBody': (no.medSafetyBody, en.medSafetyBody), 'helpline': (no.medSafetyHelpline, en.medSafetyHelpline),
      'needs': (no.medNeeds('Liv'), en.medNeeds('Liv')), 'waiting': (no.medWaitingForPartner('Liv'), en.medWaitingForPartner('Liv')),
      'waitingAnswer': (no.medWaitingForAnswer('Liv'), en.medWaitingForAnswer('Liv')), 'startNew': (no.medStartNew, en.medStartNew),
      'planEntry': (no.medPlanEntryLine, en.medPlanEntryLine),
    };
    pairs.forEach((k, v) {
      expect(v.$1.trim(), isNotEmpty, reason: '$k NO');
      expect(v.$2.trim(), isNotEmpty, reason: '$k EN');
      expect(v.$1, isNot(equals(v.$2)), reason: '$k not translated');
    });
    for (final c in kMediationCategories) {
      expect(no.medCategory(c), isNotEmpty); expect(en.medCategory(c), isNotEmpty);
    }
    for (final st in ['drafting', 'invitationDraft', 'invited', 'answering', 'round', 'generationFailed', 'agreement', 'active', 'unresolved', 'paused', 'closed', 'expired']) {
      expect(no.medStatusLabel(st), isNot(equals(st)), reason: 'NO label for $st');
      expect(en.medStatusLabel(st), isNot(equals(st)), reason: 'EN label for $st');
    }
    expect(no.medSafetyHelpline, contains('116 006'));
    expect(no.medSafetyEmergency, contains('112'));
    expect(no.medSafetyWeb, contains('dinutvei.no'));
  });
}

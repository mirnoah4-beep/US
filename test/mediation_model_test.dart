// Client model of "Oss mot problemet": tolerant parsing, own-language pick,
// current-hash acceptance, status helpers, and NO/EN strings.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/l10n/strings.dart';
import 'package:us_app/models/mediation.dart';

Map<String, dynamic> doc({String status = 'summary', String hash = 'h2', Map<String, dynamic>? accepts}) => {
      'category': 'chores', 'starterUid': 'A', 'partnerUid': 'B', 'status': status, 'timing': 'tonight',
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 28)),
      'submitted': {'A': true, 'B': true},
      'summary': {
        'langs': ['no', 'en'],
        'texts': {
          'no': {'sameTeam': 'Samme lag', 'different': 'Ulikt', 'needs': {'A': 'A trenger', 'B': 'B trenger'}, 'idea': 'Prøv'},
          'en': {'sameTeam': 'Same team', 'different': 'Different', 'needs': {'A': 'A needs', 'B': 'B needs'}, 'idea': 'Try'},
        },
        'needsConfirmed': {'A': 'confirmed'},
      },
      'agreement': {
        'revision': 2, 'hash': hash,
        'texts': {'no': {'shared': 'Vi prøver', 'perPartner': {'A': 'A gjør', 'B': 'B gjør'}}},
        'accepts': accepts ?? {'A': {'hash': 'h2', 'at': Timestamp.now()}, 'B': {'hash': 'h1', 'at': Timestamp.now()}},
      },
    };

void main() {
  test('parses a summary doc; each partner reads their own language; falls back when missing', () {
    final m = Mediation.fromMap('m1', doc())!;
    expect(m.status, 'summary');
    expect(m.isOpen, isTrue);
    expect(m.hasSubmitted('A') && m.hasSubmitted('B'), isTrue);
    expect(m.summaryFor('en')!.needs['B'], 'B needs');
    expect(m.summaryFor('no')!.sameTeam, 'Samme lag');
    expect(m.agreementFor('en')!.shared, 'Vi prøver', reason: 'only NO exists → fallback');
    expect(m.needsConfirmed, {'A': 'confirmed'});
    expect(m.otherUid('A'), 'B');
    expect(m.isStarter('A'), isTrue);
  });

  test('acceptance counts only for the CURRENT hash', () {
    final m = Mediation.fromMap('m1', doc())!;
    expect(m.hasAccepted('A'), isTrue);
    expect(m.hasAccepted('B'), isFalse, reason: 'B accepted an older revision');
    expect(m.agreementRevision, 2);
    expect(m.agreementHash, 'h2');
  });

  test('status helpers and tolerant parsing', () {
    expect(Mediation.fromMap('x', doc(status: 'active'))!.isActive, isTrue);
    expect(Mediation.fromMap('x', doc(status: 'paused'))!.isOpen, isFalse);
    expect(Mediation.fromMap('x', doc(status: 'expired'))!.isOpen, isFalse);
    expect(Mediation.fromMap('x', null), isNull);
    expect(Mediation.fromMap('x', {'status': 'invited'}), isNull, reason: 'members required');
    final minimal = Mediation.fromMap('x', {'starterUid': 'A', 'partnerUid': 'B'})!;
    expect(minimal.status, 'invited');
    expect(minimal.summaryByLang, isEmpty);
    expect(minimal.submittedBy, isEmpty);
    expect(minimal.hasSummary, isFalse);
  });

  test('draft parsing and completeness', () {
    expect(MediationDraft.fromMap(null).isComplete, isFalse);
    final d = MediationDraft.fromMap({'whatHappened': 'a', 'whatINeed': 'b', 'whatICanDo': 'c', 'draft': false});
    expect(d.isComplete, isTrue);
    expect(d.locked, isTrue);
    expect(MediationDraft.fromMap({'whatHappened': 'a', 'draft': true}).locked, isFalse);
  });

  test('every mediation string exists in NO and EN and differs (except shared labels)', () {
    const no = AppStrings(isNorwegian: true);
    const en = AppStrings(isNorwegian: false);
    final pairs = <String, (String, String)>{
      'title': (no.medTitle, en.medTitle), 'intro': (no.medIntro, en.medIntro), 'q1': (no.medQ1, en.medQ1),
      'q2': (no.medQ2, en.medQ2), 'q3': (no.medQ3, en.medQ3), 'submit': (no.medSubmit, en.medSubmit),
      'sameTeam': (no.medSameTeam, en.medSameTeam), 'different': (no.medDifferent, en.medDifferent),
      'idea': (no.medIdea, en.medIdea), 'hold': (no.medHoldToAccept, en.medHoldToAccept), 'deal': (no.medDealDone, en.medDealDone),
      'paused': (no.medPaused, en.medPaused), 'safetyTitle': (no.medSafetyTitle, en.medSafetyTitle),
      'safetyBody': (no.medSafetyBody, en.medSafetyBody), 'helpline': (no.medSafetyHelpline, en.medSafetyHelpline),
      'needs': (no.medNeeds('Liv'), en.medNeeds('Liv')), 'invite': (no.medInvite('Liv'), en.medInvite('Liv')),
      'waiting': (no.medWaitingForPartner('Liv'), en.medWaitingForPartner('Liv')),
    };
    pairs.forEach((k, v) {
      expect(v.$1.trim(), isNotEmpty, reason: '$k NO');
      expect(v.$2.trim(), isNotEmpty, reason: '$k EN');
      expect(v.$1, isNot(equals(v.$2)), reason: '$k not translated');
    });
    for (final c in kMediationCategories) {
      expect(no.medCategory(c), isNotEmpty); expect(en.medCategory(c), isNotEmpty);
    }
    expect(no.medSafetyHelpline, contains('116 006'));
    expect(no.medSafetyEmergency, contains('112'));
    expect(no.medSafetyWeb, contains('dinutvei.no'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regression guards for the 2026-09-30 couple-link incident:
// 1) a couple stream error must NEVER clear users/{uid}.coupleId;
// 2) password-provider users are routed by FirebaseAuth.emailVerified, not
//    only the legacy Firestore needsEmailVerification flag;
// 3) an empty pointer gets one server-authoritative recovery attempt.
void main() {
  final mainSrc = File('lib/main.dart').readAsStringSync();
  final serviceSrc =
      File('lib/services/firestore_service.dart').readAsStringSync();

  test('couple stream error path never clears coupleId', () {
    final errorAt = mainSrc.indexOf('if (snap.hasError)');
    final dataAt = mainSrc.indexOf('final couple = snap.data', errorAt);
    expect(errorAt, greaterThanOrEqualTo(0));
    expect(dataAt, greaterThan(errorAt));

    final errorBranch = mainSrc.substring(errorAt, dataAt);
    expect(errorBranch.contains("'coupleId': null"), isFalse,
        reason:
            'permission/network errors are not proof that the couple is stale');
  });

  test('only successful missing-couple branch may clear stale pointer', () {
    final commentAt =
        mainSrc.indexOf('Couple document missing — stale coupleId on user doc.');
    expect(commentAt, greaterThanOrEqualTo(0));
    final tail = mainSrc.substring(commentAt);
    expect(tail.contains("update({'coupleId': null})"), isTrue);
  });

  test('AuthGate covers legacy unverified password accounts', () {
    expect(mainSrc.contains("p.providerId == 'password'"), isTrue);
    expect(mainSrc.contains('!currentUser.emailVerified'), isTrue);
    expect(mainSrc.contains('userData.needsEmailVerification'), isTrue);
  });

  test('solo route attempts server-authoritative couple-link recovery', () {
    expect(mainSrc.contains('_SoloRecoveryGate(uid: user.uid)'), isTrue);
    expect(serviceSrc.contains("httpsCallable('recoverCoupleLink')"), isTrue);
  });
}

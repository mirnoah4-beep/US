// Precise server-reason → client-reason mapping for pairing. Pure.

import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/models/join_result.dart';

void main() {
  test('every server reason maps to its own client reason', () {
    expect(mapPairingError(code: 'not-found', details: {'reason': 'invalid-code'}), JoinFailureReason.invalidCode);
    expect(mapPairingError(code: 'failed-precondition', details: {'reason': 'invite-expired'}), JoinFailureReason.inviteExpired);
    expect(mapPairingError(code: 'failed-precondition', details: {'reason': 'own-invite'}), JoinFailureReason.ownInvite);
    expect(mapPairingError(code: 'failed-precondition', details: {'reason': 'already-paired'}), JoinFailureReason.selfAlreadyPartnered);
    expect(mapPairingError(code: 'failed-precondition', details: {'reason': 'inviter-already-paired'}), JoinFailureReason.inviterAlreadyPartnered);
  });

  test('permission-denied is NOT guessed as "already partnered" any more', () {
    expect(mapPairingError(code: 'permission-denied', details: null), JoinFailureReason.networkError);
    expect(mapPairingError(code: 'permission-denied', details: {}), JoinFailureReason.networkError);
  });

  test('unknown / malformed details fall back to a network error', () {
    expect(mapPairingError(code: 'internal', details: {'reason': 'something-new'}), JoinFailureReason.networkError);
    expect(mapPairingError(code: 'unavailable', details: 'oops'), JoinFailureReason.networkError);
    expect(mapPairingError(code: null, details: null), JoinFailureReason.networkError);
  });
}

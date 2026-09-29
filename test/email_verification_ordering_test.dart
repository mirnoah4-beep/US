import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Regression guard for the M2 ordering invariant in _checkVerification():
//   Auth verified -> force a fresh ID token (getIdToken(true)) -> ONLY then
//   clear needsEmailVerification and route into couple-scoped access.
//
// A full widget test would require mocking FirebaseAuth.instance.currentUser,
// User.reload / getIdToken and the static FirestoreService.updateUser, which
// the current harness cannot do without refactoring the screen for dependency
// injection (out of scope). This source-level check pins the exact ordering
// and the fail-closed behaviour instead.
void main() {
  final src = File('lib/screens/email_verification_screen.dart').readAsStringSync();

  test('token is force-refreshed before the routing flag is cleared', () {
    final refreshAt = src.indexOf('getIdToken(true)');
    final clearAt = src.indexOf("{'needsEmailVerification': false}");
    expect(refreshAt, greaterThanOrEqualTo(0), reason: 'must force-refresh the ID token');
    expect(clearAt, greaterThanOrEqualTo(0), reason: 'must clear the routing flag');
    expect(refreshAt, lessThan(clearAt),
        reason: 'getIdToken(true) must run BEFORE needsEmailVerification is cleared');
  });

  test('a failed token refresh returns early without clearing the flag', () {
    // Between the refresh call and the flag clear there must be an early
    // `return;` (the catch path), so a refresh failure never routes forward.
    final refreshAt = src.indexOf('getIdToken(true)');
    final clearAt = src.indexOf("{'needsEmailVerification': false}");
    final between = src.substring(refreshAt, clearAt);
    expect(between.contains('return;'), isTrue,
        reason: 'refresh failure must return before clearing the flag');
  });
}

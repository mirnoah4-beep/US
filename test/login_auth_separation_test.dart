// Source-level guards for the email-auth logic in login_screen.dart. A full
// behavioural test would require mocking FirebaseAuth.instance (signIn /
// create / sendPasswordResetEmail), which the current harness cannot do
// without introducing a new mocking package — out of scope for this task.
// These assertions pin the security-relevant invariants instead.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/screens/login_screen.dart').readAsStringSync();
  int count(String needle) => needle.allMatches(src).length;

  test('login and account creation are separate — login never falls back to create', () {
    // Each auth call (the invocation, not mentions in comments) appears exactly
    // once, in its own dedicated action.
    expect(count('signInWithEmailAndPassword('), 1,
        reason: 'sign-in is invoked only in _login');
    expect(count('createUserWithEmailAndPassword('), 1,
        reason: 'account creation is invoked only in _create');
    // The old combined button/label is gone.
    expect(src.contains('Logg inn / Opprett konto'), isFalse,
        reason: 'the combined login/create button was removed');
  });

  test('create flow sends verification and preserves the M2 needsEmailVerification routing', () {
    expect(src.contains('sendEmailVerification()'), isTrue);
    expect(src.contains('needsEmailVerification: true'), isTrue);
  });

  test('forgot-password uses a reset email with neutral, non-disclosing copy', () {
    expect(src.contains('sendPasswordResetEmail'), isTrue);
    expect(
      src.contains('Hvis det finnes en konto med denne e-posten, har vi sendt en lenke for å tilbakestille passordet.'),
      isTrue,
    );
  });

  test('auth error copy is generic and does not disclose whether an email exists', () {
    expect(src.contains('Feil e-post eller passord.'), isTrue);
    expect(
      src.contains('Kunne ikke opprette konto. Sjekk opplysningene eller prøv å logge inn.'),
      isTrue,
    );
  });

  test('email sheet owns its TextEditingControllers for the sheet lifetime', () {
    final loginStateStart = src.indexOf('class _LoginScreenState');
    final sheetStateStart = src.indexOf('class _EmailAuthSheetState');
    expect(loginStateStart, greaterThanOrEqualTo(0));
    expect(sheetStateStart, greaterThan(loginStateStart));

    final parentSection = src.substring(loginStateStart, sheetStateStart);
    final sheetSection = src.substring(sheetStateStart);

    expect(parentSection.contains('final _emailController = TextEditingController();'), isFalse);
    expect(parentSection.contains('final _passwordController = TextEditingController();'), isFalse);
    expect(parentSection.contains('emailController:'), isFalse);
    expect(parentSection.contains('passwordController:'), isFalse);

    expect(sheetSection.contains('final _emailController = TextEditingController();'), isTrue);
    expect(sheetSection.contains('final _passwordController = TextEditingController();'), isTrue);
    expect(sheetSection.contains('_emailController.dispose();'), isTrue);
    expect(sheetSection.contains('_passwordController.dispose();'), isTrue);
  });

  test('async auth error paths guard setState after auth-state disposal', () {
    expect(count('if (!mounted) return;'), greaterThanOrEqualTo(4));
  });
}

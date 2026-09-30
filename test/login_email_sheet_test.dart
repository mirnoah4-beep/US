// Widget tests for the redesigned email-auth bottom sheet. These exercise the
// Firebase-free paths only (mode switching, client-side validation copy) —
// the auth calls themselves (signIn / create / reset) need a real FirebaseAuth
// instance, which the current harness cannot mock without a new package; the
// auth-flow separation is pinned by login_auth_separation_test.dart instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/screens/login_screen.dart';

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  await tester.tap(find.text('Logg inn med e-post'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sheet opens in login mode', (tester) async {
    await _openSheet(tester);
    expect(find.text('Velkommen tilbake'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('emailAuthPrimary')),
        matching: find.text('Logg inn'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('switching modes updates the sheet in place (no close/reopen)',
      (tester) async {
    await _openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('emailAuthSwitch')));
    await tester.pumpAndSettle();
    // Create mode: header + primary button both read "Opprett konto".
    expect(find.text('Opprett konto'), findsWidgets);
    expect(find.text('Bare noen få steg, så er dere i gang.'), findsOneWidget);
    expect(find.text('Minst 6 tegn'), findsOneWidget);
    // Forgot-password is only shown in login mode.
    expect(find.byKey(const ValueKey('emailAuthForgot')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('emailAuthSwitch')));
    await tester.pumpAndSettle();
    expect(find.text('Velkommen tilbake'), findsOneWidget);
    expect(find.byKey(const ValueKey('emailAuthForgot')), findsOneWidget);
  });

  testWidgets('login with empty fields shows validation and keeps the sheet open',
      (tester) async {
    await _openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('emailAuthPrimary')));
    await tester.pump();
    expect(find.text('Fyll inn e-post og passord.'), findsOneWidget);
    expect(find.text('Velkommen tilbake'), findsOneWidget); // still open
  });

  testWidgets('forgot-password with empty email asks for an email and does not show the sent-copy',
      (tester) async {
    await _openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('emailAuthForgot')));
    await tester.pump();
    expect(find.text('Skriv inn e-postadressen din først.'), findsOneWidget);
    expect(find.textContaining('har vi sendt en lenke'), findsNothing);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await _openSheet(tester);
    // Default hidden → the "show" (visibility_off) icon is present.
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();
    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });
}

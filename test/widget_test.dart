// App boot smoke test.
//
// The previous version pumped `UsApp`, whose first frame is `AuthGate` →
// `FirebaseAuth.instance` — impossible without a Firebase app — and asserted
// a string that no longer exists anywhere in lib/. It could never pass.
//
// The real boot path renders `SplashScreen` first, while auth and Firestore
// resolve. That widget is pure Flutter, so the smoke test exercises the actual
// first frame the user sees without needing Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_app/screens/splash_screen.dart';

void main() {
  testWidgets('App boot renders the splash frame', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    // The US wordmark and the boot spinner — the two things on the first frame.
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/logo/us_wordmark.png');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Brand ground and burgundy accent, as a guard against theme regressions.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFFFAF7F4));
    final spinner = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
    expect(spinner.color, const Color(0xFF8B2E42));
  });
}

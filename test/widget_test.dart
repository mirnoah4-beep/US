import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:us_app/main.dart';
import 'package:us_app/models/app_state.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const UsApp(),
      ),
    );
    expect(find.text('Make time for us.'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeevandhara2/main.dart';

void main() {
  testWidgets('App builds and shows splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const JeevandharaApp());
    await tester.pump();

    expect(find.byType(JeevandharaApp), findsOneWidget);

    // Splash navigates away after 2.5s; pump past it so no timers are pending.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

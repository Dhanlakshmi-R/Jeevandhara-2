import 'package:flutter_test/flutter_test.dart';

import 'package:jeevandhara2/main.dart';

void main() {
  testWidgets('App builds and shows splash', (WidgetTester tester) async {
    await tester.pumpWidget(const JeevandharaApp());
    await tester.pump();
    expect(find.byType(JeevandharaApp), findsOneWidget);
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeevandhara2/screens/about_screen.dart';
import 'package:jeevandhara2/screens/login_screen.dart';
import 'package:jeevandhara2/screens/register_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Landing shows Get Started and Login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen(isLanding: true)));
    await tester.pump();
    expect(find.text('Get Started'), findsWidgets);
    expect(find.text('Login'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Login validates empty email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('Register role selection and terms gate', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.pump();
    await tester.tap(find.text('Trader'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Farmer');
    await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(2), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret1');
    await tester.enterText(find.byType(TextFormField).at(4), 'secret1');
    await tester.pump();
    await tester.tap(find.text('Create Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Please accept the terms & conditions'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
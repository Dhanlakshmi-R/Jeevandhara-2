import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeevandhara2/app/destinations.dart';
import 'package:jeevandhara2/app/shell/app_shell.dart';
import 'package:jeevandhara2/app/shell/command_palette.dart';
import 'package:jeevandhara2/app/shell/sidebar.dart';
import 'package:jeevandhara2/app/shell/top_bar.dart';
import 'package:jeevandhara2/chat/screens/chat_screen.dart';
import 'package:jeevandhara2/screens/trader_dashboard_screen.dart';
import 'package:jeevandhara2/theme/app_theme.dart';
import 'package:jeevandhara2/theme/locale.dart';

/// Desktop width, so the shell renders the persistent sidebar rather than the
/// drawer. `Layout.desktopBreakpoint` is 1000.
const _desktop = Size(1440, 900);

Widget _app({required AppRole role, AppDestination? initial}) {
  return MaterialApp(
    theme: buildLightTheme(),
    home: AppShell(
        role: role, initialDestination: initial ?? AppDestinations.landing),
  );
}

Finder _title(String text) =>
    find.descendant(of: find.byType(TopBar), matching: find.text(text));

/// A row inside the open palette, ignoring the sidebar behind it.
Finder _result(String text) => find.descendant(
      of: find.byType(CommandPalette),
      matching: find.text(text),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpShell(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = _desktop;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app);
    // The chat streams and the thinking indicator blinks, so `pumpAndSettle`
    // would never settle. Step frames instead.
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Steps enough frames for the palette's open/close transition to finish.
  Future<void> pumpTransition(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('farmer shell opens on chat with a grouped sidebar',
      (WidgetTester tester) async {
    await pumpShell(tester, _app(role: AppRole.farmer));

    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(_title(contextStr(tester, K.chat)), findsOneWidget);

    // Group headings, not a flat list.
    expect(find.text('ASSISTANT TOOLS'), findsOneWidget);
    expect(find.text('MARKETPLACE'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
  });

  testWidgets('selecting a sidebar destination updates the header',
      (WidgetTester tester) async {
    await pumpShell(tester, _app(role: AppRole.farmer));

    await tester.tap(find.text(contextStr(tester, K.myCrops)).first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(_title(contextStr(tester, K.myCrops)), findsOneWidget);
    expect(_title(contextStr(tester, K.chat)), findsNothing);
  });

  testWidgets('trader shell offers deals and hides farmer-only destinations',
      (WidgetTester tester) async {
    await pumpShell(
      tester,
      _app(role: AppRole.trader, initial: AppDestination.dashboard),
    );

    expect(_title(contextStr(tester, K.dashboard)), findsOneWidget);

    // Trader-only tools are reachable...
    expect(find.text(contextStr(tester, K.deals)), findsWidgets);
    expect(find.text(contextStr(tester, K.postOffer)), findsWidgets);
    // ...and the farmer's crop list is not offered.
    expect(find.text(contextStr(tester, K.myCrops)), findsNothing);
  });

  testWidgets('a destination hidden from the role falls back to the landing',
      (WidgetTester tester) async {
    await pumpShell(
      tester,
      _app(role: AppRole.trader, initial: AppDestination.myCrops),
    );

    expect(_title(contextStr(tester, K.chat)), findsOneWidget);
  });

  testWidgets('command palette opens and filters destinations',
      (WidgetTester tester) async {
    await pumpShell(tester, _app(role: AppRole.farmer));

    await tester.tap(find.byTooltip('Search and commands').first);
    await pumpTransition(tester);

    expect(find.byType(CommandPalette), findsOneWidget);

    await tester.enterText(_paletteField, 'weat');
    await tester.pump(const Duration(milliseconds: 200));

    // Weather matches by prefix on its label; My Crops does not match at all.
    // Scoped to the palette because the sidebar behind it carries every label
    // too.
    expect(_result(contextStr(tester, K.weather)), findsOneWidget);
    expect(_result(contextStr(tester, K.myCrops)), findsNothing);
  });

  testWidgets('the keyboard runs the top result and Escape dismisses',
      (WidgetTester tester) async {
    await pumpShell(tester, _app(role: AppRole.farmer));

    await tester.tap(find.byTooltip('Search and commands').first);
    await pumpTransition(tester);
    await tester.enterText(_paletteField, 'my');
    await tester.pump(const Duration(milliseconds: 200));

    // "My Crops" is the only hit, so Return has to run it.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpTransition(tester);

    expect(find.byType(CommandPalette), findsNothing);
    expect(_title(contextStr(tester, K.myCrops)), findsOneWidget);

    // Escape closes the palette without navigating.
    await tester.tap(find.byTooltip('Search and commands').first);
    await pumpTransition(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpTransition(tester);

    expect(find.byType(CommandPalette), findsNothing);
    expect(_title(contextStr(tester, K.myCrops)), findsOneWidget);
  });

  testWidgets('arrow keys walk the results without touching the field caret',
      (WidgetTester tester) async {
    await pumpShell(tester, _app(role: AppRole.farmer));

    await tester.tap(find.byTooltip('Search and commands').first);
    await pumpTransition(tester);
    await tester.enterText(_paletteField, 'e');
    await tester.pump(const Duration(milliseconds: 200));

    final before = tester
        .widget<TextField>(_paletteField)
        .controller!
        .selection
        .baseOffset;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await pumpTransition(tester);

    // The query is untouched and the palette is still open: the arrows moved
    // the highlight, not the caret.
    expect(find.byType(CommandPalette), findsOneWidget);
    expect(tester.widget<TextField>(_paletteField).controller!.text, 'e');
    expect(
      tester.widget<TextField>(_paletteField).controller!.selection.baseOffset,
      before,
    );
  });

  testWidgets('the trader entry screen lands on the deal overview',
      (WidgetTester tester) async {
    tester.view.physicalSize = _desktop;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
          theme: buildLightTheme(), home: const TraderDashboardScreen()),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppShell), findsOneWidget);
    expect(_title(contextStr(tester, K.dashboard)), findsOneWidget);
  });
}

/// The palette's search field, not the chat composer's.
final _paletteField = find.descendant(
  of: find.byType(CommandPalette),
  matching: find.byType(TextField),
);

/// The app's language is process-wide, so read it rather than hard-coding
/// English in assertions.
String contextStr(WidgetTester tester, String key) => AppStrings.of(
      tester.element(find.byType(AppShell)),
      key,
    );

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quicktap/game_state.dart';
import 'package:quicktap/main.dart';
import 'package:quicktap/mode_menu_screen.dart';

void main() {
  testWidgets('Title screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('四字熟語'), findsOneWidget);
    expect(find.text('ことわざ'), findsOneWidget);
  });

  testWidgets('Mode menu has progress start options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ModeMenuScreen(mode: GameMode.yoji)),
    );

    expect(find.text('最初から'), findsOneWidget);
    expect(find.text('つづきから'), findsOneWidget);
  });

  testWidgets('Mode menu difficulty is single-select', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ModeMenuScreen(mode: GameMode.yoji)),
    );

    await tester.tap(find.text('普通'));
    await tester.pumpAndSettle();

    final easyChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '簡単'),
    );
    final normalChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '普通'),
    );

    expect(easyChip.selected, isFalse);
    expect(normalChip.selected, isTrue);
  });
}

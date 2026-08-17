// Widget test for the example app. The plugin itself needs a real iOS device
// or simulator, so this only checks that the demo builds and toggles.
// See integration_test/ for the end-to-end test that renders actual symbols.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sf_symbols/sf_symbols.dart';

import 'package:sf_symbols_example/main.dart';

void main() {
  testWidgets('shows a grid of symbols and hides it on tap', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SF Symbols'), findsOneWidget);
    expect(find.byType(SfSymbol), findsWidgets);

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    expect(find.byType(SfSymbol), findsNothing);
  });
}

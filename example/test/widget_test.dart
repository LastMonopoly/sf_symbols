// Widget test for the example app. The plugin itself needs a real iOS device
// or simulator, so this only checks that the demo builds and responds.
// See integration_test/ for the end-to-end test that renders actual symbols.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sf_symbols/sf_symbols.dart';

import 'package:sf_symbols_example/main.dart';

void main() {
  testWidgets('builds every rendering mode', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SF Symbols'), findsOneWidget);

    final symbols = tester.widgetList<SfSymbol>(find.byType(SfSymbol));
    expect(symbols, isNotEmpty);
    expect(
      symbols.map((symbol) => symbol.renderingMode).toSet(),
      SfSymbolRenderingMode.values.toSet(),
    );
  });

  testWidgets('cycling the tint recolors the tint-driven symbols',
      (tester) async {
    await tester.pumpWidget(const MyApp());

    Set<Color?> monochromeColors() => tester
        .widgetList<SfSymbol>(find.byType(SfSymbol))
        .where((s) => s.renderingMode == SfSymbolRenderingMode.monochrome)
        .map((s) => s.color)
        .toSet();

    final before = monochromeColors();
    expect(before, hasLength(1));

    await tester.tap(find.byKey(const Key('cycleTint')));
    await tester.pump();

    final after = monochromeColors();
    expect(after, hasLength(1));
    expect(after, isNot(before));
  });

  testWidgets('the slider drives variableValue', (tester) async {
    await tester.pumpWidget(const MyApp());

    double? variableValue() => tester
        .widgetList<SfSymbol>(find.byType(SfSymbol))
        .firstWhere((s) => s.name == 'wifi')
        .variableValue;

    final before = variableValue();
    expect(before, isNotNull);

    // Drag the slider to its far right.
    await tester.drag(find.byKey(const Key('variableValue')), const Offset(500, 0));
    await tester.pump();

    expect(variableValue(), greaterThan(before!));
  });
}

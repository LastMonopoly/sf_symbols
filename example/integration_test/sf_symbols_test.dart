// End-to-end test against the real iOS plugin. Run with:
//   flutter test integration_test -d <simulator id>

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sf_symbols/sf_symbols.dart';
import 'package:sf_symbols/sf_symbols_platform_interface.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final platform = SfSymbolsPlatform.instance;

  testWidgets('registers, renders and disposes a texture', (tester) async {
    final textureId = await platform.init(
      name: 'camera',
      weight: FontWeight.w400,
      color: const Color(0xFF2196F3),
      size: 40,
    );
    expect(textureId, isNotNull);

    final size = await platform.render(textureId!);
    expect(size, isNotNull);
    expect(size!.width, greaterThan(0));
    expect(size.height, greaterThan(0));

    await platform.dispose(textureId);
  });

  testWidgets('returns null for an unknown symbol name', (tester) async {
    final textureId = await platform.init(
      name: 'definitely.not.a.symbol',
      weight: FontWeight.w400,
      color: const Color(0xFF2196F3),
      size: 40,
    );
    expect(textureId, isNull);
  });

  testWidgets('symbol weight changes the rendered size', (tester) async {
    Future<Size?> sizeFor(FontWeight weight) async {
      final id = await platform.init(
        name: 'camera',
        weight: weight,
        color: const Color(0xFFFFFFFF),
        size: 40,
      );
      final size = await platform.render(id!);
      await platform.dispose(id);
      return size;
    }

    final thin = await sizeFor(FontWeight.w100);
    final black = await sizeFor(FontWeight.w900);

    expect(thin, isNotNull);
    expect(black, isNotNull);
    // Heavier weights are drawn with thicker strokes, so they are wider.
    expect(black!.width, greaterThan(thin!.width));
  });

  testWidgets('SfSymbol widget mounts a Texture on screen', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SfSymbol(
            name: 'camera.aperture',
            color: Color(0xFFFF0000),
            size: 60,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(Texture), findsOneWidget);
    final renderedSize = tester.getSize(find.byType(Texture));
    expect(renderedSize.width, greaterThan(0));
    expect(renderedSize.height, greaterThan(0));
  });
}

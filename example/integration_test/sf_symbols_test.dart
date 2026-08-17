// End-to-end test against the real iOS plugin. Run with:
//   flutter test integration_test -d <simulator id>

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sf_symbols/sf_symbols.dart';
import 'package:sf_symbols/sf_symbols_platform_interface.dart';
import 'package:sf_symbols_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final platform = SfSymbolsPlatform.instance;

  /// Registers, renders and releases [config], returning the symbol's size.
  Future<Size?> sizeOf(SfSymbolConfig config) async {
    final id = await platform.init(config);
    if (id == null) return null;
    final size = await platform.render(id);
    await platform.dispose(id);
    return size;
  }

  testWidgets('registers, renders and disposes a texture', (tester) async {
    final textureId = await platform.init(const SfSymbolConfig(
      name: 'camera',
      size: 40,
      colors: [Color(0xFF2196F3)],
    ));
    expect(textureId, isNotNull);

    final size = await platform.render(textureId!);
    expect(size, isNotNull);
    expect(size!.width, greaterThan(0));
    expect(size.height, greaterThan(0));

    await platform.dispose(textureId);
  });

  testWidgets('returns null for an unknown symbol name', (tester) async {
    expect(
      await sizeOf(const SfSymbolConfig(name: 'definitely.not.a.symbol', size: 40)),
      isNull,
    );
  });

  testWidgets('isAvailable answers for known and unknown symbols',
      (tester) async {
    expect(await SfSymbol.isAvailable('camera'), isTrue);
    expect(await SfSymbol.isAvailable('definitely.not.a.symbol'), isFalse);
  });

  testWidgets('symbol weight changes the rendered size', (tester) async {
    final thin = await sizeOf(
      const SfSymbolConfig(name: 'camera', size: 40, weight: FontWeight.w100),
    );
    final black = await sizeOf(
      const SfSymbolConfig(name: 'camera', size: 40, weight: FontWeight.w900),
    );

    expect(thin, isNotNull);
    expect(black, isNotNull);
    // Heavier weights are drawn with thicker strokes, so they are wider.
    expect(black!.width, greaterThan(thin!.width));
  });

  testWidgets('symbol scale changes the rendered size', (tester) async {
    final small = await sizeOf(const SfSymbolConfig(
      name: 'camera',
      size: 40,
      scale: SfSymbolScale.small,
    ));
    final large = await sizeOf(const SfSymbolConfig(
      name: 'camera',
      size: 40,
      scale: SfSymbolScale.large,
    ));

    expect(small, isNotNull);
    expect(large, isNotNull);
    expect(large!.width, greaterThan(small!.width));
  });

  testWidgets('the default scale matches what UIKit renders unscaled',
      (tester) async {
    // Versions before scale support sent no scale at all, which UIKit reads as
    // UIImage.SymbolScale.unspecified. Symbols must not resize on upgrade, so
    // compare the default against unspecified (raw value 0) over the channel.
    const channel = MethodChannel('sf_symbols');
    final init = await channel.invokeMapMethod('init', {
      'name': 'camera',
      'size': 40.0,
      'weight': FontWeight.normal.value ~/ 100,
      'scale': 0, // .unspecified
      'renderingMode': 'monochrome',
      'colors': ['#FF000000'],
    });
    final id = init!['textureId'];
    final raw = await channel.invokeMapMethod('render', {'textureId': id});
    await channel.invokeMethod('dispose', {'textureId': id});
    final unspecified = Size(
      (raw!['width'] as num).toDouble(),
      (raw['height'] as num).toDouble(),
    );

    final medium = await sizeOf(const SfSymbolConfig(
      name: 'camera',
      size: 40,
      scale: SfSymbolScale.medium,
    ));

    expect(medium, unspecified);
  });

  testWidgets('every rendering mode produces a texture', (tester) async {
    for (final mode in SfSymbolRenderingMode.values) {
      final size = await sizeOf(SfSymbolConfig(
        name: 'cloud.sun.rain.fill',
        size: 40,
        renderingMode: mode,
        colors: switch (mode) {
          SfSymbolRenderingMode.palette => const [
              Color(0xFFFF0000),
              Color(0xFF00FF00),
              Color(0xFF0000FF),
            ],
          SfSymbolRenderingMode.multicolor => const <Color>[],
          _ => const [Color(0xFF2196F3)],
        },
      ));

      expect(size, isNotNull, reason: '$mode produced no texture');
      expect(size!.width, greaterThan(0), reason: '$mode');
    }
  });

  testWidgets('variable symbols accept a variable value', (tester) async {
    for (final value in const [0.0, 0.5, 1.0]) {
      final size = await sizeOf(
        SfSymbolConfig(name: 'wifi', size: 40, variableValue: value),
      );
      expect(size, isNotNull, reason: 'variableValue $value produced nothing');
    }
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

  testWidgets('SfSymbol swaps its texture when properties change',
      (tester) async {
    Future<void> pump(Color color) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SfSymbol(name: 'camera', color: color, size: 40),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    await pump(const Color(0xFF0000FF));
    final first = tester.widget<Texture>(find.byType(Texture)).textureId;

    await pump(const Color(0xFFFF0000));
    final second = tester.widget<Texture>(find.byType(Texture)).textureId;

    // A new native texture was registered for the new color.
    expect(second, isNot(first));
  });

  testWidgets('the demo app re-renders its symbols when the tint changes',
      (tester) async {
    List<int> textureIds() => tester
        .widgetList<Texture>(find.byType(Texture))
        .map((texture) => texture.textureId)
        .toList();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final before = textureIds();
    expect(before, isNotEmpty);

    await tester.tap(find.byKey(const Key('cycleTint')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final after = textureIds();
    expect(after, hasLength(before.length));

    // The demo's four palette symbols use fixed colors rather than the tint,
    // so they must keep their textures — a reload there would be wasted work.
    // Every other symbol on screen re-rendered with the new tint.
    final reused = after.toSet().intersection(before.toSet());
    expect(reused, hasLength(4),
        reason: 'only the tint-independent palette symbols may be reused');
  });
}

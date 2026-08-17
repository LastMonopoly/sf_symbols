import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sf_symbols/sf_symbols.dart';
import 'package:sf_symbols/sf_symbols_method_channel.dart';
import 'package:sf_symbols/sf_symbols_platform_interface.dart';

class FakeSfSymbolsPlatform extends SfSymbolsPlatform
    with MockPlatformInterfaceMixin {
  FakeSfSymbolsPlatform({this.symbolSize = const Size(40, 32)});

  final Size? symbolSize;

  int _nextTextureId = 1;
  final List<SfSymbolConfig> initialized = <SfSymbolConfig>[];
  final List<int> disposed = <int>[];

  @override
  Future<int?> init(SfSymbolConfig config) async {
    if (config.name == 'not.a.symbol') return null;
    initialized.add(config);
    return _nextTextureId++;
  }

  @override
  Future<Size?> render(int textureId) async => symbolSize;

  @override
  Future<void> dispose(int textureId) async => disposed.add(textureId);

  @override
  Future<bool> isAvailable(String name) async => name != 'not.a.symbol';
}

void main() {
  test('MethodChannelSfSymbols is the default instance', () {
    expect(SfSymbolsPlatform.instance, isA<MethodChannelSfSymbols>());
  });

  group('SfSymbol', () {
    late FakeSfSymbolsPlatform fake;

    setUp(() {
      fake = FakeSfSymbolsPlatform();
      SfSymbolsPlatform.instance = fake;
    });

    Widget wrap(Widget child) => Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        );

    testWidgets('renders a Texture once the symbol is ready', (tester) async {
      await tester.pumpWidget(wrap(const SfSymbol(
        name: 'camera',
        color: Color(0xFF000000),
        size: 40,
      )));

      // Nothing is shown before the platform answers.
      expect(find.byType(Texture), findsNothing);

      await tester.pumpAndSettle();

      expect(fake.initialized.single.name, 'camera');
      expect(find.byType(Texture), findsOneWidget);
      expect(tester.widget<Texture>(find.byType(Texture)).textureId, 1);
      expect(tester.getSize(find.byType(Texture)), const Size(40, 32));
    });

    testWidgets('stays empty for an unknown symbol', (tester) async {
      await tester.pumpWidget(wrap(const SfSymbol(
        name: 'not.a.symbol',
        color: Color(0xFF000000),
        size: 40,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(Texture), findsNothing);
    });

    testWidgets('releases its texture when removed from the tree',
        (tester) async {
      await tester.pumpWidget(wrap(const SfSymbol(
        name: 'camera',
        color: Color(0xFF000000),
        size: 40,
      )));
      await tester.pumpAndSettle();
      expect(fake.disposed, isEmpty);

      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.pumpAndSettle();

      expect(fake.disposed, [1]);
    });

    testWidgets('keeps the aspect ratio when constrained', (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(
        width: 20,
        child: SfSymbol(
          name: 'camera',
          color: Color(0xFF000000),
          size: 40,
        ),
      )));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(Texture)), const Size(20, 16));
    });

    testWidgets('exposes a semantic label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(const SfSymbol(
        name: 'camera',
        color: Color(0xFF000000),
        size: 40,
        semanticLabel: 'Camera',
      )));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Camera'), findsOneWidget);
      handle.dispose();
    });

    group('reacts to property changes', () {
      testWidgets('reloads and swaps the texture when the color changes',
          (tester) async {
        await tester.pumpWidget(wrap(const SfSymbol(
          name: 'camera',
          color: Color(0xFF000000),
          size: 40,
        )));
        await tester.pumpAndSettle();
        expect(tester.widget<Texture>(find.byType(Texture)).textureId, 1);

        await tester.pumpWidget(wrap(const SfSymbol(
          name: 'camera',
          color: Color(0xFFFF0000),
          size: 40,
        )));
        await tester.pumpAndSettle();

        expect(fake.initialized.map((c) => c.colors.single), [
          const Color(0xFF000000),
          const Color(0xFFFF0000),
        ]);
        // New texture shown, old one released.
        expect(tester.widget<Texture>(find.byType(Texture)).textureId, 2);
        expect(fake.disposed, [1]);
      });

      testWidgets('reloads when the name, weight, size or scale changes',
          (tester) async {
        Future<void> pump(SfSymbol symbol) async {
          await tester.pumpWidget(wrap(symbol));
          await tester.pumpAndSettle();
        }

        await pump(const SfSymbol(
            name: 'camera', color: Color(0xFF000000), size: 40));
        await pump(const SfSymbol(
            name: 'bolt', color: Color(0xFF000000), size: 40));
        await pump(const SfSymbol(
            name: 'bolt', color: Color(0xFF000000), size: 60));
        await pump(const SfSymbol(
          name: 'bolt',
          color: Color(0xFF000000),
          size: 60,
          weight: FontWeight.w900,
        ));
        await pump(const SfSymbol(
          name: 'bolt',
          color: Color(0xFF000000),
          size: 60,
          weight: FontWeight.w900,
          scale: SfSymbolScale.large,
        ));

        expect(fake.initialized, hasLength(5));
      });

      testWidgets('reloads when variableValue changes', (tester) async {
        await tester.pumpWidget(wrap(const SfSymbol(
          name: 'wifi',
          color: Color(0xFF000000),
          size: 40,
          variableValue: 0.3,
        )));
        await tester.pumpAndSettle();

        await tester.pumpWidget(wrap(const SfSymbol(
          name: 'wifi',
          color: Color(0xFF000000),
          size: 40,
          variableValue: 0.9,
        )));
        await tester.pumpAndSettle();

        expect(fake.initialized.map((c) => c.variableValue), [0.3, 0.9]);
      });

      testWidgets('does not reload when nothing meaningful changed',
          (tester) async {
        for (var i = 0; i < 3; i++) {
          await tester.pumpWidget(wrap(const SfSymbol(
            name: 'camera',
            color: Color(0xFF000000),
            size: 40,
          )));
          await tester.pumpAndSettle();
        }

        expect(fake.initialized, hasLength(1));
        expect(fake.disposed, isEmpty);
      });

      testWidgets('does not leak when changed while a load is in flight',
          (tester) async {
        await tester.pumpWidget(wrap(const SfSymbol(
          name: 'camera',
          color: Color(0xFF000000),
          size: 40,
        )));
        // Change the config repeatedly without letting any load settle.
        for (var i = 1; i <= 3; i++) {
          await tester.pumpWidget(wrap(SfSymbol(
            name: 'camera',
            color: const Color(0xFF000000),
            size: 40 + i.toDouble(),
          )));
        }
        await tester.pumpAndSettle();

        // Every texture created is either on screen or released.
        final onScreen = tester.widget<Texture>(find.byType(Texture)).textureId;
        final created = List<int>.generate(fake.initialized.length, (i) => i + 1);
        expect({...fake.disposed, onScreen}, created.toSet());
      });
    });

    group('rendering modes', () {
      testWidgets('monochrome carries one color', (tester) async {
        await tester.pumpWidget(wrap(const SfSymbol(
          name: 'camera',
          color: Color(0xFF2196F3),
          size: 40,
        )));
        await tester.pumpAndSettle();

        final config = fake.initialized.single;
        expect(config.renderingMode, SfSymbolRenderingMode.monochrome);
        expect(config.colors, const [Color(0xFF2196F3)]);
      });

      testWidgets('hierarchical carries one color', (tester) async {
        await tester.pumpWidget(wrap(const SfSymbol.hierarchical(
          name: 'square.stack.3d.up.fill',
          color: Color(0xFF2196F3),
          size: 40,
        )));
        await tester.pumpAndSettle();

        final config = fake.initialized.single;
        expect(config.renderingMode, SfSymbolRenderingMode.hierarchical);
        expect(config.colors, const [Color(0xFF2196F3)]);
      });

      testWidgets('palette carries its colors in order', (tester) async {
        await tester.pumpWidget(wrap(const SfSymbol.palette(
          name: 'person.2.fill',
          colors: [Color(0xFFFF0000), Color(0xFF00FF00)],
          size: 40,
        )));
        await tester.pumpAndSettle();

        final config = fake.initialized.single;
        expect(config.renderingMode, SfSymbolRenderingMode.palette);
        expect(
          config.colors,
          const [Color(0xFFFF0000), Color(0xFF00FF00)],
        );
      });

      testWidgets('multicolor carries no color by default', (tester) async {
        await tester.pumpWidget(wrap(const SfSymbol.multicolor(
          name: 'cloud.sun.rain.fill',
          size: 40,
        )));
        await tester.pumpAndSettle();

        final config = fake.initialized.single;
        expect(config.renderingMode, SfSymbolRenderingMode.multicolor);
        expect(config.colors, isEmpty);
      });

      test('palette rejects an unusable number of colors', () {
        expect(
          () => const SfSymbol.palette(
            name: 'person.2',
            colors: <Color>[],
            size: 40,
          ).config,
          throwsAssertionError,
        );
        expect(
          () => const SfSymbol.palette(
            name: 'person.2',
            colors: <Color>[
              Color(0xFFFF0000),
              Color(0xFF00FF00),
              Color(0xFF0000FF),
              Color(0xFFFFFFFF),
            ],
            size: 40,
          ).config,
          throwsAssertionError,
        );
      });
    });

    testWidgets('isAvailable asks the platform', (tester) async {
      expect(await SfSymbol.isAvailable('camera'), isTrue);
      expect(await SfSymbol.isAvailable('not.a.symbol'), isFalse);
    });
  });

  group('SfSymbolConfig', () {
    test('compares by value, including colors', () {
      const a = SfSymbolConfig(
        name: 'camera',
        size: 40,
        colors: [Color(0xFFFF0000)],
      );
      const b = SfSymbolConfig(
        name: 'camera',
        size: 40,
        colors: [Color(0xFFFF0000)],
      );
      const c = SfSymbolConfig(
        name: 'camera',
        size: 40,
        colors: [Color(0xFF00FF00)],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}

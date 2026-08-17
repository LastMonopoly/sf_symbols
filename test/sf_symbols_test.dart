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

  int nextTextureId = 1;
  final List<int> disposed = <int>[];
  final List<String> initialized = <String>[];

  @override
  Future<int?> init({
    required String name,
    required FontWeight weight,
    required Color color,
    required double size,
  }) async {
    if (name == 'not.a.symbol') return null;
    initialized.add(name);
    return nextTextureId++;
  }

  @override
  Future<Size?> render(int textureId) async => symbolSize;

  @override
  Future<void> dispose(int textureId) async => disposed.add(textureId);
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

      expect(fake.initialized, ['camera']);
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
  });
}

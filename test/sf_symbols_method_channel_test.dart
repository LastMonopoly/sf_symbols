import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sf_symbols/sf_symbols_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelSfSymbols();
  const channel = MethodChannel('sf_symbols');

  late List<MethodCall> log;
  late Object? Function(MethodCall) handler;

  setUp(() {
    log = <MethodCall>[];
    handler = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      return handler(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('init', () {
    test('encodes name, weight, color and size', () async {
      handler = (_) => {'textureId': 7};

      final id = await platform.init(
        name: 'camera',
        weight: FontWeight.w600,
        color: const Color(0xFF2196F3),
        size: 40,
      );

      expect(id, 7);
      expect(log.single.method, 'init');
      expect(log.single.arguments, {
        'name': 'camera',
        // w600 -> UIImage.SymbolWeight.semibold (raw value 6)
        'weight': 6,
        'color': '#FF2196F3',
        'size': 40.0,
      });
    });

    test('maps every FontWeight to a valid UIImage.SymbolWeight', () async {
      handler = (_) => {'textureId': 1};

      for (final weight in FontWeight.values) {
        log.clear();
        await platform.init(
          name: 'camera',
          weight: weight,
          color: const Color(0xFFFFFFFF),
          size: 10,
        );
        final raw = (log.single.arguments as Map)['weight'] as int;
        // UIImage.SymbolWeight: ultraLight (1) ... black (9)
        expect(raw, inInclusiveRange(1, 9));
        expect(raw, weight.value ~/ 100);
      }
    });

    test('preserves the alpha channel', () async {
      handler = (_) => {'textureId': 1};

      await platform.init(
        name: 'camera',
        weight: FontWeight.normal,
        color: const Color(0x80FF0000),
        size: 10,
      );

      expect((log.single.arguments as Map)['color'], '#80FF0000');
    });

    test('returns null when the platform throws', () async {
      handler = (_) => throw PlatformException(code: 'UNKNOWN_SYMBOL');

      final id = await platform.init(
        name: 'not.a.symbol',
        weight: FontWeight.normal,
        color: const Color(0xFFFFFFFF),
        size: 10,
      );

      expect(id, isNull);
    });
  });

  group('render', () {
    test('returns the symbol size', () async {
      handler = (_) => {'width': 44.5, 'height': 36.0};

      expect(await platform.render(7), const Size(44.5, 36.0));
      expect(log.single.method, 'render');
      expect(log.single.arguments, {'textureId': 7});
    });

    test('returns null for an empty size', () async {
      handler = (_) => {'width': 0.0, 'height': 0.0};

      expect(await platform.render(7), isNull);
    });

    test('returns null when the size is missing', () async {
      handler = (_) => <String, dynamic>{};

      expect(await platform.render(7), isNull);
    });
  });

  group('dispose', () {
    test('forwards the texture id', () async {
      await platform.dispose(7);

      expect(log.single.method, 'dispose');
      expect(log.single.arguments, {'textureId': 7});
    });

    test('swallows platform errors', () async {
      handler = (_) => throw PlatformException(code: 'INVALID_ARGUMENT');

      await expectLater(platform.dispose(7), completes);
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sf_symbols/sf_symbols_config.dart';
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

  group('encodeConfig', () {
    test('encodes a monochrome symbol', () {
      final encoded = MethodChannelSfSymbols.encodeConfig(const SfSymbolConfig(
        name: 'camera',
        size: 40,
        weight: FontWeight.w600,
        colors: [Color(0xFF2196F3)],
      ));

      expect(encoded, {
        'name': 'camera',
        'size': 40.0,
        // w600 -> UIImage.SymbolWeight.semibold (raw value 6)
        'weight': 6,
        // .medium -> UIImage.SymbolScale.medium (raw value 2)
        'scale': 2,
        'renderingMode': 'monochrome',
        'colors': ['#FF2196F3'],
      });
    });

    test('maps every FontWeight to a valid UIImage.SymbolWeight', () {
      for (final weight in FontWeight.values) {
        final encoded = MethodChannelSfSymbols.encodeConfig(
          SfSymbolConfig(name: 'camera', size: 10, weight: weight),
        );
        // UIImage.SymbolWeight: ultraLight (1) ... black (9)
        expect(encoded['weight'], inInclusiveRange(1, 9));
        expect(encoded['weight'], weight.value ~/ 100);
      }
    });

    test('maps every scale to a valid UIImage.SymbolScale', () {
      final scales = {
        SfSymbolScale.small: 1,
        SfSymbolScale.medium: 2,
        SfSymbolScale.large: 3,
      };
      scales.forEach((scale, raw) {
        final encoded = MethodChannelSfSymbols.encodeConfig(
          SfSymbolConfig(name: 'camera', size: 10, scale: scale),
        );
        expect(encoded['scale'], raw);
      });
    });

    test('encodes each rendering mode by name', () {
      for (final mode in SfSymbolRenderingMode.values) {
        final encoded = MethodChannelSfSymbols.encodeConfig(
          SfSymbolConfig(name: 'camera', size: 10, renderingMode: mode),
        );
        expect(encoded['renderingMode'], mode.name);
      }
    });

    test('encodes palette colors in order', () {
      final encoded = MethodChannelSfSymbols.encodeConfig(const SfSymbolConfig(
        name: 'person.2',
        size: 40,
        renderingMode: SfSymbolRenderingMode.palette,
        colors: [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF0000FF)],
      ));

      expect(encoded['colors'], ['#FFFF0000', '#FF00FF00', '#FF0000FF']);
    });

    test('omits variableValue when unset, and clamps it when set', () {
      expect(
        MethodChannelSfSymbols.encodeConfig(
          const SfSymbolConfig(name: 'wifi', size: 10),
        ),
        isNot(contains('variableValue')),
      );

      expect(
        MethodChannelSfSymbols.encodeConfig(
          const SfSymbolConfig(name: 'wifi', size: 10, variableValue: 0.5),
        )['variableValue'],
        0.5,
      );
      expect(
        MethodChannelSfSymbols.encodeConfig(
          const SfSymbolConfig(name: 'wifi', size: 10, variableValue: 4),
        )['variableValue'],
        1.0,
      );
      expect(
        MethodChannelSfSymbols.encodeConfig(
          const SfSymbolConfig(name: 'wifi', size: 10, variableValue: -2),
        )['variableValue'],
        0.0,
      );
    });

    test('preserves the alpha channel', () {
      final encoded = MethodChannelSfSymbols.encodeConfig(const SfSymbolConfig(
        name: 'camera',
        size: 10,
        colors: [Color(0x80FF0000)],
      ));

      expect(encoded['colors'], ['#80FF0000']);
    });
  });

  group('init', () {
    test('sends the encoded config and returns the texture id', () async {
      handler = (_) => {'textureId': 7};

      final id = await platform.init(const SfSymbolConfig(
        name: 'camera',
        size: 40,
        colors: [Color(0xFF2196F3)],
      ));

      expect(id, 7);
      expect(log.single.method, 'init');
      expect(
        log.single.arguments,
        MethodChannelSfSymbols.encodeConfig(const SfSymbolConfig(
          name: 'camera',
          size: 40,
          colors: [Color(0xFF2196F3)],
        )),
      );
    });

    test('returns null when the platform throws', () async {
      handler = (_) => throw PlatformException(code: 'UNKNOWN_SYMBOL');

      final id = await platform.init(
        const SfSymbolConfig(name: 'not.a.symbol', size: 10),
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

  group('isAvailable', () {
    test('forwards the name and returns the answer', () async {
      handler = (_) => true;

      expect(await platform.isAvailable('camera'), isTrue);
      expect(log.single.method, 'available');
      expect(log.single.arguments, {'name': 'camera'});
    });

    test('returns false when the platform throws', () async {
      handler = (_) => throw PlatformException(code: 'INVALID_ARGUMENT');

      expect(await platform.isAvailable('camera'), isFalse);
    });
  });
}

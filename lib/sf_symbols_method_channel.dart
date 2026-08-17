import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sf_symbols_config.dart';
import 'sf_symbols_platform_interface.dart';

/// An implementation of [SfSymbolsPlatform] that uses method channels.
class MethodChannelSfSymbols extends SfSymbolsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('sf_symbols');

  static const idKey = "textureId";

  /// Encodes [config] for the native side.
  @visibleForTesting
  static Map<String, dynamic> encodeConfig(SfSymbolConfig config) {
    return <String, dynamic>{
      'name': config.name,
      'size': config.size,
      // UIImage.SymbolWeight: ultraLight (1) ... black (9).
      'weight': config.weight.value ~/ 100,
      // UIImage.SymbolScale: small (1), medium (2), large (3).
      'scale': config.scale.index + 1,
      'renderingMode': config.renderingMode.name,
      'colors': [for (final color in config.colors) _hex(color)],
      if (config.variableValue != null)
        'variableValue': config.variableValue!.clamp(0.0, 1.0),
    };
  }

  static String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  @override
  Future<int?> init(SfSymbolConfig config) async {
    try {
      final result = await methodChannel.invokeMapMethod(
        'init',
        encodeConfig(config),
      );

      return (result?[idKey] as num?)?.toInt();
    } catch (e) {
      if (kDebugMode) print('SfSymbols init: $e');
      return null;
    }
  }

  @override
  Future<Size?> render(int textureId) async {
    try {
      final value = await methodChannel.invokeMapMethod('render', {
        idKey: textureId,
      });
      final width = value?['width'] as num?;
      final height = value?['height'] as num?;
      if (width == null || height == null) return null;

      final size = Size(width.toDouble(), height.toDouble());
      if (size.isEmpty) return null;
      return size;
    } catch (e) {
      if (kDebugMode) print('SfSymbols render: $e');
      return null;
    }
  }

  @override
  Future<void> dispose(int textureId) async {
    try {
      await methodChannel.invokeMethod('dispose', {
        idKey: textureId,
      });
    } catch (e) {
      if (kDebugMode) print('SfSymbols dispose: $e');
    }
  }

  @override
  Future<bool> isAvailable(String name) async {
    try {
      final available = await methodChannel.invokeMethod<bool>('available', {
        'name': name,
      });
      return available ?? false;
    } catch (e) {
      if (kDebugMode) print('SfSymbols available: $e');
      return false;
    }
  }
}

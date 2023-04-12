import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sf_symbols_platform_interface.dart';

/// An implementation of [SfSymbolsPlatform] that uses method channels.
class MethodChannelSfSymbols extends SfSymbolsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('sf_symbols');

  static const idKey = "textureId";

  @override
  Future<int?> init({
    required String name,
    required FontWeight weight,
    required Color color,
    required double size,
  }) async {
    final hexColor =
        color.value.toRadixString(16).padLeft(8, '0').toUpperCase();

    try {
      final result = await methodChannel.invokeMethod('init', {
        'name': name,
        'weight': weight.index + 1,
        'color': '#$hexColor',
        'size': size,
      });

      return result[idKey];
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
  Future dispose(int textureId) async {
    try {
      await methodChannel.invokeMethod('dispose', {
        idKey: textureId,
      });
    } catch (e) {
      if (kDebugMode) print('SfSymbols dispose: $e');
    }
  }
}

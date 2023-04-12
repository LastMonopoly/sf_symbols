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

    final result = await methodChannel.invokeMethod('init', {
      'name': name,
      'weight': weight.index + 1,
      'color': '#$hexColor',
      'size': size,
    });

    return result[idKey];
  }

  @override
  Future<Size> render(int textureId) async {
    final size = await methodChannel.invokeMethod('render', {
      idKey: textureId,
    });
    return Size(
      size['width']?.toDouble() ?? 0,
      size['height']?.toDouble() ?? 0,
    );
  }

  @override
  Future dispose(int textureId) async {
    await methodChannel.invokeMethod('dispose', {
      idKey: textureId,
    });
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sf_symbols_platform_interface.dart';

/// An implementation of [SfSymbolsPlatform] that uses method channels.
class MethodChannelSfSymbols extends SfSymbolsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('sf_symbols');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}

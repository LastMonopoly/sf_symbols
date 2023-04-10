import 'dart:ui';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'sf_symbols_method_channel.dart';

abstract class SfSymbolsPlatform extends PlatformInterface {
  /// Constructs a SfSymbolsPlatform.
  SfSymbolsPlatform() : super(token: _token);

  static final Object _token = Object();

  static SfSymbolsPlatform _instance = MethodChannelSfSymbols();

  /// The default instance of [SfSymbolsPlatform] to use.
  ///
  /// Defaults to [MethodChannelSfSymbols].
  static SfSymbolsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SfSymbolsPlatform] when
  /// they register themselves.
  static set instance(SfSymbolsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int?> init() async => throw UnimplementedError();

  Future<Size> render(int textureId) async => throw UnimplementedError();

  Future dispose(int textureId) async => throw UnimplementedError();
}

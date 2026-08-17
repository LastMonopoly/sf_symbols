import 'dart:ui';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'sf_symbols_config.dart';
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

  /// Registers a texture for [config], returning its id, or null if the symbol
  /// could not be created.
  Future<int?> init(SfSymbolConfig config) async => throw UnimplementedError();

  /// Draws the symbol into the texture, returning its size in points.
  Future<Size?> render(int textureId) async => throw UnimplementedError();

  /// Releases the texture.
  Future<void> dispose(int textureId) async => throw UnimplementedError();

  /// Whether a symbol named [name] exists on the running OS version.
  Future<bool> isAvailable(String name) async => throw UnimplementedError();

  /// Which symbol effects the running OS version can play.
  Future<SfSymbolEffectSupport> effectSupport() async =>
      throw UnimplementedError();
}

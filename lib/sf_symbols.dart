
import 'sf_symbols_platform_interface.dart';

class SfSymbols {
  Future<String?> getPlatformVersion() {
    return SfSymbolsPlatform.instance.getPlatformVersion();
  }
}

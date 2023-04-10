import 'package:flutter_test/flutter_test.dart';
import 'package:sf_symbols/sf_symbols.dart';
import 'package:sf_symbols/sf_symbols_platform_interface.dart';
import 'package:sf_symbols/sf_symbols_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSfSymbolsPlatform
    with MockPlatformInterfaceMixin
    implements SfSymbolsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SfSymbolsPlatform initialPlatform = SfSymbolsPlatform.instance;

  test('$MethodChannelSfSymbols is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSfSymbols>());
  });

  test('getPlatformVersion', () async {
    SfSymbols sfSymbolsPlugin = SfSymbols();
    MockSfSymbolsPlatform fakePlatform = MockSfSymbolsPlatform();
    SfSymbolsPlatform.instance = fakePlatform;

    expect(await sfSymbolsPlugin.getPlatformVersion(), '42');
  });
}

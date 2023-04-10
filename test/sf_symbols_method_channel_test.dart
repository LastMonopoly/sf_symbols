import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sf_symbols/sf_symbols_method_channel.dart';

void main() {
  MethodChannelSfSymbols platform = MethodChannelSfSymbols();
  const MethodChannel channel = MethodChannel('sf_symbols');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}

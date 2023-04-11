import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'sf_symbols_platform_interface.dart';

class SfSymbols {
  Future<String?> getPlatformVersion() {
    return SfSymbolsPlatform.instance.getPlatformVersion();
  }
}

class SfSymbol extends StatefulWidget {
  final String name;
  final FontWeight weight;
  final Color color;

  const SfSymbol({
    super.key,
    required this.name,
    this.weight = FontWeight.normal,
    required this.color,
  });

  @override
  State<SfSymbol> createState() => _SfSymbolState();
}

class _SfSymbolState extends State<SfSymbol> {
  String _platformVersion = 'Unknown';
  final _sfSymbolsPlugin = SfSymbols();

  @override
  void initState() {
    super.initState();
    // initPlatformState();
    initSymbol();
  }

  int? symbolTextureId;
  Size? symbolSize;

  initSymbol() async {
    FontWeight.bold.index;
    symbolTextureId = await SfSymbolsPlatform.instance.init(
      widget.name,
      widget.weight,
      widget.color,
    );

    if (symbolTextureId != null) {
      symbolSize = await SfSymbolsPlatform.instance.render(symbolTextureId!);

      if (symbolSize != null && mounted) setState(() {});
    }
  }

  @override
  dispose() {
    if (symbolTextureId != null) {
      SfSymbolsPlatform.instance.dispose(symbolTextureId!);
    }
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _sfSymbolsPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (symbolTextureId != null && symbolSize != null) {
      return AspectRatio(
        aspectRatio: symbolSize!.aspectRatio,
        child: Texture(textureId: symbolTextureId!),
      );
    } else {
      return const SizedBox();
    }
  }
}

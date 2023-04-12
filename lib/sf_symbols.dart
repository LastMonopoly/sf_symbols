import 'package:flutter/widgets.dart';

import 'sf_symbols_platform_interface.dart';

class SfSymbol extends StatefulWidget {
  final String name;
  final FontWeight weight;
  final Color color;

  /// the symbol will be rendered as a size x size image, unit is dp, not pixel
  final double size;

  const SfSymbol({
    super.key,
    required this.name,
    this.weight = FontWeight.normal,
    required this.color,
    required this.size,
  });

  @override
  State<SfSymbol> createState() => _SfSymbolState();
}

class _SfSymbolState extends State<SfSymbol> {
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
      name: widget.name,
      weight: widget.weight,
      color: widget.color,
      size: widget.size,
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

  @override
  Widget build(BuildContext context) {
    if (symbolTextureId != null && symbolSize != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: symbolSize!.aspectRatio,
          child: Texture(textureId: symbolTextureId!),
        ),
      );
    } else {
      return const SizedBox();
    }
  }
}

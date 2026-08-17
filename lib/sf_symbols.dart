import 'package:flutter/widgets.dart';

import 'sf_symbols_cache.dart';
import 'sf_symbols_config.dart';
import 'sf_symbols_platform_interface.dart';

export 'sf_symbols_cache.dart' show SfSymbolCache, SfSymbolTexture;
export 'sf_symbols_config.dart'
    show
        SfSymbolConfig,
        SfSymbolEffect,
        SfSymbolEffectSupport,
        SfSymbolRenderingMode,
        SfSymbolScale;

/// Renders an SF Symbol natively on iOS.
///
/// The default constructor draws the symbol in a single flat [color]. The named
/// constructors select the other rendering modes iOS supports:
///
/// ```dart
/// SfSymbol(name: 'camera', color: Colors.blue, size: 40)
/// SfSymbol.hierarchical(name: 'square.stack.3d.up', color: Colors.blue, size: 40)
/// SfSymbol.palette(name: 'person.2', colors: [Colors.blue, Colors.pink], size: 40)
/// SfSymbol.multicolor(name: 'cloud.sun.rain.fill', size: 40)
/// ```
///
/// Nothing is drawn while the symbol loads, or if no symbol named [name] exists
/// on the running iOS version.
class SfSymbol extends StatefulWidget {
  /// Draws the symbol in a single flat [color].
  const SfSymbol({
    super.key,
    required this.name,
    required this.size,
    required Color this.color,
    this.weight = FontWeight.normal,
    this.scale = SfSymbolScale.medium,
    this.variableValue,
    this.effect,
    this.effectRepeats = true,
    this.semanticLabel,
  })  : renderingMode = SfSymbolRenderingMode.monochrome,
        colors = null;

  /// Draws the symbol in [color], applied at several opacities across its
  /// layers so its internal structure stays readable.
  const SfSymbol.hierarchical({
    super.key,
    required this.name,
    required this.size,
    required Color this.color,
    this.weight = FontWeight.normal,
    this.scale = SfSymbolScale.medium,
    this.variableValue,
    this.effect,
    this.effectRepeats = true,
    this.semanticLabel,
  })  : renderingMode = SfSymbolRenderingMode.hierarchical,
        colors = null;

  /// Draws the symbol's layers in [colors], in order.
  ///
  /// iOS uses up to three colors. A symbol with fewer layers than colors
  /// ignores the extras.
  const SfSymbol.palette({
    super.key,
    required this.name,
    required this.size,
    required List<Color> this.colors,
    this.weight = FontWeight.normal,
    this.scale = SfSymbolScale.medium,
    this.variableValue,
    this.effect,
    this.effectRepeats = true,
    this.semanticLabel,
  })  : renderingMode = SfSymbolRenderingMode.palette,
        color = null;

  /// Draws the symbol in its own built-in colors.
  ///
  /// Symbols without a multicolor variant fall back to a monochrome
  /// appearance, so pass [color] to control that fallback.
  const SfSymbol.multicolor({
    super.key,
    required this.name,
    required this.size,
    this.color,
    this.weight = FontWeight.normal,
    this.scale = SfSymbolScale.medium,
    this.variableValue,
    this.effect,
    this.effectRepeats = true,
    this.semanticLabel,
  })  : renderingMode = SfSymbolRenderingMode.multicolor,
        colors = null;

  /// The SF Symbol name, e.g. `camera.aperture`.
  final String name;

  /// The symbol renders as roughly a [size] x [size] image, in logical pixels.
  final double size;

  /// The color for the monochrome and hierarchical modes.
  final Color? color;

  /// The colors for the palette mode.
  final List<Color>? colors;

  final FontWeight weight;

  /// The symbol's size relative to [size]. See [SfSymbolScale].
  final SfSymbolScale scale;

  final SfSymbolRenderingMode renderingMode;

  /// Fill level for variable symbols such as `wifi`, between 0.0 and 1.0.
  ///
  /// Requires iOS 16; earlier versions draw the symbol fully filled.
  final double? variableValue;

  /// The animation to run, or null for a still symbol.
  ///
  /// Requires iOS 17, and some effects iOS 18; see [SfSymbolEffect]. Animating
  /// symbols redraw every frame and are not shared with other widgets, so use
  /// them where the motion means something rather than everywhere.
  final SfSymbolEffect? effect;

  /// Whether [effect] repeats, or plays once when the symbol appears.
  final bool effectRepeats;

  /// Describes the symbol to accessibility tools such as VoiceOver.
  final String? semanticLabel;

  /// Whether a symbol named [name] exists on the running iOS version.
  static Future<bool> isAvailable(String name) =>
      SfSymbolsPlatform.instance.isAvailable(name);

  /// Renders a symbol ahead of time, so a widget showing it draws without the
  /// frame of empty space a first render would otherwise leave.
  static Future<void> precache(SfSymbolConfig config) =>
      SfSymbolCache.instance.precache(config);

  /// Which [SfSymbolEffect]s the running iOS version can play.
  static Future<SfSymbolEffectSupport> effectSupport() =>
      SfSymbolsPlatform.instance.effectSupport();

  SfSymbolConfig get config {
    final colors = this.colors;
    assert(
      renderingMode != SfSymbolRenderingMode.palette ||
          (colors != null && colors.isNotEmpty && colors.length <= 3),
      'A palette symbol takes between 1 and 3 colors, got '
      '${colors?.length ?? 0}.',
    );
    return SfSymbolConfig(
      name: name,
      size: size,
      weight: weight,
      scale: scale,
      renderingMode: renderingMode,
      colors: colors ?? (color == null ? const <Color>[] : <Color>[color!]),
      variableValue: variableValue,
      effect: effect,
      effectRepeats: effectRepeats,
    );
  }

  @override
  State<SfSymbol> createState() => _SfSymbolState();
}

class _SfSymbolState extends State<SfSymbol> {
  /// The config this widget holds a cache reference for, if any.
  SfSymbolConfig? _held;
  SfSymbolTexture? _texture;

  /// Incremented for every load, so a slow load that has been superseded — or
  /// that finishes after this widget is gone — releases instead of committing.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(SfSymbol oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config != oldWidget.config) _start();
  }

  @override
  void dispose() {
    _generation++;
    final held = _held;
    _held = null;
    if (held != null) SfSymbolCache.instance.release(held);
    super.dispose();
  }

  void _start() {
    final config = widget.config;
    final generation = ++_generation;
    final cache = SfSymbolCache.instance;

    // A symbol another widget already rendered is handed over right away. A
    // build always follows initState and didUpdateWidget, so assigning here
    // is enough — and it spares the frame of empty space an async load costs.
    final cached = cache.acquireCached(config);
    if (cached != null) {
      _swap(config, cached);
      return;
    }

    _load(config, generation, cache);
  }

  Future<void> _load(
    SfSymbolConfig config,
    int generation,
    SfSymbolCache cache,
  ) async {
    final texture = await cache.acquire(config);

    // Superseded by a newer load, or the widget is gone: give the reference
    // back rather than holding a symbol nobody is showing.
    if (generation != _generation || !mounted) {
      if (texture != null) cache.release(config);
      return;
    }

    setState(() => _swap(config, texture));
  }

  /// Adopts [texture] and releases whatever was held before, in that order, so
  /// a symbol shared between the two configs never blinks.
  void _swap(SfSymbolConfig config, SfSymbolTexture? texture) {
    final previous = _held;
    _held = texture == null ? null : config;
    _texture = texture;
    if (previous != null) SfSymbolCache.instance.release(previous);
  }

  @override
  Widget build(BuildContext context) {
    final texture = _texture;

    Widget child;
    if (texture != null) {
      final symbolSize = texture.size;
      child = LayoutBuilder(builder: (context, constraints) {
        if (constraints.isSatisfiedBy(symbolSize)) {
          return SizedBox.fromSize(
            size: symbolSize,
            child: Texture(textureId: texture.textureId),
          );
        }
        return AspectRatio(
          aspectRatio: symbolSize.aspectRatio,
          child: Texture(textureId: texture.textureId),
        );
      });
    } else {
      child = const SizedBox();
    }

    final semanticLabel = widget.semanticLabel;
    if (semanticLabel != null) {
      child = Semantics(label: semanticLabel, image: true, child: child);
    }
    return child;
  }
}

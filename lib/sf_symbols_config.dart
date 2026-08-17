import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How iOS applies color to a symbol.
///
/// Mirrors the rendering modes described in
/// [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols).
enum SfSymbolRenderingMode {
  /// A single flat color. The default, and the only mode iOS applies to every
  /// symbol.
  monochrome,

  /// A single color, applied at several opacities to the layers of the symbol,
  /// so its internal structure stays readable.
  hierarchical,

  /// Up to three explicit colors, assigned to the symbol's layers in order.
  palette,

  /// The symbol's own built-in colors. Symbols without a multicolor variant
  /// fall back to [monochrome].
  multicolor,
}

/// The symbol's size relative to its point size, i.e. `UIImage.SymbolScale`.
///
/// This is independent of `size`: a `.small` 40pt symbol and a `.large` 40pt
/// symbol share a text baseline but draw at different weights of presence.
enum SfSymbolScale {
  small,
  medium,
  large,
}

/// Everything that identifies one rendered symbol image.
///
/// Two configs that compare equal produce the same image, which makes this
/// usable as a cache key.
@immutable
class SfSymbolConfig {
  const SfSymbolConfig({
    required this.name,
    required this.size,
    this.weight = FontWeight.normal,
    this.scale = SfSymbolScale.medium,
    this.renderingMode = SfSymbolRenderingMode.monochrome,
    this.colors = const <Color>[],
    this.variableValue,
  });

  /// The SF Symbol name, e.g. `camera.aperture`.
  final String name;

  /// Point size of the symbol, in logical pixels.
  final double size;

  final FontWeight weight;

  final SfSymbolScale scale;

  final SfSymbolRenderingMode renderingMode;

  /// The colors the [renderingMode] draws with.
  ///
  /// Holds a single color for [SfSymbolRenderingMode.monochrome] and
  /// [SfSymbolRenderingMode.hierarchical], up to three for
  /// [SfSymbolRenderingMode.palette], and none for
  /// [SfSymbolRenderingMode.multicolor].
  final List<Color> colors;

  /// Fill level for variable symbols such as `wifi` or `speaker.wave.3`,
  /// between 0.0 and 1.0. Requires iOS 16; ignored on earlier versions.
  final double? variableValue;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SfSymbolConfig &&
        other.name == name &&
        other.size == size &&
        other.weight == weight &&
        other.scale == scale &&
        other.renderingMode == renderingMode &&
        other.variableValue == variableValue &&
        listEquals(other.colors, colors);
  }

  @override
  int get hashCode => Object.hash(
        name,
        size,
        weight,
        scale,
        renderingMode,
        variableValue,
        Object.hashAll(colors),
      );

  @override
  String toString() => 'SfSymbolConfig($name, size: $size, '
      'weight: $weight, scale: $scale, mode: $renderingMode, '
      'colors: $colors, variableValue: $variableValue)';
}

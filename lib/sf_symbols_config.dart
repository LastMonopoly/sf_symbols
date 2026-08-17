import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How the system applies color to a symbol.
///
/// Mirrors the rendering modes described in
/// [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols).
enum SfSymbolRenderingMode {
  /// A single flat color. The default, and the only mode that applies to every
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

/// An SF Symbols animation, applied with UIKit's or AppKit's
/// `addSymbolEffect`.
///
/// Requires iOS 17 or macOS 14, and [wiggle], [rotate] and [breathe] require
/// iOS 18 or macOS 15. A symbol asked for an effect the running OS does not
/// have simply stays still.
enum SfSymbolEffect {
  /// A quick nudge, up by default.
  bounce,

  /// Fades the symbol's layers in and out.
  pulse,

  /// Lights the symbol's layers up in turn — signal strength, loading.
  variableColor,

  /// Scales the symbol up and holds it there.
  scale,

  /// Shakes the symbol side to side. Requires iOS 18 or macOS 15.
  wiggle,

  /// Spins part of the symbol. Requires iOS 18 or macOS 15.
  rotate,

  /// Swells and shrinks, slowly. Requires iOS 18 or macOS 15.
  breathe,
}

/// Which symbol effects the running OS version can play.
enum SfSymbolEffectSupport {
  /// iOS 18 or macOS 15 and newer: every [SfSymbolEffect].
  full,

  /// iOS 17 or macOS 14: everything except wiggle, rotate and breathe.
  partial,

  /// Older than that, or not an Apple platform: symbols stay still.
  none,
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
    this.effect,
    this.effectRepeats = true,
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
  /// between 0.0 and 1.0. Requires iOS 16 or macOS 13; ignored on earlier
  /// versions.
  final double? variableValue;

  /// The animation to run, or null for a still symbol.
  final SfSymbolEffect? effect;

  /// Whether [effect] repeats, or plays once when the symbol appears.
  final bool effectRepeats;

  /// Whether this symbol animates, and so cannot be shared with others.
  bool get isAnimated => effect != null;

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
        other.effect == effect &&
        other.effectRepeats == effectRepeats &&
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
        effect,
        effectRepeats,
        Object.hashAll(colors),
      );

  @override
  String toString() => 'SfSymbolConfig($name, size: $size, '
      'weight: $weight, scale: $scale, mode: $renderingMode, '
      'colors: $colors, variableValue: $variableValue, effect: $effect)';
}

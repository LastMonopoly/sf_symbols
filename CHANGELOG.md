## 0.4.0

Adds the SF Symbols rendering modes, variable values, scale and accessibility.

* Add the hierarchical, palette and multicolor rendering modes via the
  `SfSymbol.hierarchical`, `SfSymbol.palette` and `SfSymbol.multicolor`
  constructors. The default constructor is unchanged and still monochrome.
* Add `variableValue`, for variable symbols such as `wifi` or
  `speaker.wave.3` (iOS 16+).
* Add `scale`, mapping to `UIImage.SymbolScale`. The default matches what
  earlier versions rendered, so symbols do not resize on upgrade.
* Add `semanticLabel`, so symbols are no longer invisible to VoiceOver.
* Add `SfSymbol.isAvailable`, to check a symbol name before using it.
* Fix the widget ignoring property changes: it only ever loaded its symbol in
  `initState`, so changing `name`, `color`, `weight` or `size` did nothing.
  It now reloads on change, swapping textures without a blink, and skips the
  work when the new configuration is equivalent.
* Fix a symbol with no variant for the requested rendering mode drawing in
  black instead of the requested color.

**Breaking:** `SfSymbolsPlatform.init` now takes a single `SfSymbolConfig`
instead of loose arguments. This only affects code implementing the platform
interface directly; the `SfSymbol` widget API is unchanged.

## 0.3.0

* Support the current Flutter and iOS toolchain (Flutter 3.27+, Dart 3, Xcode 16+).
* Add Swift Package Manager support, in addition to CocoaPods.
* Add a privacy manifest (`PrivacyInfo.xcprivacy`).
* Raise the minimum iOS deployment target to 15.0.
* Fix symbol tinting: colors are now baked into the rendered texture with
  `.alwaysOriginal`, instead of relying on the drawing context's fill color.
* Render into a `kCVPixelFormatType_32BGRA` buffer, matching what the Flutter
  engine expects, and mark the buffer Metal-compatible for Impeller.
* Notify the engine of new frames via `textureFrameAvailable`, so a symbol shows
  up without waiting for an unrelated repaint.
* Report an `UNKNOWN_SYMBOL` error instead of registering an empty texture when
  the symbol name does not exist.
* Replace the deprecated `Color.value` and `FontWeight.index` usages.
* Move the plugin's texture registry off of static state, so multiple Flutter
  engines no longer share it.
* Add unit tests and iOS integration tests.

## 0.2.0

* Add documentations

## 0.1.0

* Release functions of SF symbols

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

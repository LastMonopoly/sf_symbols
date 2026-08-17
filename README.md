# sf_symbols

<img src='https://raw.githubusercontent.com/LastMonopoly/sf_symbols/master/screenshots/demo.png' width=380 alt='The example app, showing symbol weights, scales, the four rendering modes and variable values'>

Use [SF Symbols](https://developer.apple.com/sf-symbols/) on iOS, the same way you would use
`Image(systemName:)` or `UIImage(systemName:)` in Swift.

## Requirements

| | |
| --- | --- |
| Flutter | 3.27 or newer |
| iOS | 15.0 or newer |
| Build system | Swift Package Manager or CocoaPods |

## Usage

Use `SfSymbol` like any other widget with picked name, weight, color & size.

Size corresponds to the pointSize in [UIImage.SymbolConfiguration](https://developer.apple.com/documentation/uikit/uiimage/symbolconfiguration/3294242-init), a SF symbol of size 40 will render roughly as big as 40pts x 40pts (pts is points in iOS).
```dart
SfSymbol(
    name: 'camera.aperture',
    weight: FontWeight.w900,
    color: Colors.pink,
    size: 40,
)
```

Names come from the [SF Symbols app](https://developer.apple.com/sf-symbols/). If a name does not
exist on the running iOS version, the widget renders nothing rather than throwing. Check first with
`await SfSymbol.isAvailable('camera.macro')` if you want to fall back to something else.

The widget re-renders whenever its properties change, so a symbol can be tinted on press or swapped
out as state changes.

### Rendering modes

SF Symbols draw in four modes. Each has its own constructor:

```dart
// One flat color.
SfSymbol(name: 'cloud.sun.rain.fill', color: Colors.blue, size: 40)

// One color, applied at several opacities across the symbol's layers.
SfSymbol.hierarchical(name: 'cloud.sun.rain.fill', color: Colors.blue, size: 40)

// Up to three colors, assigned to the layers in order.
SfSymbol.palette(
  name: 'cloud.sun.rain.fill',
  colors: [Colors.pink, Colors.amber, Colors.cyan],
  size: 40,
)

// The symbol's own colors. `color` tints symbols that have no multicolor variant.
SfSymbol.multicolor(name: 'cloud.sun.rain.fill', color: Colors.blue, size: 40)
```

### Variable symbols

Symbols such as `wifi`, `speaker.wave.3` and `battery.100` draw a fill level from
`variableValue`, between 0.0 and 1.0. Requires iOS 16; earlier versions draw the symbol full.

```dart
SfSymbol(name: 'wifi', color: Colors.blue, size: 40, variableValue: 0.45)
```

### Scale and accessibility

`scale` maps to [`UIImage.SymbolScale`](https://developer.apple.com/documentation/uikit/uiimage/symbolscale),
sizing the symbol relative to its point size. `semanticLabel` describes the symbol to VoiceOver.

```dart
SfSymbol(
  name: 'camera',
  color: Colors.blue,
  size: 40,
  scale: SfSymbolScale.large,
  semanticLabel: 'Camera',
)
```

## How it works
This package renders SF symbols natively from iOS as a texture, then reposition and resize the texture in Flutter. For more, check out the [texture class](https://api.flutter.dev/flutter/widgets/Texture-class.html) in Flutter.

## Running the example

```sh
cd example
flutter run -d <ios simulator or device>
```

The end-to-end tests exercise the native side and need a real simulator or device:

```sh
cd example
flutter test integration_test -d <ios simulator or device>
```

## Roadmap
- Support for macOS

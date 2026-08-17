# sf_symbols

<img src='https://raw.githubusercontent.com/LastMonopoly/sf_symbols/master/screenshots/demo.png'  width=300>

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
exist on the running iOS version, the widget renders nothing rather than throwing.

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

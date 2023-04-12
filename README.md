# sf_symbols

<img src='https://raw.githubusercontent.com/LastMonopoly/sf_symbols/master/screenshots/demo.png'  width=300>

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

## How it works
This package renders SF symbols natively from iOS as a texture, then reposition and resize the texture in Flutter. For more, check out the [texture class](https://api.flutter.dev/flutter/widgets/Texture-class.html) in Flutter.

## Roadmap
- Support for macOS
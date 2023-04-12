# sf_symbols

This package renders SF symbols natively from iOS as a bitmap, then reposition or resize it in Flutter.

## Result
![SF symbols demo on iOS](https://raw.githubusercontent.com/LastMonopoly/sf_symbols/master/screenshots/demo.png)

## Features
Use SF symbol like any widget with picked name, weight, color & size.
```dart
SfSymbol(
    name: 'camera.aperture',
    weight: FontWeight.w900,
    color: Colors.pink,
    size: 40,
)
```

## Roadmap
- Support for macOS
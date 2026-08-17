import 'package:flutter/material.dart';
import 'package:sf_symbols/sf_symbols.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  static const _tints = [
    Colors.blueAccent,
    Colors.pinkAccent,
    Colors.greenAccent,
    Colors.amberAccent,
  ];

  int _tintIndex = 0;
  double _variableValue = 0.45;

  Color get _tint => _tints[_tintIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SF Symbols'),
        actions: [
          // Changing the tint proves the widget reacts to property changes.
          IconButton(
            key: const Key('cycleTint'),
            icon: Icon(Icons.palette, color: _tint),
            onPressed: () => setState(
              () => _tintIndex = (_tintIndex + 1) % _tints.length,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const _Section('Weights'),
          Wrap(
            spacing: 4,
            runSpacing: 12,
            children: [
              for (final weight in FontWeight.values)
                SfSymbol(
                  name: 'camera',
                  size: 28,
                  weight: weight,
                  color: _tint,
                  semanticLabel: 'Camera',
                ),
            ],
          ),
          const _Section('Scale'),
          Row(
            spacing: 20,
            children: [
              for (final scale in SfSymbolScale.values)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SfSymbol(
                      name: 'camera.aperture',
                      size: 36,
                      scale: scale,
                      color: _tint,
                    ),
                    Text(scale.name, style: const TextStyle(fontSize: 11)),
                  ],
                ),
            ],
          ),
          const _Section('Rendering modes'),
          for (final name in const [
            'cloud.sun.rain.fill',
            'person.crop.circle.badge.plus',
            'square.stack.3d.up.fill',
            // No multicolor variant: falls back to the given color.
            'square.and.arrow.up',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                spacing: 24,
                children: [
                  _Labeled(
                    'mono',
                    SfSymbol(name: name, size: 40, color: _tint),
                  ),
                  _Labeled(
                    'hierarchical',
                    SfSymbol.hierarchical(name: name, size: 40, color: _tint),
                  ),
                  _Labeled(
                    'palette',
                    SfSymbol.palette(
                      name: name,
                      size: 40,
                      colors: const [
                        Colors.pinkAccent,
                        Colors.amberAccent,
                        Colors.cyanAccent,
                      ],
                    ),
                  ),
                  _Labeled(
                    'multicolor',
                    SfSymbol.multicolor(name: name, size: 40, color: _tint),
                  ),
                ],
              ),
            ),
          const _Section('Variable value'),
          Row(
            spacing: 24,
            children: [
              for (final name in const [
                'wifi',
                'speaker.wave.3.fill',
                'chart.bar.fill',
              ])
                SfSymbol(
                  name: name,
                  size: 40,
                  color: _tint,
                  variableValue: _variableValue,
                ),
            ],
          ),
          Slider(
            key: const Key('variableValue'),
            value: _variableValue,
            onChanged: (value) => setState(() => _variableValue = value),
          ),
          const _Section('Effects'),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              for (final effect in SfSymbolEffect.values)
                _Labeled(
                  effect.name,
                  SfSymbol(
                    name: 'wifi.router.fill',
                    size: 40,
                    color: _tint,
                    effect: effect,
                  ),
                  // Without a width the cells stretch to the full row, so the
                  // Wrap would only ever fit one effect per line.
                  width: 76,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          color: Colors.white54,
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child, {this.width});

  final String label;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 44, width: width, child: Center(child: child)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }
}

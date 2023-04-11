import 'package:flutter/material.dart';
import 'package:sf_symbols/sf_symbols.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool show = true;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SF Symbols'),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              show = !show;
            });
          },
          child: show
              ? Center(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 0,
                      runSpacing: 20,
                      children: [
                        for (var name in [
                          'camera',
                          'camera.macro',
                          'camera.aperture',
                          'camera.filters',
                        ])
                          for (var color in [
                            Colors.blueAccent,
                            Colors.pinkAccent,
                            Colors.greenAccent,
                            // Colors.amberAccent
                          ])
                            for (var weight in FontWeight.values)
                              SizedBox(
                                width: 40,
                                child: SfSymbol(
                                  weight: weight,
                                  color: color,
                                  name: name,
                                ),
                              ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

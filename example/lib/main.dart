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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SF Symbols example'),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {});
          },
          child: Center(
            child: SizedBox(
              width: 100,
              child: SfSymbol(
                key: UniqueKey(),
                weight: FontWeight.w900,
                color: const Color(0xFF00acc1),
                name: 'pencil.circle',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

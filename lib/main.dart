import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/home_screen.dart';

void main() => runApp(const TacticsApp());

class TacticsApp extends StatelessWidget {
  const TacticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tactics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _MapLoader(asset: 'assets/maps/skirmish_01.json'),
    );
  }
}

class _MapLoader extends StatefulWidget {
  const _MapLoader({required this.asset});

  final String asset;

  @override
  State<_MapLoader> createState() => _MapLoaderState();
}

class _MapLoaderState extends State<_MapLoader> {
  late final Future<Map<String, dynamic>> _map = rootBundle
      .loadString(widget.asset)
      .then((text) => jsonDecode(text) as Map<String, dynamic>);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _map,
      builder: (context, snapshot) => snapshot.hasData
          ? HomeScreen(mapJson: snapshot.data!)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

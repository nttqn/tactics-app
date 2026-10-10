import 'package:flutter/material.dart';

import '../ai/ai_player.dart';
import 'game_screen.dart';

/// Mode select: one of three computer opponents, or two players.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.mapJson});

  final Map<String, dynamic> mapJson;

  void _start(BuildContext context, AiLevel? level) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(mapJson: mapJson, aiLevel: level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget option(String label, AiLevel? level) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 240,
        height: 52,
        child: level == null
            ? OutlinedButton(
                onPressed: () => _start(context, level),
                child: Text(label),
              )
            : FilledButton(
                onPressed: () => _start(context, level),
                child: Text(label),
              ),
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xFF1B1F2A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tactics',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Play against the computer'),
                const SizedBox(height: 24),
                option('Easy', AiLevel.easy),
                option('Normal', AiLevel.normal),
                option('Hard', AiLevel.hard),
                const SizedBox(height: 12),
                option('2 players, one device', null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

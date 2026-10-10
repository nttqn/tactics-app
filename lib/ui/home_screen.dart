import 'dart:math';

import 'package:flutter/material.dart';

import '../ai/ai_player.dart';
import '../core/map_generator.dart';
import 'campaign_screen.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'my_maps_screen.dart';

/// Mode select: campaign, a one-off battle against the computer on a random
/// map, or two players on one device.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Widget _randomBattle(AiLevel? level) => GameScreen(
    mapJson: generateMap(MapSpec(seed: Random().nextInt(1 << 20))),
    aiLevel: level,
  );

  Future<void> _pickSkirmish(BuildContext context) async {
    final level = await showModalBottomSheet<AiLevel>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose the computer\'s skill'),
            ),
            for (final level in AiLevel.values)
              ListTile(
                title: Text(
                  level.name[0].toUpperCase() + level.name.substring(1),
                ),
                onTap: () => Navigator.of(sheet).pop(level),
              ),
          ],
        ),
      ),
    );
    if (level != null && context.mounted) _open(context, _randomBattle(level));
  }

  @override
  Widget build(BuildContext context) {
    Widget option(
      String label,
      VoidCallback onPressed, {
      bool primary = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 240,
        height: 52,
        child: primary
            ? FilledButton(onPressed: onPressed, child: Text(label))
            : OutlinedButton(onPressed: onPressed, child: Text(label)),
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
                const SizedBox(height: 32),
                option(
                  'Campaign',
                  () => _open(context, const CampaignScreen()),
                  primary: true,
                ),
                option('Skirmish', () => _pickSkirmish(context)),
                option(
                  '2 players, one device',
                  () => _open(context, _randomBattle(null)),
                ),
                option(
                  'Map editor',
                  () => _open(context, const MyMapsScreen()),
                ),
                option(
                  'How to play',
                  () => _open(context, const HowToPlayScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

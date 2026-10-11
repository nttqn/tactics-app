import 'dart:math';

import 'package:flutter/material.dart';

import '../campaign/progress.dart';
import '../core/map_generator.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import 'achievements_screen.dart';
import 'battle_setup.dart';
import 'campaign_screen.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'my_maps_screen.dart';

/// Mode select: continue a saved match, campaign, a one-off battle against
/// the computer on a random map, two players on one device, and extras.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<SavedMatch?> _saved = SaveService.load();

  /// Opens [screen] and refreshes the Continue button when it closes.
  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (!mounted) return;
    SoundService.instance.playMenuMusic();
    setState(() {
      _saved = SaveService.load();
    });
  }

  Future<void> _randomBattle({required bool vsComputer}) async {
    final setup = await showBattleSetup(context, vsComputer: vsComputer);
    if (setup == null || !mounted) return;
    _open(
      GameScreen(
        mapJson: setup.applyTo(
          generateMap(MapSpec(seed: Random().nextInt(1 << 20))),
        ),
        aiLevel: setup.level,
        label: vsComputer ? 'Skirmish' : '2 players',
      ),
    );
  }

  Future<void> _continue(SavedMatch saved) async {
    if (saved.mission != null) {
      final progress = await Progress.load();
      if (!mounted) return;
      _open(missionScreen(progress, saved.mission!, resume: saved));
    } else {
      _open(
        GameScreen(
          mapJson: saved.setup,
          aiLevel: saved.level,
          resumeFrom: saved.state,
          label: saved.label,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget option(
      String label,
      VoidCallback onPressed, {
      bool primary = false,
      String? subtitle,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 260,
        height: subtitle == null ? 52 : 62,
        child: (primary ? FilledButton.new : OutlinedButton.new)(
          onPressed: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              if (subtitle != null)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
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
                FutureBuilder(
                  future: _saved,
                  builder: (context, snapshot) {
                    final saved = snapshot.data;
                    if (saved == null) return const SizedBox.shrink();
                    return option(
                      'Continue',
                      () => _continue(saved),
                      primary: true,
                      subtitle: '${saved.label} · day ${saved.state.turn}',
                    );
                  },
                ),
                option('Campaign', () => _open(const CampaignScreen())),
                option('Skirmish', () => _randomBattle(vsComputer: true)),
                option(
                  '2 players, one device',
                  () => _randomBattle(vsComputer: false),
                ),
                option('Map editor', () => _open(const MyMapsScreen())),
                option('Achievements', () => _open(const AchievementsScreen())),
                option('How to play', () => _open(const HowToPlayScreen())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

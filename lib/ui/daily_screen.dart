import 'package:flutter/material.dart';

import '../campaign/daily.dart';
import '../services/achievements.dart';
import '../services/save_service.dart';
import 'game_screen.dart';

String _title(String name) => name[0].toUpperCase() + name.substring(1);

/// The battle for [challenge], or [resume] of one left unfinished.
Widget dailyScreen(
  DailyRecord record,
  DailyChallenge challenge, {
  SavedMatch? resume,
}) => GameScreen(
  mapJson: resume?.setup ?? challenge.setup(),
  resumeFrom: resume?.state,
  aiLevel: challenge.level,
  dailyKey: challenge.key,
  label: 'Daily challenge · ${challenge.key}',
  onPlayerWin: (days) async {
    await record.recordWin(challenge.key, days);
    if (record.streak(DateTime.now()) >= 7) {
      AchievementService.instance.unlock(['devoted']);
    }
  },
);

/// Today's rules and the player's record; returns true to start the battle.
Future<bool> showDailyBriefing(
  BuildContext context,
  DailyRecord record,
  DailyChallenge challenge,
) async {
  final best = record.best(challenge.key);
  final streak = record.streak(DateTime.now());
  final spec = challenge.spec;
  final lines = [
    'Map: ${spec.width} x ${spec.height}'
        '${spec.bridges > 0 ? ', river with ${spec.bridges} bridges' : ''}',
    'Enemy: ${_title(challenge.level.name)} computer led by '
        '${challenge.enemyCommander.title}',
    'You lead as ${challenge.playerCommander.title}',
    if (challenge.fog) 'Fog of war',
    best == null ? 'Not won yet today' : 'Your best today: $best days',
    'Win streak: $streak ${streak == 1 ? 'day' : 'days'}',
  ];
  final start = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Daily challenge'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The same battle for every player today. Win it on as few days '
            'as you can, and come back tomorrow to keep your streak.',
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $line'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('To battle!'),
        ),
      ],
    ),
  );
  return start ?? false;
}

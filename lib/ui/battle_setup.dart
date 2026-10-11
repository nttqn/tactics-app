import 'dart:math';

import 'package:flutter/material.dart';

import '../ai/ai_player.dart';
import '../core/models.dart';
import '../game/board_art.dart';

/// Choices made before a battle starts.
class BattleSetup {
  final AiLevel? level;
  final List<Commander?> commanders;
  final bool fog;
  const BattleSetup({
    required this.level,
    required this.commanders,
    required this.fog,
  });

  /// [map] with this setup's commanders and fog applied.
  Map<String, dynamic> applyTo(Map<String, dynamic> map) => {
    ...map,
    'fog': fog,
    'commanders': [for (final c in commanders) c?.name],
  };
}

String _title(String name) => name[0].toUpperCase() + name.substring(1);

/// Asks for difficulty, commanders and fog. Against the computer the enemy
/// commander is picked at random. Returns null if dismissed.
Future<BattleSetup?> showBattleSetup(
  BuildContext context, {
  required bool vsComputer,
  bool chooseLevel = true,
  bool chooseFog = true,
}) {
  var level = AiLevel.normal;
  final picks = <Commander>[Commander.warden, Commander.bold];
  var fog = false;
  return showModalBottomSheet<BattleSetup>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, setState) {
        Widget commanderRow(int player, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Color.lerp(playerColors[player], Colors.white, 0.45),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in Commander.values)
                  ChoiceChip(
                    label: Text(c.title.split(' ').first),
                    selected: picks[player] == c,
                    onSelected: (_) => setState(() => picks[player] = c),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${picks[player].power}: ${picks[player].description}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
          ],
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Prepare for battle',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (vsComputer && chooseLevel) ...[
                  const Text('Enemy skill'),
                  const SizedBox(height: 6),
                  SegmentedButton<AiLevel>(
                    segments: [
                      for (final l in AiLevel.values)
                        ButtonSegment(value: l, label: Text(_title(l.name))),
                    ],
                    selected: {level},
                    onSelectionChanged: (s) => setState(() => level = s.first),
                  ),
                  const SizedBox(height: 16),
                ],
                commanderRow(
                  0,
                  vsComputer ? 'Your commander' : 'Blue commander',
                ),
                if (!vsComputer) commanderRow(1, 'Red commander'),
                if (chooseFog)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fog of war'),
                    subtitle: const Text('See only what your units can see.'),
                    value: fog,
                    onChanged: (v) => setState(() => fog = v),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheet).pop(
                      BattleSetup(
                        level: vsComputer ? level : null,
                        commanders: [
                          picks[0],
                          vsComputer
                              ? Commander.values[Random().nextInt(
                                  Commander.values.length,
                                )]
                              : picks[1],
                        ],
                        fog: fog,
                      ),
                    ),
                    child: const Text('To battle!'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

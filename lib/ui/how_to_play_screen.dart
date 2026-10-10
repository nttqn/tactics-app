import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/models.dart';
import 'art_icon.dart';

String _title(String name) => name[0].toUpperCase() + name.substring(1);

/// Rules reference. Unit and terrain numbers are read from the game data,
/// so this page cannot drift from the actual rules.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const _basics = [
    'Blue moves first, then Red. On your turn every unit may move once and '
        'then attack, capture or wait.',
    'Tap a shield to select it, tap a blue tile to move, then choose an '
        'action. Undo takes back actions until you end your turn.',
    'You win by capturing the enemy castle or by defeating every enemy unit.',
    'Every building you own pays '
        '${GameState.incomePerBuilding}g at the start of your turn and heals '
        'your unit standing on it.',
    'Infantry and spearmen capture buildings. A healthy unit needs two '
        'turns; leaving the tile starts over.',
    'Recruit new units at your tent. They can act from your next turn.',
    'A wounded unit hits more weakly. The defender strikes back if the '
        'attacker is within its range.',
  ];

  /// The two unit types [type] damages most, as a readable list.
  static String _strongAgainst(UnitType type) {
    final ranked = UnitType.values.toList()
      ..sort((a, b) => type.baseDamage(b).compareTo(type.baseDamage(a)));
    return ranked.take(2).map((t) => t.name).join(', ');
  }

  static String _unitNotes(UnitType type) => [
    'Cost ${type.cost}g',
    'Move ${type.move}',
    type.minRange == type.maxRange
        ? 'Range ${type.maxRange}'
        : 'Range ${type.minRange}-${type.maxRange}',
    if (type.canCapture) 'captures',
    if (type.moveClass == MoveClass.flying) 'flies over anything',
    if (type.siege) 'cannot move and attack, never strikes back',
  ].join(' · ');

  static String _terrainNotes(Terrain t) {
    String cost(int? c) => c == null ? 'blocked' : '$c';
    return [
      'Defense ${t.defense * 10}%',
      'On foot ${cost(t.footCost)}',
      'Mounted ${cost(t.mountedCost)}',
      if (t.isBuilding) 'can be captured',
      if (t == Terrain.barracks) 'recruits units',
      if (t == Terrain.hq) 'lose it and you lose',
    ].join(' · ');
  }

  static const _terrainNames = {
    Terrain.plain: 'Grass',
    Terrain.forest: 'Forest',
    Terrain.mountain: 'Mountain',
    Terrain.water: 'Water',
    Terrain.bridge: 'Bridge',
    Terrain.city: 'Village',
    Terrain.barracks: 'Tent',
    Terrain.hq: 'Castle',
  };

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleLarge;
    return Scaffold(
      backgroundColor: const Color(0xFF1B1F2A),
      appBar: AppBar(
        title: const Text('How to play'),
        backgroundColor: const Color(0xFF1B1F2A),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final line in _basics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(line),
            ),
          const SizedBox(height: 8),
          Text('Units', style: heading),
          for (final type in UnitType.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UnitIcon(type, size: 44),
              title: Text(_title(type.name)),
              subtitle: Text(
                '${_unitNotes(type)}\nBest against: ${_strongAgainst(type)}',
              ),
              isThreeLine: true,
            ),
          const SizedBox(height: 8),
          Text('Terrain', style: heading),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Defense reduces damage taken by a unit standing there; '
              'flying units get none. Numbers are movement points to enter.',
            ),
          ),
          for (final t in Terrain.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: TerrainIcon(t, owner: 0, size: 44),
              title: Text(_terrainNames[t]!),
              subtitle: Text(_terrainNotes(t)),
            ),
        ],
      ),
    );
  }
}

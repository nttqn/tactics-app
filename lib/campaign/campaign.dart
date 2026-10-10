import '../ai/ai_player.dart';
import '../core/map_generator.dart';
import '../core/models.dart';

class Mission {
  final String name;
  final AiLevel level;
  final MapSpec spec;
  const Mission(this.name, this.level, this.spec);
}

const _i = UnitType.infantry;
const _s = UnitType.spearman;
const _a = UnitType.archer;
const _k = UnitType.knight;
const _c = UnitType.catapult;
const _g = UnitType.griffin;

/// The player is always blue (player 0). Early missions favour the player;
/// later ones give the enemy a smarter commander, more gold and more troops.
const campaign = <Mission>[
  Mission(
    'First Muster',
    AiLevel.easy,
    MapSpec(
      seed: 1,
      width: 6,
      height: 8,
      bridges: 0,
      citiesPerSide: 1,
      forest: 8,
      mountain: 0,
      funds: [300, 0],
      units: [
        [_i, _i, _i],
        [_i],
      ],
    ),
  ),
  Mission(
    'The Old Mill',
    AiLevel.easy,
    MapSpec(
      seed: 2,
      width: 6,
      height: 8,
      bridges: 0,
      citiesPerSide: 2,
      forest: 12,
      mountain: 4,
      funds: [200, 0],
      units: [
        [_i, _i, _s],
        [_i, _i],
      ],
    ),
  ),
  Mission(
    'Twin Bridges',
    AiLevel.easy,
    MapSpec(
      seed: 3,
      width: 6,
      height: 8,
      bridges: 2,
      citiesPerSide: 1,
      units: [
        [_i, _i, _a],
        [_i, _i],
      ],
    ),
  ),
  Mission(
    'Border Watch',
    AiLevel.easy,
    MapSpec(
      seed: 4,
      width: 6,
      height: 8,
      bridges: 0,
      citiesPerSide: 2,
      units: [
        [_i, _i, _k],
        [_i, _i, _s],
      ],
    ),
  ),
  Mission(
    'Harvest Road',
    AiLevel.easy,
    MapSpec(
      seed: 5,
      width: 7,
      height: 10,
      bridges: 0,
      citiesPerSide: 2,
      units: [
        [_i, _i, _s],
        [_i, _i, _s],
      ],
    ),
  ),
  Mission(
    'The Ford',
    AiLevel.easy,
    MapSpec(
      seed: 6,
      width: 7,
      height: 10,
      bridges: 1,
      citiesPerSide: 2,
      units: [
        [_i, _i, _a],
        [_i, _i, _a],
      ],
    ),
  ),
  Mission(
    'Hill Fort',
    AiLevel.normal,
    MapSpec(
      seed: 7,
      width: 7,
      height: 10,
      bridges: 0,
      citiesPerSide: 2,
      forest: 10,
      mountain: 16,
      funds: [200, 0],
      units: [
        [_i, _i, _s, _a],
        [_i, _i, _s],
      ],
    ),
  ),
  Mission(
    'Riders at Dawn',
    AiLevel.normal,
    MapSpec(
      seed: 8,
      width: 7,
      height: 10,
      bridges: 0,
      citiesPerSide: 3,
      forest: 8,
      mountain: 4,
      units: [
        [_i, _i, _s],
        [_i, _i, _k],
      ],
    ),
  ),
  Mission(
    'Broken Span',
    AiLevel.normal,
    MapSpec(
      seed: 9,
      width: 7,
      height: 10,
      bridges: 3,
      citiesPerSide: 2,
      units: [
        [_i, _i, _a, _s],
        [_i, _i, _a],
      ],
    ),
  ),
  Mission(
    'Siege Lines',
    AiLevel.normal,
    MapSpec(
      seed: 10,
      width: 7,
      height: 10,
      bridges: 0,
      citiesPerSide: 3,
      units: [
        [_i, _i, _s, _c],
        [_i, _i, _s, _c],
      ],
    ),
  ),
  Mission(
    'Greenwood',
    AiLevel.normal,
    MapSpec(
      seed: 11,
      width: 8,
      height: 10,
      bridges: 0,
      citiesPerSide: 3,
      forest: 28,
      mountain: 4,
      units: [
        [_i, _i, _a],
        [_i, _i, _a, _s],
      ],
    ),
  ),
  Mission(
    'Wings Over the River',
    AiLevel.normal,
    MapSpec(
      seed: 12,
      width: 8,
      height: 10,
      bridges: 2,
      citiesPerSide: 2,
      funds: [0, 200],
      units: [
        [_i, _i, _a],
        [_i, _i, _g],
      ],
    ),
  ),
  Mission(
    'The Long March',
    AiLevel.hard,
    MapSpec(
      seed: 13,
      width: 8,
      height: 12,
      bridges: 0,
      citiesPerSide: 3,
      funds: [300, 0],
      units: [
        [_i, _i, _s, _k],
        [_i, _i, _s],
      ],
    ),
  ),
  Mission(
    'River Crossing',
    AiLevel.hard,
    MapSpec(
      seed: 14,
      width: 8,
      height: 12,
      bridges: 2,
      citiesPerSide: 3,
      funds: [200, 0],
      units: [
        [_i, _i, _a],
        [_i, _i, _a],
      ],
    ),
  ),
  Mission(
    'Mountain Pass',
    AiLevel.hard,
    MapSpec(
      seed: 15,
      width: 8,
      height: 12,
      bridges: 0,
      citiesPerSide: 3,
      forest: 10,
      mountain: 20,
      units: [
        [_i, _i, _s, _a],
        [_i, _i, _s, _a],
      ],
    ),
  ),
  Mission(
    'Iron Tide',
    AiLevel.hard,
    MapSpec(
      seed: 16,
      width: 8,
      height: 12,
      bridges: 0,
      citiesPerSide: 4,
      units: [
        [_i, _i, _k],
        [_i, _i, _k],
      ],
    ),
  ),
  Mission(
    'Three Fords',
    AiLevel.hard,
    MapSpec(
      seed: 17,
      width: 8,
      height: 12,
      bridges: 4,
      citiesPerSide: 3,
      funds: [0, 200],
      units: [
        [_i, _i, _a, _s],
        [_i, _i, _a, _s],
      ],
    ),
  ),
  Mission(
    'Griffin Roost',
    AiLevel.hard,
    MapSpec(
      seed: 18,
      width: 8,
      height: 12,
      bridges: 2,
      citiesPerSide: 3,
      funds: [0, 300],
      units: [
        [_i, _i, _a, _a],
        [_i, _i, _g],
      ],
    ),
  ),
  Mission(
    'The Warlord',
    AiLevel.hard,
    MapSpec(
      seed: 19,
      width: 8,
      height: 12,
      bridges: 0,
      citiesPerSide: 4,
      funds: [0, 400],
      units: [
        [_i, _i, _s, _k],
        [_i, _i, _s, _k, _a],
      ],
    ),
  ),
  Mission(
    'Last Stand',
    AiLevel.hard,
    MapSpec(
      seed: 20,
      width: 8,
      height: 12,
      bridges: 2,
      citiesPerSide: 4,
      funds: [0, 500],
      units: [
        [_i, _i, _s, _a, _k],
        [_i, _i, _s, _a, _k, _c],
      ],
    ),
  ),
];

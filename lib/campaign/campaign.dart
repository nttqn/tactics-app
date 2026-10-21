import '../ai/ai_player.dart';
import '../core/map_generator.dart';
import '../core/models.dart';
import '../l10n.dart';

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
      bridges: 4,
      citiesPerSide: 3,
      funds: [200, 0],
      units: [
        [_i, _i, _a, _s],
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

/// Missions fought under fog of war (0-based).
const _fogMissions = {8, 12, 16, 18};

/// The first missions teach the basics without commander powers.
const firstMissionWithCommanders = 3;

bool missionHasFog(int index) => _fogMissions.contains(index);

bool missionHasCommanders(int index) => index >= firstMissionWithCommanders;

/// The enemy leader, rotating through the roster.
Commander? enemyCommander(int index) => missionHasCommanders(index)
    ? Commander.values[index % Commander.values.length]
    : null;

/// Days within which a win earns three stars; bigger maps get longer.
int parDays(int index) {
  final spec = campaign[index].spec;
  return switch (spec.width * spec.height) {
    <= 48 => 9,
    <= 70 => 13,
    <= 80 => 15,
    _ => 18,
  };
}

/// 3 stars within par, 2 within six days more, 1 for any win.
int starsFor(int index, int days) {
  final par = parDays(index);
  if (days <= par) return 3;
  if (days <= par + 6) return 2;
  return 1;
}

/// Map JSON plus match setup for [index], with the player leading as
/// [player] (ignored before commanders are introduced).
Map<String, dynamic> missionSetup(int index, Commander? player) => {
  ...generateMap(campaign[index].spec),
  'fog': missionHasFog(index),
  'commanders': missionHasCommanders(index)
      ? [(player ?? Commander.warden).name, enemyCommander(index)!.name]
      : [null, null],
};

const _viMissionNames = [
  'Khởi Binh',
  'Cối Xay Cũ',
  'Cầu Đôi',
  'Canh Giữ Biên Ải',
  'Đường Mùa Gặt',
  'Bến Lội',
  'Đồn Trên Đồi',
  'Kỵ Binh Lúc Bình Minh',
  'Cầu Gãy',
  'Phòng Tuyến Vây Thành',
  'Rừng Xanh',
  'Cánh Trên Dòng Sông',
  'Cuộc Hành Quân Dài',
  'Vượt Sông',
  'Đèo Núi',
  'Thủy Triều Sắt',
  'Ba Bến Lội',
  'Tổ Sư Thứu',
  'Lãnh Chúa',
  'Trận Cuối Cùng',
];

/// The mission's name in the active language.
String missionName(int index) =>
    tr(campaign[index].name, _viMissionNames[index]);

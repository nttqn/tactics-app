import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactics_app/ai/ai_player.dart';
import 'package:tactics_app/core/game_state.dart';
import 'package:tactics_app/core/models.dart';
import 'package:tactics_app/game/game_controller.dart';
import 'package:tactics_app/services/achievements.dart';
import 'package:tactics_app/services/save_service.dart';
import 'package:tactics_app/services/settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a saved match loads back and can be cleared', () async {
    expect(await SaveService.load(), isNull);
    final setup = {
      'terrain': ['h..', '...', '..h'],
      'owners': {
        '0': [
          [2, 2],
        ],
        '1': [
          [0, 0],
        ],
      },
      'units': [
        {'type': 'monk', 'owner': 0, 'x': 1, 'y': 2},
        {'type': 'infantry', 'owner': 1, 'x': 1, 'y': 0},
      ],
      'commanders': ['warden', 'swift'],
    };
    final state = GameState.fromMap(setup)..charge[0] = 40;
    await SaveService.save(
      SavedMatch(
        setup: setup,
        state: state,
        level: AiLevel.hard,
        mission: 4,
        label: 'Mission 5',
      ),
    );
    final loaded = (await SaveService.load())!;
    expect(loaded.level, AiLevel.hard);
    expect(loaded.mission, 4);
    expect(loaded.state.charge, [40, 0]);
    expect(loaded.state.unitById(0)!.type, UnitType.monk);
    await SaveService.clear();
    expect(await SaveService.load(), isNull);
  });

  test('achievements unlock once and persist', () async {
    final service = AchievementService.instance;
    await service.load();
    expect((await service.unlock(['blitz', 'nonsense'])).map((a) => a.id), [
      'blitz',
    ]);
    expect(await service.unlock(['blitz']), isEmpty);
    await service.load();
    expect(service.unlocked, {'blitz'});
  });

  test('the controller heals through the targeting flow', () {
    final c = GameController({
      'terrain': ['.....'],
      'units': [
        {'type': 'monk', 'owner': 0, 'x': 0, 'y': 0},
        {'type': 'infantry', 'owner': 0, 'x': 2, 'y': 0, 'hp': 50},
        {'type': 'infantry', 'owner': 1, 'x': 4, 'y': 0},
      ],
    });
    c.tapTile(const Pos(0, 0));
    c.tapTile(const Pos(1, 0));
    expect(c.healTargets.single.id, 1);
    c.chooseHeal();
    expect(c.healing, isTrue);
    expect(c.forecast, isNull);
    c.confirmAttack();
    expect(c.state.unitById(1)!.hp, 80);
  });

  test('battle speed cycles x1, x2, x4 and is remembered', () async {
    await Settings.load();
    expect(Settings.speed.value, 1);
    await Settings.cycleSpeed();
    await Settings.cycleSpeed();
    expect(Settings.speed.value, 4);
    Settings.speed.value = 1;
    await Settings.load();
    expect(Settings.speed.value, 4);
    await Settings.cycleSpeed();
    expect(Settings.speed.value, 1);
  });
}

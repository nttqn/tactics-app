import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tactics_app/core/actions.dart';
import 'package:tactics_app/core/game_state.dart';
import 'package:tactics_app/core/models.dart';
import 'package:tactics_app/core/rules.dart';

Map<String, dynamic> u(String type, int owner, int x, int y, {int? hp}) => {
  'type': type,
  'owner': owner,
  'x': x,
  'y': y,
  'hp': ?hp,
};

GameState state(
  List<String> rows,
  List<Map<String, dynamic>> units, {
  Map<String, dynamic>? owners,
  List<int>? funds,
}) => GameState.fromMap({
  'terrain': rows,
  'units': units,
  'owners': ?owners,
  'funds': ?funds,
});

Set<int> xs(Iterable<Pos> tiles) => {for (final p in tiles) p.x};

void main() {
  group('movement', () {
    test('foot unit walks 3 plains', () {
      final s = state(['.......'], [u('infantry', 0, 0, 0)]);
      expect(xs(s.reachable(s.units.first).destinations), {0, 1, 2, 3});
    });

    test('forest costs foot units 2', () {
      final s = state(['.f.....'], [u('infantry', 0, 0, 0)]);
      expect(xs(s.reachable(s.units.first).destinations), {0, 1, 2});
    });

    test(
      'mountain blocks mounted, water blocks ground, flyers ignore both',
      () {
        final s = state(
          ['.^.~.', '.....'],
          [u('knight', 0, 0, 0), u('infantry', 0, 2, 0), u('griffin', 0, 4, 1)],
        );
        final knight = s.reachable(s.units[0]);
        expect(knight.cost.containsKey(const Pos(1, 0)), isFalse);
        final infantry = s.reachable(s.units[1]);
        expect(infantry.cost.containsKey(const Pos(3, 0)), isFalse);
        expect(infantry.cost[const Pos(1, 0)], 3);
        final griffin = s.reachable(s.units[2]);
        expect(griffin.cost[const Pos(3, 0)], 2);
        expect(griffin.cost[const Pos(1, 0)], 4);
      },
    );

    test('enemies block, friends can be passed but not stopped on', () {
      final blocked = state(
        ['.....'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 2, 0)],
      );
      expect(xs(blocked.reachable(blocked.units.first).destinations), {0, 1});

      final passed = state(
        ['.....'],
        [u('infantry', 0, 0, 0), u('infantry', 0, 1, 0)],
      );
      final moves = passed.reachable(passed.units.first);
      expect(xs(moves.destinations), {0, 2, 3});
      expect(moves.pathTo(const Pos(3, 0)), const [
        Pos(0, 0),
        Pos(1, 0),
        Pos(2, 0),
        Pos(3, 0),
      ]);
    });
  });

  group('combat', () {
    test('melee deals terrain-reduced damage and takes a weaker counter', () {
      final s = state(
        ['....'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 2, 0)],
      );
      final events = s.apply(
        const UnitAction(0, Pos(1, 0), ActionKind.attack, Pos(2, 0)),
      );
      expect(s.unitById(1)!.hp, 51);
      expect(s.unitById(0)!.hp, 71);
      expect(events.whereType<UnitDamaged>().map((e) => e.isCounter), [
        false,
        true,
      ]);
    });

    test('archer and melee cannot counter each other', () {
      final s = state(
        ['.....'],
        [u('archer', 0, 0, 0), u('infantry', 1, 3, 0)],
      );
      s.apply(const UnitAction(0, Pos(1, 0), ActionKind.attack, Pos(3, 0)));
      expect(s.unitById(1)!.hp, 46);
      expect(s.unitById(0)!.hp, 100);

      s.apply(const EndTurnAction());
      s.apply(const UnitAction(1, Pos(2, 0), ActionKind.attack, Pos(1, 0)));
      expect(s.unitById(0)!.hp, 71);
      expect(s.unitById(1)!.hp, 46);
    });

    test('siege unit cannot move and attack', () {
      final s = state(
        ['......'],
        [u('catapult', 0, 0, 0), u('infantry', 1, 4, 0)],
      );
      expect(
        () => s.apply(
          const UnitAction(0, Pos(1, 0), ActionKind.attack, Pos(4, 0)),
        ),
        throwsArgumentError,
      );
      expect(s.unitById(0)!.pos, const Pos(0, 0));
      s.apply(const UnitAction(0, Pos(0, 0), ActionKind.attack, Pos(4, 0)));
      expect(s.unitById(1)!.hp, 24);
    });

    test('destroying the last enemy unit wins', () {
      final s = state(
        ['...'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 2, 0, hp: 10)],
      );
      final events = s.apply(
        const UnitAction(0, Pos(1, 0), ActionKind.attack, Pos(2, 0)),
      );
      expect(s.winner, 0);
      expect(events.whereType<UnitDied>(), hasLength(1));
      expect(events.last, isA<GameOver>());
      expect(() => s.apply(const EndTurnAction()), throwsStateError);
    });
  });

  group('capture', () {
    test('full-HP infantry takes a city in two turns, then earns income', () {
      final s = state(
        ['.c...'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 4, 0)],
      );
      s.apply(const UnitAction(0, Pos(1, 0), ActionKind.capture));
      expect(s.capture[const Pos(1, 0)], 10);
      expect(s.owners[const Pos(1, 0)], isNull);
      s.apply(const EndTurnAction());
      s.apply(const EndTurnAction());
      s.apply(const UnitAction(0, Pos(1, 0), ActionKind.capture));
      expect(s.owners[const Pos(1, 0)], 0);
      expect(s.capture, isEmpty);
      s.apply(const EndTurnAction());
      s.apply(const EndTurnAction());
      expect(s.funds, [100, 0]);
    });

    test('walking away abandons the capture', () {
      final s = state(
        ['.c...'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 4, 0)],
      );
      s.apply(const UnitAction(0, Pos(1, 0), ActionKind.capture));
      s.apply(const EndTurnAction());
      s.apply(const EndTurnAction());
      s.apply(const UnitAction(0, Pos(2, 0), ActionKind.wait));
      expect(s.capture, isEmpty);
    });

    test('capturing the enemy HQ wins', () {
      final s = state(
        ['.h.'],
        [u('infantry', 0, 0, 0), u('griffin', 1, 2, 0)],
        owners: {
          '1': [
            [1, 0],
          ],
        },
      );
      s.apply(const UnitAction(0, Pos(1, 0), ActionKind.capture));
      s.apply(const EndTurnAction());
      s.apply(const EndTurnAction());
      s.apply(const UnitAction(0, Pos(1, 0), ActionKind.capture));
      expect(s.winner, 0);
    });

    test('non-capturing units cannot capture', () {
      final s = state(['.c.'], [u('knight', 0, 0, 0)]);
      expect(
        () => s.apply(const UnitAction(0, Pos(1, 0), ActionKind.capture)),
        throwsArgumentError,
      );
    });
  });

  group('economy and turns', () {
    final owned = {
      '0': [
        [0, 0],
      ],
    };

    test('building spends funds and the new unit cannot act', () {
      final s = state(
        ['b..'],
        [u('infantry', 1, 2, 0)],
        owners: owned,
        funds: [500, 0],
      );
      expect(s.funds[0], 600);
      s.apply(const BuildAction(Pos(0, 0), UnitType.knight));
      expect(s.funds[0], 100);
      final built = s.unitAt(const Pos(0, 0))!;
      expect(built.acted, isTrue);
      expect(s.buildableAt(const Pos(0, 0)), isEmpty);
      expect(
        () => s.apply(const BuildAction(Pos(0, 0), UnitType.infantry)),
        throwsArgumentError,
      );
      s.apply(const EndTurnAction());
      s.apply(const EndTurnAction());
      expect(built.acted, isFalse);
      expect(s.turn, 2);
    });

    test('units heal on their own buildings at turn start', () {
      final s = state(['c..'], [u('infantry', 0, 0, 0, hp: 50)], owners: owned);
      expect(s.units.first.hp, 70);
    });

    test('a unit acts once per turn and only on its owner\'s turn', () {
      final s = state(
        ['.....'],
        [u('infantry', 0, 0, 0), u('infantry', 1, 4, 0)],
      );
      expect(
        () => s.apply(const UnitAction(1, Pos(4, 0), ActionKind.wait)),
        throwsArgumentError,
      );
      s.apply(const UnitAction(0, Pos(1, 0), ActionKind.wait));
      expect(
        () => s.apply(const UnitAction(0, Pos(2, 0), ActionKind.wait)),
        throwsArgumentError,
      );
    });
  });

  group('skirmish_01', () {
    final json =
        jsonDecode(File('assets/maps/skirmish_01.json').readAsStringSync())
            as Map<String, dynamic>;

    test('loads with both sides mirrored', () {
      final s = GameState.fromMap(json);
      expect((s.width, s.height), (8, 12));
      expect(s.buildingCount(0), s.buildingCount(1));
      expect(s.unitsOf(0).length, s.unitsOf(1).length);
      for (var y = 0; y < s.height; y++) {
        for (var x = 0; x < s.width; x++) {
          expect(
            s.terrainAt(Pos(x, y)),
            s.terrainAt(Pos(s.width - 1 - x, s.height - 1 - y)),
          );
        }
      }
    });

    test('random playouts never reach an invalid state', () {
      for (var seed = 0; seed < 40; seed++) {
        final rng = Random(seed);
        final s = GameState.fromMap(json);
        for (var i = 0; i < 400 && s.winner == null; i++) {
          final actions = s.legalActions();
          s.apply(actions[rng.nextInt(actions.length)]);
          expect({for (final u in s.units) u.pos}, hasLength(s.units.length));
          for (final unit in s.units) {
            expect(unit.hp, inInclusiveRange(1, 100));
            expect(
              s.terrainAt(unit.pos).moveCost(unit.type.moveClass),
              isNotNull,
            );
          }
          expect(s.funds.every((f) => f >= 0), isTrue);
          expect(s.capture.keys.every((p) => s.unitAt(p) != null), isTrue);
        }
      }
    });
  });
}

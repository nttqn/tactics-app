import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactics_app/core/game_state.dart';
import 'package:tactics_app/core/models.dart';
import 'package:tactics_app/editor/editable_map.dart';
import 'package:tactics_app/editor/map_store.dart';

/// A minimal fair map: mirrored castles and one infantry each.
EditableMap ready() => EditableMap.blank('Test', 6, 8)
  ..paintTerrain(const Pos(0, 7), Terrain.hq, 0, mirror: true)
  ..placeUnit(const Pos(1, 7), UnitType.infantry, 0, mirror: true);

void main() {
  test('mirrored edits give the other side to the other player', () {
    final map = ready();
    expect(map.terrainAt(const Pos(5, 0)), Terrain.hq);
    expect(map.owners[const Pos(0, 7)], 0);
    expect(map.owners[const Pos(5, 0)], 1);
    expect(map.units[const Pos(4, 0)], (type: UnitType.infantry, owner: 1));

    map.paintTerrain(const Pos(2, 2), Terrain.city, null, mirror: true);
    expect(map.terrainAt(const Pos(3, 5)), Terrain.city);
    expect(map.owners.containsKey(const Pos(3, 5)), isFalse);
    expect(map.problems(), isEmpty);
  });

  test('placing a second castle moves the first', () {
    final map = ready()..paintTerrain(const Pos(2, 7), Terrain.hq, 0);
    expect(map.terrainAt(const Pos(0, 7)), Terrain.plain);
    expect(map.owners[const Pos(2, 7)], 0);
    expect(map.owners.values.where((o) => o == 0), hasLength(1));
  });

  test('units never stay on terrain they cannot stand on', () {
    final map = ready()
      ..placeUnit(const Pos(2, 4), UnitType.knight, 0)
      ..placeUnit(const Pos(3, 4), UnitType.griffin, 0)
      ..paintTerrain(const Pos(2, 4), Terrain.mountain, null)
      ..paintTerrain(const Pos(3, 4), Terrain.water, null);
    expect(map.units.containsKey(const Pos(2, 4)), isFalse);
    expect(map.units[const Pos(3, 4)]!.type, UnitType.griffin);
    map.placeUnit(const Pos(3, 4), UnitType.infantry, 0);
    expect(map.units[const Pos(3, 4)]!.type, UnitType.griffin);
    // Whatever was painted, the result must still load as a match.
    GameState.fromMap(map.toJson());
  });

  test('erase removes the unit first, then the terrain', () {
    final map = ready()..paintTerrain(const Pos(1, 7), Terrain.forest, null);
    map.erase(const Pos(1, 7));
    expect(map.units.containsKey(const Pos(1, 7)), isFalse);
    expect(map.terrainAt(const Pos(1, 7)), Terrain.forest);
    map.erase(const Pos(1, 7));
    expect(map.terrainAt(const Pos(1, 7)), Terrain.plain);
  });

  test('problems explain what is missing', () {
    final blank = EditableMap.blank('Blank', 6, 8);
    expect(blank.problems(), hasLength(4));

    final cut = ready();
    for (var x = 0; x < 6; x++) {
      cut.paintTerrain(Pos(x, 3), Terrain.water, null);
    }
    expect(cut.problems(), [
      'The castles must be connected by land or a bridge.',
    ]);
    cut.paintTerrain(const Pos(2, 3), Terrain.bridge, null);
    expect(cut.problems(), isEmpty);
  });

  test('share codes round-trip and reject junk', () {
    final map = ready()..name = 'Ford';
    final copy = EditableMap.fromCode(map.toCode())!;
    expect(copy.name, 'Ford');
    expect(copy.toJson(), map.toJson());
    expect(EditableMap.fromCode('hello'), isNull);
    expect(EditableMap.fromCode('TAC1:not-base64!'), isNull);
    expect(EditableMap.fromCode('TAC1:e30='), isNull);
  });

  test('maps survive being stored and reloaded', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await MapStore.load();
    await store.add(ready());
    store.maps.first.paintTerrain(const Pos(3, 3), Terrain.forest, null);
    await store.persist();

    final reloaded = await MapStore.load();
    expect(reloaded.maps, hasLength(1));
    expect(reloaded.maps.first.terrainAt(const Pos(3, 3)), Terrain.forest);
    await reloaded.removeAt(0);
    expect((await MapStore.load()).maps, isEmpty);
  });
}

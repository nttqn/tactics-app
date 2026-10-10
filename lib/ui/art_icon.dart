import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/models.dart';
import '../game/board_art.dart';

/// A single terrain tile drawn with the board's own artwork.
class TerrainIcon extends StatelessWidget {
  const TerrainIcon(this.terrain, {super.key, this.owner, this.size = 40});

  final Terrain terrain;
  final int? owner;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _ArtPainter((canvas) {
      final state = GameState.fromMap({
        'terrain': [terrain.symbol],
        if (terrain.isBuilding && owner != null)
          'owners': {
            '$owner': [
              [0, 0],
            ],
          },
      });
      drawTerrain(canvas, state, const Pos(0, 0));
    }, (terrain, owner)),
  );
}

/// A unit's shield drawn with the board's own artwork.
class UnitIcon extends StatelessWidget {
  const UnitIcon(this.type, {super.key, this.owner = 0, this.size = 40});

  final UnitType type;
  final int owner;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _ArtPainter(
      (canvas) => drawUnit(
        canvas,
        const Offset(tile / 2, tile / 2),
        Unit(id: 0, type: type, owner: owner, pos: const Pos(0, 0)),
        spent: false,
        selected: false,
      ),
      (type, owner),
    ),
  );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.draw, this.identity);

  /// Draws into a [tile]-sized square.
  final void Function(Canvas canvas) draw;
  final Object identity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / tile);
    canvas.clipRect(const Rect.fromLTWH(0, 0, tile, tile));
    draw(canvas);
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.identity != identity;
}

import 'dart:ui';

import 'package:flame/game.dart';

import 'board_component.dart';
import 'game_controller.dart';

class TacticsGame extends FlameGame {
  TacticsGame(this.controller);

  final GameController controller;

  @override
  Color backgroundColor() => const Color(0xFF1B1F2A);

  @override
  Future<void> onLoad() async {
    final board = BoardComponent(controller);
    world.add(board);
    // Fit the whole board on screen with a small margin.
    camera.viewfinder
      ..visibleGameSize = board.size + Vector2.all(16)
      ..position = board.size / 2;
  }
}

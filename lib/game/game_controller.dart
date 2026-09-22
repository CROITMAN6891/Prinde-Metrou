import 'dart:async';

import 'package:flutter/gestures.dart';

import '../core/constants.dart';
import '../core/grid.dart';
import 'game_state.dart';

class GameController {
  GameController(this.gameState);

  final GameState gameState;
  Timer? _ticker;

  void start() {
    _ticker?.cancel();
    _ticker = Timer.periodic(GameConstants.tickInterval, (_) {
      gameState.tick();
      if (gameState.phase != GamePhase.playing) {
        _ticker?.cancel();
      }
    });
  }

  void resumeAfterCollision() {
    gameState.reset();
    start();
  }

  void onSwipeEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < GameConstants.swipeVelocityThreshold) return;

    final newDirection = velocity.dx.abs() > velocity.dy.abs()
        ? (velocity.dx > 0 ? Direction.right : Direction.left)
        : (velocity.dy > 0 ? Direction.down : Direction.up);

    gameState.queueDirection(newDirection);
  }

  void dispose() {
    _ticker?.cancel();
  }
}

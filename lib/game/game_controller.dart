import 'dart:async';

import 'package:flutter/gestures.dart';

import '../core/constants.dart';
import '../core/grid.dart';
import 'game_state.dart';
import 'progress_store.dart';

class GameController {
  GameController(this.gameState, {this.progressStore});

  final GameState gameState;
  final ProgressStore? progressStore;
  Timer? _ticker;
  Completer<void>? _resumed;

  void start() {
    _ticker?.cancel();
    if (gameState.isPaused) return;
    _ticker = Timer.periodic(gameState.tier.tickInterval, (_) {
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

  void chooseTier({required bool advance}) {
    gameState.chooseTier(advance: advance);
    if (advance) progressStore?.saveTier(gameState.tier);
    start();
  }

  /// Freezes the train exactly where it is. Safe to call repeatedly.
  void pause() {
    _ticker?.cancel();
    if (gameState.isPaused) return;
    _resumed = Completer<void>();
    gameState.pause();
  }

  void resume() {
    if (!gameState.isPaused) return;
    gameState.resume();
    _resumed?.complete();
    _resumed = null;
    if (gameState.phase == GamePhase.playing) start();
  }

  /// Completes immediately when running, otherwise once [resume] is called.
  /// Lets timed sequences (e.g. the collision messages) hold while paused.
  Future<void> waitUntilResumed() => _resumed?.future ?? Future.value();

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

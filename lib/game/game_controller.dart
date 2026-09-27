import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/grid.dart';
import 'game_state.dart';
import 'progress_store.dart';
import 'progression.dart';

class GameController {
  GameController(this.gameState, {this.progressStore});

  final GameState gameState;
  final ProgressStore? progressStore;
  Timer? _ticker;
  Completer<void>? _resumed;
  Offset _swipeTravel = Offset.zero;
  bool _swipeHandled = false;

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

  /// Switches speed mid-run (from the speed picker); the score carries on.
  void selectTier(SpeedTier tier) {
    gameState.selectTier(tier);
    progressStore?.saveTier(tier);
    if (!gameState.isPaused && gameState.phase == GamePhase.playing) start();
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

  void onSwipeStart(DragStartDetails details) {
    _swipeTravel = Offset.zero;
    _swipeHandled = false;
  }

  /// Decides the direction from the finger's accumulated travel as soon as
  /// it passes the threshold and points somewhere the train can turn, then
  /// ignores the rest of the gesture. Using travel rather than release
  /// velocity matters: the last few ms before lift-off often hook back,
  /// which flipped swipes to the opposite way. Waiting for a real turn
  /// matters too: thumb swipes arc, so their first pixels often run along
  /// the current heading (or back against it) before bending the intended
  /// way, and locking onto those swallowed the swipe.
  void onSwipeUpdate(DragUpdateDetails details) {
    if (_swipeHandled) return;
    _swipeTravel += details.delta;
    if (_swipeTravel.distance < GameConstants.swipeDistanceThreshold) return;
    final direction = directionForSwipe(_swipeTravel);
    if (!gameState.canTurn(direction)) return;
    _swipeHandled = true;
    gameState.queueDirection(direction);
  }

  @visibleForTesting
  static Direction directionForSwipe(Offset travel) =>
      travel.dx.abs() > travel.dy.abs()
          ? (travel.dx > 0 ? Direction.right : Direction.left)
          : (travel.dy > 0 ? Direction.down : Direction.up);

  void dispose() {
    _ticker?.cancel();
  }
}

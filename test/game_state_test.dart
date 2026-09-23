import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prinde_metrou/core/grid.dart';
import 'package:prinde_metrou/game/collision.dart';
import 'package:prinde_metrou/game/game_controller.dart';
import 'package:prinde_metrou/game/game_state.dart';

void main() {
  group('GameState movement', () {
    test('train moves one cell per tick in the current direction', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      final head = state.head;
      state.tick();
      expect(state.head, GridPosition(head.row, head.col + 1));
      expect(state.phase, GamePhase.playing);
    });

    test(
        'queued direction is applied on the next tick, ignoring reversal '
        'once the train has grown', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      final head = state.head;
      state.wagon = GridPosition(head.row, head.col + 1);
      state.tick(); // grows to 2 segments, still moving right

      state.queueDirection(Direction.left); // opposite of right, ignored
      state.tick();
      expect(state.direction, Direction.right);

      state.queueDirection(Direction.down);
      state.tick();
      expect(state.direction, Direction.down);
    });

    test('collecting the wagon grows the train and increments score', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      final head = state.head;
      state.wagon = GridPosition(head.row, head.col + 1);
      final lengthBefore = state.segments.length;

      state.tick();

      expect(state.score, 1);
      expect(state.segments.length, lengthBefore + 1);
      expect(state.wagon, isNot(GridPosition(head.row, head.col + 1)));
    });
  });

  group('GameState collisions', () {
    test('hitting the right wall sets phase=colliding with side=right', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      for (var i = 0; i < 10 && state.phase == GamePhase.playing; i++) {
        state.tick();
      }
      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.right);
    });

    test('hitting the top wall sets side=top', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      state.queueDirection(Direction.up);
      for (var i = 0; i < 10 && state.phase == GamePhase.playing; i++) {
        state.tick();
      }
      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.top);
    });

    test('ticking while colliding does not move the train further', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      for (var i = 0; i < 10 && state.phase == GamePhase.playing; i++) {
        state.tick();
      }
      final headAtCollision = state.head;
      state.tick();
      expect(state.head, headAtCollision);
    });

    test('reset() restores score to zero and phase to playing', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      for (var i = 0; i < 10 && state.phase == GamePhase.playing; i++) {
        state.tick();
      }
      expect(state.phase, GamePhase.colliding);

      state.reset();

      expect(state.phase, GamePhase.playing);
      expect(state.score, 0);
      expect(state.segments.length, 1);
    });

    test('running into own tail sets side=self', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      final head = state.head;
      // Build a 3-segment train that can turn back into itself.
      state.segments
        ..clear()
        ..addAll([
          head,
          GridPosition(head.row, head.col - 1),
          GridPosition(head.row - 1, head.col - 1),
        ]);
      state.direction = Direction.up;
      state.wagon = const GridPosition(4, 4);

      state.queueDirection(Direction.left);
      state.tick();

      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.self);
    });
  });

  group('Pause', () {
    test('paused state ignores ticks and direction changes', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      final head = state.head;
      state.pause();

      state.queueDirection(Direction.down);
      state.tick();

      expect(state.head, head);
      state.resume();
      state.tick();
      expect(state.head, GridPosition(head.row, head.col + 1));
      expect(state.direction, Direction.right);
    });

    test('controller holds waitUntilResumed until resume()', () async {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      final controller = GameController(state);
      var released = false;

      controller.pause();
      controller.pause(); // idempotent
      unawaited(controller.waitUntilResumed().then((_) => released = true));
      await Future<void>.delayed(Duration.zero);
      expect(released, isFalse);
      expect(state.isPaused, isTrue);

      controller.resume();
      await Future<void>.delayed(Duration.zero);
      expect(released, isTrue);
      expect(state.isPaused, isFalse);
      controller.dispose();
    });
  });
}

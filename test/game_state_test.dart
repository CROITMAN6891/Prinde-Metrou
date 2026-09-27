import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prinde_metrou/core/grid.dart';
import 'package:prinde_metrou/game/collision.dart';
import 'package:prinde_metrou/game/game_controller.dart';
import 'package:prinde_metrou/game/game_state.dart';
import 'package:prinde_metrou/game/progress_store.dart';
import 'package:prinde_metrou/game/progression.dart';
import 'package:prinde_metrou/game/train_skin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GameState movement', () {
    test('train moves one cell per tick in the current direction', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      final head = state.head;
      state.tick();
      expect(state.head, GridPosition(head.row, head.col + 1));
      expect(state.phase, GamePhase.playing);
    });

    test('queued direction is applied on the next tick, ignoring reversal '
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
      state.tick(); // grace tick
      state.tick();

      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.self);
    });

    test('the train holds for one tick in front of a wall before crashing',
        () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      state.wagon = const GridPosition(0, 0);
      state.tick();
      state.tick(); // head now on the last column
      final headAtWall = state.head;

      state.tick();
      expect(state.phase, GamePhase.playing);
      expect(state.head, headAtWall);

      state.tick();
      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.right);
    });

    test('a turn queued during the grace tick steers clear of the wall', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      state.wagon = const GridPosition(0, 0);
      state.tick();
      state.tick();
      state.tick(); // grace tick at the wall

      state.queueDirection(Direction.down);
      state.tick();

      expect(state.phase, GamePhase.playing);
      expect(state.direction, Direction.down);
      expect(state.head, const GridPosition(3, 4));
    });

    test('grace is granted again after the train moves on', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      state.wagon = const GridPosition(0, 0);
      state.tick();
      state.tick();
      state.tick(); // grace used at the right wall
      state.queueDirection(Direction.down);
      state.tick(); // (3, 4)
      state.tick(); // (4, 4), last row

      state.tick();
      expect(state.phase, GamePhase.playing);

      state.tick();
      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.bottom);
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

  group('Speed tiers', () {
    /// Puts the score one below [target] and the wagon right in front of
    /// the head, so the next tick lands exactly on [target].
    void tickOnto(GameState state, int target) {
      state.score = target - 1;
      state.wagon = state.head.moved(state.direction);
      state.tick();
    }

    test('reaching 25 stops the game on the tier choice', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      tickOnto(state, 24);
      expect(state.phase, GamePhase.playing);

      tickOnto(state, 25);
      expect(state.score, 25);
      expect(state.phase, GamePhase.choosingTier);

      final head = state.head;
      state.tick();
      expect(state.head, head, reason: 'train must not move while choosing');
    });

    test('advancing moves up one tier; staying keeps it', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      tickOnto(state, 25);
      state.chooseTier(advance: false);
      expect(state.tier, SpeedTier.veryEasy);
      expect(state.phase, GamePhase.playing);

      tickOnto(state, 50);
      state.chooseTier(advance: true);
      expect(state.tier, SpeedTier.light);
      expect(state.phase, GamePhase.playing);
    });

    test('no tier choice once at the top tier', () {
      final state = GameState(
        gridSize: const GridSize(columns: 5, rows: 5),
        tier: SpeedTier.hard,
      );
      tickOnto(state, 50);
      expect(state.phase, GamePhase.playing);
    });

    test('a collision resets the score but keeps the tier', () {
      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      tickOnto(state, 25);
      state.chooseTier(advance: true);

      for (var i = 0; i < 10 && state.phase == GamePhase.playing; i++) {
        state.tick();
      }
      expect(state.phase, GamePhase.colliding);
      state.reset();

      expect(state.score, 0);
      expect(state.tier, SpeedTier.light);
    });

    test('ProgressStore persists the tier reached', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();
      expect(store.tier, SpeedTier.veryEasy);

      final state = GameState(gridSize: const GridSize(columns: 5, rows: 5));
      final controller = GameController(state, progressStore: store);
      tickOnto(state, 25);
      controller.chooseTier(advance: true);
      controller.dispose();

      final reloaded = await ProgressStore.load();
      expect(reloaded.tier, SpeedTier.light);
    });

    test('new players start on Very Easy, the slowest tier, below Light', () {
      final state = GameState();
      expect(state.tier, SpeedTier.veryEasy);
      expect(
        SpeedTier.veryEasy.tickInterval,
        greaterThan(SpeedTier.light.tickInterval),
      );
      expect(SpeedTier.veryEasy.next, SpeedTier.light);
    });

    test('choosing a slower tier keeps the faster ones unlocked', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();
      await store.saveTier(SpeedTier.medium);

      await store.saveTier(SpeedTier.veryEasy);

      final reloaded = await ProgressStore.load();
      expect(reloaded.tier, SpeedTier.veryEasy);
      expect(reloaded.unlockedTier, SpeedTier.medium);
    });

    test('a tier played before unlocks were stored counts as unlocked',
        () async {
      SharedPreferences.setMockInitialValues({'speedTier': 'medium'});
      final store = await ProgressStore.load();
      expect(store.unlockedTier, SpeedTier.medium);
      expect(store.tier, SpeedTier.medium);
    });

    test('a fresh store has only Very Easy unlocked', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await ProgressStore.load()).unlockedTier, SpeedTier.veryEasy);
    });

    test('selecting a tier mid-run keeps the score and saves the choice',
        () async {
      SharedPreferences.setMockInitialValues({'speedTier': 'medium'});
      final store = await ProgressStore.load();
      final state = GameState(
        gridSize: const GridSize(columns: 5, rows: 5),
        tier: SpeedTier.medium,
      );
      final controller = GameController(state, progressStore: store);
      tickOnto(state, 3);

      controller.selectTier(SpeedTier.veryEasy);
      controller.dispose();

      expect(state.tier, SpeedTier.veryEasy);
      expect(state.score, 3);
      final reloaded = await ProgressStore.load();
      expect(reloaded.tier, SpeedTier.veryEasy);
      expect(reloaded.unlockedTier, SpeedTier.medium);
    });

    test('a tier saved before Very Easy existed still loads', () async {
      SharedPreferences.setMockInitialValues({'speedTier': 'light'});
      expect((await ProgressStore.load()).tier, SpeedTier.light);
    });
  });

  group('Celebrations', () {
    test('fire exactly at 5, 10, 15 and every multiple of 25', () {
      final fired = {
        for (var score = 0; score <= 100; score++)
          if (celebrationFor(score) != null) score: celebrationFor(score),
      };
      expect(fired, {
        5: Celebration.goodJob,
        10: Celebration.perfect,
        15: Celebration.incredible,
        25: Celebration.legend,
        50: Celebration.legend,
        75: Celebration.legend,
        100: Celebration.legend,
      });
    });
  });

  group('Train skins', () {
    test('unlock by best score and report only newly unlocked ones', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();
      expect(store.skin, TrainSkin.classic);

      expect(store.recordScore(4), isEmpty);
      expect(store.recordScore(5).map((s) => s.id), ['emerald']);
      expect(store.recordScore(5), isEmpty, reason: 'not a new best');
      expect(store.recordScore(3), isEmpty, reason: 'lower run');
      expect(store.bestScore, 5);
      expect(store.recordScore(25).map((s) => s.id), [
        'ocean',
        'violet',
        'legend',
      ]);
    });

    test('selected skin persists, but falls back if still locked', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();
      final legend = TrainSkin.byId('legend');

      await store.saveSkin(legend);
      expect(store.skin, TrainSkin.classic, reason: 'best is still 0');

      store.recordScore(25);
      expect((await ProgressStore.load()).skin, legend);
    });
  });

  group('Swipe detection', () {
    void drag(GameController controller, List<Offset> deltas) {
      controller.onSwipeStart(DragStartDetails());
      for (final delta in deltas) {
        controller.onSwipeUpdate(
          DragUpdateDetails(globalPosition: Offset.zero, delta: delta),
        );
      }
    }

    test('a rightward swipe that hooks back at lift-off stays right', () {
      final state = GameState(gridSize: const GridSize(columns: 9, rows: 9));
      state.direction = Direction.up;
      final controller = GameController(state);

      drag(controller, const [
        Offset(10, -4),
        Offset(12, -3),
        Offset(8, 2),
        Offset(-15, 1), // finger recoils as it lifts
        Offset(-20, 0),
      ]);
      state.tick();

      expect(state.direction, Direction.right);
    });

    test('diagonal swipes resolve by the dominant axis of travel', () {
      expect(
        GameController.directionForSwipe(const Offset(30, -20)),
        Direction.right,
      );
      expect(
        GameController.directionForSwipe(const Offset(-18, 25)),
        Direction.down,
      );
      expect(
        GameController.directionForSwipe(const Offset(-30, -29)),
        Direction.left,
      );
    });

    // Paths below are trimmed from swipes logged on a physical phone.
    test('a swipe whose arc starts back against the heading still turns', () {
      final state = GameState(gridSize: const GridSize(columns: 9, rows: 9));
      state.direction = Direction.down;
      state.segments = [state.head, state.head.moved(Direction.up)];
      final controller = GameController(state);

      drag(controller, const [
        Offset(-0.4, -7.3),
        Offset(-1.5, -7.3),
        Offset(-2.2, -6.9),
        Offset(-3.6, -6.2),
        Offset(-4.0, -4.4),
        Offset(-4.7, -3.6),
        Offset(-4.7, -2.5),
        Offset(-4.4, -1.5),
        Offset(-5.1, -1.8),
        Offset(-5.4, -1.1),
        Offset(-5.4, -1.1),
        Offset(-5.8, -0.7),
        Offset(-6.2, -0.4),
        Offset(-5.8, -0.7),
        Offset(-5.4, 0.0),
      ]);
      state.tick();

      expect(state.direction, Direction.left);
    });

    test(
      'a swipe that drifts along the heading before bending still turns',
      () {
        final state = GameState(gridSize: const GridSize(columns: 9, rows: 9));
        state.direction = Direction.right;
        final controller = GameController(state);

        drag(controller, const [
          Offset(3.3, -1.8),
          Offset(3.6, -1.8),
          Offset(2.9, -1.8),
          Offset(2.9, -1.8),
          Offset(2.5, -1.5),
          Offset(2.9, -1.8),
          Offset(2.5, -1.5),
          Offset(2.9, -1.5),
          Offset(2.9, -1.5),
          Offset(2.5, -1.5),
          Offset(2.5, -1.5),
          Offset(2.9, -1.8),
          Offset(2.9, -1.8),
          Offset(2.9, -2.5),
          Offset(5.4, -5.8),
          Offset(2.5, -3.6),
          Offset(2.2, -4.4),
          Offset(2.2, -4.0),
          Offset(1.5, -4.7),
          Offset(1.1, -5.1),
          Offset(1.1, -7.6),
          Offset(1.1, -9.0),
          Offset(1.0, -12.0),
          Offset(1.0, -14.0),
          Offset(1.0, -16.0),
        ]);
        state.tick();

        expect(state.direction, Direction.up);
      },
    );

    test('a swipe straight back against the heading changes nothing', () {
      final state = GameState(gridSize: const GridSize(columns: 9, rows: 9));
      state.segments = [state.head, state.head.moved(Direction.left)];
      final controller = GameController(state);

      drag(controller, const [Offset(-15, 1), Offset(-20, 0), Offset(-20, 2)]);
      state.tick();

      expect(state.direction, Direction.right);
    });

    test('tiny drags below the threshold are ignored', () {
      final state = GameState(gridSize: const GridSize(columns: 9, rows: 9));
      final controller = GameController(state);

      drag(controller, const [Offset(0, 5), Offset(0, 6)]);
      state.tick();

      expect(state.direction, Direction.right);
    });
  });
}

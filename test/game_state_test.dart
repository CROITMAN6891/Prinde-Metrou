import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// A game with no stations or portals, so a test's train is never
/// diverted or paid a bonus by wherever they happened to land.
GameState plainGame(GridSize gridSize, {SpeedTier tier = SpeedTier.veryEasy}) {
  final state = GameState(gridSize: gridSize, tier: tier);
  state.stations.clear();
  state.portals = [];
  return state;
}

void main() {
  group('GameState movement', () {
    test('train moves one cell per tick in the current direction', () {
      final state = plainGame(const GridSize(columns: 5, rows: 5));
      final head = state.head;
      state.tick();
      expect(state.head, GridPosition(head.row, head.col + 1));
      expect(state.phase, GamePhase.playing);
    });

    test('queued direction is applied on the next tick, ignoring reversal '
        'once the train has grown', () {
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
      for (var i = 0; i < 10 && state.phase == GamePhase.playing; i++) {
        state.tick();
      }
      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.right);
    });

    test('hitting the top wall sets side=top', () {
      final state = plainGame(const GridSize(columns: 5, rows: 5));
      state.queueDirection(Direction.up);
      for (var i = 0; i < 10 && state.phase == GamePhase.playing; i++) {
        state.tick();
      }
      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.top);
    });

    test('ticking while colliding does not move the train further', () {
      final state = plainGame(const GridSize(columns: 5, rows: 5));
      for (var i = 0; i < 10 && state.phase == GamePhase.playing; i++) {
        state.tick();
      }
      final headAtCollision = state.head;
      state.tick();
      expect(state.head, headAtCollision);
    });

    test('reset() restores score to zero and phase to playing', () {
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(
        const GridSize(columns: 5, rows: 5),
        tier: SpeedTier.hard,
      );
      tickOnto(state, 50);
      expect(state.phase, GamePhase.playing);
    });

    test('a collision resets the score but keeps the tier', () {
      final state = plainGame(const GridSize(columns: 5, rows: 5));
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

      final state = plainGame(const GridSize(columns: 5, rows: 5));
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
      final state = plainGame(
        const GridSize(columns: 5, rows: 5),
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

  group('Stations', () {
    test('three stations sit on cells free of the train, wagon and each '
        'other; two of them are far-apart inner portals', () {
      for (var run = 0; run < 50; run++) {
        final state = GameState();
        expect(state.stations, hasLength(3));
        expect(state.stations.toSet(), hasLength(3));
        for (final station in state.stations) {
          expect(station.isInside(state.gridSize), isTrue);
          expect(state.segments, isNot(contains(station)));
          expect(station, isNot(state.wagon));
        }

        expect(state.portals, hasLength(2));
        expect(state.stations, containsAll(state.portals));
        for (final portal in state.portals) {
          expect(portal.row, inInclusiveRange(1, state.gridSize.rows - 2));
          expect(portal.col, inInclusiveRange(1, state.gridSize.columns - 2));
        }
        final [a, b] = state.portals;
        expect(
          (a.row - b.row).abs() + (a.col - b.col).abs(),
          greaterThanOrEqualTo(4),
        );
      }
    });

    test('a grid too small for a far-apart pair plays without portals', () {
      final state = GameState(gridSize: const GridSize(columns: 3, rows: 3));
      expect(state.portals, isEmpty);
      expect(state.stations, hasLength(3));
    });

    test('stations stay put while wagons are collected', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final stations = List.of(state.stations);
      state.stations
        ..clear()
        ..addAll(stations);
      state.wagon = state.head.moved(Direction.right);
      state.tick();

      expect(state.score, 1);
      expect(state.stations, stations);
    });

    test('stations move to new cells on each new chance', () {
      final state = GameState();
      final first = List.of(state.stations);
      var moved = false;
      // Random placement could repeat once by chance; not five times.
      for (var i = 0; i < 5 && !moved; i++) {
        state.reset();
        moved = !listEquals(state.stations, first);
      }
      expect(moved, isTrue);
    });

    test('the train runs through a station like any free cell', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final ahead = state.head.moved(Direction.right);
      state.stations
        ..clear()
        ..add(ahead);
      state.wagon = const GridPosition(0, 0);

      state.tick();

      expect(state.phase, GamePhase.playing);
      expect(state.head, ahead);
    });

    test('the first pass through a station is worth a wagon', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final ahead = state.head.moved(Direction.right);
      state.stations
        ..clear()
        ..add(ahead);
      state.wagon = const GridPosition(0, 0);

      state.tick();

      expect(state.score, 1);
      expect(state.segments, hasLength(2));
      expect(state.lastGainWasBonus, isTrue);
      expect(state.claimedStations, {ahead});
      expect(state.wagon, const GridPosition(0, 0)); // no new wagon spawned
    });

    test('passing through the same station again pays nothing', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final station = state.head.moved(Direction.right);
      state.stations
        ..clear()
        ..add(station);
      state.wagon = const GridPosition(0, 0);
      state.tick(); // bonus

      // Loop back round onto the station: down, left, up, right.
      for (final turn in [
        Direction.down,
        Direction.left,
        Direction.up,
        Direction.right,
      ]) {
        state.queueDirection(turn);
        state.tick();
      }

      expect(state.head, station);
      expect(state.score, 1);
      expect(state.segments, hasLength(2));
    });

    test('each station pays out once per round, then again next round', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      state.stations
        ..clear()
        ..add(state.head.moved(Direction.right));
      state.wagon = const GridPosition(0, 0);
      state.tick();
      expect(state.claimedStations, hasLength(1));

      state.reset();

      expect(state.claimedStations, isEmpty);
      expect(state.lastGainWasBonus, isFalse);
    });

    test('a bonus that reaches a milestone opens the tier choice', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      state.score = 24;
      state.stations
        ..clear()
        ..add(state.head.moved(Direction.right));
      state.wagon = const GridPosition(0, 0);

      state.tick();

      expect(state.score, 25);
      expect(state.phase, GamePhase.choosingTier);
    });

    test('entering a portal puts the head on the other, same heading', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final entry = state.head.moved(Direction.right);
      const exit = GridPosition(1, 1);
      state.portals = [entry, exit];
      state.stations.addAll(state.portals);
      state.wagon = const GridPosition(8, 8);

      state.tick();

      expect(state.head, exit);
      expect(state.direction, Direction.right);
      expect(state.segments, isNot(contains(entry)));

      state.tick();
      expect(state.head, const GridPosition(1, 2));
    });

    test('a portal pays the bonus for the end stepped into', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final entry = state.head.moved(Direction.right);
      const exit = GridPosition(1, 1);
      state.portals = [entry, exit];
      state.stations.addAll(state.portals);
      state.wagon = const GridPosition(8, 8);

      state.tick();

      expect(state.score, 1);
      expect(state.segments, hasLength(2));
      expect(state.lastGainWasBonus, isTrue);
      expect(state.claimedStations, {entry});
    });

    test('a claimed portal still teleports, but pays nothing more', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final entry = state.head.moved(Direction.right);
      const exit = GridPosition(1, 1);
      state.portals = [entry, exit];
      state.stations.addAll(state.portals);
      state.claimedStations.add(entry);
      state.wagon = const GridPosition(8, 8);

      state.tick();

      expect(state.head, exit);
      expect(state.score, 0);
      expect(state.segments, hasLength(1));
    });

    test('wagons follow the head through the portal', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final start = state.head;
      final entry = start.moved(Direction.right);
      const exit = GridPosition(1, 1);
      state.segments = [start, start.moved(Direction.left)];
      state.portals = [entry, exit];
      state.stations.addAll(state.portals);
      state.claimedStations.addAll(state.portals);
      state.wagon = const GridPosition(8, 8);

      state.tick(); // head jumps to the exit
      state.tick(); // the first wagon comes out behind it

      expect(state.segments, [const GridPosition(1, 2), exit]);
    });

    test('an exit blocked by the train is a collision, after the grace '
        'tick', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final entry = state.head.moved(Direction.right);
      final exit = state.head.moved(Direction.left);
      state.segments = [state.head, exit, exit.moved(Direction.left)];
      state.portals = [entry, exit];
      state.stations.addAll(state.portals);
      state.wagon = const GridPosition(8, 8);

      state.tick();
      expect(state.phase, GamePhase.playing);
      state.tick();

      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.self);
    });

    test('the head may take the cell the tail is leaving', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      // A 2x2 loop: the head at (4, 4) turns up into (3, 4), where the
      // tail sits and is about to move on.
      state.segments = [
        const GridPosition(4, 4),
        const GridPosition(4, 3),
        const GridPosition(3, 3),
        const GridPosition(3, 4),
      ];
      state.direction = Direction.right;
      state.wagon = const GridPosition(8, 8);

      state.queueDirection(Direction.up);
      state.tick();

      expect(state.phase, GamePhase.playing);
      expect(state.head, const GridPosition(3, 4));
      expect(state.segments, hasLength(4));
    });

    test('the tail stays in the way when that step grows the train', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      const tail = GridPosition(3, 4);
      state.segments = [
        const GridPosition(4, 4),
        const GridPosition(4, 3),
        const GridPosition(3, 3),
        tail,
      ];
      state.direction = Direction.right;
      // Stepping onto the tail cell would also claim a station's bonus.
      state.stations.add(tail);
      state.wagon = const GridPosition(8, 8);

      state.queueDirection(Direction.up);
      state.tick(); // grace
      state.tick();

      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.self);
      expect(state.score, 0);
    });

    test('a split train collides with wagons still short of the portal', () {
      final state = plainGame(const GridSize(columns: 9, rows: 14));
      // Entry at (5, 5) approached from the left; exit at (6, 2), right
      // under the lane the rear of the train is still on.
      state.portals = [const GridPosition(5, 5), const GridPosition(6, 2)];
      state.stations.addAll(state.portals);
      state.claimedStations.addAll(state.portals);
      state.segments = [for (var c = 4; c >= 0; c--) GridPosition(5, c)];
      state.wagon = const GridPosition(13, 8);

      state.tick(); // out at (6, 2)
      state.tick(); // (6, 3)
      state.queueDirection(Direction.up); // (5, 3): a wagon, not the tail
      state.tick();
      state.tick();

      expect(state.phase, GamePhase.colliding);
      expect(state.lastCollisionSide, CollisionSide.self);
    });

    test('a split train may take the tail cell across the portal', () {
      final state = plainGame(const GridSize(columns: 9, rows: 14));
      state.portals = [const GridPosition(5, 5), const GridPosition(6, 2)];
      state.stations.addAll(state.portals);
      state.claimedStations.addAll(state.portals);
      state.segments = [for (var c = 4; c >= 1; c--) GridPosition(5, c)];
      state.wagon = const GridPosition(13, 8);

      state.tick(); // out at (6, 2)
      state.tick(); // (6, 3)
      state.queueDirection(Direction.up); // (5, 3): now the tail
      state.tick();

      expect(state.phase, GamePhase.playing);
      expect(state.head, const GridPosition(5, 3));
    });

    test('collecting a wagon is not flagged as a bonus', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      state.stations.clear();
      state.wagon = state.head.moved(Direction.right);

      state.tick();

      expect(state.score, 1);
      expect(state.lastGainWasBonus, isFalse);
    });

    test('a new wagon never lands on a station', () {
      final state = plainGame(const GridSize(columns: 3, rows: 3));
      // Once the train grows onto (1, 2), only (0, 2) is neither train
      // nor station.
      state.segments = [const GridPosition(1, 1)];
      state.stations
        ..clear()
        ..addAll(const [
          GridPosition(0, 0), GridPosition(0, 1), GridPosition(1, 0),
          GridPosition(2, 0), GridPosition(2, 1), GridPosition(2, 2),
        ]);
      state.wagon = const GridPosition(1, 2);
      state.tick(); // collects it and spawns the next

      expect(state.wagon, const GridPosition(0, 2));
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
      final state = plainGame(const GridSize(columns: 9, rows: 9));
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
      final state = plainGame(const GridSize(columns: 9, rows: 9));
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
        final state = plainGame(const GridSize(columns: 9, rows: 9));
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
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      state.segments = [state.head, state.head.moved(Direction.left)];
      final controller = GameController(state);

      drag(controller, const [Offset(-15, 1), Offset(-20, 0), Offset(-20, 2)]);
      state.tick();

      expect(state.direction, Direction.right);
    });

    test('tiny drags below the threshold are ignored', () {
      final state = plainGame(const GridSize(columns: 9, rows: 9));
      final controller = GameController(state);

      drag(controller, const [Offset(0, 5), Offset(0, 6)]);
      state.tick();

      expect(state.direction, Direction.right);
    });
  });
}

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/grid.dart';
import 'collision.dart';
import 'progression.dart';

enum GamePhase {
  playing,
  colliding,

  /// Stopped at a milestone, waiting for the player to pick a speed tier.
  choosingTier,
}

class GameState extends ChangeNotifier {
  GameState({GridSize? gridSize, this.tier = SpeedTier.veryEasy})
      : gridSize = gridSize ?? GameConstants.gridSize {
    _reset();
  }

  final GridSize gridSize;
  final Random _random = Random();

  late List<GridPosition> segments;
  late Direction direction;
  Direction? _queuedDirection;
  late GridPosition wagon;

  /// Set while the train holds for one tick in front of an obstacle, so a
  /// swipe that lands just too late can still steer it clear.
  bool _inGraceTick = false;

  /// Survives [reset]: a collision restarts the score, not the speed.
  SpeedTier tier;
  int score = 0;
  GamePhase phase = GamePhase.playing;
  CollisionSide? lastCollisionSide;

  /// Orthogonal to [phase]: the game can be paused mid-play, mid-collision
  /// or while a choice screen is up, and resumes into the same phase.
  bool isPaused = false;

  GridPosition get head => segments.first;

  /// Whether [newDirection] would change where the train goes next:
  /// not the way it already heads, and not straight back into itself.
  bool canTurn(Direction newDirection) =>
      phase == GamePhase.playing &&
      !isPaused &&
      newDirection != direction &&
      !(newDirection == direction.opposite && segments.length > 1);

  void queueDirection(Direction newDirection) {
    if (phase != GamePhase.playing || isPaused) return;
    if (newDirection == direction.opposite && segments.length > 1) return;
    _queuedDirection = newDirection;
  }

  void tick() {
    if (phase != GamePhase.playing || isPaused) return;

    if (_queuedDirection != null) {
      direction = _queuedDirection!;
      _queuedDirection = null;
    }

    final newHead = head.moved(direction);
    final CollisionSide? hit = !newHead.isInside(gridSize)
        ? _sideForOutOfBounds(newHead)
        : segments.contains(newHead)
        ? CollisionSide.self
        : null;

    if (hit != null) {
      if (_inGraceTick) {
        _collide(hit);
      } else {
        _inGraceTick = true;
      }
      return;
    }
    _inGraceTick = false;

    final grew = newHead == wagon;
    segments.insert(0, newHead);
    if (grew) {
      score += 1;
      _spawnWagon();
      if (isTierMilestone(score) && tier.next != null) {
        phase = GamePhase.choosingTier;
      }
    } else {
      segments.removeLast();
    }

    notifyListeners();
  }

  CollisionSide _sideForOutOfBounds(GridPosition attempted) {
    if (attempted.col < 0) return CollisionSide.left;
    if (attempted.col >= gridSize.columns) return CollisionSide.right;
    if (attempted.row < 0) return CollisionSide.top;
    return CollisionSide.bottom;
  }

  void _collide(CollisionSide side) {
    phase = GamePhase.colliding;
    lastCollisionSide = side;
    notifyListeners();
  }

  /// Resolves a [GamePhase.choosingTier] stop: moves up a tier or stays.
  void chooseTier({required bool advance}) {
    if (phase != GamePhase.choosingTier) return;
    if (advance) tier = tier.next ?? tier;
    phase = GamePhase.playing;
    notifyListeners();
  }

  void selectTier(SpeedTier newTier) {
    tier = newTier;
    notifyListeners();
  }

  void pause() {
    if (isPaused) return;
    isPaused = true;
    notifyListeners();
  }

  void resume() {
    if (!isPaused) return;
    isPaused = false;
    notifyListeners();
  }

  void reset() {
    _reset();
    notifyListeners();
  }

  void _reset() {
    final startRow = gridSize.rows ~/ 2;
    final startCol = gridSize.columns ~/ 2;
    segments = [GridPosition(startRow, startCol)];
    direction = Direction.right;
    _queuedDirection = null;
    _inGraceTick = false;
    score = 0;
    phase = GamePhase.playing;
    lastCollisionSide = null;
    _spawnWagon();
  }

  void _spawnWagon() {
    final freeCells = <GridPosition>[
      for (var r = 0; r < gridSize.rows; r++)
        for (var c = 0; c < gridSize.columns; c++)
          if (!segments.contains(GridPosition(r, c))) GridPosition(r, c),
    ];
    wagon = freeCells[_random.nextInt(freeCells.length)];
  }
}

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/grid.dart';
import 'collision.dart';

enum GamePhase { playing, colliding }

class GameState extends ChangeNotifier {
  GameState({GridSize? gridSize})
      : gridSize = gridSize ?? GameConstants.gridSize {
    _reset();
  }

  final GridSize gridSize;
  final Random _random = Random();

  late List<GridPosition> segments;
  late Direction direction;
  Direction? _queuedDirection;
  late GridPosition wagon;
  int score = 0;
  GamePhase phase = GamePhase.playing;
  CollisionSide? lastCollisionSide;

  /// Orthogonal to [phase]: the game can be paused mid-play, mid-collision
  /// or while a choice screen is up, and resumes into the same phase.
  bool isPaused = false;

  GridPosition get head => segments.first;

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

    if (!newHead.isInside(gridSize)) {
      _collide(_sideForOutOfBounds(newHead));
      return;
    }

    if (segments.contains(newHead)) {
      _collide(CollisionSide.self);
      return;
    }

    final grew = newHead == wagon;
    segments.insert(0, newHead);
    if (grew) {
      score += 1;
      _spawnWagon();
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

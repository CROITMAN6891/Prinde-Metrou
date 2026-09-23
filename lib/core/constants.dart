import 'grid.dart';

class GameConstants {
  GameConstants._();

  static const GridSize gridSize = GridSize(columns: 9, rows: 14);
  static const Duration collisionAnimationDuration =
      Duration(milliseconds: 550);
  static const Duration ouchMessageDuration = Duration(milliseconds: 700);
  static const Duration newChanceMessageDuration = Duration(milliseconds: 700);
  static const double swipeVelocityThreshold = 150;
}

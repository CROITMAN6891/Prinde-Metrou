enum Direction { up, down, left, right }

extension DirectionDelta on Direction {
  int get dRow {
    switch (this) {
      case Direction.up:
        return -1;
      case Direction.down:
        return 1;
      case Direction.left:
      case Direction.right:
        return 0;
    }
  }

  int get dCol {
    switch (this) {
      case Direction.left:
        return -1;
      case Direction.right:
        return 1;
      case Direction.up:
      case Direction.down:
        return 0;
    }
  }

  Direction get opposite {
    switch (this) {
      case Direction.up:
        return Direction.down;
      case Direction.down:
        return Direction.up;
      case Direction.left:
        return Direction.right;
      case Direction.right:
        return Direction.left;
    }
  }
}

class GridSize {
  const GridSize({required this.columns, required this.rows});

  final int columns;
  final int rows;
}

class GridPosition {
  const GridPosition(this.row, this.col);

  final int row;
  final int col;

  GridPosition moved(Direction direction) =>
      GridPosition(row + direction.dRow, col + direction.dCol);

  bool isInside(GridSize size) =>
      row >= 0 && row < size.rows && col >= 0 && col < size.columns;

  @override
  bool operator ==(Object other) =>
      other is GridPosition && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'GridPosition($row, $col)';
}

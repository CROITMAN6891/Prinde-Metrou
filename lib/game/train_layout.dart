import '../core/grid.dart';

/// The direction from [from] to the orthogonally adjacent [to].
Direction directionBetween(GridPosition from, GridPosition to) {
  if (to.row < from.row) return Direction.up;
  if (to.row > from.row) return Direction.down;
  return to.col < from.col ? Direction.left : Direction.right;
}

/// Which way each piece of the train faces, derived from where the pieces
/// actually are rather than from pending input, so the head only turns once
/// it has really moved.
///
/// Every piece but the tail faces the way it arrived (from the piece behind
/// it), which keeps its rear, and so its coupler, pointed straight at the
/// next piece even on corners. The tail has no piece behind it, so it faces
/// the piece ahead. A lone head uses [headDirection].
List<Direction> segmentHeadings(
  List<GridPosition> segments,
  Direction headDirection,
) {
  final last = segments.length - 1;
  return [
    for (var i = 0; i <= last; i++)
      if (last == 0)
        headDirection
      else if (i < last)
        directionBetween(segments[i + 1], segments[i])
      else
        directionBetween(segments[i], segments[i - 1]),
  ];
}

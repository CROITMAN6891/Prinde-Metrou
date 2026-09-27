import '../core/grid.dart';

/// The direction from [from] to the orthogonally adjacent [to].
Direction directionBetween(GridPosition from, GridPosition to) {
  if (to.row < from.row) return Direction.up;
  if (to.row > from.row) return Direction.down;
  return to.col < from.col ? Direction.left : Direction.right;
}

/// Whether [a] and [b] are side by side, i.e. physically coupled. Two
/// consecutive pieces are not when a portal jump lies between them.
bool areLinked(GridPosition a, GridPosition b) =>
    (a.row - b.row).abs() + (a.col - b.col).abs() == 1;

/// Which way each piece of the train faces, derived from where the pieces
/// actually are rather than from pending input, so the head only turns once
/// it has really moved.
///
/// Every piece faces the way it arrived (from the piece behind it), which
/// keeps its rear, and so its coupler, pointed straight at the next piece
/// even on corners. Where there is no linked piece behind (the tail, or the
/// first piece out of a portal) it faces the piece ahead instead; a piece
/// with neither, left just short of a portal's entry, faces that portal.
/// A lone head uses [headDirection].
List<Direction> segmentHeadings(
  List<GridPosition> segments,
  Direction headDirection, {
  List<GridPosition> portals = const [],
}) {
  final last = segments.length - 1;
  Direction headingOf(int i) {
    final here = segments[i];
    if (i < last && areLinked(segments[i + 1], here)) {
      return directionBetween(segments[i + 1], here);
    }
    if (i == 0) return headDirection;
    if (areLinked(here, segments[i - 1])) {
      return directionBetween(here, segments[i - 1]);
    }
    for (final portal in portals) {
      if (areLinked(here, portal)) return directionBetween(here, portal);
    }
    return headDirection;
  }

  return [for (var i = 0; i <= last; i++) headingOf(i)];
}

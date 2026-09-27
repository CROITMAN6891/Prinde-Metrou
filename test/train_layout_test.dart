import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prinde_metrou/core/grid.dart';
import 'package:prinde_metrou/game/game_state.dart';
import 'package:prinde_metrou/game/train_layout.dart';
import 'package:prinde_metrou/game/train_skin.dart';
import 'package:prinde_metrou/ui/widgets/metro_grid.dart';
import 'package:prinde_metrou/ui/widgets/train_segment.dart';

void main() {
  group('segmentHeadings', () {
    test('a lone head faces the direction of travel', () {
      expect(
        segmentHeadings(const [GridPosition(3, 3)], Direction.up),
        [Direction.up],
      );
    });

    test('a straight train faces its direction of travel throughout', () {
      expect(
        segmentHeadings(const [
          GridPosition(2, 4),
          GridPosition(2, 3),
          GridPosition(2, 2),
        ], Direction.right),
        [Direction.right, Direction.right, Direction.right],
      );
    });

    test('on a corner each wagon faces the way it arrived', () {
      // Travelling right, then turned down: the head is below the wagon
      // that is still on the upper row.
      expect(
        segmentHeadings(const [
          GridPosition(3, 4),
          GridPosition(2, 4),
          GridPosition(2, 3),
          GridPosition(2, 2),
        ], Direction.down),
        [Direction.down, Direction.right, Direction.right, Direction.right],
      );
    });

    test('the tail faces the piece ahead of it', () {
      expect(
        segmentHeadings(const [
          GridPosition(1, 1),
          GridPosition(2, 1),
          GridPosition(2, 2),
        ], Direction.up),
        [Direction.up, Direction.left, Direction.left],
      );
    });

    test('across a portal jump each side faces its own linked piece', () {
      // Heading right: (4, 2) is about to enter the portal at (4, 3); the
      // head and one wagon have already come out of the portal at (1, 1).
      expect(
        segmentHeadings(
          const [GridPosition(1, 2), GridPosition(1, 1), GridPosition(4, 2)],
          Direction.right,
          portals: const [GridPosition(4, 3), GridPosition(1, 1)],
        ),
        [Direction.right, Direction.right, Direction.right],
      );
    });

    test('a head fresh out of a portal keeps the direction of travel', () {
      expect(
        segmentHeadings(
          const [GridPosition(1, 1), GridPosition(4, 2), GridPosition(4, 1)],
          Direction.right,
          portals: const [GridPosition(4, 3), GridPosition(1, 1)],
        ),
        [Direction.right, Direction.right, Direction.right],
      );
    });

    test('the head only turns once it has actually moved', () {
      // A turn up has been queued, but the head is still where the
      // rightward move left it.
      expect(
        segmentHeadings(const [
          GridPosition(2, 3),
          GridPosition(2, 2),
        ], Direction.up).first,
        Direction.right,
      );
    });
  });

  testWidgets('the grid paints a train and marks only its last piece as tail', (
    tester,
  ) async {
    final state = GameState(gridSize: const GridSize(columns: 9, rows: 14));
    state.stations.clear();
    state.portals = [];
    state.wagon = state.head.moved(Direction.right);
    state.tick(); // grows onto the wagon

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 560,
          child: MetroGrid(
            gameState: state,
            collisionAnimation: const AlwaysStoppedAnimation(0),
            skin: TrainSkin.classic,
            stationLabel: 'STATION',
            portalLabel: 'PORTAL',
          ),
        ),
      ),
    );

    final pieces = tester
        .widgetList<TrainSegment>(find.byType(TrainSegment))
        .toList();
    expect(pieces, hasLength(2));
    expect(pieces.where((p) => p.isTail), hasLength(1));
    expect(pieces.singleWhere((p) => p.isTail).isHead, isFalse);
    expect(tester.takeException(), isNull);
  });
}

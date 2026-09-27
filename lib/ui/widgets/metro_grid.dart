import 'package:flutter/material.dart';

import '../../core/grid.dart';
import '../../game/game_state.dart';
import '../../game/train_layout.dart';
import '../../game/train_skin.dart';
import '../theme/metro_theme.dart';
import 'train_painter.dart';
import 'train_segment.dart';

class MetroGrid extends StatelessWidget {
  const MetroGrid({
    super.key,
    required this.gameState,
    required this.collisionAnimation,
    required this.skin,
  });

  final GameState gameState;
  final Animation<double> collisionAnimation;
  final TrainSkin skin;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([gameState, collisionAnimation]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth / gameState.gridSize.columns;
            final cellHeight = constraints.maxHeight / gameState.gridSize.rows;
            final cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;
            final gridWidth = cellSize * gameState.gridSize.columns;
            final gridHeight = cellSize * gameState.gridSize.rows;
            final colliding = gameState.phase == GamePhase.colliding;
            final segments = gameState.segments;
            final headings = segmentHeadings(segments, gameState.direction);

            return Center(
              child: SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: MetroTheme.gridLine, width: 2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: gameState.wagon.col * cellSize,
                      top: gameState.wagon.row * cellSize,
                      width: cellSize,
                      height: cellSize,
                      // A smaller copy of a real wagon, loose on the track.
                      child: Padding(
                        padding: EdgeInsets.all(cellSize * 0.12),
                        child: CustomPaint(
                          painter: TrainPiecePainter(
                            isHead: false,
                            heading: Direction.right,
                            color: MetroTheme.wagonColor,
                            coupler: false,
                          ),
                        ),
                      ),
                    ),
                    // Back to front, so the head's beams paint over the
                    // wagons rather than under them.
                    for (var i = segments.length - 1; i >= 0; i--)
                      Positioned(
                        left: segments[i].col * cellSize,
                        top: segments[i].row * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: TrainSegment(
                          isHead: i == 0,
                          // Recomputed every frame from the list, so the
                          // position lights follow whichever piece is last.
                          isTail: i == segments.length - 1,
                          heading: headings[i],
                          segmentIndex: i,
                          cellSize: cellSize,
                          skin: skin,
                          collisionSide: colliding
                              ? gameState.lastCollisionSide
                              : null,
                          collisionProgress: colliding
                              ? collisionAnimation.value
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

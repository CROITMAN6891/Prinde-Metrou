import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/train_skin.dart';
import '../theme/metro_theme.dart';
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
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: MetroTheme.wagonColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < gameState.segments.length; i++)
                      Positioned(
                        left: gameState.segments[i].col * cellSize,
                        top: gameState.segments[i].row * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: TrainSegment(
                          isHead: i == 0,
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

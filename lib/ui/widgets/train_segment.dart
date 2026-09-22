import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/collision.dart';
import '../theme/metro_theme.dart';

/// Renders a single train segment (head or wagon) and, while a collision
/// is in progress, applies the tilt (left/right) or tumble (top/bottom)
/// transform matching [collisionSide].
class TrainSegment extends StatelessWidget {
  const TrainSegment({
    super.key,
    required this.isHead,
    required this.segmentIndex,
    required this.cellSize,
    this.collisionSide,
    this.collisionProgress,
  });

  final bool isHead;
  final int segmentIndex;
  final double cellSize;
  final CollisionSide? collisionSide;
  final double? collisionProgress;

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: _buildTransform(),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: BoxDecoration(
            color: isHead ? MetroTheme.trainHead : MetroTheme.trainBody,
            borderRadius: BorderRadius.circular(cellSize * 0.25),
            border: Border.all(color: MetroTheme.gridLine, width: 1),
          ),
        ),
      ),
    );
  }

  Matrix4 _buildTransform() {
    final matrix = Matrix4.identity();
    final side = collisionSide;
    final progress = collisionProgress;
    if (side == null || progress == null) return matrix;

    matrix.setEntry(3, 2, 0.0015);
    matrix.translateByDouble(cellSize / 2, cellSize / 2, 0.0, 1.0);

    switch (side) {
      case CollisionSide.left:
      case CollisionSide.right:
        final sign = side == CollisionSide.left ? -1.0 : 1.0;
        matrix.rotateZ(sign * progress * (pi / 2.4));
      case CollisionSide.top:
      case CollisionSide.bottom:
        final delay = (segmentIndex * 0.12).clamp(0.0, 0.7);
        final local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
        final sign = side == CollisionSide.bottom ? 1.0 : -1.0;
        matrix.rotateX(sign * local * 2 * pi);
      case CollisionSide.self:
        final shake = sin(progress * pi * 8) * (cellSize * 0.08);
        matrix.translateByDouble(shake, 0.0, 0.0, 1.0);
    }

    matrix.translateByDouble(-cellSize / 2, -cellSize / 2, 0.0, 1.0);
    return matrix;
  }
}

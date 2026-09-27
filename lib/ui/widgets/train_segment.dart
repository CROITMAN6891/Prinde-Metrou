import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/grid.dart';
import '../../game/collision.dart';
import '../../game/train_skin.dart';
import 'train_painter.dart';

/// Renders a single train segment (head or wagon) and, while a collision
/// is in progress, applies the tilt (left/right) or tumble (top/bottom)
/// transform matching [collisionSide].
class TrainSegment extends StatelessWidget {
  const TrainSegment({
    super.key,
    required this.isHead,
    required this.isTail,
    required this.coupled,
    required this.heading,
    required this.segmentIndex,
    required this.cellSize,
    this.skin = TrainSkin.classic,
    this.collisionSide,
    this.collisionProgress,
  });

  final bool isHead;
  final bool isTail;

  /// Whether the next piece sits right behind this one; not the case for
  /// the tail, nor across a portal jump.
  final bool coupled;
  final Direction heading;
  final int segmentIndex;
  final double cellSize;
  final TrainSkin skin;
  final CollisionSide? collisionSide;
  final double? collisionProgress;

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: _buildTransform(),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size.square(cellSize),
        painter: TrainPiecePainter(
          isHead: isHead,
          heading: heading,
          coupler: coupled,
          tailLights: isTail,
          color: isHead ? skin.head : skin.body,
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

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/grid.dart';

/// Draws one train piece (the head or a wagon) seen from straight above;
/// also used, without coupler or lights, for the wagon waiting on the grid.
///
/// Every shape is laid out facing right, in units of the cell size [s] with
/// the origin at the cell's center; the canvas is rotated to [heading]
/// first, so each design exists once instead of once per direction.
///
/// The body is one coupler gap shorter than the cell (half at each end),
/// so neighbouring pieces sit exactly [couplerGap] apart and the coupler at
/// the rear spans that gap. Headlight beams and the coupler reach outside
/// the cell; the grid clips them at its border.
class TrainPiecePainter extends CustomPainter {
  TrainPiecePainter({
    required this.isHead,
    required this.heading,
    required this.color,
    this.coupler = true,
    this.tailLights = false,
  });

  final bool isHead;
  final Direction heading;
  final Color color;

  /// The link to the piece behind; off for the tail, which has none.
  final bool coupler;

  /// The red position lights, drawn on whichever piece is last.
  final bool tailLights;

  /// Coupler length, and so the gap between pieces, as a share of the cell.
  static const couplerGap = 0.18;

  static const _glass = Color(0xFF1D3557);
  static const _metal = Color(0xFF2B2D42);
  static const _lamp = Color(0xFFFFF3B0);
  static const _beam = Color(0xFFFFD166);
  static const _tailLight = Color(0xFFFF3B30);

  static double _angleFor(Direction heading) => switch (heading) {
    Direction.right => 0,
    Direction.down => pi / 2,
    Direction.left => pi,
    Direction.up => -pi / 2,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(_angleFor(heading));

    final length = s * (1 - couplerGap);
    final rear = -length / 2;
    final front = length / 2;
    final halfWidth = s * 0.34;
    final line = max(1.0, s * 0.02);
    final outline = Color.lerp(color, Colors.black, 0.45)!;

    if (isHead) _paintBeams(canvas, s, front);

    // Coupler, bridging the gap to the next piece behind.
    if (coupler) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          rear - s * couplerGap,
          -s * 0.07,
          rear + s * 0.02,
          s * 0.07,
          Radius.circular(s * 0.02),
        ),
        Paint()..color = _metal,
      );
    }

    // Wheel bars straddle the long edges, so only their outer half shows
    // once the body is painted over them.
    final wheelXs = isHead
        ? [rear + length * 0.2, rear + length * 0.5]
        : [rear + length * 0.22, front - length * 0.22];
    final wheelPaint = Paint()..color = _metal;
    for (final x in wheelXs) {
      for (final y in [-halfWidth, halfWidth]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, y),
              width: s * 0.2,
              height: s * 0.14,
            ),
            Radius.circular(s * 0.035),
          ),
          wheelPaint,
        );
      }
    }

    final body = isHead
        ? _headOutline(s, rear, front, halfWidth)
        : (Path()..addRRect(
            RRect.fromLTRBR(
              rear,
              -halfWidth,
              front,
              halfWidth,
              Radius.circular(s * 0.12),
            ),
          ));
    canvas.drawPath(body, Paint()..color = color);

    canvas.save();
    canvas.clipPath(body);
    if (isHead) {
      _paintHeadDetails(canvas, s, rear, front, line, outline);
    } else {
      _paintWagonDetails(canvas, s, rear, front, halfWidth, line, outline);
    }
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = line,
    );

    if (tailLights) {
      final ring = Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = line * 0.8;
      for (final y in [-s * 0.2, s * 0.2]) {
        final center = Offset(rear + s * 0.05, y);
        canvas.drawCircle(center, s * 0.04, Paint()..color = _tailLight);
        canvas.drawCircle(center, s * 0.04, ring);
      }
    }

    canvas.restore();
  }

  /// A snout: straight and full width at the back where it couples to the
  /// first wagon, narrowing through rounded shoulders to a blunt nose.
  Path _headOutline(double s, double rear, double front, double halfWidth) {
    final shoulder = rear + (front - rear) * 0.45;
    final nose = s * 0.16;
    final corner = s * 0.1;
    final bend = shoulder + (front - shoulder) * 0.6;
    return Path()
      ..moveTo(rear + corner, -halfWidth)
      ..lineTo(shoulder, -halfWidth)
      ..cubicTo(bend, -halfWidth, front, -halfWidth * 0.75, front, -nose)
      ..quadraticBezierTo(front + s * 0.05, 0, front, nose)
      ..cubicTo(front, halfWidth * 0.75, bend, halfWidth, shoulder, halfWidth)
      ..lineTo(rear + corner, halfWidth)
      ..quadraticBezierTo(rear, halfWidth, rear, halfWidth - corner)
      ..lineTo(rear, -halfWidth + corner)
      ..quadraticBezierTo(rear, -halfWidth, rear + corner, -halfWidth)
      ..close();
  }

  void _paintHeadDetails(
    Canvas canvas,
    double s,
    double rear,
    double front,
    double line,
    Color outline,
  ) {
    // Lens-shaped windshield in the front half: widest at the nose end,
    // tapering back, and stopping well short of the roof.
    final windshieldRear = rear + (front - rear) * 0.43;
    final windshieldFront = front - s * 0.12;
    final windshield = Path()
      ..moveTo(windshieldRear, -s * 0.07)
      ..quadraticBezierTo(
        windshieldFront - s * 0.05,
        -s * 0.22,
        windshieldFront,
        -s * 0.18,
      )
      ..quadraticBezierTo(
        windshieldFront + s * 0.05,
        0,
        windshieldFront,
        s * 0.18,
      )
      ..quadraticBezierTo(
        windshieldFront - s * 0.05,
        s * 0.22,
        windshieldRear,
        s * 0.07,
      )
      ..close();
    canvas.drawPath(windshield, Paint()..color = _glass);

    // Small side windows flanking the windshield, back from its wide end
    // so they sit beside the glass rather than up by the headlights.
    for (final y in [-s * 0.24, s * 0.24]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(windshieldFront - s * 0.18, y),
            width: s * 0.12,
            height: s * 0.075,
          ),
          Radius.circular(s * 0.02),
        ),
        Paint()..color = _glass,
      );
    }

    _paintRoofLines(
      canvas,
      s,
      rear + s * 0.07,
      windshieldRear - s * 0.04,
      line,
      outline,
    );

    for (final lamp in _headlights(s, front)) {
      canvas.drawCircle(lamp, s * 0.035, Paint()..color = _lamp);
    }
  }

  void _paintWagonDetails(
    Canvas canvas,
    double s,
    double rear,
    double front,
    double halfWidth,
    double line,
    Color outline,
  ) {
    // A window strip along each long side, set in from the edge and split
    // into separate panes.
    final stripStart = rear + s * 0.08;
    final stripEnd = front - s * 0.08;
    const panes = 4;
    final paneStep = (stripEnd - stripStart) / panes;
    final stripDepth = s * 0.09;
    final divider = Paint()
      ..color = color
      ..strokeWidth = max(1.0, s * 0.025);
    for (final sign in [-1.0, 1.0]) {
      final outer = sign * (halfWidth - s * 0.06);
      final inner = outer - sign * stripDepth;
      final strip = Rect.fromLTRB(
        stripStart,
        min(outer, inner),
        stripEnd,
        max(outer, inner),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(strip, Radius.circular(s * 0.02)),
        Paint()..color = _glass,
      );
      for (var i = 1; i < panes; i++) {
        final x = stripStart + paneStep * i;
        canvas.drawLine(Offset(x, strip.top), Offset(x, strip.bottom), divider);
      }
    }

    _paintRoofLines(
      canvas,
      s,
      rear + s * 0.1,
      front - s * 0.1,
      line,
      outline,
    );
  }

  /// Three lines along the direction of travel on the opaque roof.
  void _paintRoofLines(
    Canvas canvas,
    double s,
    double from,
    double to,
    double line,
    Color outline,
  ) {
    final paint = Paint()
      ..color = outline
      ..strokeWidth = line
      ..strokeCap = StrokeCap.round;
    for (final y in [-s * 0.07, 0.0, s * 0.07]) {
      canvas.drawLine(Offset(from, y), Offset(to, y), paint);
    }
  }

  /// One lamp at the nose tip and two either side of it.
  static List<Offset> _headlights(double s, double front) => [
    Offset(front - s * 0.03, 0),
    Offset(front - s * 0.08, -s * 0.13),
    Offset(front - s * 0.08, s * 0.13),
  ];

  /// A translucent triangle ahead of each headlight, its tip on the lamp.
  void _paintBeams(Canvas canvas, double s, double front) {
    final fill = Paint()..color = _beam.withValues(alpha: 0.55);
    final edge = Paint()
      ..color = _beam.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, s * 0.015);
    for (final lamp in _headlights(s, front)) {
      final reach = lamp.dx + s * 0.45;
      final beam = Path()
        ..moveTo(lamp.dx, lamp.dy)
        ..lineTo(reach, lamp.dy - s * 0.09)
        ..lineTo(reach, lamp.dy + s * 0.09)
        ..close();
      canvas.drawPath(beam, fill);
      canvas.drawPath(beam, edge);
    }
  }

  @override
  bool shouldRepaint(TrainPiecePainter old) =>
      old.isHead != isHead ||
      old.coupler != coupler ||
      old.tailLights != tailLights ||
      old.heading != heading ||
      old.color != color;
}

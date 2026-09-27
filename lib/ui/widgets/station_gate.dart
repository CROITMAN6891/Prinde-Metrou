import 'package:flutter/material.dart';

import '../theme/metro_theme.dart';

/// A station drawn as a gate the train runs through: two thick pillars at
/// the cell's side edges, joined by a curved arch that carries the station
/// name. The grid paints it over the train; the opening between the
/// pillars is left clear, so a piece passing through stays visible and
/// reads as going under the arch. It stays upright whatever way the train
/// goes, so the name is always readable.
class StationGate extends StatelessWidget {
  const StationGate({
    super.key,
    required this.cellSize,
    required this.label,
    this.claimed = false,
  });

  final double cellSize;
  final String label;

  /// Its bonus is already taken this round: the board goes grey and blank,
  /// so the player can tell at a glance which station still pays out.
  final bool claimed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _ArchPainter())),
        // The name board hangs from the top of the arch, between the
        // pillars.
        Positioned(
          left: cellSize * 0.15,
          right: cellSize * 0.15,
          top: cellSize * 0.15,
          height: cellSize * 0.22,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: cellSize * 0.03),
            decoration: BoxDecoration(
              color: claimed ? const Color(0xFF5C6773) : MetroTheme.wagonColor,
              borderRadius: BorderRadius.circular(cellSize * 0.04),
              border: Border.all(color: MetroTheme.background, width: 1),
            ),
            child: claimed
                ? null
                // Shrinks, never wraps, if the name is wider than the board.
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: cellSize * 0.17,
                        fontWeight: FontWeight.w900,
                        color: MetroTheme.background,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ArchPainter extends CustomPainter {
  static const _stone = Color(0xFFB8C1CC);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final fill = Paint()..color = _stone;
    final edge = Paint()
      ..color = MetroTheme.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03;

    // One outline: up the left pillar, over the arch, down the right
    // pillar, then back under the arch's inner curve.
    final gate = Path()
      ..moveTo(s * 0.02, s * 0.96)
      ..lineTo(s * 0.02, s * 0.3)
      ..quadraticBezierTo(s * 0.5, -s * 0.14, s * 0.98, s * 0.3)
      ..lineTo(s * 0.98, s * 0.96)
      ..lineTo(s * 0.84, s * 0.96)
      ..lineTo(s * 0.84, s * 0.36)
      ..quadraticBezierTo(s * 0.5, s * 0.06, s * 0.16, s * 0.36)
      ..lineTo(s * 0.16, s * 0.96)
      ..close();
    canvas.drawPath(gate, fill);
    canvas.drawPath(gate, edge);

    // A darker foot at the bottom of each pillar, so they read as
    // standing structures rather than stripes.
    final foot = Paint()..color = Color.lerp(_stone, Colors.black, 0.35)!;
    for (final x in [s * 0.0, s * 0.82]) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          s * 0.86,
          x + s * 0.18,
          s * 0.98,
          Radius.circular(s * 0.02),
        ),
        foot,
      );
    }
  }

  @override
  bool shouldRepaint(_ArchPainter old) => false;
}

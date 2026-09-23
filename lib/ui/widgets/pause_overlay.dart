import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/metro_theme.dart';

/// Dims the grid and waits for a tap anywhere on it before the game
/// resumes, so the player isn't surprised by a moving train on return.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.visible,
    required this.onResume,
  });

  final bool visible;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onResume,
          child: ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.pause_circle_outline,
                    size: 64,
                    color: MetroTheme.wagonColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.pausedTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tapToContinue,
                    style: const TextStyle(
                      color: MetroTheme.scoreText,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

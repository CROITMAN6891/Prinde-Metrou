import 'package:flutter/material.dart';

import '../../game/progression.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/metro_theme.dart';

/// Short, non-blocking banner at the top of the grid for wagon milestones.
/// Timing is owned by GameScreen.
class CelebrationOverlay extends StatelessWidget {
  const CelebrationOverlay({super.key, required this.celebration});

  final Celebration? celebration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (celebration) {
      Celebration.goodJob => l10n.celebrateGoodJob,
      Celebration.perfect => l10n.celebratePerfect,
      Celebration.incredible => l10n.celebrateIncredible,
      Celebration.legend => l10n.celebrateLegend,
      null => null,
    };

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.7),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: message == null
              ? const SizedBox.shrink(key: ValueKey('empty'))
              : Container(
                  key: ValueKey(celebration),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: MetroTheme.wagonColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: MetroTheme.background,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

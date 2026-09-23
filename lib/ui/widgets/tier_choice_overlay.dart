import 'package:flutter/material.dart';

import '../../game/progression.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/metro_theme.dart';

extension SpeedTierLabel on SpeedTier {
  String label(AppLocalizations l10n) => switch (this) {
        SpeedTier.light => l10n.tierLight,
        SpeedTier.medium => l10n.tierMedium,
        SpeedTier.hard => l10n.tierHard,
      };
}

/// Shown at each 25-wagon milestone while a faster tier exists: the game is
/// already stopped, and nothing resumes until one of the two buttons is hit.
class TierChoiceOverlay extends StatelessWidget {
  const TierChoiceOverlay({
    super.key,
    required this.visible,
    required this.score,
    required this.tier,
    required this.onChoose,
  });

  final bool visible;
  final int score;
  final SpeedTier tier;
  final void Function({required bool advance}) onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final next = tier.next;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                color: MetroTheme.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MetroTheme.wagonColor, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.tierChoiceTitle(score),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MetroTheme.wagonColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.tierCurrent(tier.label(l10n)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: MetroTheme.scoreText),
                  ),
                  const SizedBox(height: 18),
                  if (next != null)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: MetroTheme.wagonColor,
                        foregroundColor: MetroTheme.background,
                      ),
                      onPressed: () => onChoose(advance: true),
                      child: Text(l10n.tierAdvance(next.label(l10n))),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MetroTheme.wagonColor,
                      side: const BorderSide(color: MetroTheme.wagonColor),
                    ),
                    onPressed: () => onChoose(advance: false),
                    child: Text(l10n.tierStay),
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

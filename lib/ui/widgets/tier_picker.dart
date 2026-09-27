import 'package:flutter/material.dart';

import '../../game/progression.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/metro_theme.dart';
import 'tier_choice_overlay.dart';

/// Bottom-sheet list of speed tiers. Tiers above [unlocked] are greyed out
/// with how to reach them; tapping an unlocked one pops the sheet with it.
class TierPicker extends StatelessWidget {
  const TierPicker({super.key, required this.selected, required this.unlocked});

  final SpeedTier selected;
  final SpeedTier unlocked;

  static Future<SpeedTier?> show(
    BuildContext context, {
    required SpeedTier selected,
    required SpeedTier unlocked,
  }) {
    return showModalBottomSheet<SpeedTier>(
      context: context,
      backgroundColor: MetroTheme.background,
      // Sized to its rows rather than capped at half the screen, and
      // scrollable if even that doesn't fit.
      isScrollControlled: true,
      builder: (_) => TierPicker(selected: selected, unlocked: unlocked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.tierPickerTitle,
              style: const TextStyle(
                color: MetroTheme.scoreText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (final tier in SpeedTier.values)
              _TierRow(
                key: ValueKey('tier-${tier.name}'),
                label: tier.label(l10n),
                selected: tier == selected,
                lockedHint: tier.index <= unlocked.index
                    ? null
                    : l10n.tierLocked(
                        tierMilestoneInterval,
                        tier.previous!.label(l10n),
                      ),
                onTap: () => Navigator.of(context).pop(tier),
              ),
          ],
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    super.key,
    required this.label,
    required this.selected,
    required this.lockedHint,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// How to unlock this tier, or `null` when it is already unlocked.
  final String? lockedHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = lockedHint != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? MetroTheme.wagonColor : MetroTheme.gridLine,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Opacity(
            opacity: locked ? 0.45 : 1,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: locked
                      ? const Icon(
                          Icons.lock,
                          size: 18,
                          color: MetroTheme.scoreText,
                        )
                      : selected
                      ? const Icon(
                          Icons.check,
                          size: 20,
                          color: MetroTheme.wagonColor,
                        )
                      : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: selected
                              ? MetroTheme.wagonColor
                              : MetroTheme.scoreText,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (locked)
                        Text(
                          lockedHint!,
                          style: const TextStyle(
                            color: MetroTheme.scoreText,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

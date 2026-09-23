import 'package:flutter/material.dart';

import '../../game/train_skin.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/metro_theme.dart';

/// Bottom-sheet grid of train colors. Locked ones show the wagon count
/// needed; tapping an unlocked one pops the sheet with that skin.
class SkinPicker extends StatelessWidget {
  const SkinPicker({
    super.key,
    required this.selected,
    required this.bestScore,
  });

  final TrainSkin selected;
  final int bestScore;

  static Future<TrainSkin?> show(
    BuildContext context, {
    required TrainSkin selected,
    required int bestScore,
  }) {
    return showModalBottomSheet<TrainSkin>(
      context: context,
      backgroundColor: MetroTheme.background,
      builder: (_) => SkinPicker(selected: selected, bestScore: bestScore),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.skinPickerTitle,
              style: const TextStyle(
                color: MetroTheme.scoreText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                for (final skin in TrainSkin.all)
                  _SkinSwatch(
                    key: ValueKey('skin-${skin.id}'),
                    skin: skin,
                    selected: skin.id == selected.id,
                    unlocked: skin.isUnlockedBy(bestScore),
                    lockedLabel: l10n.skinLocked(skin.unlockAt),
                    onTap: () => Navigator.of(context).pop(skin),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinSwatch extends StatelessWidget {
  const _SkinSwatch({
    super.key,
    required this.skin,
    required this.selected,
    required this.unlocked,
    required this.lockedLabel,
    required this.onTap,
  });

  final TrainSkin skin;
  final bool selected;
  final bool unlocked;
  final String lockedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const cell = 20.0;
    Widget car(Color color) => Container(
      width: cell,
      height: cell,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(cell * 0.25),
      ),
    );

    final swatch = InkWell(
      onTap: unlocked ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? MetroTheme.wagonColor : MetroTheme.gridLine,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: unlocked ? 1 : 0.3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [car(skin.head), car(skin.body), car(skin.body)],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 18,
              child: unlocked
                  ? (selected
                        ? const Icon(
                            Icons.check,
                            size: 18,
                            color: MetroTheme.wagonColor,
                          )
                        : null)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock,
                          size: 14,
                          color: MetroTheme.scoreText,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${skin.unlockAt}',
                          style: const TextStyle(
                            color: MetroTheme.scoreText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
    return unlocked ? swatch : Tooltip(message: lockedLabel, child: swatch);
  }
}

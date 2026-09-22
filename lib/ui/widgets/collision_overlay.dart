import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

enum CollisionMessageKind { ouch, newChance }

/// Purely presentational: shows the message matching [kind] ("Ouch!" /
/// "New chance", localized) with a fade/scale transition. Timing is owned
/// by GameScreen.
class CollisionOverlay extends StatelessWidget {
  const CollisionOverlay({super.key, required this.kind});

  final CollisionMessageKind? kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (kind) {
      CollisionMessageKind.ouch => l10n.collisionOuch,
      CollisionMessageKind.newChance => l10n.collisionNewChance,
      null => null,
    };

    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: message == null
            ? const SizedBox.shrink(key: ValueKey('empty'))
            : Container(
                key: ValueKey(kind),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }
}

import 'dart:ui';

import '../ui/theme/metro_theme.dart';

/// A cosmetic train color scheme, unlocked once the player's best run
/// reaches [unlockAt] wagons.
class TrainSkin {
  const TrainSkin({
    required this.id,
    required this.head,
    required this.body,
    required this.unlockAt,
  });

  /// Stable key for persistence; never rename an existing one.
  final String id;
  final Color head;
  final Color body;
  final int unlockAt;

  bool isUnlockedBy(int bestScore) => bestScore >= unlockAt;

  static const classic = TrainSkin(
    id: 'classic',
    head: MetroTheme.trainHead,
    body: MetroTheme.trainBody,
    unlockAt: 0,
  );

  // Thresholds match the celebration milestones, so every unlock arrives
  // together with a celebration banner.
  static const all = <TrainSkin>[
    classic,
    TrainSkin(
      id: 'emerald',
      head: Color(0xFF2A9D8F),
      body: Color(0xFFD8F3DC),
      unlockAt: 5,
    ),
    TrainSkin(
      id: 'ocean',
      head: Color(0xFF1D70B8),
      body: Color(0xFFA8DADC),
      unlockAt: 10,
    ),
    TrainSkin(
      id: 'violet',
      head: Color(0xFF7B2CBF),
      body: Color(0xFFE0C3FC),
      unlockAt: 15,
    ),
    TrainSkin(
      id: 'legend',
      head: Color(0xFFFF006E),
      body: Color(0xFFFFD6E8),
      unlockAt: 25,
    ),
  ];

  static TrainSkin byId(String? id) =>
      all.firstWhere((skin) => skin.id == id, orElse: () => classic);
}

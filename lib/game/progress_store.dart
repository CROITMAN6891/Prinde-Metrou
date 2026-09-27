import 'package:shared_preferences/shared_preferences.dart';

import 'progression.dart';
import 'train_skin.dart';

/// Player progress that must survive app restarts.
class ProgressStore {
  ProgressStore(this._prefs);

  static Future<ProgressStore> load() async =>
      ProgressStore(await SharedPreferences.getInstance());

  static const _tierKey = 'speedTier';
  static const _unlockedTierKey = 'unlockedTier';
  static const _bestScoreKey = 'bestScore';
  static const _skinKey = 'trainSkin';

  final SharedPreferences _prefs;

  static SpeedTier? _tierNamed(String? name) =>
      SpeedTier.values.asNameMap()[name];

  /// The tier the player plays at; never above [unlockedTier].
  SpeedTier get tier {
    final saved = _tierNamed(_prefs.getString(_tierKey)) ?? SpeedTier.veryEasy;
    final unlocked = unlockedTier;
    return saved.index <= unlocked.index ? saved : unlocked;
  }

  /// The fastest tier ever reached through a milestone; only ever rises.
  /// Before it was stored separately, the saved [tier] was the fastest
  /// reached, so that still counts as unlocked.
  SpeedTier get unlockedTier {
    final unlocked = _tierNamed(_prefs.getString(_unlockedTierKey));
    final played = _tierNamed(_prefs.getString(_tierKey));
    return [
      SpeedTier.veryEasy,
      ?unlocked,
      ?played,
    ].reduce((a, b) => a.index >= b.index ? a : b);
  }

  /// Saves [tier] as the one to play at, unlocking it if it is new.
  Future<void> saveTier(SpeedTier tier) async {
    // Written every time, not just on a new unlock: until it is stored, the
    // unlock is inferred from [tier], which this call may be lowering.
    final unlocked = unlockedTier;
    await _prefs.setString(
      _unlockedTierKey,
      (tier.index > unlocked.index ? tier : unlocked).name,
    );
    await _prefs.setString(_tierKey, tier.name);
  }

  /// Best single-run wagon count ever; drives skin unlocks.
  int get bestScore => _prefs.getInt(_bestScoreKey) ?? 0;

  /// Records [score] if it beats the best, and returns any skins that this
  /// newly unlocked (empty in the common case).
  List<TrainSkin> recordScore(int score) {
    final previousBest = bestScore;
    if (score <= previousBest) return const [];
    _prefs.setInt(_bestScoreKey, score);
    return [
      for (final skin in TrainSkin.all)
        if (!skin.isUnlockedBy(previousBest) && skin.isUnlockedBy(score)) skin,
    ];
  }

  TrainSkin get skin {
    final saved = TrainSkin.byId(_prefs.getString(_skinKey));
    // Guards against a stored choice whose threshold was raised later.
    return saved.isUnlockedBy(bestScore) ? saved : TrainSkin.classic;
  }

  Future<void> saveSkin(TrainSkin skin) => _prefs.setString(_skinKey, skin.id);
}

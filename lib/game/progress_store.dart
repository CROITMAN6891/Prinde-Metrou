import 'package:shared_preferences/shared_preferences.dart';

import 'progression.dart';
import 'train_skin.dart';

/// Player progress that must survive app restarts.
class ProgressStore {
  ProgressStore(this._prefs);

  static Future<ProgressStore> load() async =>
      ProgressStore(await SharedPreferences.getInstance());

  static const _tierKey = 'speedTier';
  static const _bestScoreKey = 'bestScore';
  static const _skinKey = 'trainSkin';

  final SharedPreferences _prefs;

  SpeedTier get tier {
    final name = _prefs.getString(_tierKey);
    return SpeedTier.values.asNameMap()[name] ?? SpeedTier.light;
  }

  Future<void> saveTier(SpeedTier tier) =>
      _prefs.setString(_tierKey, tier.name);

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

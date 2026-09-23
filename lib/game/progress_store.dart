import 'package:shared_preferences/shared_preferences.dart';

import 'progression.dart';

/// Player progress that must survive app restarts.
class ProgressStore {
  ProgressStore(this._prefs);

  static Future<ProgressStore> load() async =>
      ProgressStore(await SharedPreferences.getInstance());

  static const _tierKey = 'speedTier';

  final SharedPreferences _prefs;

  SpeedTier get tier {
    final name = _prefs.getString(_tierKey);
    return SpeedTier.values.asNameMap()[name] ?? SpeedTier.light;
  }

  Future<void> saveTier(SpeedTier tier) => _prefs.setString(_tierKey, tier.name);
}

/// Every this many wagons in a single run, the player is offered the next
/// speed tier (as long as one exists).
const int tierMilestoneInterval = 25;

enum SpeedTier {
  light(Duration(milliseconds: 260)),
  medium(Duration(milliseconds: 200)),
  hard(Duration(milliseconds: 150));

  const SpeedTier(this.tickInterval);

  final Duration tickInterval;

  /// The tier after this one, or `null` at the top speed.
  SpeedTier? get next =>
      index + 1 < SpeedTier.values.length ? SpeedTier.values[index + 1] : null;
}

bool isTierMilestone(int score) =>
    score > 0 && score % tierMilestoneInterval == 0;

enum Celebration { goodJob, perfect, incredible, legend }

/// The message to flash when the run's score becomes [score], if any.
Celebration? celebrationFor(int score) => switch (score) {
      5 => Celebration.goodJob,
      10 => Celebration.perfect,
      15 => Celebration.incredible,
      _ when isTierMilestone(score) => Celebration.legend,
      _ => null,
    };

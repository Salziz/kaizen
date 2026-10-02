/// A fixed, discrete ladder of usage levels. Deliberately NOT a
/// continuous slider — every figure shown on screen must be a value
/// the catalogue actually holds (AC04), and a continuous input would
/// require interpolating between known points, which is a guess no
/// matter how small the gap. A fixed set of named rungs means every
/// position on the ladder is something the catalogue can genuinely
/// answer for, or genuinely not — never something in between that
/// got estimated.
enum UsageLevel {
  starter,
  growth,
  scale;

  /// Plain-words description for AC02's "basis" requirement, e.g.
  /// "assumes around 10,000 requests a month".
  String get label => switch (this) {
        UsageLevel.starter => 'around 1,000 requests a month',
        UsageLevel.growth => 'around 10,000 requests a month',
        UsageLevel.scale => 'around 100,000 requests a month',
      };

  int get requestsPerMonth => switch (this) {
        UsageLevel.starter => 1000,
        UsageLevel.growth => 10000,
        UsageLevel.scale => 100000,
      };
}

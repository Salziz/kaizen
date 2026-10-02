import '../models/usage_level.dart';
import 'shortlist_generator.dart';

/// One chosen tool's contribution to the project estimate at a given
/// usage level. `monthlyCost == null` means the catalogue genuinely
/// does not hold a figure at this rung for this tool (AC04) — never
/// computed as an invented number.
///
/// `knownLimitation != null` (or `hasKnownLimitation` / `isPartial`)
/// flags when `monthlyCost` represents a known partial figure or lower bound
/// (e.g. Stripe flat-fee-only component, excluding the volume percentage fee).
class ToolContribution {
  final String toolName;
  final double? monthlyCost; // null = unknown at this usage level
  final String currency;
  final bool isRecurring;
  final String lastChecked;
  final String? knownLimitation;

  const ToolContribution({
    required this.toolName,
    required this.monthlyCost,
    required this.currency,
    required this.isRecurring,
    required this.lastChecked,
    this.knownLimitation,
  });

  bool get hasKnownLimitation => knownLimitation != null;
  bool get isPartial => hasKnownLimitation;
}

/// The full upfront estimate for a project, across every tool the
/// user has chosen, at one point on the fixed usage ladder (AC01-06).
class ProjectEstimate {
  final UsageLevel usageLevel;
  final List<ToolContribution> contributions;

  const ProjectEstimate({
    required this.usageLevel,
    required this.contributions,
  });

  /// Plain-words usage assumption for AC02, e.g.
  /// "assumes around 10,000 requests a month".
  String get usageAssumptionLabel => 'assumes ${usageLevel.label}';

  /// The total — null if ANY chosen tool's contribution at this rung
  /// is unknown or partial (has a known limitation), since summing a
  /// known number with an unknown or incomplete one produces a number
  /// that LOOKS solid but isn't (AC04's whole point). A partial known
  /// figure is still shown per-tool; it is just not collapsed into a
  /// single misleadingly-precise grand total.
  double? get total {
    if (contributions.isEmpty) return null;
    final currency = contributions.first.currency;
    if (contributions.any((c) => c.currency != currency)) {
      return null; // mixed currencies can't be summed without a rate
    }
    if (contributions.any((c) => c.monthlyCost == null || c.hasKnownLimitation)) {
      return null;
    }
    return contributions.fold<double>(0.0, (sum, c) => sum + c.monthlyCost!);
  }

  bool get hasUnknownComponent =>
      contributions.any((c) => c.monthlyCost == null);

  bool get hasPartialComponent =>
      contributions.any((c) => c.hasKnownLimitation);

  String? get currency =>
      contributions.isEmpty ? null : contributions.first.currency;
}

/// Builds the estimate for a set of chosen tools at one usage rung.
/// AC05: callers must not invoke this with an empty selection and
/// treat the result as a real estimate — the UI layer is responsible
/// for showing "what choosing will produce" instead of calling this
/// with zero tools chosen.
ProjectEstimate buildProjectEstimate({
  required List<String> chosenToolNames,
  required UsageLevel usageLevel,
  required Map<String, ToolPriceEstimate> catalogue,
}) {
  final contributions = chosenToolNames.map((name) {
    final estimate = catalogue[name];
    if (estimate == null) {
      // Tool genuinely not in the catalogue at all — every field unknown.
      return ToolContribution(
        toolName: name,
        monthlyCost: null,
        currency: 'USD', // display currency only; cost itself is unknown
        isRecurring: true,
        lastChecked: '',
        knownLimitation: null,
      );
    }
    return ToolContribution(
      toolName: name,
      monthlyCost: estimate.costAtRequests(usageLevel.requestsPerMonth),
      currency: estimate.currency,
      isRecurring: estimate.isRecurring,
      lastChecked: estimate.lastChecked,
      knownLimitation: estimate.knownLimitation,
    );
  }).toList(growable: false);

  return ProjectEstimate(usageLevel: usageLevel, contributions: contributions);
}

/// AC02/06 coverage check — per Adaeze's coverage note: the target is
/// every tool the shortlist can currently return, at every rung, not
/// a partial pass. Call this in tests against the real catalogue and
/// the real _recommendationsFor tool list to catch silent gaps before
/// they reach a user.
List<String> findCoverageGaps({
  required List<String> allPossibleToolNames,
  required Map<String, ToolPriceEstimate> catalogue,
}) {
  final gaps = <String>[];
  for (final name in allPossibleToolNames) {
    final estimate = catalogue[name];
    if (estimate == null) {
      gaps.add('$name: not in catalogue at all');
      continue;
    }
    for (final level in UsageLevel.values) {
      final cost = estimate.costAtRequests(level.requestsPerMonth);
      if (cost == null) {
        gaps.add('$name: unknown at ${level.name} (${level.label})');
      }
    }
  }
  return gaps;
}

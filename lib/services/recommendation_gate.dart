import '../models/project_state.dart';

enum GateVerdict { enough, notEnough }

class GateResult {
  final GateVerdict verdict;
  final List<String> missing;

  const GateResult({required this.verdict, this.missing = const []});

  bool get canRecommend => verdict == GateVerdict.enough;
}

/// Pure policy check for the facts extracted from a project description.
///
/// The extractor must preserve unknown values as null or empty rather than
/// guessing. A project category alone is not enough: a budget, platform, or
/// feature is also required to make the resulting shortlist meaningfully
/// tailored.
GateResult evaluateRecommendationGate(ProjectState state) {
  final missing = <String>[];
  final hasProjectType =
      state.projectType != null && state.projectType!.trim().isNotEmpty;
  if (!hasProjectType) {
    missing.add('projectType');
  }

  final hasAnyConstraint =
      (state.budget?.isValid ?? false) ||
      state.platforms.any((value) => value.trim().isNotEmpty) ||
      state.features.any((value) => value.trim().isNotEmpty);
  if (hasProjectType && !hasAnyConstraint) {
    missing.add('constraint');
  }

  if (missing.isNotEmpty) {
    return GateResult(verdict: GateVerdict.notEnough, missing: missing);
  }
  return const GateResult(verdict: GateVerdict.enough);
}

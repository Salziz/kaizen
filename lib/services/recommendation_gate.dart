import '../models/project_state.dart';

enum GateVerdict { enough, notEnough }

class GateResult {
  final GateVerdict verdict;
  final List<String> missing;

  const GateResult({required this.verdict, this.missing = const []});

  bool get canRecommend => verdict == GateVerdict.enough;
}

/// Evaluates whether the extracted project state has enough information to
/// generate a recommendation, without making a network or model call.
///
/// The extractor must preserve unknown values as null rather than guessing;
/// this gate cannot distinguish a guessed value from one stated by the user.
GateResult evaluateRecommendationGate(ProjectState state) {
  final hasProjectType =
      state.projectType != null && state.projectType!.trim().isNotEmpty;
  if (!hasProjectType) {
    return const GateResult(
      verdict: GateVerdict.notEnough,
      missing: ['projectType'],
    );
  }

  // AC01 requires minimal concrete descriptions to pass. Budget, platforms,
  // and features can inform recommendations but are not gate requirements.
  return const GateResult(verdict: GateVerdict.enough);
}

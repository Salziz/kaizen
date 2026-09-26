/// Structured facts extracted from the user's project description.
///
/// Null fields and empty lists mean the user did not state that information.
/// The extractor must not fill gaps with assumptions.
class ProjectState {
  final String? projectType;
  final Budget? budget;
  final List<String> platforms;
  final List<String> features;

  const ProjectState({
    this.projectType,
    this.budget,
    this.platforms = const [],
    this.features = const [],
  });

  factory ProjectState.fromJson(Map<String, dynamic> json) {
    final rawProjectType = json['projectType'];
    return ProjectState(
      projectType: rawProjectType is String ? rawProjectType : null,
      budget: Budget.tryParse(json['budget']),
      platforms: _parseStringList(json['platforms']),
      features: _parseStringList(json['features']),
    );
  }

  Map<String, dynamic> toJson() => {
    'projectType': projectType,
    'budget': budget?.toJson(),
    'platforms': platforms,
    'features': features,
  };

  static List<String> _parseStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class Budget {
  final double amount;
  final String currency;
  final bool hard;

  bool get isValid =>
      amount >= 0 && amount.isFinite && currency.trim().isNotEmpty;

  const Budget({
    required this.amount,
    required this.currency,
    required this.hard,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    final budget = tryParse(json);
    if (budget == null) {
      throw const FormatException(
        'Budget requires a valid amount and currency.',
      );
    }
    return budget;
  }

  /// Parses untrusted model output without allowing one malformed field to
  /// invalidate the rest of the extracted project state.
  static Budget? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final rawAmount = value['amount'];
    final rawCurrency = value['currency'];
    final rawHard = value['hard'];
    if (rawAmount is! num ||
        !rawAmount.toDouble().isFinite ||
        rawAmount < 0 ||
        rawCurrency is! String ||
        rawCurrency.trim().isEmpty ||
        rawHard is! bool) {
      return null;
    }

    return Budget(
      amount: rawAmount.toDouble(),
      currency: rawCurrency.trim(),
      hard: rawHard,
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currency': currency,
    'hard': hard,
  };
}

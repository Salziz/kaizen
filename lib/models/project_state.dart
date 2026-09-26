/// Structured extraction output — what the service's model call
/// produces from a raw message thread. Fields are null when the user
/// never stated them; the extractor must never invent a value, since
/// the gate's correctness depends entirely on nulls meaning "unknown,"
/// not "assumed."
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

  factory ProjectState.fromJson(Map<String, dynamic> json) => ProjectState(
    projectType: json['projectType'] as String?,
    budget: json['budget'] != null
        ? Budget.fromJson(json['budget'] as Map<String, dynamic>)
        : null,
    platforms: List<String>.from(json['platforms'] as List? ?? []),
    features: List<String>.from(json['features'] as List? ?? []),
  );

  Map<String, dynamic> toJson() => {
    'projectType': projectType,
    'budget': budget?.toJson(),
    'platforms': platforms,
    'features': features,
  };
}

class Budget {
  final double amount;
  final String currency;
  final bool hard;

  const Budget({
    required this.amount,
    required this.currency,
    required this.hard,
  });

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    amount: (json['amount'] as num).toDouble(),
    currency: json['currency'] as String,
    hard: json['hard'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currency': currency,
    'hard': hard,
  };
}

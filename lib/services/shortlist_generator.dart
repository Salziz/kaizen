import '../models/project_state.dart';
import 'recommendation_gate.dart';

class ToolRecommendation {
  const ToolRecommendation({
    required this.name,
    required this.category,
    required this.rationale,
    required this.tradeoff,
    this.budgetAssessment = '',
  });

  final String name;
  final String category;
  final String rationale;
  final String tradeoff;
  final String budgetAssessment;
}

class ToolPriceEstimate {
  const ToolPriceEstimate({
    required this.monthlyAmount,
    required this.currency,
    required this.basis,
  });

  final double monthlyAmount;
  final String currency;
  final String basis;
}

class ShortlistResult {
  const ShortlistResult({
    required this.gate,
    this.recommendations = const [],
    this.budgetAcknowledgment,
    this.budget,
  });

  final GateResult gate;
  final List<ToolRecommendation> recommendations;
  final String? budgetAcknowledgment;
  final Budget? budget;

  bool get canRecommend => gate.canRecommend;

  String toReplyText() {
    if (!canRecommend) {
      if (gate.missing.contains('projectType')) {
        return 'What are you building? A short description of the app or '
            'project will help me narrow the options.';
      }
      return 'What constraint should I prioritize? A target platform, a key '
          'feature, or a budget is enough to tailor the shortlist.';
    }

    final buffer = StringBuffer('Here is a starter shortlist:\n');
    for (final recommendation in recommendations) {
      buffer
        ..write('\n')
        ..write('${recommendation.name} — ${recommendation.category}\n')
        ..write('Why it fits: ${recommendation.rationale}\n')
        ..write('Tradeoff: ${recommendation.tradeoff}\n')
        ..write('Budget: ${recommendation.budgetAssessment}\n');
    }
    buffer
      ..write('\n')
      ..write(budgetAcknowledgment);
    return buffer.toString();
  }
}

/// Produces a small, deterministic starter shortlist from explicit project
/// facts. Optional price estimates support fit/break comparisons, but are not
/// live pricing and must be verified before users rely on them.
ShortlistResult generateShortlist(
  ProjectState state, {
  Map<String, ToolPriceEstimate> priceEstimates = const {},
}) {
  final gate = evaluateRecommendationGate(state);
  if (!gate.canRecommend) {
    return ShortlistResult(gate: gate);
  }

  final projectType = state.projectType!.trim();
  final budget = state.budget?.isValid == true ? state.budget : null;
  final context = _statedContext(state, budget);
  final candidates = enforceShortlistBounds(
    _recommendationsFor(projectType: projectType, context: context),
  );
  final recommendations = candidates
      .map((recommendation) {
        return ToolRecommendation(
          name: recommendation.name,
          category: recommendation.category,
          rationale: recommendation.rationale,
          tradeoff:
              '${recommendation.tradeoff} For this project, weigh that against '
              '$context.',
          budgetAssessment: _budgetAssessment(
            budget: budget,
            estimate: priceEstimates[recommendation.name],
          ),
        );
      })
      .toList(growable: false);
  final result = ShortlistResult(
    gate: gate,
    recommendations: recommendations,
    budgetAcknowledgment: _budgetAcknowledgment(budget),
    budget: budget,
  );
  final violations = validateShortlist(result);
  if (violations.isNotEmpty) {
    throw StateError(
      'Generated shortlist violated its output contract: '
      '${violations.join(', ')}.',
    );
  }
  return result;
}

/// Enforces the shortlist-size contract, failing clearly when fewer than
/// three candidates exist and truncating oversized catalogues to six.
List<ToolRecommendation> enforceShortlistBounds(
  List<ToolRecommendation> candidates,
) {
  if (candidates.length < 3) {
    throw StateError(
      'Shortlist catalogue produced ${candidates.length} options; at least 3 '
      'are required.',
    );
  }
  return candidates.take(6).toList(growable: false);
}

/// Checks the deterministic shortlist invariants before content is shown.
List<String> validateShortlist(ShortlistResult result) {
  final violations = <String>[];
  if (!result.canRecommend) {
    if (result.recommendations.isNotEmpty ||
        result.budgetAcknowledgment != null) {
      violations.add('refused recommendations must not contain shortlist data');
    }
    return violations;
  }

  if (result.recommendations.length < 3 || result.recommendations.length > 6) {
    violations.add('shortlist must contain between 3 and 6 tools');
  }
  if (result.recommendations.map((item) => item.name).toSet().length !=
      result.recommendations.length) {
    violations.add('tool names must be unique');
  }
  if (result.recommendations.any(
    (item) =>
        item.name.trim().isEmpty ||
        item.category.trim().isEmpty ||
        item.rationale.trim().isEmpty ||
        item.tradeoff.trim().isEmpty ||
        item.budgetAssessment.trim().isEmpty,
  )) {
    violations.add(
      'each tool needs a name, category, rationale, tradeoff, and budget assessment',
    );
  }
  if (result.budgetAcknowledgment == null ||
      result.budgetAcknowledgment!.trim().isEmpty) {
    violations.add('budget acknowledgment is required');
  } else if (result.budget == null &&
      !result.budgetAcknowledgment!.contains(
        'No usable budget was available',
      )) {
    violations.add('unavailable budget must be acknowledged as unavailable');
  } else if (result.budget case final budget?) {
    final acknowledgment = result.budgetAcknowledgment!;
    final amount = _formatAmount(budget.amount);
    final budgetType = budget.hard ? 'hard cap' : 'target budget';
    if (!acknowledgment.contains(budget.currency) ||
        !acknowledgment.contains(amount) ||
        !acknowledgment.contains(budgetType)) {
      violations.add('stated budget must be accurately acknowledged');
    }
  }
  return violations;
}

String _budgetAssessment({
  required Budget? budget,
  required ToolPriceEstimate? estimate,
}) {
  if (budget == null) {
    return 'No usable budget was stated; current pricing and budget fit have '
        'not been verified for this tool.';
  }
  if (estimate == null ||
      !estimate.monthlyAmount.isFinite ||
      estimate.monthlyAmount < 0 ||
      estimate.basis.trim().isEmpty ||
      estimate.currency.toUpperCase() != budget.currency.toUpperCase()) {
    return 'Your ${budget.hard ? 'hard cap' : 'target budget'} of '
        '${budget.currency} ${_formatAmount(budget.amount)}. This tool’s '
        'current price is unverified, so whether it fits or exceeds that '
        'budget is unknown.';
  }

  final fits = estimate.monthlyAmount <= budget.amount;
  final fitDescription = fits ? 'fits within' : 'exceeds';
  final budgetType = budget.hard ? 'hard cap' : 'target budget';
  return 'Estimated at ${estimate.currency} '
      '${_formatAmount(estimate.monthlyAmount)}/month (${estimate.basis}); '
      'this $fitDescription your $budgetType of ${budget.currency} '
      '${_formatAmount(budget.amount)}. Verify current provider pricing.';
}

List<ToolRecommendation> _recommendationsFor({
  required String projectType,
  required String context,
}) {
  final kind = projectType.toLowerCase();
  if (_containsAny(kind, const ['store', 'shop', 'commerce', 'retail'])) {
    return [
      ToolRecommendation(
        name: 'Shopify',
        category: 'Commerce platform',
        rationale:
            'For a $projectType, it provides a managed catalog and checkout; '
            'the stated constraint is $context.',
        tradeoff:
            'Fast to launch, but customization and ongoing platform costs can '
            'grow as the storefront becomes more bespoke.',
      ),
      ToolRecommendation(
        name: 'Stripe',
        category: 'Payments',
        rationale:
            'It provides a mature payments API for the checkout flow in a '
            '$projectType, with $context in mind.',
        tradeoff:
            'You own more integration and compliance work than with an '
            'all-in-one commerce platform; transaction fees still apply.',
      ),
      ToolRecommendation(
        name: 'Supabase',
        category: 'Database and backend',
        rationale:
            'Its relational database is a natural fit for product, inventory, '
            'and order data in a $projectType; the priority is $context.',
        tradeoff:
            'You will need to design and maintain the data model and access '
            'policies rather than relying entirely on a hosted store.',
      ),
      ToolRecommendation(
        name: 'Vercel',
        category: 'Web deployment',
        rationale:
            'It can deploy a custom storefront for a $projectType and keep '
            'the web release workflow simple; the constraint is $context.',
        tradeoff:
            'It is focused on web deployment, and usage-based limits and '
            'platform coupling should be reviewed before scaling.',
      ),
    ];
  }

  if (_containsAny(kind, const ['game', 'gaming'])) {
    return [
      ToolRecommendation(
        name: 'Unity Gaming Services',
        category: 'Game services',
        rationale:
            'It offers game-oriented identity and player services for a '
            '$projectType, with $context as the stated constraint.',
        tradeoff:
            'It adds a separate service ecosystem and usage limits to track; '
            'confirm each service fits the chosen game engine.',
      ),
      ToolRecommendation(
        name: 'Firebase',
        category: 'Backend and analytics',
        rationale:
            'It provides managed authentication and data services that can '
            'support a $projectType while prioritizing $context.',
        tradeoff:
            'Its document model and vendor-specific APIs can make later '
            'migration or complex relational queries harder.',
      ),
      ToolRecommendation(
        name: 'Sentry',
        category: 'Error monitoring',
        rationale:
            'It helps surface crashes and runtime errors early in a '
            '$projectType, especially when working within $context.',
        tradeoff:
            'It does not replace gameplay analytics, and event volume can '
            'affect cost and data-retention choices.',
      ),
    ];
  }

  if (_containsAny(kind, const ['chat', 'messaging', 'conversation'])) {
    return [
      ToolRecommendation(
        name: 'Supabase',
        category: 'Database and realtime backend',
        rationale:
            'Its relational data and realtime capabilities suit a $projectType; '
            'the stated priority is $context.',
        tradeoff:
            'Realtime throughput, database policies, and scaling limits need '
            'to be tested against the expected conversation volume.',
      ),
      ToolRecommendation(
        name: 'Firebase',
        category: 'Managed app backend',
        rationale:
            'It offers mobile-friendly authentication and realtime data '
            'services for a $projectType, tailored around $context.',
        tradeoff:
            'The document data model can complicate relational queries and '
            'vendor-specific services increase lock-in.',
      ),
      ToolRecommendation(
        name: 'Stream Chat',
        category: 'Managed chat infrastructure',
        rationale:
            'It provides chat-specific building blocks for a $projectType, '
            'leaving more time for the product features behind $context.',
        tradeoff:
            'It is a specialized paid service with less control over the '
            'messaging infrastructure than building on a general backend.',
      ),
    ];
  }

  return [
    ToolRecommendation(
      name: 'Supabase',
      category: 'Database and backend',
      rationale:
          'Its SQL database and integrated services are a flexible starting '
          'point for a $projectType, prioritizing $context.',
      tradeoff:
          'You will need to design the schema and access policies, and verify '
          'that its realtime or hosting limits fit the workload.',
    ),
    ToolRecommendation(
      name: 'Firebase',
      category: 'Managed app backend',
      rationale:
          'It provides managed authentication and data services for a '
          '$projectType, with $context as the known constraint.',
      tradeoff:
          'The document model and proprietary APIs can increase migration '
          'cost and complicate relational data.',
    ),
    ToolRecommendation(
      name: 'Vercel',
      category: 'Web deployment',
      rationale:
          'It offers a straightforward deployment path if the $projectType '
          'includes a web client; the stated priority is $context.',
      tradeoff:
          'It only addresses web deployment, and usage-based limits and '
          'platform coupling should be reviewed.',
    ),
  ];
}

bool _containsAny(String value, List<String> terms) =>
    terms.any(value.contains);

String _statedContext(ProjectState state, Budget? budget) {
  final details = <String>[
    ...state.platforms.map((value) => 'platform ${value.trim()}'),
    ...state.features.map((value) => 'feature ${value.trim()}'),
  ];
  if (budget != null) {
    final capType = budget.hard ? 'hard cap' : 'target budget';
    details.add('$capType ${budget.currency} ${_formatAmount(budget.amount)}');
  }
  return details.isEmpty
      ? 'the stated project requirements'
      : details.join(', ');
}

String _budgetAcknowledgment(Budget? budget) {
  if (budget == null) {
    return 'No usable budget was available from the project details, so these '
        'options are not cost-ranked. '
        'Check current pricing before committing to a stack.';
  }

  final capType = budget.hard ? 'hard cap' : 'target budget';
  return 'Budget noted: $capType of ${budget.currency} '
      '${_formatAmount(budget.amount)}. This shortlist is not verified against '
      'live pricing; check current plans and usage charges before committing.';
}

String _formatAmount(double amount) =>
    amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : '$amount';

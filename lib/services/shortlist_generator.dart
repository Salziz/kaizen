import '../models/project_state.dart';
import '../models/variable_rate.dart';
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'rationale': rationale,
        'tradeoff': tradeoff,
        'budgetAssessment': budgetAssessment,
      };

  factory ToolRecommendation.fromJson(Map<String, dynamic> json) =>
      ToolRecommendation(
        name: json['name'] as String,
        category: json['category'] as String,
        rationale: json['rationale'] as String,
        tradeoff: json['tradeoff'] as String,
        budgetAssessment: json['budgetAssessment'] as String? ?? '',
      );
}

class ToolPriceEstimate {
  const ToolPriceEstimate({
    required this.monthlyAmount,
    required this.currency,
    required this.basis,
    required this.sourceUrl,
    required this.lastChecked,
    this.variableRate,
    this.knownLimitation,
    this.isRecurring = true,
    this.isPriceUnknown = false,
  });

  final double monthlyAmount;
  final String currency;
  final String basis;
  final String sourceUrl;
  final String lastChecked;

  /// Structured replacement for the old free-text `variablePricing`
  /// field. See variable_rate.dart for why: a prose string could only
  /// say THAT a tool had variable pricing, never compute HOW MUCH it
  /// would cost at a given usage level — which was the actual root
  /// cause of the zero-hard-cap misclassification this type replaces.
  final VariableRate? variableRate;

  /// Flagged limitation when this estimate represents a partial figure or
  /// lower bound (e.g. Stripe flat fee only, excluding transaction value %).
  final String? knownLimitation;

  /// Whether charges for this tool are recurring (monthly) or one-time.
  /// AC04 requires this attribute to live on the catalogue entry rather
  /// than being hardcoded at the display boundary.
  final bool isRecurring;

  /// True when the tool's pricing contains an unmodeled fee component
  /// (e.g. Stripe's 2.9% transaction-value fee) that cannot be computed
  /// from the request-volume ladder alone. Per AC04 ("any value the
  /// catalogue does not hold reads as unknown, never as a number"),
  /// costAtRequests returns null rather than computing a misleading
  /// incomplete figure.
  final bool isPriceUnknown;

  bool get hasKnownLimitation => knownLimitation != null;
  bool get isPartial => hasKnownLimitation;

  /// Exact cost at a given monthly request volume: fixed component
  /// plus whatever the variable rate computes for that volume. This is
  /// arithmetic over catalogue-held numbers (the fixed amount, the
  /// rate, the free allowance) — never a guess, never an
  /// interpolation. Returns null when the price is unknown or when
  /// the variable rate reports the volume exceeds what the catalogue
  /// confidently prices (see VariableRate.maxKnownRequests).
  double? costAtRequests(int requestsPerMonth) {
    if (isPriceUnknown) return null;
    if (variableRate == null) return monthlyAmount;
    final variableCost = variableRate!.costAt(requestsPerMonth);
    if (variableCost == null) return null;
    return monthlyAmount + variableCost;
  }
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

  /// JSON round trip — this is what lets TFS-009's transport carry the
  /// same structure over the wire, and what lets the UI widgets
  /// consume ShortlistResult directly instead of only ever receiving
  /// toReplyText()'s flattened prose. toReplyText() remains a
  /// rendering helper for the plain-text chat path; it is not the only
  /// way to consume this type anymore.
  Map<String, dynamic> toJson() => {
        'canRecommend': canRecommend,
        'missing': gate.missing,
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'budgetAcknowledgment': budgetAcknowledgment,
        'budget': budget?.toJson(),
      };

  factory ShortlistResult.fromJson(Map<String, dynamic> json) {
    final canRecommend = json['canRecommend'] as bool;
    final gate = GateResult(
      verdict: canRecommend ? GateVerdict.enough : GateVerdict.notEnough,
      missing: List<String>.from(json['missing'] as List? ?? []),
    );
    return ShortlistResult(
      gate: gate,
      recommendations: (json['recommendations'] as List? ?? [])
          .map((r) => ToolRecommendation.fromJson(r as Map<String, dynamic>))
          .toList(),
      budgetAcknowledgment: json['budgetAcknowledgment'] as String?,
      budget: json['budget'] != null
          ? Budget.fromJson(json['budget'] as Map<String, dynamic>)
          : null,
    );
  }

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
    _recommendationsFor(
      projectType: projectType,
      context: context,
      state: state,
    ),
  );
  final combinedMonthlyCosts = _combinedMonthlyCosts(
    candidates,
    priceEstimates,
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
            combinedMonthlyCosts: combinedMonthlyCosts,
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

/// Plain-words description of a tool's variable rate, for display in
/// prose contexts (the old free-text field's job, now derived from
/// structured data instead of being the source of truth itself).
String _describeVariableRate(VariableRate rate) {
  final allowancePart = rate.freeAllowanceRequests > 0
      ? 'first ${rate.freeAllowanceRequests} requests free, then '
      : '';
  return '$allowancePart\$${rate.ratePerRequest} per request beyond that';
}

String _budgetAssessment({
  required Budget? budget,
  required ToolPriceEstimate? estimate,
  required _CombinedMonthlyCosts? combinedMonthlyCosts,
}) {
  if (budget == null) {
    return 'No usable budget was stated; current pricing and budget fit have '
        'not been verified for this tool.';
  }
  if (estimate == null ||
      !estimate.monthlyAmount.isFinite ||
      estimate.monthlyAmount < 0 ||
      estimate.currency.trim().isEmpty ||
      estimate.basis.trim().isEmpty ||
      estimate.sourceUrl.trim().isEmpty ||
      estimate.lastChecked.trim().isEmpty) {
    return 'Your ${budget.hard ? 'hard cap' : 'target budget'} of '
        '${budget.currency} ${_formatAmount(budget.amount)}. This tool’s '
        'price and its source or check date are unavailable, so whether it '
        'fits or exceeds that budget is unknown.';
  }

  final provenance =
      'Pricing source: ${estimate.sourceUrl} (checked ${estimate.lastChecked}).';
  final toolPrice =
      'This tool has a listed fixed component of '
      '${estimate.currency} ${_formatAmount(estimate.monthlyAmount)}/month '
      '(${estimate.basis}).';
  final sameCurrency =
      estimate.currency.toUpperCase() == budget.currency.toUpperCase();
  final hasVariableRate = estimate.variableRate != null;
  final variableSuffix = hasVariableRate
      ? ' Variable charges apply (${_describeVariableRate(estimate.variableRate!)}).'
      : '';

  // A tool exceeds a zero cap if its fixed monthly cost is positive,
  // or if its variable rate has no free allowance (so any transaction is billable).
  // A tool with a free allowance before its rate kicks in does not exceed
  // a $0 cap at baseline, closing the bug where free-tier-with-overage tools
  // were misclassified as exceeding $0.
  final hasZeroCapExcess = estimate.monthlyAmount > 0 ||
      (estimate.variableRate != null &&
          estimate.variableRate!.freeAllowanceRequests == 0 &&
          estimate.variableRate!.ratePerRequest > 0);
  final zeroCapHasKnownExcess = budget.amount == 0 && hasZeroCapExcess;

  if (zeroCapHasKnownExcess) {
    final reason = estimate.variableRate != null &&
            estimate.variableRate!.freeAllowanceRequests == 0
        ? 'variable charges are positive for any charged transaction'
        : 'its known recurring cost is positive';
    return '$toolPrice This tool exceeds your ${_budgetLabel(budget)} of '
        '${budget.currency} 0 because $reason.$variableSuffix $provenance';
  }

  if (!sameCurrency) {
    if (estimate.monthlyAmount == 0 && !hasVariableRate) {
      return '$toolPrice Its listed fixed price is zero, which fits your '
          '${_budgetLabel(budget)} of ${budget.currency} '
          '${_formatAmount(budget.amount)} regardless of currency — a zero '
          'cost converts to zero in any currency. Unlisted usage charges are '
          'not included. $provenance';
    }
    return '$toolPrice The currencies cannot be compared without an exchange '
        'rate; no conversion was applied, so whether this fits your '
        '${_budgetLabel(budget)} of ${budget.currency} '
        '${_formatAmount(budget.amount)} is unknown.$variableSuffix $provenance';
  }

  if (budget.period == BudgetPeriod.monthly) {
    final fitsFixed = estimate.monthlyAmount <= budget.amount;
    if (hasVariableRate) {
      final fixedStatus = fitsFixed
          ? 'its fixed monthly component fits within'
          : 'its fixed monthly component exceeds';
      return '$toolPrice The fixed component $fixedStatus your '
          '${_budgetLabel(budget)} of ${budget.currency} '
          '${_formatAmount(budget.amount)}, but additional variable charges '
          'apply (${_describeVariableRate(estimate.variableRate!)}), so total '
          'fit is unknown. $provenance';
    }
    final verdict = fitsFixed ? 'fits within' : 'exceeds';
    final stackNote =
        combinedMonthlyCosts == null ||
            combinedMonthlyCosts.currency.toUpperCase() !=
                budget.currency.toUpperCase()
        ? ''
        : ' If you used every listed option together, their fixed monthly '
              'cost would total ${combinedMonthlyCosts.currency} '
              '${_formatAmount(combinedMonthlyCosts.fixedAmount)}, which '
              '${combinedMonthlyCosts.fixedAmount <= budget.amount ? 'fits within' : 'exceeds'} '
              'your ${_budgetLabel(budget)}; some recommendations may be '
              'alternatives.';
    return '$toolPrice This tool $verdict your ${_budgetLabel(budget)} of '
        '${budget.currency} ${_formatAmount(budget.amount)}.$stackNote '
        '$provenance';
  }

  if (budget.period == BudgetPeriod.total) {
    final stackCostNote = combinedMonthlyCosts == null
        ? ''
        : ' If every listed option were used together, their fixed costs '
              'would total ${combinedMonthlyCosts.currency} '
              '${_formatAmount(combinedMonthlyCosts.fixedAmount)} for one '
              'month; some recommendations may be alternatives.';
    if (estimate.monthlyAmount > budget.amount) {
      return '$toolPrice Even one month of this tool exceeds your '
          '${_budgetLabel(budget)} of ${budget.currency} '
          '${_formatAmount(budget.amount)}.$stackCostNote $provenance';
    }
    if (combinedMonthlyCosts != null &&
        combinedMonthlyCosts.currency.toUpperCase() ==
            budget.currency.toUpperCase() &&
        combinedMonthlyCosts.fixedAmount > budget.amount) {
      return '$toolPrice $stackCostNote Even one month of all listed fixed '
          'costs exceeds your ${_budgetLabel(budget)} of ${budget.currency} '
          '${_formatAmount(budget.amount)}; for a subset or alternatives, '
          'duration is needed to assess total cost. $provenance';
    }
    if (estimate.monthlyAmount == 0 && !hasVariableRate) {
      return '$toolPrice The listed recurring fixed cost fits within your '
          '${_budgetLabel(budget)} of ${budget.currency} '
          '${_formatAmount(budget.amount)}; unlisted usage charges are not '
          'included. $provenance';
    }
    return '$toolPrice Its monthly fixed cost is below your total budget, '
        'but project duration is unstated, so total fit is unknown.'
        '$stackCostNote$variableSuffix $provenance';
  }

  if (budget.amount == 0 && estimate.monthlyAmount == 0 && !hasVariableRate) {
    return '$toolPrice The listed recurring fixed cost fits within your '
        'zero ${_budgetLabel(budget)}; unlisted usage charges are not '
        'included. $provenance';
  }

  if (estimate.monthlyAmount == 0 && !hasVariableRate) {
    return '$toolPrice This tool has no listed fixed cost, so it fits your '
        '${_budgetLabel(budget)} of ${budget.currency} '
        '${_formatAmount(budget.amount)} regardless of whether that figure '
        'is monthly or total — a zero cost never exceeds a stated positive '
        'amount. Unlisted usage charges are not included. $provenance';
  }

  return '$toolPrice The budget period was not stated. Say whether '
      '${budget.currency} ${_formatAmount(budget.amount)} is monthly or total '
      'to compare it with recurring prices.$variableSuffix $provenance';
}

_CombinedMonthlyCosts? _combinedMonthlyCosts(
  List<ToolRecommendation> recommendations,
  Map<String, ToolPriceEstimate> priceEstimates,
) {
  final estimates = <ToolPriceEstimate>[];
  for (final recommendation in recommendations) {
    final estimate = priceEstimates[recommendation.name];
    if (estimate == null ||
        !estimate.monthlyAmount.isFinite ||
        estimate.monthlyAmount < 0 ||
        estimate.currency.trim().isEmpty ||
        estimate.basis.trim().isEmpty ||
        estimate.sourceUrl.trim().isEmpty ||
        estimate.lastChecked.trim().isEmpty) {
      return null;
    }
    estimates.add(estimate);
  }

  final currency = estimates.first.currency;
  if (estimates.any(
    (estimate) => estimate.currency.toUpperCase() != currency.toUpperCase(),
  )) {
    return null;
  }

  return _CombinedMonthlyCosts(
    fixedAmount: estimates.fold(
      0,
      (total, estimate) => total + estimate.monthlyAmount,
    ),
    currency: currency,
  );
}

class _CombinedMonthlyCosts {
  const _CombinedMonthlyCosts({
    required this.fixedAmount,
    required this.currency,
  });

  final double fixedAmount;
  final String currency;
}

String _budgetLabel(Budget budget) {
  final type = budget.hard ? 'hard cap' : 'target budget';
  return switch (budget.period) {
    BudgetPeriod.monthly => '$type per month',
    BudgetPeriod.total => 'total $type',
    BudgetPeriod.unspecified => type,
  };
}

List<ToolRecommendation> _recommendationsFor({
  required String projectType,
  required String context,
  ProjectState? state,
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

  // Dynamic feature & platform-tailored stack selection
  final featureSignals =
      state?.features.map((f) => f.toLowerCase()).join(' ') ?? '';
  final platformSignals =
      state?.platforms.map((p) => p.toLowerCase()).join(' ') ?? '';
  final combinedText = '$kind $featureSignals $platformSignals';

  final result = <ToolRecommendation>[];
  final addedNames = <String>{};

  void addCandidate(ToolRecommendation tool) {
    if (addedNames.add(tool.name)) {
      result.add(tool);
    }
  }

  // 1. Database & Core Backend (always fundamental)
  addCandidate(
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
  );

  // 2. Payments (if payment/billing/checkout/stripe requested)
  if (_containsAny(
      combinedText, const ['pay', 'stripe', 'checkout', 'bill', 'subscrip', 'monetiz'])) {
    addCandidate(
      ToolRecommendation(
        name: 'Stripe',
        category: 'Payments',
        rationale:
            'It provides secure card checkout and subscription processing for a '
            '$projectType, with $context in mind.',
        tradeoff:
            'You own webhook handling and compliance checking; variable percentage '
            'fees apply per transaction.',
      ),
    );
  }

  // 3. Background workflows / Jobs (if workflow/job/queue/agent/background requested)
  if (_containsAny(combinedText,
      const ['workflow', 'job', 'queue', 'task', 'background', 'agent', 'schedule'])) {
    addCandidate(
      ToolRecommendation(
        name: 'Trigger.dev',
        category: 'Background workflows',
        rationale:
            'It provides reliable serverless background jobs and workflow scheduling '
            'for a $projectType, tailored around $context.',
        tradeoff:
            'Worker execution requires long timeouts and job payload monitoring '
            'as execution frequency scales.',
      ),
    );
  }

  // 4. Error monitoring (if monitoring/error/crash/observability requested)
  if (_containsAny(combinedText,
      const ['monitor', 'error', 'crash', 'log', 'sentry', 'observab', 'tracing'])) {
    addCandidate(
      ToolRecommendation(
        name: 'Sentry',
        category: 'Error monitoring',
        rationale:
            'It helps surface crashes and runtime errors early in a '
            '$projectType, especially when working within $context.',
        tradeoff:
            'It does not replace gameplay or operational analytics, and event volume '
            'can affect cost choices.',
      ),
    );
  }

  // 5. Mobile & Realtime (if mobile/android/ios/flutter/sync requested)
  if (_containsAny(combinedText,
      const ['mobile', 'android', 'ios', 'flutter', 'sync', 'realtime', 'push'])) {
    addCandidate(
      ToolRecommendation(
        name: 'Firebase',
        category: 'Managed app backend',
        rationale:
            'It provides managed mobile authentication, cloud sync, and messaging '
            'for a $projectType, with $context as the known constraint.',
        tradeoff:
            'The document model and proprietary APIs can increase migration cost '
            'and complicate relational data.',
      ),
    );
  }

  // 6. Web deployment
  if (_containsAny(combinedText,
          const ['web', 'frontend', 'dashboard', 'saas', 'browser', 'portal', 'api']) ||
      result.length < 3) {
    addCandidate(
      ToolRecommendation(
        name: 'Vercel',
        category: 'Web deployment',
        rationale:
            'It offers a straightforward deployment path if the $projectType '
            'includes a web client or API; the stated priority is $context.',
        tradeoff:
            'It only addresses web deployment, and usage-based limits and '
            'platform coupling should be reviewed.',
      ),
    );
  }

  // Fallback candidates to ensure between 3 and 6 tools
  if (result.length < 3) {
    addCandidate(
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
    );
  }
  if (result.length < 3) {
    addCandidate(
      ToolRecommendation(
        name: 'Sentry',
        category: 'Error monitoring',
        rationale:
            'It helps surface crashes and runtime errors early in a '
            '$projectType, especially when working within $context.',
        tradeoff:
            'It does not replace operational telemetry, and event volume can '
            'affect cost and data-retention choices.',
      ),
    );
  }

  return result;
}

bool _containsAny(String value, List<String> terms) =>
    terms.any(value.contains);

String _statedContext(ProjectState state, Budget? budget) {
  final details = <String>[
    ...state.platforms.map((value) => 'platform ${value.trim()}'),
    ...state.features.map((value) => 'feature ${value.trim()}'),
  ];
  if (budget != null) {
    details.add(
      '${_budgetLabel(budget)} ${budget.currency} '
      '${_formatAmount(budget.amount)}',
    );
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

  return 'Budget noted: ${_budgetLabel(budget)} of ${budget.currency} '
      '${_formatAmount(budget.amount)}. Provider catalogue estimates are '
      'reviewed figures, not live quotes; check current plans and usage '
      'charges before committing.';
}

String _formatAmount(double amount) =>
    amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : '$amount';

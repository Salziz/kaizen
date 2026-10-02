import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/models/project_state.dart';
import 'package:kaizen/models/usage_level.dart';
import 'package:kaizen/models/variable_rate.dart';
import 'package:kaizen/services/project_estimate.dart';
import 'package:kaizen/services/recommendation_gate.dart';
import 'package:kaizen/services/shortlist_generator.dart';
import 'package:kaizen/services/tool_price_catalogue.dart';

void main() {
  group('UsageLevel', () {
    test('defines discrete ladder rungs with plain-words basis labels', () {
      expect(UsageLevel.starter.requestsPerMonth, 1000);
      expect(UsageLevel.starter.label, 'around 1,000 requests a month');

      expect(UsageLevel.growth.requestsPerMonth, 10000);
      expect(UsageLevel.growth.label, 'around 10,000 requests a month');

      expect(UsageLevel.scale.requestsPerMonth, 100000);
      expect(UsageLevel.scale.label, 'around 100,000 requests a month');
    });
  });

  group('VariableRate', () {
    test('computes exact arithmetic cost at given request volumes', () {
      const rate = VariableRate(
        freeAllowanceRequests: 1000,
        ratePerRequest: 0.05,
        maxKnownRequests: 50000,
      );

      // Usage within free allowance costs $0
      expect(rate.costAt(500), 0.0);
      expect(rate.costAt(1000), 0.0);

      // Usage beyond free allowance computes billable * rate
      expect(rate.costAt(2000), 50.0); // (2000 - 1000) * 0.05
      expect(rate.costAt(10000), 450.0); // (10000 - 1000) * 0.05

      // Usage beyond maxKnownRequests returns null (unknown)
      expect(rate.costAt(60000), isNull);
    });

    test('serializes to and from JSON', () {
      const original = VariableRate(
        freeAllowanceRequests: 500,
        ratePerRequest: 0.02,
        maxKnownRequests: 25000,
      );

      final json = original.toJson();
      final recovered = VariableRate.fromJson(json);

      expect(recovered.freeAllowanceRequests, original.freeAllowanceRequests);
      expect(recovered.ratePerRequest, original.ratePerRequest);
      expect(recovered.maxKnownRequests, original.maxKnownRequests);
    });
  });

  group('ShortlistResult & ToolRecommendation JSON round trip', () {
    test('serializes and deserializes ShortlistResult cleanly', () {
      const recommendation = ToolRecommendation(
        name: 'Supabase',
        category: 'Database and backend',
        rationale: 'Scalable relational database',
        tradeoff: 'Requires SQL knowledge',
        budgetAssessment: 'Fits within budget',
      );

      const result = ShortlistResult(
        gate: GateResult(verdict: GateVerdict.enough, missing: []),
        recommendations: [recommendation],
        budgetAcknowledgment: 'Budget noted: USD 100',
        budget: Budget(
          amount: 100,
          currency: 'USD',
          hard: true,
          period: BudgetPeriod.monthly,
        ),
      );

      final json = result.toJson();
      final restored = ShortlistResult.fromJson(json);

      expect(restored.canRecommend, isTrue);
      expect(restored.recommendations, hasLength(1));
      expect(restored.recommendations.first.name, 'Supabase');
      expect(restored.recommendations.first.category, 'Database and backend');
      expect(restored.recommendations.first.rationale, 'Scalable relational database');
      expect(restored.recommendations.first.tradeoff, 'Requires SQL knowledge');
      expect(restored.recommendations.first.budgetAssessment, 'Fits within budget');
      expect(restored.budgetAcknowledgment, 'Budget noted: USD 100');
      expect(restored.budget?.amount, 100);
      expect(restored.budget?.currency, 'USD');
      expect(restored.budget?.hard, isTrue);
      expect(restored.budget?.period, BudgetPeriod.monthly);
    });
  });

  group('ToolPriceEstimate costAtRequests', () {
    test('combines fixed monthly cost and variable rate', () {
      const estimate = ToolPriceEstimate(
        monthlyAmount: 20,
        currency: 'USD',
        basis: 'Base fee plus usage',
        sourceUrl: 'https://example.com',
        lastChecked: '2026-09-26',
        variableRate: VariableRate(
          freeAllowanceRequests: 1000,
          ratePerRequest: 0.10,
          maxKnownRequests: 20000,
        ),
      );

      expect(estimate.costAtRequests(500), 20.0);
      expect(estimate.costAtRequests(2000), 120.0); // 20 + 100
      expect(estimate.costAtRequests(30000), isNull);
    });

    test('returns fixed monthly cost when variableRate is null', () {
      const estimate = ToolPriceEstimate(
        monthlyAmount: 29,
        currency: 'USD',
        basis: 'Basic plan',
        sourceUrl: 'https://example.com',
        lastChecked: '2026-09-26',
      );

      expect(estimate.costAtRequests(1000), 29.0);
      expect(estimate.costAtRequests(100000), 29.0);
    });
  });

  group('ProjectEstimate & buildProjectEstimate', () {
    test('builds accurate upfront estimate across completely known tools at given rung', () {
      final estimate = buildProjectEstimate(
        chosenToolNames: ['Shopify', 'Supabase'],
        usageLevel: UsageLevel.growth,
        catalogue: kToolPriceCatalogue,
      );

      expect(estimate.usageLevel, UsageLevel.growth);
      expect(estimate.usageAssumptionLabel, 'assumes around 10,000 requests a month');
      expect(estimate.contributions, hasLength(2));
      expect(estimate.currency, 'USD');
      expect(estimate.hasUnknownComponent, isFalse);
      expect(estimate.hasPartialComponent, isFalse);

      // Shopify: 29
      // Supabase: 0
      // Total: 29
      expect(estimate.total, 29.0);
    });

    test('Option 2: displays partial figure for tool with known limitation, and makes grand total null', () {
      final estimate = buildProjectEstimate(
        chosenToolNames: ['Shopify', 'Supabase', 'Stripe'],
        usageLevel: UsageLevel.growth,
        catalogue: kToolPriceCatalogue,
      );

      expect(estimate.usageLevel, UsageLevel.growth);
      expect(estimate.contributions, hasLength(3));
      expect(estimate.hasUnknownComponent, isFalse);
      expect(estimate.hasPartialComponent, isTrue);

      final stripe = estimate.contributions.firstWhere((c) => c.toolName == 'Stripe');
      // Stripe's partial flat-fee cost is shown per-tool ($3,000 at growth), flagged not hidden
      expect(stripe.monthlyCost, 3000.0);
      expect(stripe.hasKnownLimitation, isTrue);
      expect(stripe.isPartial, isTrue);
      expect(stripe.knownLimitation, contains('Flat fee only'));

      // Grand total is null because an ingredient is partial (Option 2)
      expect(estimate.total, isNull);
    });

    test('returns null total when any tool has unknown cost at a rung', () {
      const customCatalogue = {
        'KnownTool': ToolPriceEstimate(
          monthlyAmount: 10,
          currency: 'USD',
          basis: 'Fixed',
          sourceUrl: 'https://example.com',
          lastChecked: '2026-09-26',
        ),
        'LimitedTool': ToolPriceEstimate(
          monthlyAmount: 0,
          currency: 'USD',
          basis: 'Usage capped',
          sourceUrl: 'https://example.com',
          lastChecked: '2026-09-26',
          variableRate: VariableRate(
            freeAllowanceRequests: 0,
            ratePerRequest: 0.05,
            maxKnownRequests: 5000, // Unknown at growth (10,000)
          ),
        ),
      };

      final estimate = buildProjectEstimate(
        chosenToolNames: ['KnownTool', 'LimitedTool'],
        usageLevel: UsageLevel.growth,
        catalogue: customCatalogue,
      );

      expect(estimate.hasUnknownComponent, isTrue);
      expect(estimate.total, isNull);
      expect(estimate.contributions.first.monthlyCost, 10.0);
      expect(estimate.contributions.last.monthlyCost, isNull);
    });

    test('handles tools not present in catalogue with null cost', () {
      final estimate = buildProjectEstimate(
        chosenToolNames: ['NonExistentTool'],
        usageLevel: UsageLevel.starter,
        catalogue: kToolPriceCatalogue,
      );

      expect(estimate.hasUnknownComponent, isTrue);
      expect(estimate.total, isNull);
      expect(estimate.contributions.single.monthlyCost, isNull);
    });
  });

  group('findCoverageGaps', () {
    test('all 8 tools in kToolPriceCatalogue have confident pricing at every rung', () {
      final gaps = findCoverageGaps(
        allPossibleToolNames: kToolPriceCatalogue.keys.toList(),
        catalogue: kToolPriceCatalogue,
      );

      expect(gaps, isEmpty);
    });
  });
}

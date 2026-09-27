import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/models/project_state.dart';
import 'package:kaizen/services/shortlist_generator.dart';
import 'package:kaizen/services/tool_price_catalogue.dart';

void main() {
  group('Catalogue price assessments are bounded by available evidence', () {
    test('"free tools only" - extracted as a hard \$0 budget - identifies '
        'fixed and variable costs that exceed it', () {
      final state = ProjectState.fromJson({
        'projectType': 'small storefront',
        'budget': {'amount': 0, 'currency': 'USD', 'hard': true},
        'platforms': [],
        'features': [],
      });

      final result = generateShortlist(
        state,
        priceEstimates: kToolPriceCatalogue,
      );

      expect(result.canRecommend, isTrue);
      final fixedPriceTools = result.recommendations.where(
        (tool) => tool.name != 'Stripe',
      );
      expect(
        fixedPriceTools.every(
          (tool) =>
              tool.budgetAssessment.contains('fits within') ||
              tool.budgetAssessment.contains('fits your') ||
              tool.budgetAssessment.contains('exceeds'),
        ),
        isTrue,
      );

      final stripe = result.recommendations.singleWhere(
        (tool) => tool.name == 'Stripe',
      );
      expect(stripe.budgetAssessment, contains('Variable charges apply'));
      expect(stripe.budgetAssessment, contains('exceeds your hard cap'));

      final shopify = result.recommendations.firstWhere(
        (tool) => tool.name == 'Shopify',
      );
      expect(shopify.budgetAssessment, contains('exceeds'));
      expect(
        shopify.budgetAssessment,
        contains('https://www.shopify.com/pricing'),
      );
      expect(shopify.budgetAssessment, contains('checked 2026-09-26'));
    });

    test('monthly estimate includes source and check date', () {
      const state = ProjectState(
        projectType: 'small storefront',
        budget: Budget(
          amount: 50,
          currency: 'USD',
          hard: true,
          period: BudgetPeriod.monthly,
        ),
      );
      final result = generateShortlist(
        state,
        priceEstimates: kToolPriceCatalogue,
      );
      final shopify = result.recommendations.firstWhere(
        (tool) => tool.name == 'Shopify',
      );

      expect(shopify.budgetAssessment, contains('fits within'));
      expect(
        shopify.budgetAssessment,
        contains('If you used every listed option together'),
      );
      expect(
        shopify.budgetAssessment,
        contains('fixed monthly cost would total USD 29'),
      );
    });

    test('does not convert USD catalogue figures into another currency', () {
      const state = ProjectState(
        projectType: 'small storefront',
        budget: Budget(amount: 40, currency: 'EUR', hard: true),
      );
      final result = generateShortlist(
        state,
        priceEstimates: kToolPriceCatalogue,
      );
      final shopify = result.recommendations.singleWhere(
        (tool) => tool.name == 'Shopify',
      );

      expect(shopify.budgetAssessment, contains('cannot be compared'));
      expect(shopify.budgetAssessment, contains('no conversion was applied'));
      expect(shopify.budgetAssessment, contains('is unknown'));
      expect(
        shopify.budgetAssessment,
        contains('https://www.shopify.com/pricing'),
      );

      final stripe = result.recommendations.singleWhere(
        (tool) => tool.name == 'Stripe',
      );
      expect(stripe.budgetAssessment, contains('Variable charges apply'));
      expect(stripe.budgetAssessment, contains('cannot be compared'));

      expect(
        result.recommendations
            .where((tool) => tool.name == 'Supabase' || tool.name == 'Vercel')
            .every(
              (tool) =>
                  tool.budgetAssessment.contains('fits your') &&
                  tool.budgetAssessment.contains('regardless of currency'),
            ),
        isTrue,
      );
    });

    test('a total USD budget does not treat a monthly price as a total fit', () {
      const state = ProjectState(
        projectType: 'small storefront',
        budget: Budget(
          amount: 50,
          currency: 'USD',
          hard: true,
          period: BudgetPeriod.total,
        ),
      );
      final result = generateShortlist(
        state,
        priceEstimates: kToolPriceCatalogue,
      );
      final shopify = result.recommendations.singleWhere(
        (tool) => tool.name == 'Shopify',
      );

      expect(shopify.budgetAssessment, isNot(contains('fits within')));
      expect(shopify.budgetAssessment, contains('project duration is unstated'));
    });
  });
}

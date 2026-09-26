import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/models/project_state.dart';
import 'package:kaizen/services/shortlist_generator.dart';
import 'package:kaizen/services/tool_price_catalogue.dart';

void main() {
  group('Catalogue price assessments are bounded by available evidence', () {
    test('"free tools only" - extracted as a hard \$0 budget - produces '
        'fit/exceeds language only for comparable fixed prices', () {
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
              tool.budgetAssessment.contains('exceeds'),
        ),
        isTrue,
      );

      final stripe = result.recommendations.singleWhere(
        (tool) => tool.name == 'Stripe',
      );
      expect(stripe.budgetAssessment, contains('additional variable charges'));
      expect(stripe.budgetAssessment, contains('Whether this fits your'));
      expect(stripe.budgetAssessment, isNot(contains('fits within')));

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

    test('a nonzero hard budget also produces fit/exceeds text', () {
      const state = ProjectState(
        projectType: 'small storefront',
        budget: Budget(amount: 50, currency: 'USD', hard: true),
      );
      final result = generateShortlist(
        state,
        priceEstimates: kToolPriceCatalogue,
      );
      final shopify = result.recommendations.firstWhere(
        (tool) => tool.name == 'Shopify',
      );

      expect(shopify.budgetAssessment, contains('fits within'));
    });

    test('does not compare currencies without an exchange rate', () {
      const state = ProjectState(
        projectType: 'small storefront',
        budget: Budget(amount: 50, currency: 'EUR', hard: true),
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
      expect(
        shopify.budgetAssessment,
        contains('https://www.shopify.com/pricing'),
      );

      final stripe = result.recommendations.singleWhere(
        (tool) => tool.name == 'Stripe',
      );
      expect(
        stripe.budgetAssessment,
        contains('additional variable charges apply'),
      );
      expect(
        stripe.budgetAssessment,
        contains('currencies cannot be compared'),
      );
    });
  });
}

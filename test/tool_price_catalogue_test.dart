import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/models/project_state.dart';
import 'package:kaizen/services/shortlist_generator.dart';
import 'package:kaizen/services/tool_price_catalogue.dart';

void main() {
  group('Real catalogue makes the fit/exceeds branch reachable', () {
    test('"free tools only" - extracted as a hard \$0 budget - produces '
        'per-entry fit/exceeds language', () {
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
      for (final tool in result.recommendations) {
        expect(tool.budgetAssessment, isNot(contains('is unverified')));
        expect(
          tool.budgetAssessment,
          anyOf(contains('fits within'), contains('exceeds')),
        );
      }

      final stripe = result.recommendations.firstWhere(
        (tool) => tool.name == 'Stripe',
      );
      expect(stripe.budgetAssessment, contains('fits within'));

      final shopify = result.recommendations.firstWhere(
        (tool) => tool.name == 'Shopify',
      );
      expect(shopify.budgetAssessment, contains('exceeds'));
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
  });
}

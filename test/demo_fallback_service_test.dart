import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/services/demo_fallback_service.dart';

void main() {
  group('DemoFallbackService', () {
    test('extracts facts and generates shortlist for mobile app with budget', () {
      final result = DemoFallbackService.generateShortlistResult(
        'Building a cross-platform mobile chat app on Flutter for iOS and Android with a hard budget of \$50/month',
      );

      expect(result.canRecommend, isTrue);
      expect(result.recommendations, isNotEmpty);
      expect(
        result.recommendations.any((r) => r.name == 'Supabase'),
        isTrue,
      );
      expect(result.budgetAcknowledgment, contains('50'));
    });

    test('extracts facts and generates shortlist for storefront with zero budget', () {
      final result = DemoFallbackService.generateShortlistResult(
        'Building a small storefront with checkout. Only free tools please.',
      );

      expect(result.canRecommend, isTrue);
      expect(result.budget?.amount, 0);
      expect(result.recommendations.any((r) => r.name == 'Shopify'), isTrue);
    });

    test('asks for clarification when prompt is too vague', () {
      final result = DemoFallbackService.generateShortlistResult('Hello');
      expect(result.canRecommend, isFalse);
      expect(result.toReplyText(), contains('What are you building?'));
    });
  });
}

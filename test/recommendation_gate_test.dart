import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/models/project_state.dart';
import 'package:kaizen/services/recommendation_gate.dart';

void main() {
  group('AC01 — minimal but concrete descriptions pass the gate', () {
    test('group chat app', () {
      final result = evaluateRecommendationGate(
        const ProjectState(projectType: 'group chat app'),
      );
      expect(result.canRecommend, isTrue);
      expect(result.missing, isEmpty);
    });

    test('small storefront', () {
      final result = evaluateRecommendationGate(
        const ProjectState(projectType: 'small storefront'),
      );
      expect(result.canRecommend, isTrue);
    });

    test('simple game', () {
      final result = evaluateRecommendationGate(
        const ProjectState(projectType: 'simple game'),
      );
      expect(result.canRecommend, isTrue);
    });
  });

  group('AC04 — underspecified input is refused, not guessed', () {
    test('no project type stated at all', () {
      final result = evaluateRecommendationGate(const ProjectState());
      expect(result.canRecommend, isFalse);
      expect(result.missing, contains('projectType'));
    });

    test('empty-string project type counts as unstated, not a value', () {
      final result = evaluateRecommendationGate(
        const ProjectState(projectType: ''),
      );
      expect(result.canRecommend, isFalse);
    });

    test('whitespace-only project type counts as unstated', () {
      final result = evaluateRecommendationGate(
        const ProjectState(projectType: '   '),
      );
      expect(result.canRecommend, isFalse);
    });
  });

  group('Budget/platform/features are optional, not gating', () {
    test('project type alone, with no budget, still passes', () {
      // This is the AC01 case restated deliberately: the gate must
      // NOT be tempted to require a budget just because AC03 cares
      // about budget acknowledgment downstream. Those are separate
      // concerns — gating vs. validating — and conflating them would
      // make AC01's three minimal test cases fail.
      final result = evaluateRecommendationGate(
        const ProjectState(projectType: 'simple game', platforms: []),
      );
      expect(result.canRecommend, isTrue);
    });

    test('fully detailed rich description also passes', () {
      final result = evaluateRecommendationGate(
        const ProjectState(
          projectType: 'collaborative markdown notes app',
          budget: Budget(amount: 30, currency: 'USD', hard: true),
          platforms: ['ios', 'android', 'web'],
          features: ['realtime sync', 'authentication'],
        ),
      );
      expect(result.canRecommend, isTrue);
    });
  });

  group('ProjectState JSON round-trip (matches the envelope shape)', () {
    test('parses a budget-bearing envelope correctly', () {
      final json = {
        'projectType': 'small storefront',
        'budget': {'amount': 50, 'currency': 'USD', 'hard': true},
        'platforms': ['ios', 'android'],
        'features': ['product list', 'cart', 'checkout'],
      };
      final state = ProjectState.fromJson(json);
      expect(state.projectType, 'small storefront');
      expect(state.budget?.amount, 50);
      expect(state.budget?.hard, isTrue);
      expect(state.platforms, ['ios', 'android']);
    });

    test('missing/null fields parse as null, not defaulted values', () {
      final state = ProjectState.fromJson({'projectType': null});
      expect(state.projectType, isNull);
      expect(state.budget, isNull);
      expect(evaluateRecommendationGate(state).canRecommend, isFalse);
    });
  });
}

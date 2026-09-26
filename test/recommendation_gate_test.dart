import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/models/project_state.dart';
import 'package:kaizen/services/recommendation_gate.dart';

void main() {
  group('AC01 — project descriptions with stated constraints pass', () {
    test('group chat app with platforms and budget', () {
      final result = evaluateRecommendationGate(
        const ProjectState(
          projectType: 'group chat app for a small friend circle',
          platforms: ['ios', 'android'],
          budget: Budget(amount: 0, currency: 'USD', hard: true),
        ),
      );
      expect(result.canRecommend, isTrue);
      expect(result.missing, isEmpty);
    });

    test('small storefront with feature and budget', () {
      final result = evaluateRecommendationGate(
        const ProjectState(
          projectType: 'small online storefront for handmade jewelry',
          features: ['card payments'],
          budget: Budget(amount: 40, currency: 'USD', hard: true),
        ),
      );
      expect(result.canRecommend, isTrue);
    });

    test('simple game with a platform and no budget', () {
      final result = evaluateRecommendationGate(
        const ProjectState(
          projectType: 'simple 2D single-player mobile game',
          platforms: ['android'],
        ),
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

    test('empty-string project type counts as unstated', () {
      final result = evaluateRecommendationGate(
        const ProjectState(projectType: ''),
      );
      expect(result.canRecommend, isFalse);
      expect(result.missing, contains('projectType'));
    });

    test('whitespace-only project type counts as unstated', () {
      final result = evaluateRecommendationGate(
        const ProjectState(projectType: '   '),
      );
      expect(result.canRecommend, isFalse);
      expect(result.missing, contains('projectType'));
    });

    test('a project name without any stated constraint is refused', () {
      final result = evaluateRecommendationGate(
        const ProjectState(projectType: 'chat app'),
      );
      expect(result.canRecommend, isFalse);
      expect(result.missing, contains('constraint'));
    });

    test('a hard zero budget is a stated constraint', () {
      final result = evaluateRecommendationGate(
        const ProjectState(
          projectType: 'chat app',
          budget: Budget(amount: 0, currency: 'USD', hard: true),
        ),
      );
      expect(result.canRecommend, isTrue);
    });

    test('a feature alone is enough to clear the constraint requirement', () {
      final result = evaluateRecommendationGate(
        const ProjectState(
          projectType: 'chat app',
          features: ['group messaging'],
        ),
      );
      expect(result.canRecommend, isTrue);
    });

    test('an invalid budget object is not treated as a constraint', () {
      final result = evaluateRecommendationGate(
        const ProjectState(
          projectType: 'chat app',
          budget: Budget(amount: -1, currency: 'USD', hard: true),
        ),
      );
      expect(result.canRecommend, isFalse);
      expect(result.missing, contains('constraint'));
    });

    test('blank platform and feature entries do not count as constraints', () {
      final result = evaluateRecommendationGate(
        const ProjectState(
          projectType: 'chat app',
          platforms: ['  '],
          features: [''],
        ),
      );
      expect(result.canRecommend, isFalse);
      expect(result.missing, contains('constraint'));
    });
  });

  group('ProjectState JSON parsing', () {
    test('parses a budget-bearing envelope correctly', () {
      final state = ProjectState.fromJson({
        'projectType': 'small storefront',
        'budget': {'amount': 50, 'currency': 'USD', 'hard': true},
        'platforms': ['ios', 'android'],
        'features': ['product list', 'cart', 'checkout'],
      });
      expect(state.projectType, 'small storefront');
      expect(state.budget?.amount, 50);
      expect(state.budget?.hard, isTrue);
      expect(state.platforms, ['ios', 'android']);
      expect(state.features, ['product list', 'cart', 'checkout']);
    });

    test('missing or invalid fields degrade to unknown values', () {
      final state = ProjectState.fromJson({
        'projectType': null,
        'budget': 'free',
        'platforms': 'android',
        'features': [null, 4, '  '],
      });
      expect(state.projectType, isNull);
      expect(state.budget, isNull);
      expect(state.platforms, isEmpty);
      expect(state.features, isEmpty);
      expect(evaluateRecommendationGate(state).canRecommend, isFalse);
    });

    test(
      'partial or malformed budgets degrade to null instead of throwing',
      () {
        final missingAmount = ProjectState.fromJson({
          'projectType': 'chat app',
          'budget': {'currency': 'USD'},
        });
        final stringAmount = ProjectState.fromJson({
          'projectType': 'chat app',
          'budget': {'amount': 'fifty', 'currency': 'USD'},
        });
        final invalidHardFlag = ProjectState.fromJson({
          'projectType': 'chat app',
          'budget': {'amount': 50, 'currency': 'USD', 'hard': 'yes'},
        });

        expect(missingAmount.budget, isNull);
        expect(stringAmount.budget, isNull);
        expect(invalidHardFlag.budget, isNull);
        expect(evaluateRecommendationGate(missingAmount).canRecommend, isFalse);
        expect(
          evaluateRecommendationGate(invalidHardFlag).canRecommend,
          isFalse,
        );
      },
    );

    test('serializes and parses its valid state', () {
      const state = ProjectState(
        projectType: 'chat app',
        budget: Budget(amount: 50, currency: 'USD', hard: true),
        platforms: ['android'],
        features: ['group messaging'],
      );

      final restored = ProjectState.fromJson(state.toJson());
      expect(restored.projectType, state.projectType);
      expect(restored.budget?.amount, state.budget?.amount);
      expect(restored.budget?.currency, state.budget?.currency);
      expect(restored.budget?.hard, state.budget?.hard);
      expect(restored.platforms, state.platforms);
      expect(restored.features, state.features);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/models/project_state.dart';
import 'package:kaizen/services/recommendation_gate.dart';
import 'package:kaizen/services/shortlist_generator.dart';

void main() {
  test(
    'does not produce a shortlist for a project name without constraints',
    () {
      final result = generateShortlist(
        const ProjectState(projectType: 'chat app'),
      );

      expect(result.canRecommend, isFalse);
      expect(result.recommendations, isEmpty);
      expect(
        result.toReplyText(),
        contains('What constraint should I prioritize?'),
      );
    },
  );

  test('generates 3-6 tailored tools with a tradeoff for each', () {
    final result = generateShortlist(
      const ProjectState(
        projectType: 'group chat app',
        platforms: ['android'],
        features: ['realtime group messaging'],
      ),
    );

    expect(result.canRecommend, isTrue);
    expect(result.recommendations.length, inInclusiveRange(3, 6));
    expect(validateShortlist(result), isEmpty);
    expect(
      result.recommendations.every(
        (item) =>
            item.name.isNotEmpty &&
            item.category.isNotEmpty &&
            item.rationale.contains('group chat app') &&
            item.rationale.contains('android') &&
            item.tradeoff.contains('android') &&
            item.tradeoff.contains('realtime group messaging'),
      ),
      isTrue,
    );
    expect(result.toReplyText(), contains('Tradeoff:'));
    expect(
      result.budgetAcknowledgment,
      contains('No usable budget was available'),
    );
  });

  test('acknowledges a hard budget without claiming live price fit', () {
    final result = generateShortlist(
      const ProjectState(
        projectType: 'small online store',
        budget: Budget(amount: 0, currency: 'USD', hard: true),
      ),
    );

    expect(result.canRecommend, isTrue);
    expect(result.recommendations.length, inInclusiveRange(3, 6));
    expect(result.budgetAcknowledgment, contains('hard cap of USD 0'));
    expect(
      result.budgetAcknowledgment,
      contains('not verified against live pricing'),
    );
    expect(validateShortlist(result), isEmpty);
    expect(result.recommendations.any((item) => item.name == 'Stripe'), isTrue);
    expect(
      result.recommendations.every(
        (item) =>
            item.budgetAssessment.contains('hard cap of USD 0') &&
            item.budgetAssessment.contains('fits or exceeds'),
      ),
      isTrue,
    );
  });

  test('per-tool budget assessments distinguish fits from breaks', () {
    final state = const ProjectState(
      projectType: 'small online store',
      budget: Budget(amount: 10, currency: 'USD', hard: true),
    );
    final names = generateShortlist(
      state,
    ).recommendations.map((item) => item.name).toList();
    final estimates = {
      for (final name in names)
        name: ToolPriceEstimate(
          monthlyAmount: name == 'Shopify' ? 29 : 5,
          currency: 'USD',
          basis: 'test estimate',
        ),
    };

    final result = generateShortlist(state, priceEstimates: estimates);

    expect(
      result.recommendations
          .where((item) => item.name == 'Shopify')
          .single
          .budgetAssessment,
      contains('exceeds your hard cap'),
    );
    expect(
      result.recommendations
          .where((item) => item.name != 'Shopify')
          .every((item) => item.budgetAssessment.contains('fits within')),
      isTrue,
    );
    expect(
      result.toReplyText().split('Budget:'),
      hasLength(result.recommendations.length + 1),
    );
  });

  test(
    'shortlist size bounds hold for undersized and oversized catalogues',
    () {
      ToolRecommendation candidate(String name) => ToolRecommendation(
        name: name,
        category: 'Category',
        rationale: 'Reason',
        tradeoff: 'Tradeoff',
      );

      expect(
        () => enforceShortlistBounds([candidate('one'), candidate('two')]),
        throwsA(isA<StateError>()),
      );

      final tenCandidates = List.generate(
        10,
        (index) => candidate('Tool $index'),
      );
      expect(enforceShortlistBounds(tenCandidates), hasLength(6));
      expect(
        generateShortlist(
          const ProjectState(
            projectType: 'simple game',
            platforms: ['android'],
          ),
        ).recommendations.length,
        inInclusiveRange(3, 6),
      );
    },
  );

  test('selects game-specific recommendations for a game project', () {
    final result = generateShortlist(
      const ProjectState(projectType: 'simple 2D game', platforms: ['android']),
    );

    expect(result.canRecommend, isTrue);
    expect(
      result.recommendations.any(
        (item) => item.name == 'Unity Gaming Services',
      ),
      isTrue,
    );
    expect(result.recommendations.length, inInclusiveRange(3, 6));
  });

  test('asks for a project type when the description omits it', () {
    final result = generateShortlist(
      const ProjectState(features: ['realtime messaging']),
    );

    expect(result.canRecommend, isFalse);
    expect(result.toReplyText(), contains('What are you building?'));
  });

  test('validator rejects shortlists that violate output invariants', () {
    final invalid = ShortlistResult(
      gate: const GateResult(verdict: GateVerdict.enough),
      recommendations: const [
        ToolRecommendation(
          name: 'Supabase',
          category: 'Backend',
          rationale: 'Fits the project.',
          tradeoff: '',
        ),
      ],
      budgetAcknowledgment: 'Budget noted.',
    );

    final violations = validateShortlist(invalid);
    expect(
      violations,
      contains('shortlist must contain between 3 and 6 tools'),
    );
    expect(
      violations,
      contains(
        'each tool needs a name, category, rationale, tradeoff, and budget assessment',
      ),
    );
  });
}

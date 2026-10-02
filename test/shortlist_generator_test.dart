import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/models/project_state.dart';
import 'package:kaizen/models/variable_rate.dart';
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
    expect(result.budgetAcknowledgment, contains('not live quotes'));
    expect(validateShortlist(result), isEmpty);
    expect(result.recommendations.any((item) => item.name == 'Stripe'), isTrue);
    expect(
      result.recommendations.every(
        (item) =>
            item.budgetAssessment.contains('hard cap of USD 0') &&
            (item.budgetAssessment.contains('unknown') ||
                item.budgetAssessment.contains('exceeds')),
      ),
      isTrue,
    );
  });

  test('per-tool budget assessments distinguish fits from breaks', () {
    final state = const ProjectState(
      projectType: 'small online store',
      budget: Budget(
        amount: 10,
        currency: 'USD',
        hard: true,
        period: BudgetPeriod.monthly,
      ),
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
          sourceUrl: 'https://example.com/pricing',
          lastChecked: '2026-09-26',
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
          .singleWhere((item) => item.name == 'Shopify')
          .budgetAssessment,
      contains('exceeds your hard cap per month'),
    );
    expect(
      result.recommendations
          .where((item) => item.name != 'Shopify')
          .every(
            (item) =>
                item.budgetAssessment.contains('fits within') ||
                item.budgetAssessment.contains('fixed monthly component'),
          ),
      isTrue,
    );
    expect(
      result.toReplyText(),
      contains('fixed monthly cost would total USD 44'),
    );
    expect(result.toReplyText(), contains('exceeds your hard cap per month'));
    expect(
      result.toReplyText().split('Budget:'),
      hasLength(result.recommendations.length + 1),
    );
  });

  test('total budgets compare only with a matching total-cost horizon', () {
    const state = ProjectState(
      projectType: 'small online store',
      budget: Budget(
        amount: 50,
        currency: 'USD',
        hard: true,
        period: BudgetPeriod.total,
      ),
    );
    final estimates = {
      for (final name in ['Shopify', 'Stripe', 'Supabase', 'Vercel'])
        name: ToolPriceEstimate(
          monthlyAmount: switch (name) {
            'Shopify' => 29,
            'Stripe' => 10,
            'Supabase' => 10,
            _ => 15,
          },
          currency: 'USD',
          basis: 'test estimate',
          sourceUrl: 'https://example.com/$name',
          lastChecked: '2026-09-26',
        ),
    };

    final result = generateShortlist(state, priceEstimates: estimates);

    expect(
      result.recommendations.every(
        (item) =>
            item.budgetAssessment.contains(
              'one month of all listed fixed costs exceeds',
            ) ||
            item.budgetAssessment.contains('project duration is unstated'),
      ),
      isTrue,
    );
  });

  test('monthly budget compares the summed listed monthly fixed costs', () {
    const state = ProjectState(
      projectType: 'small online store',
      budget: Budget(
        amount: 50,
        currency: 'USD',
        hard: true,
        period: BudgetPeriod.monthly,
      ),
    );
    const estimates = {
      'Shopify': ToolPriceEstimate(
        monthlyAmount: 29,
        currency: 'USD',
        basis: 'test estimate',
        sourceUrl: 'https://example.com/shopify',
        lastChecked: '2026-09-26',
      ),
      'Stripe': ToolPriceEstimate(
        monthlyAmount: 10,
        currency: 'USD',
        basis: 'test estimate',
        sourceUrl: 'https://example.com/stripe',
        lastChecked: '2026-09-26',
      ),
      'Vercel': ToolPriceEstimate(
        monthlyAmount: 5,
        currency: 'USD',
        basis: 'test estimate',
        sourceUrl: 'https://example.com/vercel',
        lastChecked: '2026-09-26',
      ),
      'Supabase': ToolPriceEstimate(
        monthlyAmount: 5,
        currency: 'USD',
        basis: 'test estimate',
        sourceUrl: 'https://example.com/supabase',
        lastChecked: '2026-09-26',
      ),
    };

    final result = generateShortlist(state, priceEstimates: estimates);

    expect(
      result.recommendations.every(
        (item) =>
            item.budgetAssessment.contains(
              'fixed monthly cost would total USD 49',
            ) &&
            item.budgetAssessment.contains('fits within') &&
            item.budgetAssessment.contains(
              'some recommendations may be alternatives',
            ),
      ),
      isTrue,
    );
  });

  test('unspecified budget period does not compare recurring prices', () {
    const state = ProjectState(
      projectType: 'small online store',
      budget: Budget(amount: 50, currency: 'USD', hard: true),
    );
    final estimates = {
      'Shopify': const ToolPriceEstimate(
        monthlyAmount: 29,
        currency: 'USD',
        basis: 'test estimate',
        sourceUrl: 'https://example.com/shopify',
        lastChecked: '2026-09-26',
      ),
      'Stripe': const ToolPriceEstimate(
        monthlyAmount: 0,
        currency: 'USD',
        basis: 'test estimate',
        sourceUrl: 'https://example.com/stripe',
        lastChecked: '2026-09-26',
        variableRate: VariableRate(
          freeAllowanceRequests: 0,
          ratePerRequest: 0.30,
        ),
      ),
      'Supabase': const ToolPriceEstimate(
        monthlyAmount: 5,
        currency: 'USD',
        basis: 'test estimate',
        sourceUrl: 'https://example.com/supabase',
        lastChecked: '2026-09-26',
      ),
      'Vercel': const ToolPriceEstimate(
        monthlyAmount: 0,
        currency: 'USD',
        basis: 'test estimate',
        sourceUrl: 'https://example.com/vercel',
        lastChecked: '2026-09-26',
      ),
    };

    final result = generateShortlist(state, priceEstimates: estimates);

    expect(
      result.recommendations
          .singleWhere((item) => item.name == 'Shopify')
          .budgetAssessment,
      contains('period was not stated'),
    );
    expect(
      result.recommendations
          .singleWhere((item) => item.name == 'Stripe')
          .budgetAssessment,
      contains('period was not stated'),
    );
    expect(
      result.recommendations
          .singleWhere((item) => item.name == 'Vercel')
          .budgetAssessment,
      contains('fits your'),
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

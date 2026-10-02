import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/controllers/chat_controller.dart';
import 'package:kaizen/screens/chat_screen.dart';
import 'package:kaizen/services/conversation_store.dart';
import 'package:kaizen/services/recommendation_gate.dart';
import 'package:kaizen/services/shortlist_generator.dart';
import 'package:kaizen/widgets/shortlist_estimate_widget.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  const sampleShortlist = ShortlistResult(
    gate: GateResult(verdict: GateVerdict.enough, missing: []),
    budgetAcknowledgment: 'Here is a starter shortlist for your storefront app:',
    recommendations: [
      ToolRecommendation(
        name: 'Supabase',
        category: 'Backend',
        rationale: 'Postgres database with auth',
        tradeoff: 'Requires SQL knowledge',
        budgetAssessment: 'Free tier available',
      ),
      ToolRecommendation(
        name: 'Shopify',
        category: 'Ecommerce',
        rationale: 'Hosted online store platform',
        tradeoff: 'Ongoing monthly subscription cost',
        budgetAssessment: 'Basic plan starting price',
      ),
      ToolRecommendation(
        name: 'Sentry',
        category: 'Monitoring',
        rationale: 'Error tracking and performance monitoring',
        tradeoff: 'Quota limits on free tier',
        budgetAssessment: 'Free developer plan',
      ),
    ],
  );

  const shortlistWithStripe = ShortlistResult(
    gate: GateResult(verdict: GateVerdict.enough, missing: []),
    budgetAcknowledgment: 'Here is a starter shortlist with payment processing:',
    recommendations: [
      ToolRecommendation(
        name: 'Supabase',
        category: 'Backend',
        rationale: 'Postgres database with auth',
        tradeoff: 'Requires SQL knowledge',
      ),
      ToolRecommendation(
        name: 'Stripe',
        category: 'Payments',
        rationale: 'Online payment processing',
        tradeoff: 'Per-transaction processing fees',
      ),
    ],
  );

  group('ShortlistEstimateWidget (TFS-007 User-Facing Features)', () {
    testWidgets(
      'AC01: user can mark and unmark tools to include/exclude them from estimate',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShortlistEstimateWidget(shortlist: sampleShortlist),
              ),
            ),
          ),
        );

        // Initially all 3 tools are marked
        expect(find.text('Shopify'), findsNWidgets(2)); // in tool list + in breakdown
        expect(find.byKey(const Key('project_estimate_total')), findsOneWidget);
        expect(find.text('\$29 / mo'), findsOneWidget);

        // Tap Shopify checkbox to unmark it
        await tester.tap(find.byKey(const Key('tool_checkbox_Shopify')));
        await tester.pump();

        // Total updates: Shopify removed, remaining Supabase ($0) + Sentry ($0) = $0
        expect(find.text('\$0 / mo'), findsOneWidget);

        // Tap Shopify checkbox again to mark it
        await tester.tap(find.byKey(const Key('tool_checkbox_Shopify')));
        await tester.pump();

        // Total restores to $29
        expect(find.text('\$29 / mo'), findsOneWidget);
      },
    );

    testWidgets(
      'AC02: upfront estimate shows plain-words basis assumption',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShortlistEstimateWidget(shortlist: sampleShortlist),
              ),
            ),
          ),
        );

        // Default rung is growth (10,000 requests/month)
        expect(
          find.byKey(const Key('usage_assumption_label')),
          findsOneWidget,
        );
        expect(
          find.text('assumes around 10,000 requests a month'),
          findsOneWidget,
        );

        // Shows upfront total estimate
        expect(find.text('\$29 / mo'), findsOneWidget);
        expect(find.text('USD, recurring'), findsOneWidget);
      },
    );

    testWidgets(
      'AC03: moving along usage ladder updates the total and basis label',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShortlistEstimateWidget(shortlist: sampleShortlist),
              ),
            ),
          ),
        );

        // Switch to Starter (1k)
        await tester.tap(find.byKey(const Key('usage_rung_starter')));
        await tester.pump();

        expect(
          find.text('assumes around 1,000 requests a month'),
          findsOneWidget,
        );

        // Switch to Scale (100k)
        await tester.tap(find.byKey(const Key('usage_rung_scale')));
        await tester.pump();

        expect(
          find.text('assumes around 100,000 requests a month'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AC04: Stripe cost reads as Unknown (never as a number) and grand total reads Unknown',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShortlistEstimateWidget(shortlist: shortlistWithStripe),
              ),
            ),
          ),
        );

        // Stripe is marked: its cost in the breakdown must read as Unknown (recurring), NOT a dollar amount
        expect(
          find.byKey(const Key('contribution_cost_Stripe')),
          findsOneWidget,
        );
        expect(find.text('Unknown (recurring)'), findsOneWidget);

        // Limitation note is clearly rendered
        expect(
          find.byKey(const Key('contribution_limitation_Stripe')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Excludes 2.9% transaction-value fee which requires transaction volume; total cost is unknown.',
          ),
          findsOneWidget,
        );

        // Grand total is Unknown, never a guessed or partial number
        expect(
          find.byKey(const Key('project_estimate_total')),
          findsOneWidget,
        );
        expect(find.text('Unknown'), findsOneWidget);

        // Caveat explanation is visible
        expect(
          find.byKey(const Key('project_estimate_caveat')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Total cannot be calculated because pricing for one or more chosen tools is unknown at this usage level.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AC05: empty selection prompts user to mark tools and never treats empty selection as \$0 estimate',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShortlistEstimateWidget(shortlist: sampleShortlist),
              ),
            ),
          ),
        );

        // Unmark all 3 tools
        await tester.tap(find.byKey(const Key('tool_checkbox_Supabase')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('tool_checkbox_Shopify')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('tool_checkbox_Sentry')));
        await tester.pump();

        // Empty selection guidance is shown
        expect(find.byKey(const Key('empty_selection_heading')), findsOneWidget);
        expect(find.text('No tools marked'), findsOneWidget);
        expect(find.byKey(const Key('empty_selection_message')), findsOneWidget);
        expect(
          find.text(
            'Mark one or more tools above to calculate your project estimate. '
            'Choosing tools will show an upfront monthly cost breakdown and '
            'total based on your assumed usage.',
          ),
          findsOneWidget,
        );

        // The estimate breakdown and total are NOT rendered (no false $0 estimate)
        expect(find.byKey(const Key('project_estimate_total')), findsNothing);
      },
    );

    testWidgets(
      'AC06: full breakdown shows tool contributions with cadence and total',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShortlistEstimateWidget(shortlist: sampleShortlist),
              ),
            ),
          ),
        );

        expect(find.text('Tool contributions (3):'), findsOneWidget);
        expect(find.text('\$0/mo (recurring)'), findsNWidgets(2)); // Supabase & Sentry
        expect(find.text('\$29/mo (recurring)'), findsOneWidget); // Shopify
        expect(find.text('\$29 / mo'), findsOneWidget);
      },
    );
  });

  group('ChatScreen integration with ShortlistEstimateWidget', () {
    testWidgets(
      'assistant message carrying shortlist renders ShortlistEstimateWidget on screen',
      (tester) async {
        final store = ConversationStore();
        final controller = ChatController(
          store,
          replySender: (_) async => sampleShortlist,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        // Send a message
        await controller.sendMessage('I want to build a small online shop');
        await tester.pumpAndSettle();

        // The assistant block renders the ShortlistEstimateWidget!
        expect(find.byType(ShortlistEstimateWidget), findsOneWidget);
        expect(find.text('Recommended shortlist'), findsOneWidget);
        expect(find.text('Upfront Cost Estimate'), findsOneWidget);
        expect(find.text('\$29 / mo'), findsOneWidget);
      },
    );
  });
}

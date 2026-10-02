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
      'AC05 on first render: starts empty with clear guidance prompt, no estimate or false \$0 displayed',
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

        // On initial paint, no tools are marked
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

        // Estimate total is NOT rendered on initial paint
        expect(find.byKey(const Key('project_estimate_total')), findsNothing);
      },
    );

    testWidgets(
      'AC01: user marks tools, estimate appears, and unmarking updates the total',
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

        // Initial state: empty
        expect(find.byKey(const Key('empty_selection_heading')), findsOneWidget);

        // Mark Shopify ($29)
        await tester.tap(find.byKey(const Key('tool_checkbox_Shopify')));
        await tester.pump();

        // Estimate is now displayed with Shopify
        expect(find.byKey(const Key('empty_selection_heading')), findsNothing);
        expect(find.byKey(const Key('project_estimate_total')), findsOneWidget);
        expect(find.text('\$29 / month'), findsOneWidget);
        expect(find.text('\$29/month (recurring)'), findsOneWidget);

        // Mark Supabase ($0)
        await tester.tap(find.byKey(const Key('tool_checkbox_Supabase')));
        await tester.pump();

        expect(find.text('Tool contributions (2):'), findsOneWidget);
        expect(find.text('\$0/month (recurring)'), findsOneWidget);
        expect(find.text('\$29 / month'), findsOneWidget);

        // Unmark Shopify -> only Supabase remains ($0)
        await tester.tap(find.byKey(const Key('tool_checkbox_Shopify')));
        await tester.pump();

        expect(find.text('Tool contributions (1):'), findsOneWidget);
        expect(find.text('\$0 / month'), findsOneWidget);

        // Unmark Supabase -> returns to empty selection prompt (AC05)
        await tester.tap(find.byKey(const Key('tool_checkbox_Supabase')));
        await tester.pump();

        expect(find.byKey(const Key('empty_selection_heading')), findsOneWidget);
        expect(find.byKey(const Key('project_estimate_total')), findsNothing);
      },
    );

    testWidgets(
      'AC02 & AC03: upfront estimate shows basis label and ladder updates costs',
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

        // Mark Shopify
        await tester.tap(find.byKey(const Key('tool_checkbox_Shopify')));
        await tester.pump();

        // Default rung is growth
        expect(
          find.byKey(const Key('usage_assumption_label')),
          findsOneWidget,
        );
        expect(
          find.text('assumes around 10,000 requests a month'),
          findsOneWidget,
        );
        expect(find.text('\$29 / month'), findsOneWidget);
        expect(find.text('USD, recurring'), findsOneWidget);

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

        // Mark Stripe
        await tester.tap(find.byKey(const Key('tool_checkbox_Stripe')));
        await tester.pump();

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
      'AC06: each tool contribution surfaces the verification date from the catalogue',
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

        // Mark Supabase and Shopify
        await tester.tap(find.byKey(const Key('tool_checkbox_Supabase')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('tool_checkbox_Shopify')));
        await tester.pump();

        // Verify lastChecked dates are rendered on each row
        expect(
          find.byKey(const Key('contribution_verified_Supabase')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('contribution_verified_Shopify')),
          findsOneWidget,
        );
        expect(find.text('Price verified: 2026-09-26'), findsNWidgets(2));
      },
    );

    testWidgets(
      'reads currency and one-time cadence from model rather than hardcoding',
      (tester) async {
        const customCatalogue = {
          'OneTimeSetup': ToolPriceEstimate(
            monthlyAmount: 50,
            currency: 'EUR',
            basis: 'Setup fee',
            sourceUrl: 'https://example.com',
            lastChecked: '2026-09-26',
            isRecurring: false,
          ),
        };

        const customShortlist = ShortlistResult(
          gate: GateResult(verdict: GateVerdict.enough, missing: []),
          recommendations: [
            ToolRecommendation(
              name: 'OneTimeSetup',
              category: 'Services',
              rationale: 'Initial setup service',
              tradeoff: 'Upfront cost',
            ),
          ],
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShortlistEstimateWidget(
                  shortlist: customShortlist,
                  catalogue: customCatalogue,
                ),
              ),
            ),
          ),
        );

        // Mark OneTimeSetup
        await tester.tap(find.byKey(const Key('tool_checkbox_OneTimeSetup')));
        await tester.pump();

        // Verifies EUR currency and one-time cadence are rendered without '/month'
        expect(find.text('€50 (one-time)'), findsOneWidget);
        expect(find.text('€50'), findsOneWidget);
        expect(find.text('EUR, one-time'), findsOneWidget);
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
        // Initially empty selection prompt is visible
        expect(find.text('No tools marked'), findsOneWidget);

        // User marks Shopify
        await tester.tap(find.byKey(const Key('tool_checkbox_Shopify')));
        await tester.pumpAndSettle();

        expect(find.text('\$29 / month'), findsOneWidget);
      },
    );
  });
}

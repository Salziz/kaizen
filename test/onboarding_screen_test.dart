import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kaizen/main.dart';
import 'package:kaizen/screens/onboarding_screen.dart';

void main() {
  late InMemorySharedPreferencesAsync preferencesStore;

  setUp(() {
    preferencesStore = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = preferencesStore;
  });

  group('OnboardingScreen UX Flow', () {
    testWidgets('Screen 1 renders hero cards with Supabase, Vercel, Sentry, Trigger.dev', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pump();

      // Top bar brand & skip button
      expect(find.text('KAIZEN'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);

      // Screen 1 headline
      expect(find.byKey(const Key('onboarding_heading_screen_1')), findsOneWidget);

      // Hero tool cards
      expect(find.text('Supabase'), findsOneWidget);
      expect(find.text('Vercel'), findsOneWidget);
      expect(find.text('Sentry'), findsOneWidget);
      expect(find.text('Trigger.dev'), findsOneWidget);
    });

    testWidgets('Progresses from Screen 1 to Screen 2 (Cost Clarity / Honest Estimates)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pump();

      // Tap Next to go to Screen 2
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Screen 2 headline & content
      expect(find.byKey(const Key('onboarding_heading_screen_2')), findsOneWidget);
      expect(find.text('ESTIMATED MONTHLY TOTAL'), findsOneWidget);
      expect(find.text('\$71'), findsOneWidget);
      expect(find.text('Verified catalogue'), findsOneWidget);
    });

    testWidgets('Progresses to Screen 3 (Domain picker) and allows multi-selection', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pump();

      // Screen 1 -> Screen 2
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Screen 2 -> Screen 3
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_heading_screen_3')), findsOneWidget);
      expect(find.text('B2B SaaS'), findsOneWidget);
      expect(find.text('Mobile App'), findsOneWidget);
      expect(find.text('AI & LLM Agent'), findsOneWidget);

      // Tap on Mobile App domain chip
      await tester.tap(find.byKey(const Key('domain_chip_mobile')));
      await tester.pumpAndSettle();

      // Verify Continue button is present on step 3
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Progresses to Screen 4 (Stage picker) and allows selecting stage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pump();

      // Navigate to Screen 4
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_heading_screen_4')), findsOneWidget);
      expect(find.text('Idea & Architecture'), findsOneWidget);
      expect(find.text('Building MVP'), findsOneWidget);
      expect(find.text('Scaling & Optimization'), findsOneWidget);

      // Select Prototype stage
      await tester.tap(find.byKey(const Key('stage_card_prototype')));
      await tester.pumpAndSettle();

      // Button says "Build My Space"
      expect(find.text('Build My Space'), findsOneWidget);
    });

    testWidgets('Progresses to Screen 5 (Celebration & Completion) and completes onboarding', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pump();

      // Settle up through Screen 4
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('onboarding_next_button')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('onboarding_heading_screen_4')), findsOneWidget);

      // Tap Next to navigate to Screen 5
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Screen 5 headline
      expect(find.byKey(const Key('onboarding_heading_screen_5')), findsOneWidget);

      // Tap Enter Workspace
      await tester.tap(find.byKey(const Key('onboarding_enter_workspace_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(completed, isTrue);

      // Verify preferences saved
      final prefs = SharedPreferencesAsync();
      final hasCompleted = await prefs.getBool('onboarding_completed');
      expect(hasCompleted, isTrue);
    });

    testWidgets('Skip button immediately triggers completion and records preferences', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pump();

      // Tap Skip on Screen 1
      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(completed, isTrue);

      final prefs = SharedPreferencesAsync();
      final hasCompleted = await prefs.getBool('onboarding_completed');
      expect(hasCompleted, isTrue);
    });

    testWidgets('KaizenApp routes to OnboardingScreen when showOnboarding is true', (tester) async {
      await tester.pumpWidget(const KaizenApp(showOnboarding: true));
      await tester.pump();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('KAIZEN'), findsOneWidget);
    });
  });
}

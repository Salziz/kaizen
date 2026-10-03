import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kaizen/main.dart';
import 'package:kaizen/screens/chat_screen.dart';
import 'package:kaizen/screens/onboarding_screen.dart';
import 'package:kaizen/widgets/kaizen_logo.dart';
import 'package:kaizen/screens/projects_screen.dart';

void main() {
  late InMemorySharedPreferencesAsync preferencesStore;

  setUp(() {
    preferencesStore = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = preferencesStore;
  });

  group('ProjectsScreen UI & Features', () {
    testWidgets('Renders header, stats, and default sample projects', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ProjectsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Brand & Header
      expect(find.byType(KaizenLogo), findsOneWidget);
      expect(find.text('kaizen'), findsOneWidget);
      expect(find.byKey(const Key('projects_heading')), findsOneWidget);

      // Stats
      expect(find.text('WORKSPACES'), findsOneWidget);
      expect(find.text('EST. BURN'), findsOneWidget);
      expect(find.text('CATALOGUE'), findsOneWidget);

      // Sample Projects
      expect(find.text('Pulse AI'), findsOneWidget);
      expect(find.text('Kite Mobile'), findsOneWidget);
      expect(find.text('Nova Storefront'), findsOneWidget);

      // Stack chips
      expect(find.text('Supabase Pro'), findsWidgets);
      expect(find.text('Vercel Pro'), findsWidgets);
    });

    testWidgets('Filtering by domain updates the visible list', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ProjectsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Filter by 'Mobile'
      await tester.tap(find.byKey(const Key('filter_tab_Mobile')));
      await tester.pumpAndSettle();

      expect(find.text('Kite Mobile'), findsOneWidget);
      expect(find.text('Pulse AI'), findsNothing);

      // Filter back to 'All'
      await tester.tap(find.byKey(const Key('filter_tab_All')));
      await tester.pumpAndSettle();

      expect(find.text('Pulse AI'), findsOneWidget);
      expect(find.text('Kite Mobile'), findsOneWidget);
    });

    testWidgets('Tapping a project card pushes ChatScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProjectsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Pulse AI
      await tester.tap(find.text('Pulse AI'));
      await tester.pumpAndSettle();

      // Should push ChatScreen
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('Tapping create project card opens modal and creates a new project', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProjectsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Start New Architecture
      await tester.tap(find.byKey(const Key('create_new_project_card')));
      await tester.pumpAndSettle();

      // Modal appears
      expect(find.text('New Project'), findsOneWidget);
      expect(find.byKey(const Key('new_project_title_input')), findsOneWidget);

      // Enter name
      await tester.enterText(
        find.byKey(const Key('new_project_title_input')),
        'Omni Agent',
      );
      await tester.pump();

      // Tap confirm button
      await tester.tap(find.byKey(const Key('confirm_create_project_button')));
      await tester.pumpAndSettle();

      // Enters ChatScreen
      expect(find.byType(ChatScreen), findsOneWidget);

      // Pop back to ProjectsScreen
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      // 'Omni Agent' is now visible in the list
      expect(find.text('Omni Agent'), findsOneWidget);
    });

    testWidgets('Tapping Intro Demo opens OnboardingScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProjectsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Intro Demo
      await tester.tap(find.byKey(const Key('replay_onboarding_button')));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('KaizenApp(showOnboarding: false) loads ProjectsScreen', (tester) async {
      await tester.pumpWidget(const KaizenApp(showOnboarding: false));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectsScreen), findsOneWidget);
    });

    testWidgets('Configuring Groq API key updates live indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProjectsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Starts in fallback mode
      expect(find.text('API Key'), findsOneWidget);

      // Open settings modal
      await tester.tap(find.byKey(const Key('api_key_settings_button')));
      await tester.pumpAndSettle();

      expect(find.text('Groq Live API Settings'), findsOneWidget);

      // Enter mock key
      await tester.enterText(
        find.byKey(const Key('groq_api_key_input')),
        'gsk_test1234567890abcdef',
      );
      await tester.pump();

      // Tap save
      await tester.tap(find.byKey(const Key('save_groq_key_button')));
      await tester.pumpAndSettle();

      // Now Live indicator appears
      expect(find.text('Live'), findsOneWidget);
    });
  });
}

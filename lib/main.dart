import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/chat_controller.dart';
import 'screens/chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/projects_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = SharedPreferencesAsync();
  final onboardingCompleted =
      await prefs.getBool('onboarding_completed') ?? false;
  runApp(KaizenApp(showOnboarding: !onboardingCompleted));
}

class KaizenApp extends StatelessWidget {
  const KaizenApp({
    super.key,
    this.controller,
    this.showOnboarding,
    this.homeScreen,
  });

  final ChatController? controller;
  final bool? showOnboarding;
  final Widget? homeScreen;

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (homeScreen != null) {
      home = homeScreen!;
    } else if (showOnboarding == true) {
      home = OnboardingScreen(controller: controller);
    } else if (showOnboarding == false) {
      home = ProjectsScreen(controller: controller);
    } else {
      home = ChatScreen(controller: controller);
    }

    return MaterialApp(
      title: 'Kaizen',
      restorationScopeId: 'kaizen_app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090A0F),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}

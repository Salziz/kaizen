import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/chat_controller.dart';
import 'screens/chat_screen.dart';
import 'screens/onboarding_screen.dart';

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
  });

  final ChatController? controller;
  final bool? showOnboarding;

  @override
  Widget build(BuildContext context) {
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
      home: (showOnboarding ?? false)
          ? OnboardingScreen(controller: controller)
          : ChatScreen(controller: controller),
    );
  }
}

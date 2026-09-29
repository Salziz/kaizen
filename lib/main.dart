import 'package:flutter/material.dart';

import 'controllers/chat_controller.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const KaizenApp());
}

class KaizenApp extends StatelessWidget {
  const KaizenApp({super.key, this.controller});

  final ChatController? controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaizen',
      restorationScopeId: 'kaizen_app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ChatScreen(controller: controller),
    );
  }
}

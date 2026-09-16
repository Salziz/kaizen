// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kaizen/main.dart';

void main() {
  late InMemorySharedPreferencesAsync preferencesStore;

  setUp(() {
    preferencesStore = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = preferencesStore;
  });

  testWidgets('shows the initial event', (WidgetTester tester) async {
    await tester.pumpWidget(const KaizenApp());

    expect(find.text('App launched'), findsOneWidget);
  });

  testWidgets('restores the resume message from the restoration bucket only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KaizenApp());

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    // Remove the durable fallback. A passing assertion now requires the
    // RestorationManager bucket written during the paused lifecycle event.
    await SharedPreferencesAsync().remove('backgrounded_at');

    await tester.restartAndRestore();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.textContaining('Resumed after'), findsOneWidget);
  });

  testWidgets('restores the resume message from preferences without a bucket', (
    WidgetTester tester,
  ) async {
    await preferencesStore.setString(
      'backgrounded_at',
      DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(),
      const SharedPreferencesOptions(),
    );

    // No paused lifecycle event is sent, so this fresh widget tree has no
    // restoration-bucket value. It must use the persisted fallback instead.
    await tester.pumpWidget(const KaizenApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Resumed after'), findsOneWidget);
  });
}

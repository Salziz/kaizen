import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const KaizenApp());
}

class KaizenApp extends StatelessWidget {
  const KaizenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaizen',
      // This top-level scope ID is required — without it, restoration
      // is disabled entirely for the whole app, silently.
      restorationScopeId: 'kaizen_app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RestorationMixin {
  static const _backgroundedAtKey = 'backgrounded_at';

  // RestorableDateTimeN is the nullable variant — survives process death,
  // unlike a plain DateTime? field which just lives in RAM.
  final RestorableDateTimeN _backgroundedAt = RestorableDateTimeN(null);
  final RestorableString _lastEvent = RestorableString('App launched');
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  bool _resumeHandled = false;

  @override
  String get restorationId => 'home_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    // Every RestorableProperty must be registered here, with a unique
    // key per property, or it won't actually be saved/restored.
    registerForRestoration(_backgroundedAt, 'backgrounded_at');
    registerForRestoration(_lastEvent, 'last_event');

    // On an Android activity recreation, `resumed` can be delivered before
    // this widget starts observing lifecycle changes. Handle the restored
    // timestamp here too, so "Don't keep activities" is covered.
    if (initialRestore && _backgroundedAt.value != null) {
      _recordResumeFromBackground();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restorePersistedBackgroundTime());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundedAt.dispose();
    _lastEvent.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        // .value writes through the RestorableProperty, which is what
        // actually persists it to disk — a plain field assignment
        // would not survive process death.
        _saveBackgroundTime();
        debugPrint('[Lifecycle] paused at ${_backgroundedAt.value}');
        break;

      case AppLifecycleState.resumed:
        if (_backgroundedAt.value != null) {
          setState(_recordResumeFromBackground);
        }
        break;

      case AppLifecycleState.inactive:
        debugPrint('[Lifecycle] inactive (transient — e.g. incoming call)');
        break;

      case AppLifecycleState.detached:
        debugPrint('[Lifecycle] detached');
        break;

      case AppLifecycleState.hidden:
        _saveBackgroundTime();
        debugPrint('[Lifecycle] hidden');
        break;
    }
  }

  void _recordResumeFromBackground() {
    if (_resumeHandled) {
      return;
    }

    final backgroundedAt = _backgroundedAt.value;
    if (backgroundedAt == null) {
      return;
    }

    _resumeHandled = true;
    final elapsed = DateTime.now().difference(backgroundedAt);
    debugPrint('[Lifecycle] resumed after ${elapsed.inSeconds}s');
    _lastEvent.value = 'Resumed after ${elapsed.inSeconds}s backgrounded';
    // Do not report this same interval again on a later restoration.
    _backgroundedAt.value = null;
    unawaited(_preferences.remove(_backgroundedAtKey));
  }

  void _saveBackgroundTime() {
    // The RestorableProperty handles Android instance state; this persistent
    // copy also survives a launch with no Android restoration bucket.
    _resumeHandled = false;
    _backgroundedAt.value ??= DateTime.now();
    unawaited(
      _preferences.setString(
        _backgroundedAtKey,
        _backgroundedAt.value!.toIso8601String(),
      ),
    );
  }

  Future<void> _restorePersistedBackgroundTime() async {
    final savedValue = await _preferences.getString(_backgroundedAtKey);
    final backgroundedAt = savedValue == null
        ? null
        : DateTime.tryParse(savedValue);

    if (!mounted ||
        _resumeHandled ||
        backgroundedAt == null ||
        _backgroundedAt.value != null) {
      return;
    }

    setState(() {
      _backgroundedAt.value = backgroundedAt;
      _recordResumeFromBackground();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kaizen')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _lastEvent.value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

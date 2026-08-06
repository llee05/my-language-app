import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';

import 'local_database.dart';
import 'database/flashcard_seed.dart';
import 'ai/ollama_service.dart';
import 'models/learner_profile.dart';
import 'models/learning_progress.dart';
import 'models/lesson.dart';
import 'repositories/app_dependencies.dart';
import 'repositories/development_repository.dart';
import 'repositories/lesson_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/settings_repository.dart';

export 'models/learner_profile.dart';
export 'models/lesson.dart';

part 'core/theme/app_colors.dart';
part 'core/widgets/app_sidebar.dart';
part 'core/widgets/shared_widgets.dart';
part 'features/ai_tutor/ai_tutor_page.dart';
part 'features/dashboard/dashboard_page.dart';
part 'features/dashboard/widgets/learning_panel.dart';
part 'features/dashboard/widgets/progress_rail.dart';
part 'features/lessons/lessons_page.dart';
part 'features/onboarding/learner_setup_page.dart';
part 'features/review/daily_queue_page.dart';
part 'features/settings/settings_page.dart';
part 'features/vocab_rush/vocab_rush_page.dart';
part 'features/vocabulary/vocabulary_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start Ollama automatically on desktop if it is not already running.
  try {
    await OllamaService.instance.ensureRunning();
  } catch (_) {
    // Keep the rest of the app usable if Ollama is not installed or on PATH.
  }

  // Initialize local services
  await LocalDatabase.ensureInitialized();
  runApp(const HanziPathApp());
}

class HanziPathApp extends StatefulWidget {
  const HanziPathApp({
    super.key,
    this.initialProfile,
    this.dependencies = const AppDependencies(),
  });

  /// Primarily useful for previews and widget tests.
  final LearnerProfile? initialProfile;
  final AppDependencies dependencies;

  @override
  State<HanziPathApp> createState() => _HanziPathAppState();
}

class _HanziPathAppState extends State<HanziPathApp> {
  late Future<LearnerProfile?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile == null
        ? _loadProfile()
        : Future.value(widget.initialProfile);
  }

  Future<LearnerProfile?> _loadProfile() async {
    return widget.dependencies.learners.load();
  }

  Future<void> _completeSetup(LearnerProfile profile) async {
    await widget.dependencies.learners.save(profile);
    if (!mounted) return;
    setState(() {
      _profile = Future.value(profile);
    });
  }

  Future<void> _resetOnboarding() async {
    await widget.dependencies.learners.clear();
    if (!mounted) return;
    setState(() {
      _profile = Future.value();
    });
  }

  Future<void> _resetAllData() async {
    await widget.dependencies.development.resetAllData();
    if (!mounted) return;
    setState(() {
      _profile = Future.value();
    });
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFFF6B5F);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HanziPath',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: AppColors.surface,
        ),
        fontFamily: 'sans-serif',
        dividerColor: AppColors.border,
        splashColor: seed.withValues(alpha: .12),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
            height: 1.15,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          titleMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          bodyMedium: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ),
      home: FutureBuilder<LearnerProfile?>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _AppLoadingScreen();
          }
          final profile = snapshot.data;
          if (profile == null) {
            return LearnerSetupPage(onComplete: _completeSetup);
          }
          return DashboardPage(
            profile: profile,
            onProfileChanged: _completeSetup,
            onResetOnboarding: _resetOnboarding,
            onResetAllData: _resetAllData,
            lessonRepository: widget.dependencies.lessons,
            progressRepository: widget.dependencies.progress,
            settingsRepository: widget.dependencies.settings,
            developmentRepository: widget.dependencies.development,
          );
        },
      ),
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2),
      ),
    );
  }
}

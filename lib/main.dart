import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show rootBundle;

import 'local_database.dart';
import 'database/flashcard_seed.dart';
import 'database/vocabulary_content.dart';
import 'ai/ollama_service.dart';
import 'models/learner_profile.dart';
import 'models/learning_progress.dart';
import 'models/lesson.dart';
import 'repositories/app_dependencies.dart';
import 'repositories/development_repository.dart';
import 'repositories/daily_review_session_repository.dart';
import 'repositories/lesson_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/sqlite_repositories.dart';
import 'services/review_scheduler.dart';
import 'services/pronunciation_service_factory.dart';
import 'services/study_streak_calculator.dart';

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
part 'features/review/daily_review_card_screen.dart';
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
  await LocalDatabase.initialize();
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
  late final PronunciationService _pronunciationService;

  @override
  void initState() {
    super.initState();
    _pronunciationService = widget.dependencies.createPronunciationService();
    final initialProfile = widget.initialProfile;
    if (initialProfile == null) {
      _profile = _loadProfileAndPronunciation();
    } else {
      _profile = Future.value(initialProfile);
    }
  }

  Future<LearnerProfile?> _loadProfileAndPronunciation() async {
    final profile = await _loadProfile();
    if (profile != null) unawaited(_restorePronunciationPreferences());
    return profile;
  }

  Future<void> _restorePronunciationPreferences() async {
    final service = _pronunciationService;
    if (service is! OfflinePronunciationManager) return;
    try {
      final settings = await widget.dependencies.settings.load();
      await (service as OfflinePronunciationManager).configurePronunciation(
        engine: settings.pronunciationEngine,
        voiceIds: settings.kokoroVoiceIds,
      );
    } catch (error) {
      debugPrint('Pronunciation preferences could not be restored: $error');
    }
  }

  Future<LearnerProfile?> _loadProfile() async {
    try {
      return await widget.dependencies.learners.load();
    } catch (error) {
      debugPrint('Learner profile load failed: $error');
      rethrow;
    }
  }

  void _retryProfileLoad() {
    setState(() {
      _profile = _loadProfileAndPronunciation();
    });
  }

  Future<void> _completeSetup(LearnerProfile profile) async {
    await widget.dependencies.learners.save(profile);
    if (!mounted) return;
    setState(() {
      _profile = Future.value(profile);
    });
  }

  Future<void> _resetOnboarding() async {
    await widget.dependencies.learners.resetOnboarding();
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
  void dispose() {
    unawaited(_pronunciationService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFFF6B5F);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TingShuo',
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
          if (snapshot.hasError) {
            return _AppStartupErrorScreen(onRetry: _retryProfileLoad);
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
            dailyReviewSessionRepository: widget.dependencies.dailyReviews,
            settingsRepository: widget.dependencies.settings,
            developmentRepository: widget.dependencies.development,
            pronunciationService: _pronunciationService,
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

class _AppStartupErrorScreen extends StatelessWidget {
  const _AppStartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _AppErrorState(
          key: const Key('app-startup-error'),
          title: _AppErrorCopy.profileTitle,
          message: _AppErrorCopy.profileMessage,
          onRetry: onRetry,
          retryKey: const Key('app-startup-retry'),
        ),
      ),
    ),
  );
}

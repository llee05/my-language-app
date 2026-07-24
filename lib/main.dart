import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'local_database.dart';
import 'database/flashcard_seed.dart';
import 'ai/ollama_service.dart';

part 'core/theme/app_colors.dart';
part 'core/widgets/app_sidebar.dart';
part 'core/widgets/shared_widgets.dart';
part 'features/ai_tutor/ai_tutor_page.dart';
part 'features/dashboard/dashboard_page.dart';
part 'features/dashboard/widgets/learning_panel.dart';
part 'features/dashboard/widgets/progress_rail.dart';
part 'features/lessons/lessons_page.dart';
part 'features/onboarding/learner_setup_page.dart';
part 'features/vocab_rush/vocab_rush_page.dart';

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

class LearnerProfile {
  const LearnerProfile({
    required this.name,
    required this.hskLevel,
    required this.dailyWordTarget,
  });

  final String name;
  final int hskLevel;
  final int dailyWordTarget;

  Map<String, dynamic> toJson() => {
    'name': name,
    'hskLevel': hskLevel,
    'dailyWordTarget': dailyWordTarget,
  };

  static LearnerProfile? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = json['name'];
    final hskLevel = json['hskLevel'];
    final dailyWordTarget = json['dailyWordTarget'];
    if (name is! String ||
        name.trim().isEmpty ||
        hskLevel is! int ||
        hskLevel < 1 ||
        hskLevel > 6 ||
        dailyWordTarget is! int ||
        dailyWordTarget < 1) {
      return null;
    }
    return LearnerProfile(
      name: name.trim(),
      hskLevel: hskLevel,
      dailyWordTarget: dailyWordTarget,
    );
  }
}

class HanziPathApp extends StatefulWidget {
  const HanziPathApp({super.key, this.initialProfile});

  /// Primarily useful for previews and widget tests.
  final LearnerProfile? initialProfile;

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
    final profile = await LocalDatabase.learnerProfile();
    return LearnerProfile.fromJson(profile);
  }

  Future<void> _completeSetup(LearnerProfile profile) async {
    await LocalDatabase.saveLearnerProfile(profile.toJson());
    if (!mounted) return;
    setState(() => _profile = Future.value(profile));
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
          return DashboardPage(profile: profile);
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

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'local_database.dart';
import 'database/flashcard_seed.dart';
import 'ai/ollama_service.dart';

part 'app_colors.dart';
part 'app_sidebar.dart';
part 'ai_tutor_page.dart';
part 'dashboard_page.dart';
part 'learning_panel.dart';
part 'progress_rail.dart';
part 'shared_widgets.dart';
part 'vocab_rush_page.dart';

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

class HanziPathApp extends StatelessWidget {
  const HanziPathApp({super.key});

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
      home: const DashboardPage(),
    );
  }
}

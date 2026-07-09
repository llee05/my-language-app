import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'local_database.dart';
import 'database/flashcard_seed.dart';
import 'ai/openai_service.dart';

part 'app_colors.dart';
part 'app_sidebar.dart';
part 'dashboard_page.dart';
part 'learning_panel.dart';
part 'progress_rail.dart';
part 'shared_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables from a local .env file (if present).
  // Create a `.env` file in the project root with `OPENAI_API_KEY=...` for local dev.
  try {
    await dotenv.load();
  } catch (_) {}

  // Initialize local services
  await LocalDatabase.ensureInitialized();

  // Initialize OpenAI service (loads key from dotenv)
  await OpenAIService.instance.ensureInitialized();
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

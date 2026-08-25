import 'development_repository.dart';
import 'daily_review_session_repository.dart';
import 'learner_repository.dart';
import 'lesson_repository.dart';
import 'progress_repository.dart';
import 'settings_repository.dart';
import 'sqlite_repositories.dart';
import '../services/pronunciation_service_factory.dart';

class AppDependencies {
  const AppDependencies({
    this.learners = const SqliteLearnerRepository(),
    this.lessons = const SqliteLessonRepository(),
    this.development = const SqliteDevelopmentRepository(),
    this.settings = const SqliteSettingsRepository(),
    this.progress = const SqliteProgressRepository(),
    this.dailyReviews = const SqliteDailyReviewSessionRepository(),
    this.createPronunciationService = createDefaultPronunciationService,
  });

  final LearnerRepository learners;
  final LessonRepository lessons;
  final DevelopmentRepository development;
  final SettingsRepository settings;
  final ProgressRepository progress;
  final DailyReviewSessionRepository dailyReviews;
  final PronunciationServiceFactory createPronunciationService;
}

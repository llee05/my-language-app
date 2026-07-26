import 'development_repository.dart';
import 'learner_repository.dart';
import 'lesson_repository.dart';
import 'sqlite_repositories.dart';

class AppDependencies {
  const AppDependencies({
    this.learners = const SqliteLearnerRepository(),
    this.lessons = const SqliteLessonRepository(),
    this.development = const SqliteDevelopmentRepository(),
  });

  final LearnerRepository learners;
  final LessonRepository lessons;
  final DevelopmentRepository development;
}

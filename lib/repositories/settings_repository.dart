import '../models/learning_progress.dart';

abstract interface class SettingsRepository {
  Future<LearnerSettings> load();
  Future<void> save(LearnerSettings settings);
}

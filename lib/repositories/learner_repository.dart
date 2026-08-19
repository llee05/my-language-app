import '../models/learner_profile.dart';

abstract interface class LearnerRepository {
  Future<LearnerProfile?> load();
  Future<void> save(LearnerProfile profile);
  Future<void> resetOnboarding();
}

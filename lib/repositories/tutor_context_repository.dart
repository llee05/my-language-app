import '../models/tutor_learner_snapshot.dart';

abstract interface class TutorContextRepository {
  /// Loads only the small subset of local study data approved for tutor use.
  Future<TutorLearnerSnapshot> load({required DateTime asOf});
}

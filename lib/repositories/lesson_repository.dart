import '../models/lesson.dart';

abstract interface class LessonRepository {
  Future<List<LessonSummary>> topics();

  Future<Lesson?> findById(int id);

  Future<Lesson?> findGenerated({required String theme, required int hskLevel});

  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  });

  /// Saves a new lesson, preserving earlier lessons on the same topic and
  /// their cards, review history, and session positions.
  Future<void> saveGenerated(Lesson lesson);
}

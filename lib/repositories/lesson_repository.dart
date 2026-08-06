import '../models/lesson.dart';

abstract interface class LessonRepository {
  Future<List<LessonSummary>> topics();

  Future<Lesson?> findById(int id);

  Future<Lesson?> findGenerated({required String theme, required int hskLevel});

  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  });

  Future<void> saveGenerated(Lesson lesson);
}

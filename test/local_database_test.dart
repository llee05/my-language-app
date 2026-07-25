import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/local_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('database initializes and starts empty', () async {
    await LocalDatabase.resetForTesting();
    final db = await LocalDatabase.ensureInitialized();

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='app_data'",
    );

    expect(tables, hasLength(1));

    final rows = await db.query('app_data');
    expect(rows, isEmpty);
  });

  test('learner profile is persisted in app data', () async {
    await LocalDatabase.saveLearnerProfile({
      'name': 'Mei',
      'hskLevel': 3,
      'dailyWordTarget': 20,
    });

    expect(await LocalDatabase.learnerProfile(), {
      'name': 'Mei',
      'hskLevel': 3,
      'dailyWordTarget': 20,
    });

    await LocalDatabase.clearLearnerProfile();
    expect(await LocalDatabase.learnerProfile(), isNull);
  });

  test('generated lessons are saved and offered as previous topics', () async {
    await LocalDatabase.resetForTesting();
    await LocalDatabase.ensureInitialized();

    await LocalDatabase.saveGeneratedLesson(
      title: 'Ordering breakfast · HSK 1',
      theme: 'Ordering breakfast',
      hskLevel: 1,
      cards: const [
        {
          'chinese': '吃',
          'pinyin': 'chī',
          'english_meaning': 'to eat',
          'part_of_speech': 'verb',
          'example_sentence_chinese': '我吃早饭。',
          'example_sentence_pinyin': 'Wǒ chī zǎofàn.',
          'example_sentence_english': 'I eat breakfast.',
        },
      ],
    );

    final topics = await LocalDatabase.lessonTopics();
    expect(topics.first['lesson_title'], 'Ordering breakfast · HSK 1');
    expect(topics.first['theme'], 'Ordering breakfast');

    final db = await LocalDatabase.ensureInitialized();
    final cards = await db.query(
      'cards',
      where: 'lesson_id = ?',
      whereArgs: [topics.first['id']],
    );
    expect(cards, hasLength(1));
    expect(cards.single['chinese'], '吃');
    expect(cards.single['example_sentence_english'], 'I eat breakfast.');

    final cached = await LocalDatabase.generatedLesson(
      theme: 'ordering BREAKFAST',
      hskLevel: 1,
    );
    expect(cached, isNotNull);
    expect(cached!['title'], 'Ordering breakfast · HSK 1');
    expect(cached['cards'], hasLength(1));
  });
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/repositories/bundled_listening_sentence_repository.dart';

const _example = {
  'source': 'Tatoeba',
  'chinese': '我喝茶。',
  'pinyin': 'Wǒ hē chá.',
  'english': 'I drink tea.',
  'chineseId': '123',
  'englishId': '456',
  'pinyinContributor': 'Test contributor',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const repository = BundledListeningSentenceRepository();

  test(
    'loads unique attributed sentences from the bundled Tatoeba examples',
    () async {
      final sentences = await repository.load();
      expect(sentences, hasLength(3567));
      expect(
        sentences.map((s) => s.chinese).toSet(),
        hasLength(sentences.length),
      );
      for (final sentence in sentences) {
        expect(sentence.chinese, isNotEmpty);
        expect(sentence.pinyin, isNotEmpty);
        expect(sentence.english, isNotEmpty);
        expect(sentence.practiceVocabularyIds, isNotEmpty);
        expect(sentence.chineseSource.host, 'tatoeba.org');
        expect(
          sentence.englishSource.path,
          '/en/sentences/show/${sentence.englishId}',
        );
      }
    },
  );

  test(
    'deduplicates deck overlap, excludes originals, and caches immutable data',
    () async {
      final bundle = _SentenceBundle([
        _example,
        _example,
        {..._example, 'source': 'Original', 'chinese': '原创。'},
      ]);
      final first = repository.load(bundle: bundle);
      final second = repository.load(bundle: bundle);
      final sentences = await first;
      expect(await second, same(sentences));
      expect(await repository.load(bundle: bundle), same(sentences));
      expect(bundle.reads, 1);
      expect(sentences, hasLength(1));
      expect(sentences.single.pinyinContributor, 'Test contributor');
      expect(sentences.single.practiceVocabularyIds, ['word-0', 'word-1']);
      expect(
        () => sentences.single.practiceVocabularyIds!.clear(),
        throwsUnsupportedError,
      );
      expect(
        sentences.single.chineseSource.toString(),
        'https://tatoeba.org/en/sentences/show/123',
      );
      expect(() => sentences.clear(), throwsUnsupportedError);
    },
  );

  for (final field in [
    'chinese',
    'pinyin',
    'english',
    'chineseId',
    'englishId',
  ]) {
    test('rejects missing $field and permits a corrected retry', () async {
      final bundle = _SentenceBundle([
        {..._example, field: ''},
      ]);
      await expectLater(repository.load(bundle: bundle), throwsFormatException);
      bundle.examples = [_example];
      expect(await repository.load(bundle: bundle), hasLength(1));
      expect(bundle.reads, 2);
    });
  }

  test('rejects invalid source IDs', () async {
    for (final id in ['0', '-1', 'sentence']) {
      await expectLater(
        repository.load(
          bundle: _SentenceBundle([
            {..._example, 'chineseId': id},
          ]),
        ),
        throwsFormatException,
      );
    }
  });
}

class _SentenceBundle extends CachingAssetBundle {
  _SentenceBundle(this.examples);
  List<Map<String, dynamic>> examples;
  int reads = 0;

  @override
  Future<ByteData> load(String key) async {
    expect(key, 'assets/data/vocabulary_lessons.json');
    reads++;
    return ByteData.sublistView(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'lessons': [
              {
                'entries': [
                  for (final (index, example) in examples.indexed)
                    {'vocabularyId': 'word-$index', 'example': example},
                ],
              },
            ],
          }),
        ),
      ),
    );
  }
}

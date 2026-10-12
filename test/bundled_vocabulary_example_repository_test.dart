import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/database/vocabulary_content.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_example_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const repository = BundledVocabularyExampleRepository();

  test(
    'all primary examples survive and alternates retain existing Tatoeba provenance',
    () async {
      final curriculum =
          jsonDecode(
                File('assets/data/vocabulary_lessons.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final primary = <String, dynamic>{};
      final pool = <String>{};
      for (final lesson in curriculum['lessons']) {
        for (final entry in lesson['entries']) {
          primary[entry['vocabularyId']] = entry['example'];
          if (entry['example']['source'] == 'Tatoeba') {
            pool.add(jsonEncode(entry['example']));
          }
        }
      }
      final document =
          jsonDecode(
                File('assets/data/vocabulary_examples.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      var alternates = 0;
      var withAlternates = 0;
      for (final entry in document['entries']) {
        final examples = entry['examples'] as List;
        expect(examples.first, primary[entry['vocabularyId']]);
        expect(examples.length, inInclusiveRange(1, 5));
        expect(
          examples.map((e) => e['chinese']).toSet(),
          hasLength(examples.length),
        );
        if (examples.length > 1) withAlternates++;
        for (final example in examples.skip(1)) {
          expect(
            pool.contains(jsonEncode(example)),
            isTrue,
            reason: entry['vocabularyId'],
          );
          expect(example['source'], 'Tatoeba');
          expect(example['chinese'], contains(entry['chinese']));
          alternates++;
        }
      }
      expect(primary, hasLength(4991));
      expect(document['entries'], hasLength(primary.length));
      expect(alternates, 1611);
      expect(withAlternates, 833);
      expect(document['alternateExampleCount'], alternates);
      expect(document['wordsWithAlternates'], withAlternates);
      expect(await repository.load(), hasLength(4991));
      expect(await repository.forWord('茶', 'chá'), hasLength(5));
      expect(await repository.forWord('茶', 'chā'), isEmpty);
      expect(await repository.forWord('自定义词', 'zì dìng yì cí'), isEmpty);
    },
  );

  test(
    'shares concurrent loads and exposes immutable maps and lists',
    () async {
      final bundle = _Bundle();
      final first = repository.load(bundle: bundle);
      final second = repository.load(bundle: bundle);
      final map = await first;
      expect(await second, same(map));
      expect(bundle.reads, 1);
      expect(() => map.clear(), throwsUnsupportedError);
      expect(() => map.values.first.clear(), throwsUnsupportedError);
      expect(map[vocabularyWordKey('茶', 'chá')]!.single.chineseId, '123');
    },
  );

  test(
    'invalid example metadata fails without preventing a corrected retry',
    () async {
      final bundle = _Bundle();
      bundle.example['pinyin'] = '';
      await expectLater(repository.load(bundle: bundle), throwsFormatException);
      bundle.example['pinyin'] = 'Wǒ hē chá.';
      bundle.example['chineseId'] = '0';
      await expectLater(repository.load(bundle: bundle), throwsFormatException);
      bundle.example['chineseId'] = '123';
      expect(await repository.load(bundle: bundle), hasLength(1));
      expect(bundle.reads, 3);
    },
  );
}

class _Bundle extends CachingAssetBundle {
  int reads = 0;
  final example = <String, dynamic>{
    'chinese': '我喝茶。',
    'pinyin': 'Wǒ hē chá.',
    'english': 'I drink tea.',
    'source': 'Tatoeba',
    'chineseId': '123',
    'englishId': '456',
    'pinyinContributor': 'Test author',
  };
  @override
  Future<ByteData> load(String key) async {
    reads++;
    expect(key, 'assets/data/vocabulary_examples.json');
    return ByteData.sublistView(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': 1,
            'entries': [
              {
                'chinese': '茶',
                'pinyin': 'chá',
                'examples': [example],
              },
            ],
          }),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_repository.dart';

void main() {
  const repository = BundledVocabularyRepository();

  test('shares concurrent parsing and returns deeply immutable data', () async {
    final bundle = _VocabularyBundle();
    final first = repository.load(bundle: bundle);
    final second = repository.load(bundle: bundle);
    final words = await first;
    expect(await second, same(words));
    expect(await repository.load(bundle: bundle), same(words));
    expect(bundle.reads, 1);
    expect(() => words.clear(), throwsUnsupportedError);
    expect(() => words.first['simplified'] = '错', throwsUnsupportedError);
    expect(
      () => (words.first['meanings'] as List).clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'asset eviction and different bundles do not reuse old content',
    () async {
      final bundle = _VocabularyBundle();
      final first = await repository.load(bundle: bundle);
      bundle.source = '[{"simplified":"新"}]';
      bundle.evict('assets/data/hsk_vocabulary.json');
      final second = await repository.load(bundle: bundle);
      expect(second, isNot(same(first)));
      expect(second.first['simplified'], '新');
      final other = await repository.load(bundle: _VocabularyBundle());
      expect(other.first['simplified'], '学');
    },
  );

  test('failed loads can be retried', () async {
    final bundle = _VocabularyBundle()..fail = true;
    await expectLater(repository.load(bundle: bundle), throwsStateError);
    bundle.fail = false;
    expect(await repository.load(bundle: bundle), hasLength(1));
    expect(bundle.reads, 2);
  });
}

class _VocabularyBundle extends CachingAssetBundle {
  int reads = 0;
  bool fail = false;
  String source = '[{"simplified":"学","meanings":["study"]}]';

  @override
  Future<ByteData> load(String key) async {
    reads++;
    if (fail) throw StateError('unavailable');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}

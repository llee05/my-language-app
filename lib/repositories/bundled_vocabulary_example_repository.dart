import 'dart:convert';

import 'package:flutter/services.dart';

import '../database/vocabulary_content.dart';
import '../models/vocabulary_example.dart';

/// Immutable examples keyed by the word's complete Mandarin reading.
class BundledVocabularyExampleRepository {
  const BundledVocabularyExampleRepository();

  Future<Map<String, List<VocabularyExample>>> load({AssetBundle? bundle}) =>
      (bundle ?? rootBundle).loadStructuredData(
        'assets/data/vocabulary_examples.json',
        (source) async {
          final document = jsonDecode(source) as Map<String, dynamic>;
          if (document['version'] != 1) {
            throw const FormatException('Unsupported vocabulary examples.');
          }
          final result = <String, List<VocabularyExample>>{};
          for (final entry in document['entries'] as List<dynamic>) {
            final chinese = entry['chinese'] as String;
            final pinyin = entry['pinyin'] as String;
            final examples = (entry['examples'] as List<dynamic>)
                .map(
                  (value) =>
                      VocabularyExample.fromJson(value as Map<String, dynamic>),
                )
                .toList(growable: false);
            final key = vocabularyWordKey(chinese, pinyin);
            if (chinese.trim().isEmpty ||
                pinyin.trim().isEmpty ||
                examples.isEmpty ||
                examples.length > 5 ||
                result.containsKey(key) ||
                examples.any((example) => !example.chinese.contains(chinese)) ||
                examples.map((example) => example.chinese).toSet().length !=
                    examples.length) {
              throw const FormatException('Invalid vocabulary examples.');
            }
            result[key] = List.unmodifiable(examples);
          }
          return Map<String, List<VocabularyExample>>.unmodifiable(result);
        },
      );

  Future<List<VocabularyExample>> forWord(
    String chinese,
    String pinyin,
  ) async => (await load())[vocabularyWordKey(chinese, pinyin)] ?? const [];
}

import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/listening_sentence.dart';

/// Reuses the attributed curriculum examples without packaging the full corpus.
class BundledListeningSentenceRepository {
  const BundledListeningSentenceRepository();

  Future<List<ListeningSentence>> load({AssetBundle? bundle}) =>
      (bundle ?? rootBundle).loadStructuredData(
        'assets/data/vocabulary_lessons.json',
        (source) async {
          final document = jsonDecode(source) as Map<String, dynamic>;
          final sentences = <String, ListeningSentence>{};
          final vocabularyIds = <String, Set<String>>{};
          for (final lesson in document['lessons'] as List<dynamic>) {
            for (final entry in lesson['entries'] as List<dynamic>) {
              final example = entry['example'] as Map<String, dynamic>;
              if (example['source'] != 'Tatoeba') continue;
              final sentence = ListeningSentence.fromTatoeba(example);
              // Overlapping decks and different headwords can share a sentence.
              sentences.putIfAbsent(sentence.chinese, () => sentence);
              final id = entry['vocabularyId'];
              if (id is! String || id.trim().isEmpty) {
                throw const FormatException('Missing sentence vocabulary ID.');
              }
              vocabularyIds.putIfAbsent(sentence.chinese, () => {}).add(id);
            }
          }
          return List<ListeningSentence>.unmodifiable(
            sentences.values.map(
              (sentence) => sentence.withPracticeVocabulary(
                vocabularyIds[sentence.chinese]!,
              ),
            ),
          );
        },
      );
}

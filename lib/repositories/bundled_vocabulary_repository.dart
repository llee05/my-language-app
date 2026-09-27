import 'dart:convert';

import 'package:flutter/services.dart';

/// Immutable bundled content, independent of learner progress.
/// CachingAssetBundle shares parsing across callers, retries failed parses, and
/// invalidates both string and structured data when the asset is evicted.
class BundledVocabularyRepository {
  const BundledVocabularyRepository();

  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) =>
      (bundle ?? rootBundle).loadStructuredData(
        'assets/data/hsk_vocabulary.json',
        (source) async {
          final decoded = jsonDecode(source) as List<dynamic>;
          return List<Map<String, dynamic>>.unmodifiable(
            decoded.map((entry) => _freeze(entry) as Map<String, dynamic>),
          );
        },
      );
}

Object? _freeze(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, item) => MapEntry(key, _freeze(item))),
    );
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

import 'dart:convert';

/// Vocabulary that an AI roleplay mission is allowed to use.
class RoleplayVocabularyWord {
  const RoleplayVocabularyWord({
    required this.chinese,
    required this.pinyin,
    required this.english,
  });

  final String chinese;
  final String pinyin;
  final String english;

  Map<String, String> toJson() => {
    'chinese': chinese,
    'pinyin': pinyin,
    'english': english,
  };
}

/// One locally validated turn returned by the configured AI provider.
class RoleplayMissionTurn {
  const RoleplayMissionTurn({
    required this.npcReply,
    required this.hint,
    required this.progress,
    required this.missionComplete,
    required this.feedback,
    required this.reviewWords,
  });

  final RoleplayPhrase npcReply;
  final RoleplayPhrase hint;
  final String progress;
  final bool missionComplete;
  final String feedback;
  final List<RoleplayVocabularyWord> reviewWords;

  static RoleplayMissionTurn fromAiResponse(
    String response, {
    required Iterable<RoleplayVocabularyWord> knownWords,
    required Iterable<RoleplayVocabularyWord> missionWords,
  }) {
    final normalized = response
        .trim()
        .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
        .replaceAll(RegExp(r'\s*```$'), '');
    final decoded = jsonDecode(normalized);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The roleplay turn must be a JSON object.');
    }

    final known = _roleplayWordMap(knownWords);
    final mission = _roleplayWordMap(missionWords);
    final allowed = {...mission, ...known};
    if (allowed.isEmpty) {
      throw const FormatException('The roleplay needs approved vocabulary.');
    }

    final npcReply = RoleplayPhrase.fromJson(
      _roleplayObject(decoded['npc_reply'], 'npc_reply'),
      allowedWords: allowed.keys.toSet(),
      knownWords: known.keys.toSet(),
    );
    final hint = RoleplayPhrase.fromJson(
      _roleplayObject(decoded['hint'], 'hint'),
      allowedWords: allowed.keys.toSet(),
      knownWords: known.keys.toSet(),
    );
    final complete = decoded['mission_complete'];
    if (complete is! bool) {
      throw const FormatException('mission_complete must be a boolean.');
    }
    final feedback = _roleplayText(
      decoded,
      'feedback',
      maxLength: 500,
      allowEmpty: !complete,
    );
    final reviewWordText = _roleplayStringList(
      decoded['review_words'],
      'review_words',
      maxItems: 5,
    );
    if (complete && (feedback.isEmpty || reviewWordText.isEmpty)) {
      throw const FormatException(
        'A completed mission needs feedback and review words.',
      );
    }
    if (!complete && (feedback.isNotEmpty || reviewWordText.isNotEmpty)) {
      throw const FormatException(
        'Feedback and review words are only valid after completion.',
      );
    }
    if (reviewWordText.toSet().length != reviewWordText.length ||
        reviewWordText.any((word) => !allowed.containsKey(word))) {
      throw const FormatException(
        'Review words must come from the approved vocabulary.',
      );
    }

    return RoleplayMissionTurn(
      npcReply: npcReply,
      hint: hint,
      progress: _roleplayText(decoded, 'progress', maxLength: 160),
      missionComplete: complete,
      feedback: feedback,
      reviewWords: List.unmodifiable([
        for (final word in reviewWordText) allowed[word]!,
      ]),
    );
  }
}

class RoleplayPhrase {
  const RoleplayPhrase({
    required this.chinese,
    required this.tokens,
    required this.pinyin,
    required this.english,
  });

  final String chinese;
  final List<String> tokens;
  final String pinyin;
  final String english;

  static RoleplayPhrase fromJson(
    Map<String, dynamic> json, {
    required Set<String> allowedWords,
    required Set<String> knownWords,
  }) {
    final tokens = _roleplayStringList(json['tokens'], 'tokens', maxItems: 24);
    if (tokens.isEmpty || tokens.any((word) => !allowedWords.contains(word))) {
      throw const FormatException(
        'The roleplay used vocabulary outside the approved word list.',
      );
    }
    if (knownWords.isNotEmpty) {
      final knownCount = tokens.where(knownWords.contains).length;
      if (knownCount * 2 <= tokens.length) {
        throw const FormatException(
          'The roleplay must use mostly studied vocabulary.',
        );
      }
    }
    final chinese = _roleplayText(json, 'chinese', maxLength: 140);
    if (_roleplayLexicalText(chinese) != _roleplayLexicalText(tokens.join())) {
      throw const FormatException(
        'Roleplay tokens must account for the complete Chinese phrase.',
      );
    }
    return RoleplayPhrase(
      chinese: chinese,
      tokens: tokens,
      pinyin: _roleplayText(json, 'pinyin', maxLength: 220),
      english: _roleplayText(json, 'english', maxLength: 220),
    );
  }
}

Map<String, RoleplayVocabularyWord> _roleplayWordMap(
  Iterable<RoleplayVocabularyWord> words,
) {
  final result = <String, RoleplayVocabularyWord>{};
  for (final word in words) {
    final chinese = word.chinese.trim();
    if (chinese.isEmpty) continue;
    result.putIfAbsent(chinese, () => word);
  }
  return result;
}

Map<String, dynamic> _roleplayObject(Object? value, String field) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$field must be an object.');
  }
  return value;
}

List<String> _roleplayStringList(
  Object? value,
  String field, {
  required int maxItems,
}) {
  if (value is! List || value.length > maxItems) {
    throw FormatException('$field must be a short list.');
  }
  final result = <String>[];
  for (final item in value) {
    if (item is! String || item.trim().isEmpty || item.length > 80) {
      throw FormatException('$field contains invalid text.');
    }
    result.add(item.trim());
  }
  return List.unmodifiable(result);
}

String _roleplayText(
  Map<String, dynamic> json,
  String field, {
  required int maxLength,
  bool allowEmpty = false,
}) {
  final value = json[field];
  if (value is! String || value.length > maxLength) {
    throw FormatException('$field is missing or too long.');
  }
  final text = value.trim();
  if (!allowEmpty && text.isEmpty) {
    throw FormatException('$field is missing or too long.');
  }
  return text;
}

String _roleplayLexicalText(String text) =>
    text.replaceAll(RegExp(r'''[\s，。！？、,.!?；;：:“”'"（）()…—-]'''), '');

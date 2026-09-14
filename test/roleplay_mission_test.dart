import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/models/roleplay_mission.dart';

const _knownWords = [
  RoleplayVocabularyWord(chinese: '你', pinyin: 'nǐ', english: 'you'),
  RoleplayVocabularyWord(chinese: '好', pinyin: 'hǎo', english: 'good'),
  RoleplayVocabularyWord(chinese: '我', pinyin: 'wǒ', english: 'I'),
  RoleplayVocabularyWord(chinese: '想', pinyin: 'xiǎng', english: 'want'),
  RoleplayVocabularyWord(chinese: '这个', pinyin: 'zhège', english: 'this'),
  RoleplayVocabularyWord(chinese: '不', pinyin: 'bù', english: 'not'),
];

const _missionWords = [
  RoleplayVocabularyWord(chinese: '菜', pinyin: 'cài', english: 'dish'),
  RoleplayVocabularyWord(chinese: '辣', pinyin: 'là', english: 'spicy'),
  RoleplayVocabularyWord(chinese: '点', pinyin: 'diǎn', english: 'to order'),
];

Map<String, Object?> _turnJson({
  bool complete = false,
  List<String> npcTokens = const ['你', '好', '你', '想', '点', '菜'],
}) => {
  'npc_reply': {
    'chinese': '${npcTokens.join()}？',
    'tokens': npcTokens,
    'pinyin': 'Nǐ hǎo, nǐ xiǎng diǎn cài?',
    'english': 'Hello, would you like to order?',
  },
  'hint': {
    'chinese': '我想点这个菜。',
    'tokens': ['我', '想', '点', '这个', '菜'],
    'pinyin': 'Wǒ xiǎng diǎn zhège cài.',
    'english': 'I would like to order this dish.',
  },
  'progress': complete ? 'Goal achieved.' : 'Order a dish and ask about spice.',
  'mission_complete': complete,
  'feedback': complete
      ? 'You ordered clearly and checked the spice level.'
      : '',
  'review_words': complete ? ['菜', '辣'] : <String>[],
};

void main() {
  test('parses a constrained in-progress roleplay turn', () {
    final turn = RoleplayMissionTurn.fromAiResponse(
      '```json\n${jsonEncode(_turnJson())}\n```',
      knownWords: _knownWords,
      missionWords: _missionWords,
    );

    expect(turn.npcReply.chinese, '你好你想点菜？');
    expect(turn.hint.chinese, '我想点这个菜。');
    expect(turn.missionComplete, isFalse);
    expect(turn.reviewWords, isEmpty);
  });

  test('maps completed review words to locally supplied vocabulary', () {
    final turn = RoleplayMissionTurn.fromAiResponse(
      jsonEncode(_turnJson(complete: true)),
      knownWords: _knownWords,
      missionWords: _missionWords,
    );

    expect(turn.missionComplete, isTrue);
    expect(turn.feedback, contains('spice level'));
    expect(turn.reviewWords.map((word) => word.pinyin), ['cài', 'là']);
  });

  test('rejects vocabulary outside the approved mission set', () {
    expect(
      () => RoleplayMissionTurn.fromAiResponse(
        jsonEncode(_turnJson(npcTokens: const ['你', '好', '服务员'])),
        knownWords: _knownWords,
        missionWords: _missionWords,
      ),
      throwsFormatException,
    );
  });

  test('rejects turns that do not use mostly studied vocabulary', () {
    expect(
      () => RoleplayMissionTurn.fromAiResponse(
        jsonEncode(_turnJson(npcTokens: const ['点', '菜', '辣'])),
        knownWords: _knownWords,
        missionWords: _missionWords,
      ),
      throwsFormatException,
    );
  });

  test('requires feedback and review words when a mission completes', () {
    final json = _turnJson(complete: true)
      ..['feedback'] = ''
      ..['review_words'] = <String>[];

    expect(
      () => RoleplayMissionTurn.fromAiResponse(
        jsonEncode(json),
        knownWords: _knownWords,
        missionWords: _missionWords,
      ),
      throwsFormatException,
    );
  });
}

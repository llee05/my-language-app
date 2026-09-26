import 'dart:math';

import '../database/vocabulary_content.dart';

/// Local retrieval keeps both AI and offline lessons grounded in bundled words.
class LessonVocabularySelector {
  const LessonVocabularySelector();

  List<Map<String, dynamic>> select({
    required List<Map<String, dynamic>> vocabulary,
    required String topic,
    required int hskLevel,
    Set<String> studiedWords = const {},
    Set<String> previousWords = const {},
    bool randomMix = false,
    required Random random,
  }) {
    final terms = _tokens(topic).difference(_stopWords);
    final expanded = {...terms};
    for (final group in _topicGroups) {
      if (group.any(terms.contains)) expanded.addAll(group);
    }
    final seen = <String>{};
    final pool = vocabulary.where((word) {
      return (word['hskLevel'] as int) <= hskLevel &&
          seen.add(word['simplified'] as String);
    }).toList()..shuffle(random);
    int score(Map<String, dynamic> word) {
      if (randomMix) return 0;
      final chinese = word['simplified'] as String;
      final meaning = _tokens(vocabularyStudyMeaning(word));
      // Match whole words in the concise study meaning, not incidental prose
      // in long dictionary entries (e.g. "and" inside "husband").
      return expanded
          .where((term) => term == chinese || meaning.contains(term))
          .length;
    }

    final scores = {for (final word in pool) word['simplified']: score(word)};
    final order = {
      for (final (index, word) in pool.indexed) word['simplified']: index,
    };
    pool.sort((a, b) {
      final aText = a['simplified'] as String;
      final bText = b['simplified'] as String;
      final relevance = scores[bText]!.compareTo(scores[aText]!);
      if (relevance != 0) return relevance;
      final previous = (previousWords.contains(aText) ? 1 : 0).compareTo(
        previousWords.contains(bText) ? 1 : 0,
      );
      if (previous != 0) return previous;
      final studied = (studiedWords.contains(aText) ? 1 : 0).compareTo(
        studiedWords.contains(bText) ? 1 : 0,
      );
      if (studied != 0) return studied;
      return order[aText]!.compareTo(order[bText]!);
    });
    final current = pool.where((word) => word['hskLevel'] == hskLevel).toList();
    final supporting = pool
        .where((word) => word['hskLevel'] != hskLevel)
        .toList();
    // Interleave so taking the first ten also yields a balanced offline deck.
    // At least two thirds of a full shortlist come from the requested level.
    final selected = <Map<String, dynamic>>[];
    var currentIndex = 0;
    var supportingIndex = 0;
    while (selected.length < 60 &&
        (currentIndex < current.length ||
            supportingIndex < supporting.length)) {
      for (var i = 0; i < 2 && currentIndex < current.length; i++) {
        selected.add(current[currentIndex++]);
      }
      if (supportingIndex < supporting.length && selected.length < 60) {
        selected.add(supporting[supportingIndex++]);
      }
    }
    return selected.take(60).toList(growable: false);
  }
}

Set<String> _tokens(String text) => {
  for (final match in RegExp(
    r'[a-z]+|[\u3400-\u9fff]+',
  ).allMatches(text.toLowerCase()))
    _singular(match.group(0)!),
};

String _singular(String word) {
  if (word.endsWith('ies') && word.length > 4) {
    return '${word.substring(0, word.length - 3)}y';
  }
  if (word.endsWith('s') && !word.endsWith('ss') && word.length > 3) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

const _stopWords = {
  'a',
  'an',
  'the',
  'and',
  'or',
  'in',
  'on',
  'at',
  'of',
  'to',
  'for',
  'with',
  'about',
  'lesson',
  'please',
  'learn',
  'me',
  'my',
};

// Small concept groups cover the built-in topics and common custom scenarios.
// Unknown topics still use whole-word retrieval plus level-balanced exploration.
final _topicGroups = <Set<String>>[
  _tokens(
    'daily life routine everyday morning evening wake sleep eat drink home work 今天 明天 早上 晚上 起床 睡觉 吃 喝',
  ),
  _tokens(
    'greeting hello goodbye welcome thank thanks sorry please meet name 你好 您 谢谢 再见 请 对不起 认识 叫 好',
  ),
  _tokens(
    'family parent mother father mom dad son daughter brother sister husband wife child 家 妈妈 爸爸 儿子 女儿',
  ),
  _tokens(
    'food drink breakfast lunch dinner dining restaurant order ordering eat tea coffee rice noodle vegetable fruit water hungry 餐厅 饭店 吃 喝 菜 米饭 水 茶',
  ),
  _tokens(
    'number time clock hour minute day week month year date today tomorrow yesterday 数字 时间 点 分钟',
  ),
  _tokens(
    'school education study learn teacher student class lesson book read write exam university 学校 老师 学生 学习',
  ),
  _tokens(
    'shopping buy sell price money shop store expensive cheap pay clothes 买 卖 钱 商店',
  ),
  _tokens(
    'weather rain snow wind sunny cloudy cold hot temperature 天气 雨 雪 冷 热',
  ),
  _tokens('hobby sport music movie play swim dance sing exercise 爱好 运动 音乐 电影'),
  _tokens(
    'getting around travel trip transport bus train plane airport station road ticket hotel map journey 旅行 旅游 车 车站 飞机',
  ),
  _tokens('work job office company meeting colleague career study 工作 公司 办公室'),
  _tokens(
    'culture chinese tradition festival custom holiday art history 文化 传统 节日',
  ),
  _tokens(
    'technology computer phone internet software science digital robot invention 技术 科技 电脑 网络',
  ),
  _tokens('relationship friend love marriage together feeling emotion 关系 朋友 爱'),
  _tokens(
    'news medium media report newspaper television interview journalist 新闻 报纸 记者',
  ),
  _tokens(
    'health doctor hospital medicine sick illness body treatment exercise 健康 医生 医院',
  ),
  _tokens('society community public citizen population social 社会 公共 人口'),
  _tokens(
    'environment pollution climate nature forest animal protect recycle 环境 污染 保护',
  ),
  _tokens(
    'art literature novel poetry poem story author paint painting music 艺术 文学 小说',
  ),
  _tokens(
    'business commerce trade company contract customer market profit investment 商业 贸易 合同 客户',
  ),
  _tokens(
    'economic economics economy finance capital demand supply inflation currency bank tax market investment 经济 资本 金融 需求',
  ),
  _tokens(
    'politic politics political government law election policy state nation citizen democracy president reform 政治 政府 法律 政策 民主',
  ),
  _tokens(
    'science research experiment evidence theory discover laboratory 科学 研究 实验 理论',
  ),
  _tokens(
    'history philosophy historical ancient dynasty civilization thought belief reason 历史 哲学 思想 古代',
  ),
];

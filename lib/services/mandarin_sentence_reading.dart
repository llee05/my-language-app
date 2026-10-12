/// Splits source pinyin without replacing it with dictionary or provider text.
/// Tone numbers, tone marks, apostrophes, joined syllables and erhua are accepted.
class MandarinSyllable {
  const MandarinSyllable({
    required this.base,
    required this.tone,
    this.capitalized = false,
    this.sentenceInitial = false,
  });

  final String base;
  final int tone;
  final bool capitalized;
  final bool sentenceInitial;
}

List<MandarinSyllable>? parseMandarinSentenceReading(String pinyin) {
  if (pinyin.length > 8192) return null;
  final source = pinyin.replaceAll('u:', 'ü').replaceAll('U:', 'Ü');
  final chunks = RegExp(
    r'[a-zA-ZüÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙǕǗǙǛńňǹḿŃŇǸḾ\u0300-\u036f1-5]+',
  ).allMatches(source);
  final result = <MandarinSyllable>[];
  var previousEnd = 0;
  for (final chunk in chunks) {
    if (_hasUnparsedLetters(source.substring(previousEnd, chunk.start))) {
      return null;
    }
    final text = chunk.group(0)!;
    if (text.length > 512) return null;
    final parsed = _splitPinyinChunk(text);
    if (parsed == null) return null;
    final capitalized = text[0] != text[0].toLowerCase();
    final initial =
        result.isEmpty ||
        RegExp(
          r'[.!?。！？]',
        ).hasMatch(source.substring(previousEnd, chunk.start));
    result.addAll(
      parsed.map(
        (syllable) => MandarinSyllable(
          base: syllable.base,
          tone: syllable.tone,
          capitalized: capitalized,
          sentenceInitial: initial,
        ),
      ),
    );
    previousEnd = chunk.end;
  }
  if (_hasUnparsedLetters(source.substring(previousEnd))) return null;
  return List.unmodifiable(result);
}

bool _hasUnparsedLetters(String text) => text.runes.any((rune) {
  final character = String.fromCharCode(rune);
  return (rune >= 48 && rune <= 57) ||
      (rune >= 0x3400 && rune <= 0x9fff) ||
      character.toLowerCase() != character.toUpperCase();
});

List<MandarinSyllable>? _splitPinyinChunk(String chunk) {
  final memo = <int, List<MandarinSyllable>?>{};
  List<MandarinSyllable>? split(int start) {
    if (start == chunk.length) return const [];
    if (memo.containsKey(start)) return memo[start];
    List<MandarinSyllable>? best;
    for (var end = start + 1; end <= chunk.length && end <= start + 9; end++) {
      final syllable = _parsePinyinSyllable(chunk.substring(start, end));
      if (syllable == null) continue;
      final rest = split(end);
      if (rest == null) continue;
      final candidate = [syllable, ...rest];
      if (best == null || candidate.length < best.length) best = candidate;
    }
    return memo[start] = best;
  }

  return split(0);
}

MandarinSyllable? _parsePinyinSyllable(String source) {
  const marks = {
    'ā': ('a', 1),
    'á': ('a', 2),
    'ǎ': ('a', 3),
    'à': ('a', 4),
    'ē': ('e', 1),
    'é': ('e', 2),
    'ě': ('e', 3),
    'è': ('e', 4),
    'ī': ('i', 1),
    'í': ('i', 2),
    'ǐ': ('i', 3),
    'ì': ('i', 4),
    'ō': ('o', 1),
    'ó': ('o', 2),
    'ǒ': ('o', 3),
    'ò': ('o', 4),
    'ū': ('u', 1),
    'ú': ('u', 2),
    'ǔ': ('u', 3),
    'ù': ('u', 4),
    'ǖ': ('ü', 1),
    'ǘ': ('ü', 2),
    'ǚ': ('ü', 3),
    'ǜ': ('ü', 4),
    'ń': ('n', 2),
    'ň': ('n', 3),
    'ǹ': ('n', 4),
    'ḿ': ('m', 2),
  };
  var text = source.toLowerCase().replaceAll('v', 'ü');
  var tone = 5;
  var marked = false;
  final last = int.tryParse(text[text.length - 1]);
  if (last != null) {
    if (last < 1 || last > 5) return null;
    tone = last;
    marked = true;
    text = text.substring(0, text.length - 1);
  }
  var base = '';
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    final value = marks[character];
    if (value != null) {
      if (marked) return null;
      base += value.$1;
      tone = value.$2;
      marked = true;
    } else if (character == '\u0308') {
      if (!base.endsWith('u')) return null;
      base = '${base.substring(0, base.length - 1)}ü';
    } else if (const [
      '\u0304',
      '\u0301',
      '\u030c',
      '\u0300',
    ].contains(character)) {
      if (marked || base.isEmpty) return null;
      tone =
          const ['\u0304', '\u0301', '\u030c', '\u0300'].indexOf(character) + 1;
      marked = true;
    } else {
      base += character;
    }
  }
  if (!_pinyinBases.contains(base)) return null;
  return MandarinSyllable(base: base, tone: tone);
}

// Mandarin syllable inventory, including source-attested syllabic nasals and r.
final _pinyinBases =
    'a ai an ang ao ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu ca cai can cang cao ce ceng cha chai chan chang chao che chen cheng chi chong chou chu chuan chuang chui chun chuo ci cong cou cu cuan cui cun cuo da dai dan dang dao de dei deng di dian diao die ding diu dong dou du duan dui dun duo e en er fa fan fang fei fen feng fo fou fu ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo ha hai han hang hao he hei hen heng hm hng hong hou hu hua huai huan huang hui hun huo ji jia jian jiang jiao jie jin jing jiu ju juan jue jun ka kai kan kang kao ke ken keng kong kou ku kua kuai kuan kuang kui kun kuo la lai lan lang lao le lei leng li lia lian liang liao lie lin ling liu long lou lu luan lun luo lü lüe m ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu n na nai nan nao ne nei nen neng ng ni nian niang niao nie nin ning niu nong nu nuan nuo nü nüe o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun r ran rang rao re ren reng ri rong rou ru ruan rui run ruo sa sai san sang sao se sen sha shai shan shang shao she shei shen sheng shi shou shu shua shuai shuan shuang shui shun shuo si song sou su suan sui sun suo ta tai tan tang tao te teng ti tian tiao tie ting tong tou tu tuan tui tun tuo wa wai wan wang wei wen wo wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun ya yan yang yao ye yi yin ying yo yong you yu yuan yue yun za zai zan zang zao ze zei zen zeng zha zhai zhan zhang zhao zhe zhen zheng zhi zhong zhou zhu zhua zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo'
        .split(' ')
        .toSet();

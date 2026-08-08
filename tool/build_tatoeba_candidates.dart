import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/build_tatoeba_candidates.dart '
      '<sentence-pairs.tsv> <flashcard-seed.dart> <output.json>',
    );
    exitCode = 64;
    return;
  }

  final targets = _readTargets(File(args[1]));
  final candidates = <String, List<_Candidate>>{
    for (final target in targets) target.word: <_Candidate>[],
  };

  var malformedRows = 0;
  final lines = File(
    args[0],
  ).openRead().transform(utf8.decoder).transform(const LineSplitter());

  lines.listen(
    (rawLine) {
      final line = rawLine.startsWith('\ufeff')
          ? rawLine.substring(1)
          : rawLine;
      final fields = line.split('\t');
      if (fields.length != 4) {
        malformedRows++;
        return;
      }

      final chinese = fields[1].trim();
      final english = fields[3].trim();
      for (final target in targets) {
        if (!chinese.contains(target.word)) continue;
        candidates[target.word]!.add(
          _Candidate(
            chineseId: int.tryParse(fields[0]) ?? 0,
            chinese: chinese,
            englishId: int.tryParse(fields[2]) ?? 0,
            english: english,
            score: _score(chinese, english, target),
          ),
        );
      }
    },
    onDone: () {
      final output = <Map<String, Object>>[];
      var covered = 0;
      for (final target in targets) {
        final matches = candidates[target.word]!;
        matches.sort((a, b) => b.score.compareTo(a.score));
        final unique = <String>{};
        final best = matches
            .where((candidate) => unique.add(candidate.chinese))
            .take(12)
            .map((candidate) => candidate.toJson())
            .toList();
        if (best.isNotEmpty) covered++;
        output.add({
          'target': target.word,
          'hskLevel': target.hskLevel,
          'candidateCount': matches.length,
          'candidates': best,
        });
      }

      File(args[2]).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(output)}\n',
      );
      stdout.writeln(
        'Matched $covered/${targets.length} targets; '
        'ignored $malformedRows malformed rows.',
      );
    },
  );
}

List<_Target> _readTargets(File seed) {
  final targets = <_Target>[];
  var hskLevel = 1;
  for (final line in seed.readAsLinesSync()) {
    final levelMatch = RegExp(r'"hsk_level": (\d+)').firstMatch(line);
    if (levelMatch != null) hskLevel = int.parse(levelMatch.group(1)!);

    final wordMatch = RegExp(r'^\s{8}"chinese": "([^"]+)"').firstMatch(line);
    if (wordMatch != null) {
      targets.add(_Target(wordMatch.group(1)!, hskLevel));
    }
  }
  if (targets.isEmpty) {
    throw const FormatException('No flashcard targets were found in the seed.');
  }
  return targets;
}

int _score(String chinese, String english, _Target target) {
  final hanziLength = RegExp(r'[\u3400-\u9fff]').allMatches(chinese).length;
  final englishWords = english.split(RegExp(r'\s+')).length;
  final idealLength = 6 + target.hskLevel * 3;
  var score = 100 - (hanziLength - idealLength).abs() * 3;

  if (hanziLength < 5) score -= 40;
  if (englishWords < 4 || englishWords > 24) score -= 25;
  if (RegExp(r'[A-Za-z]').hasMatch(chinese)) score -= 30;
  if (RegExp(r'[“”「」『』]').hasMatch(chinese)) score -= 8;
  if (chinese.endsWith('。') || chinese.endsWith('？')) score += 4;
  if (chinese.startsWith(target.word)) score += 2;
  return score;
}

class _Target {
  const _Target(this.word, this.hskLevel);

  final String word;
  final int hskLevel;
}

class _Candidate {
  const _Candidate({
    required this.chineseId,
    required this.chinese,
    required this.englishId,
    required this.english,
    required this.score,
  });

  final int chineseId;
  final String chinese;
  final int englishId;
  final String english;
  final int score;

  Map<String, Object> toJson() => {
    'chineseId': chineseId,
    'chinese': chinese,
    'englishId': englishId,
    'english': english,
    'score': score,
  };
}

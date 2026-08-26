import 'dart:convert';
import 'dart:io';

import 'hsk_vocabulary_overrides.dart';

typedef _GlossaryEntry = ({
  String traditional,
  List<String> pinyin,
  String meaning,
});

const _displayPinyinOverrides = <String, String>{
  '系领带': 'jì lǐng dài',
  '纽扣儿': 'niǔ kòu r',
  '致力于': 'zhì lì yú',
};

const _studyMeaningOverrides = <String, String>{
  '只': 'only',
  '字典': 'dictionary',
  '致力于': 'to dedicate oneself to',
};

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/import_hsk_vocabulary.dart '
      '<complete.json> <hsk-glossary-directory> <output.json>',
    );
    exitCode = 64;
    return;
  }

  final source = jsonDecode(File(args[0]).readAsStringSync()) as List<dynamic>;
  final glossary = _loadGlossary(Directory(args[1]));
  final output = <Map<String, dynamic>>[];

  for (final raw in source) {
    final entry = raw as Map<String, dynamic>;
    final levels = (entry['level'] as List<dynamic>).cast<String>();
    final oldLevels = levels
        .where((level) => RegExp(r'^old-[1-6]$').hasMatch(level))
        .map((level) => int.parse(level.substring(4)))
        .toList();
    if (oldLevels.isEmpty) continue;

    final simplified = entry['simplified'] as String;
    final forms = (entry['forms'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (forms.isEmpty) continue;
    final glossaryEntry = glossary[simplified];
    final form = _selectStudyForm(
      simplified: simplified,
      forms: forms,
      glossary: glossaryEntry,
    );
    final meanings = (form['meanings'] as List<dynamic>).cast<String>();
    if (meanings.isEmpty) continue;
    final transcriptions = form['transcriptions'] as Map<String, dynamic>;
    final sourcePinyin = transcriptions['pinyin'] as String;
    final pinyin = _displayPinyin(
      simplified: simplified,
      sourcePinyin: sourcePinyin,
      glossary: glossaryEntry,
    );
    final studyMeaning = _studyMeaning(
      simplified: simplified,
      selectedPinyin: pinyin,
      meanings: meanings,
      glossary: glossaryEntry,
    );
    final hskLevel = oldLevels.reduce((a, b) => a < b ? a : b);

    output.add({
      'id': 'hsk-old-$hskLevel-$simplified',
      'simplified': simplified,
      'traditional': form['traditional'],
      'pinyin': pinyin,
      'studyMeaning': studyMeaning,
      'meanings': meanings,
      'partOfSpeech': entry['pos'],
      'hskLevel': hskLevel,
      'frequency': entry['frequency'],
    });
  }

  output.sort((a, b) {
    final level = (a['hskLevel'] as int).compareTo(b['hskLevel'] as int);
    return level != 0
        ? level
        : (a['simplified'] as String).compareTo(b['simplified'] as String);
  });
  File(
    args[2],
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  stdout.writeln('Imported ${output.length} HSK 2.0 vocabulary entries.');
}

Map<String, _GlossaryEntry> _loadGlossary(Directory directory) {
  if (!directory.existsSync()) {
    throw ArgumentError('Glossary directory does not exist: ${directory.path}');
  }

  final files =
      directory
          .listSync()
          .whereType<File>()
          .where(
            (file) => RegExp(
              r'HSK Official With Definitions 2012 L[1-6]\.txt$',
              caseSensitive: false,
            ).hasMatch(file.path),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.length != 6) {
    throw StateError(
      'Expected six HSK glossary files in ${directory.path}; '
      'found ${files.length}.',
    );
  }

  final result = <String, _GlossaryEntry>{};
  for (final file in files) {
    for (var line in file.readAsLinesSync()) {
      line = line
          .replaceFirst('\ufeff', '')
          .replaceFirst(RegExp(r'[\t\s]+$'), '');
      if (line.isEmpty) continue;
      final fields = line.split('\t');
      if (fields.length != 5) {
        throw FormatException('Malformed glossary row in ${file.path}: $line');
      }
      result.putIfAbsent(
        fields[0],
        () => (
          traditional: fields[1],
          pinyin: fields[3]
              .split(RegExp(r',\s*'))
              .map((value) => value.trim())
              .toList(growable: false),
          meaning: fields[4].trim(),
        ),
      );
    }
  }
  return result;
}

Map<String, dynamic> _selectStudyForm({
  required String simplified,
  required List<Map<String, dynamic>> forms,
  required _GlossaryEntry? glossary,
}) {
  Iterable<Map<String, dynamic>> candidates = forms;
  final preferredPinyin = preferredHsk2Pinyin[simplified];
  if (preferredPinyin != null) {
    final matches = forms.where(
      (form) =>
          _normalizedPinyin(_formPinyin(form)) ==
          _normalizedPinyin(preferredPinyin),
    );
    if (matches.isEmpty) {
      throw StateError(
        'Preferred pinyin $preferredPinyin is missing for $simplified.',
      );
    }
    candidates = matches;
  } else if (glossary != null) {
    final matches = forms.where(
      (form) => glossary.pinyin.any(
        (pinyin) =>
            _normalizedPinyin(_formPinyin(form)) == _normalizedPinyin(pinyin),
      ),
    );
    if (matches.isNotEmpty) candidates = matches;
  }

  final preferredTraditional = preferredHsk2Traditional[simplified];
  if (preferredTraditional != null) {
    final matches = candidates.where(
      (form) => form['traditional'] == preferredTraditional,
    );
    if (matches.isEmpty) {
      throw StateError(
        'Preferred traditional form $preferredTraditional is missing for '
        '$simplified.',
      );
    }
    candidates = matches;
  }

  final ranked = candidates.toList()
    ..sort(
      (a, b) => _formPenalty(a, glossary).compareTo(_formPenalty(b, glossary)),
    );
  return ranked.first;
}

int _formPenalty(Map<String, dynamic> form, _GlossaryEntry? glossary) {
  var penalty = 0;
  final pinyin = _formPinyin(form);
  final meanings = (form['meanings'] as List<dynamic>).cast<String>();
  final text = meanings.join(' ').toLowerCase();
  if (glossary != null && form['traditional'] != glossary.traditional) {
    penalty += 20;
  }
  if (RegExp(r'^[A-Z]').hasMatch(pinyin)) penalty += 30;
  if (RegExp(r'\bsurname\b').hasMatch(text)) penalty += 100;
  if (RegExp(r'\b(?:old |erhua )?variant of\b').hasMatch(text)) penalty += 60;
  if (RegExp(r'^(?:used in|see(?: also)?|abbr\. for)\b').hasMatch(text)) {
    penalty += 50;
  }
  if (RegExp(r'\b(?:county|district|prefecture) of\b').hasMatch(text)) {
    penalty += 40;
  }
  return penalty;
}

String _formPinyin(Map<String, dynamic> form) =>
    (form['transcriptions'] as Map<String, dynamic>)['pinyin'] as String;

String _displayPinyin({
  required String simplified,
  required String sourcePinyin,
  required _GlossaryEntry? glossary,
}) {
  final override = _displayPinyinOverrides[simplified];
  if (override != null) return override;

  var result = sourcePinyin.replaceAll('u:', 'ü');
  if (glossary != null &&
      glossary.pinyin.any(
        (candidate) =>
            _normalizedPinyin(candidate.toLowerCase()) ==
            _normalizedPinyin(result.toLowerCase()),
      ) &&
      glossary.pinyin.every(
        (candidate) => !RegExp(r'^[A-Z]').hasMatch(candidate),
      )) {
    result = result.toLowerCase();
  }
  return result;
}

String _studyMeaning({
  required String simplified,
  required String selectedPinyin,
  required List<String> meanings,
  required _GlossaryEntry? glossary,
}) {
  final override = _studyMeaningOverrides[simplified];
  if (override != null) return override;

  if (glossary != null) {
    final branches = glossary.meaning.split(RegExp(r'\s+\|\s+'));
    var branch = branches.first;
    if (branches.length == glossary.pinyin.length) {
      final selectedIndex = glossary.pinyin.indexWhere(
        (candidate) =>
            _normalizedPinyin(candidate).toLowerCase() ==
            _normalizedPinyin(selectedPinyin).toLowerCase(),
      );
      if (selectedIndex >= 0) branch = branches[selectedIndex];
    }
    return _conciseGloss(branch);
  }

  final substantive = meanings.firstWhere(
    (meaning) => !_isDictionaryReference(meaning),
    orElse: () => meanings.first,
  );
  return _conciseGloss(substantive);
}

String _conciseGloss(String meaning) {
  var result = meaning.split(';').first.trim();
  result = result.replaceAll(
    RegExp(r'\s*\(Kangxi radical[^)]*\)', caseSensitive: false),
    '',
  );
  result = result.replaceFirstMapped(
    RegExp(r'^\(mw for ([^)]+)\)$', caseSensitive: false),
    (match) => 'classifier for ${match[1]}',
  );
  result = result.replaceFirstMapped(
    RegExp(r'^\(([^)]+)\)$'),
    (match) => match[1]!,
  );
  result = result.trim();
  if (result.isEmpty) throw StateError('Study meaning cannot be empty.');
  return result;
}

bool _isDictionaryReference(String meaning) => RegExp(
  r'^(?:surname\b|(?:old |erhua )?variant of\b|used in\b|see(?: also)?\b|abbr\. for\b)',
  caseSensitive: false,
).hasMatch(meaning.trim());

String _normalizedPinyin(String value) =>
    value.replaceAll('u:', 'ü').replaceAll(RegExp(r'\s+'), '');

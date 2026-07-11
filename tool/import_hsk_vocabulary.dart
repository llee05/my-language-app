import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/import_hsk_vocabulary.dart <complete.json> <output.json>',
    );
    exitCode = 64;
    return;
  }

  final source = jsonDecode(File(args[0]).readAsStringSync()) as List<dynamic>;
  final output = <Map<String, dynamic>>[];

  for (final raw in source) {
    final entry = raw as Map<String, dynamic>;
    final levels = (entry['level'] as List<dynamic>).cast<String>();
    final oldLevels = levels
        .where((level) => RegExp(r'^old-[1-6]$').hasMatch(level))
        .map((level) => int.parse(level.substring(4)))
        .toList();
    if (oldLevels.isEmpty) continue;

    final forms = entry['forms'] as List<dynamic>;
    if (forms.isEmpty) continue;
    final form = forms.first as Map<String, dynamic>;
    final meanings = (form['meanings'] as List<dynamic>).cast<String>();
    if (meanings.isEmpty) continue;
    final transcriptions = form['transcriptions'] as Map<String, dynamic>;

    output.add({
      'id':
          'hsk-old-${oldLevels.reduce((a, b) => a < b ? a : b)}-${entry['simplified']}',
      'simplified': entry['simplified'],
      'traditional': form['traditional'],
      'pinyin': transcriptions['pinyin'],
      'meanings': meanings,
      'partOfSpeech': entry['pos'],
      'hskLevel': oldLevels.reduce((a, b) => a < b ? a : b),
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
    args[1],
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  stdout.writeln('Imported ${output.length} HSK 2.0 vocabulary entries.');
}

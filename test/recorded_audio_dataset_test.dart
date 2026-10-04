import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'desktop pack has curriculum matches, attribution and intact pinned clips',
    () async {
      const root = 'assets/audio/mandarin';
      final catalog =
          jsonDecode(await File('$root/catalog.json').readAsString())
              as Map<String, dynamic>;
      final vocabulary =
          jsonDecode(
                await File('assets/data/hsk_vocabulary.json').readAsString(),
              )
              as List;
      final words = {
        for (final word in vocabulary) word['simplified'] as String: word,
      };
      final clips = catalog['clips'] as List;
      expect(catalog['revision'], 'ff9ed3d0c631195bd2c06f39450f3264c7124040');
      expect(catalog['license'], 'CC-BY-SA-3.0-US');
      expect(catalog['speaker'], 'Yue Tan');
      expect(clips.length, 4379);
      expect(clips.map((e) => e['text']).toSet().length, clips.length);
      expect(clips.map((e) => e['hskLevel']).toSet(), {1, 2, 3, 4, 5, 6});
      expect(
        await File('$root/LICENSE.txt').readAsString(),
        contains('Copyright (c) 2009 Yue Tan'),
      );
      for (final entry in clips) {
        expect(entry['pinyin'], words[entry['text']]?['pinyin']);
        expect(entry['file'], '${entry['sha256']}.mp3');
        final bytes = await File('$root/clips/${entry['file']}').readAsBytes();
        expect(bytes.length, entry['bytes'], reason: entry['text'] as String);
        expect(
          sha256.convert(bytes).toString(),
          entry['sha256'],
          reason: entry['text'] as String,
        );
      }
      expect(clips.any((e) => e['text'] == '行' || e['text'] == '长'), isFalse);
    },
  );

  test(
    'only Linux and Windows CMake package recordings outside Flutter assets',
    () async {
      for (final platform in ['linux', 'windows']) {
        final cmake = await File('$platform/CMakeLists.txt').readAsString();
        expect(cmake, contains('../assets/audio/mandarin/'));
        expect(cmake, contains('INSTALL_BUNDLE_DATA_DIR}/mandarin_audio'));
      }
      expect(
        await File('pubspec.yaml').readAsString(),
        isNot(contains('assets/audio/')),
      );
    },
  );
}

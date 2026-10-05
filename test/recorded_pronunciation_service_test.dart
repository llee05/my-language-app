import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/pronunciation_service_native.dart';
import 'package:mylanguageapp/services/pronunciation_service_system.dart';
import 'package:mylanguageapp/services/recorded_pronunciation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in ['linux', 'windows', 'android', 'apple']) {
    test('selects recordings only on Linux and Windows ($platform)', () async {
      final service = createDesktopAwarePronunciationService(
        isAndroid: platform == 'android',
        isLinux: platform == 'linux',
        isWindows: platform == 'windows',
      );
      if (platform == 'linux' || platform == 'windows') {
        expect(service, isA<RecordedAudioPronunciation>());
        expect(service, isA<DesktopVoiceInstaller>());
        expect(service, isNot(isA<OfflinePronunciationManager>()));
        await service.dispose();
      } else if (platform == 'android') {
        expect(service, isA<AndroidSystemPronunciationService>());
        expect(service, isNot(isA<RecordedAudioPronunciation>()));
        expect(service, isNot(isA<DesktopVoiceInstaller>()));
        await service.dispose();
      } else {
        expect(service, isA<OfflinePronunciationManager>());
        expect(service, isNot(isA<RecordedAudioPronunciation>()));
        expect(service, isNot(isA<DesktopVoiceInstaller>()));
        await service.dispose();
      }
    });
  }

  group('recorded playback', () {
    late _Library library;
    late _Player player;
    late _Speech speech;
    late RecordedPronunciationService service;
    setUp(() {
      library = _Library();
      player = _Player();
      speech = _Speech();
      service = RecordedPronunciationService(
        library,
        player,
        speech,
        systemSpeechDescription: 'System Mandarin speech',
      );
    });
    tearDown(() => service.dispose());

    test('checks and installs fallback speech without playing audio', () async {
      expect(await service.isMandarinVoiceInstalled(), isFalse);
      await service.installMandarinVoice();
      expect(await service.isMandarinVoiceInstalled(), isTrue);
      expect(speech.voiceInstallCalls, 1);
      expect(speech.spoken, isEmpty);
      expect(player.played, isEmpty);
    });

    test('uses the recording and requested listening speed', () async {
      library.bytes = Uint8List.fromList([1, 2, 3]);
      await service.speakMandarinAtRate('你好', rate: .7);
      expect(player.played.single, [1, 2, 3]);
      expect(player.rates, [.7]);
      expect(speech.spoken, isEmpty);
      expect(
        (await service.checkOfflineVoice()).state,
        OfflineVoiceState.ready,
      );
    });

    test(
      'missing recordings use system speech at the practice speed',
      () async {
        await service.speakMandarinAtRate('这是一句话。', rate: .8);
        expect(player.played, isEmpty);
        expect(speech.spoken, ['这是一句话。']);
        expect(speech.rates, [.8]);
      },
    );

    test(
      'damaged clips and playback failures fall back and can retry',
      () async {
        library.failure = true;
        await service.speakMandarin('你');
        library.failure = false;
        library.bytes = Uint8List(3);
        player.failure = true;
        await service.speakMandarin('你');
        player.failure = false;
        await service.speakMandarin('你');
        expect(speech.spoken, ['你', '你']);
        expect(player.played, hasLength(1));
      },
    );

    test('a stopped or superseded load never starts playback', () async {
      final pending = Completer<Uint8List?>();
      library.pending = pending.future;
      final first = service.speakMandarin('你');
      await Future<void>.delayed(Duration.zero);
      await service.stop();
      library.pending = null;
      await service.speakMandarin('下一句');
      pending.complete(Uint8List(3));
      await first;
      expect(player.played, isEmpty);
      expect(speech.spoken, ['下一句']);
    });

    test('preparation is silent and never blocks study on failure', () async {
      library.failure = true;
      await service.prepareMandarin('你');
      expect(speech.spoken, isEmpty);
      expect(player.played, isEmpty);
      expect(
        (await service.checkOfflineVoice()).state,
        OfflineVoiceState.failed,
      );
    });

    test(
      'disposal cancels pending playback and releases both engines',
      () async {
        final pending = Completer<Uint8List?>();
        library.pending = pending.future;
        final playing = service.speakMandarin('你');
        await Future<void>.delayed(Duration.zero);
        await service.dispose();
        pending.complete(Uint8List(2));
        await playing;
        await service.speakMandarin('你');
        expect(player.disposed, isTrue);
        expect(speech.disposed, isTrue);
        expect(player.played, isEmpty);
        expect(speech.spoken, isEmpty);
      },
    );
  });

  group('bundled library', () {
    late Directory directory;
    late BundledRecordedAudioLibrary library;
    final bytes = Uint8List.fromList([1, 2, 3]);
    final digest = sha256.convert(bytes).toString();
    late Map<String, Object> catalog;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('recorded-audio-test');
      await Directory('${directory.path}/clips').create();
      await File('${directory.path}/clips/$digest.mp3').writeAsBytes(bytes);
      catalog = {
        'version': 1,
        'clips': [
          {'text': '你', 'file': '$digest.mp3', 'sha256': digest, 'bytes': 3},
        ],
      };
      library = BundledRecordedAudioLibrary(directory: () => directory);
    });
    tearDown(() async {
      library.clear();
      await directory.delete(recursive: true);
    });
    Future<void> writeCatalog() => File(
      '${directory.path}/catalog.json',
    ).writeAsString(jsonEncode(catalog));

    test(
      'matches whole words, verifies hashes and caches prepared bytes',
      () async {
        await writeCatalog();
        expect(await library.count(), 1);
        expect(await library.load(' 你 '), bytes);
        expect(await library.load('你好'), isNull);
        await File('${directory.path}/clips/$digest.mp3').delete();
        expect(await library.load('你'), bytes);
      },
    );

    test(
      'missing catalog and damaged clips can be repaired and retried',
      () async {
        await expectLater(library.count(), throwsA(isA<FileSystemException>()));
        await writeCatalog();
        await File(
          '${directory.path}/clips/$digest.mp3',
        ).writeAsBytes([4, 5, 6]);
        await expectLater(library.load('你'), throwsFormatException);
        await File('${directory.path}/clips/$digest.mp3').writeAsBytes(bytes);
        expect(await library.load('你'), bytes);
      },
    );

    test(
      'rejects path traversal, duplicates, oversized clips and invalid versions',
      () async {
        for (final invalid in [
          {'text': '你', 'file': '../outside.mp3', 'sha256': digest, 'bytes': 3},
          {
            'text': '你',
            'file': '$digest.mp3',
            'sha256': digest,
            'bytes': 2000000,
          },
        ]) {
          catalog['clips'] = [invalid];
          await writeCatalog();
          await expectLater(library.count(), throwsFormatException);
        }
        final valid = {
          'text': '你',
          'file': '$digest.mp3',
          'sha256': digest,
          'bytes': 3,
        };
        catalog['clips'] = [valid, valid];
        await writeCatalog();
        await expectLater(library.count(), throwsFormatException);
        catalog['version'] = 2;
        catalog['clips'] = [valid];
        await writeCatalog();
        await expectLater(library.count(), throwsFormatException);
      },
    );
  });
}

class _Library implements RecordedAudioLibrary {
  Uint8List? bytes;
  Future<Uint8List?>? pending;
  bool failure = false;
  @override
  Future<int> count() async {
    if (failure) throw const FormatException();
    return 1;
  }

  @override
  Future<Uint8List?> load(String text) async {
    if (failure) throw const FormatException();
    return pending ?? bytes;
  }

  @override
  void clear() {}
}

class _Player implements RecordedAudioPlayer {
  final played = <Uint8List>[];
  final rates = <double>[];
  bool failure = false;
  bool disposed = false;
  @override
  Future<void> play(Uint8List bytes, {required double rate}) async {
    if (failure) throw StateError('device unavailable');
    played.add(bytes);
    rates.add(rate);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _Speech
    implements
        PronunciationService,
        PlaybackRatePronunciationService,
        DesktopVoiceInstaller {
  bool voiceInstalled = false;
  int voiceInstallCalls = 0;

  @override
  Future<bool> isMandarinVoiceInstalled() async => voiceInstalled;

  @override
  Future<void> installMandarinVoice() async {
    voiceInstallCalls++;
    voiceInstalled = true;
  }

  final spoken = <String>[];
  final rates = <double>[];
  bool disposed = false;
  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => const Stream.empty();
  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable();
  @override
  Future<void> installOfflineVoice() async {}
  @override
  Future<void> speakMandarin(String text) => speakMandarinAtRate(text, rate: 1);
  @override
  Future<void> speakMandarinAtRate(String text, {required double rate}) async {
    spoken.add(text);
    rates.add(rate);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

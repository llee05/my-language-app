import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/linux_system_pronunciation_service.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

void main() {
  test(
    'passes Mandarin voice and speed as arguments, and text via stdin',
    () async {
      final process = _Process();
      final service = LinuxSystemPronunciationService(
        launch: (command, arguments) async {
          expect(command, 'espeak-ng');
          expect(arguments, ['-v', 'cmn', '-s', '120', '--stdin']);
          return process;
        },
      );
      await service.speakMandarinAtRate(r'你好 $(example) -v en', rate: .8);
      expect(process.text, r'你好 $(example) -v en');
      await service.dispose();
    },
  );

  test(
    'tries legacy eSpeak only when the newer executable is absent',
    () async {
      final commands = <String>[];
      final service = LinuxSystemPronunciationService(
        launch: (command, arguments) async {
          commands.add(command);
          if (command == 'espeak-ng') {
            throw const ProcessException('espeak-ng', [], 'missing', 2);
          }
          expect(arguments[1], 'zh');
          return _Process();
        },
      );
      await service.speakMandarin('你好');
      expect(commands, ['espeak-ng', 'espeak']);
      await service.dispose();
    },
  );

  test('reports a missing Mandarin engine without hiding it', () async {
    final service = LinuxSystemPronunciationService(
      launch: (command, arguments) async {
        throw ProcessException(command, arguments, 'missing', 2);
      },
    );
    await expectLater(
      service.speakMandarin('你好'),
      throwsA(isA<MandarinVoiceUnavailableException>()),
    );
    await service.dispose();
  });

  test(
    'stop cancels a running engine and a launch that completes late',
    () async {
      final pending = Completer<LinuxSpeechProcess>();
      final lateProcess = _Process();
      final service = LinuxSystemPronunciationService(
        launch: (command, arguments) => pending.future,
      );
      final speaking = service.speakMandarin('你好');
      await service.stop();
      pending.complete(lateProcess);
      await speaking;
      expect(lateProcess.cancelled, isTrue);
      expect(lateProcess.text, isNull);
      await service.dispose();

      final running = _Process(completion: Completer<int>());
      final active = LinuxSystemPronunciationService(
        launch: (command, arguments) async => running,
      );
      final playback = active.speakMandarin('你好');
      await Future<void>.delayed(Duration.zero);
      await active.stop();
      running.completion!.complete(-15);
      await playback;
      expect(running.cancelled, isTrue);
      await active.dispose();
    },
  );
}

class _Process implements LinuxSpeechProcess {
  _Process({this.completion});
  final Completer<int>? completion;
  String? text;
  bool cancelled = false;
  @override
  Future<void> sendText(String text) async {
    this.text = text;
  }

  @override
  Future<int> get exitCode => completion?.future ?? Future.value(0);
  @override
  void cancel() {
    cancelled = true;
  }
}

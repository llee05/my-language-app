import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mylanguageapp/services/desktop_voice_installation.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/windows_system_pronunciation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Linux silently verifies the actual Mandarin voice', () async {
    final installer = LinuxMandarinVoiceInstaller(
      run: (executable, arguments) async {
        expect(executable, 'espeak-ng');
        expect(arguments, ['-q', '-v', 'cmn', '--stdin']);
        return ProcessResult(1, 0, '', '');
      },
    );
    expect(await installer.isMandarinVoiceInstalled(), isTrue);
  });

  test(
    'Linux checks legacy eSpeak if the newer executable is absent',
    () async {
      final commands = <String>[];
      final installer = LinuxMandarinVoiceInstaller(
        run: (executable, arguments) async {
          commands.add(executable);
          if (executable == 'espeak-ng') {
            throw ProcessException(executable, arguments, 'missing', 2);
          }
          expect(arguments, ['-q', '-v', 'zh', '--stdin']);
          return ProcessResult(1, 0, '', '');
        },
      );
      expect(await installer.isMandarinVoiceInstalled(), isTrue);
      expect(commands, ['espeak-ng', 'espeak']);
    },
  );

  test(
    'Linux rejects a broken newer voice and propagates check failures',
    () async {
      final installer = LinuxMandarinVoiceInstaller(
        run: (executable, arguments) async {
          expect(executable, 'espeak-ng');
          return ProcessResult(1, 1, '', 'voice missing');
        },
      );
      expect(await installer.isMandarinVoiceInstalled(), isFalse);
      final denied = LinuxMandarinVoiceInstaller(
        run: (executable, arguments) async {
          throw ProcessException(executable, arguments, 'denied', 13);
        },
      );
      await expectLater(
        denied.isMandarinVoiceInstalled(),
        throwsA(isA<ProcessException>()),
      );
    },
  );

  test(
    'Linux reports absent engines and leaves an installed voice alone',
    () async {
      final missing = LinuxMandarinVoiceInstaller(
        run: (executable, arguments) async {
          throw ProcessException(executable, arguments, 'missing', 2);
        },
      );
      expect(await missing.isMandarinVoiceInstalled(), isFalse);
      var calls = 0;
      final ready = LinuxMandarinVoiceInstaller(
        run: (executable, arguments) async {
          calls++;
          expect(executable, 'espeak-ng');
          return ProcessResult(1, 0, '', '');
        },
        fileExists: (_) async => throw StateError('must not start installer'),
      );
      await ready.installMandarinVoice();
      expect(calls, 1);
    },
  );

  const managers = {
    '/usr/bin/apt-get': ['install', '-y', 'espeak-ng'],
    '/usr/bin/dnf': ['install', '-y', 'espeak-ng'],
    '/usr/bin/pacman': ['-S', '--needed', '--noconfirm', 'espeak-ng'],
    '/usr/bin/zypper': ['--non-interactive', 'install', 'espeak-ng'],
    '/sbin/apk': ['add', 'espeak-ng'],
  };
  for (final manager in managers.entries) {
    test(
      'Linux installs using ${manager.key} with system authentication',
      () async {
        var ready = false;
        var installCalls = 0;
        final installer = LinuxMandarinVoiceInstaller(
          fileExists: (path) async =>
              path == '/usr/bin/pkexec' || path == manager.key,
          run: (executable, arguments) async {
            if (executable == 'espeak-ng') {
              return ProcessResult(1, ready ? 0 : 1, '', '');
            }
            expect(executable, '/usr/bin/pkexec');
            expect(arguments, [manager.key, ...manager.value]);
            installCalls++;
            ready = true;
            return ProcessResult(1, 0, '', '');
          },
        );
        await installer.installMandarinVoice();
        expect(installCalls, 1);
        expect(await installer.isMandarinVoiceInstalled(), isTrue);
      },
    );
  }

  for (final hasPolicyKit in [true, false]) {
    test(
      'Linux explains unavailable installation (PolicyKit: $hasPolicyKit)',
      () async {
        final installer = LinuxMandarinVoiceInstaller(
          run: (executable, arguments) async {
            expect(executable, 'espeak-ng');
            return ProcessResult(1, 1, '', '');
          },
          fileExists: (path) async => hasPolicyKit && path == '/usr/bin/pkexec',
        );
        await expectLater(
          installer.installMandarinVoice(),
          throwsA(isA<DesktopVoiceInstallationException>()),
        );
      },
    );
  }

  test(
    'Linux serializes duplicate installs, surfaces cancellation, and retries',
    () async {
      final completion = Completer<ProcessResult>();
      var installs = 0;
      final installer = LinuxMandarinVoiceInstaller(
        fileExists: (path) async =>
            path == '/usr/bin/pkexec' || path == '/usr/bin/pacman',
        run: (executable, arguments) async {
          if (executable == 'espeak-ng') return ProcessResult(1, 1, '', '');
          installs++;
          return installs == 1
              ? completion.future
              : ProcessResult(1, 0, '', '');
        },
      );
      final first = installer.installMandarinVoice();
      final second = installer.installMandarinVoice();
      expect(identical(first, second), isTrue);
      final assertion = expectLater(
        first,
        throwsA(isA<DesktopVoiceInstallationException>()),
      );
      completion.complete(ProcessResult(1, 126, '', 'cancelled'));
      await assertion;
      await installer.installMandarinVoice();
      expect(installs, 2);
    },
  );

  test(
    'Windows installs only Mandarin Basic and TextToSpeech through UAC',
    () async {
      final installation = WindowsMandarinVoiceInstallation(
        windowsDirectory: r'D:\Windows',
        run: (executable, arguments) async {
          expect(
            executable,
            r'D:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
          );
          expect(arguments.take(3), [
            '-NoProfile',
            '-NonInteractive',
            '-EncodedCommand',
          ]);
          final outer = _decodePowerShell(arguments.last);
          expect(outer, contains('-Verb RunAs -Wait -PassThru'));
          expect(outer, contains('exit \$installer.ExitCode'));
          final child = RegExp(
            r'-EncodedCommand ([A-Za-z0-9+/=]+)',
          ).firstMatch(outer)!.group(1)!;
          final script = _decodePowerShell(child);
          expect(
            RegExp(
              r'Language\.[A-Za-z]+~~~[^\x27]+',
            ).allMatches(script).map((m) => m.group(0)),
            [
              'Language.Basic~~~zh-CN~0.0.1.0',
              'Language.TextToSpeech~~~zh-CN~0.0.1.0',
            ],
          );
          expect(
            script,
            contains('Add-WindowsCapability -Online -Name \$name'),
          );
          expect(
            script,
            contains(
              "(Get-WindowsCapability -Online -Name \$name).State -ne 'Installed'",
            ),
          );
          return ProcessResult(1, 0, '', '');
        },
      );
      await installation.install();
    },
  );

  test(
    'Windows shares installation work, propagates failure and retries',
    () async {
      final completion = Completer<ProcessResult>();
      var calls = 0;
      final installation = WindowsMandarinVoiceInstallation(
        run: (executable, arguments) async {
          calls++;
          return calls == 1 ? completion.future : ProcessResult(1, 0, '', '');
        },
      );
      final first = installation.install();
      expect(identical(first, installation.install()), isTrue);
      final assertion = expectLater(
        first,
        throwsA(isA<DesktopVoiceInstallationException>()),
      );
      completion.complete(ProcessResult(1, 1, '', 'cancelled'));
      await assertion;
      await installation.install();
      expect(calls, 2);
    },
  );

  test(
    'Windows checks voices available to playback and skips unnecessary installation',
    () async {
      var installations = 0;
      final tts = _VoicesTts();
      final service = WindowsSystemPronunciationService(
        tts: tts,
        installation: WindowsMandarinVoiceInstallation(
          run: (executable, arguments) async {
            installations++;
            return ProcessResult(1, 0, '', '');
          },
        ),
      );
      addTearDown(service.dispose);
      expect(await service.isMandarinVoiceInstalled(), isFalse);
      tts.voices = [
        {'locale': 'zh-TW', 'name': 'another voice'},
      ];
      expect(await service.isMandarinVoiceInstalled(), isFalse);
      tts.voices = [
        {'locale': 'zh_CN', 'name': 'Mandarin'},
      ];
      expect(await service.isMandarinVoiceInstalled(), isTrue);
      await service.installMandarinVoice();
      expect(installations, 0);
      tts.voices = 'unknown';
      await expectLater(service.isMandarinVoiceInstalled(), throwsStateError);
      tts.voices = [
        {'name': 'malformed'},
      ];
      await expectLater(service.isMandarinVoiceInstalled(), throwsStateError);
    },
  );

  test(
    'Windows exposes newly installed voices to the pronunciation service',
    () async {
      final tts = _VoicesTts();
      var installations = 0;
      final service = WindowsSystemPronunciationService(
        tts: tts,
        installation: WindowsMandarinVoiceInstallation(
          run: (executable, arguments) async {
            installations++;
            tts.voices = [
              {'locale': 'zh-CN', 'name': 'Mandarin'},
            ];
            return ProcessResult(1, 0, '', '');
          },
        ),
      );
      addTearDown(service.dispose);
      expect(await service.isMandarinVoiceInstalled(), isFalse);
      await service.installMandarinVoice();
      expect(installations, 1);
      expect(await service.isMandarinVoiceInstalled(), isTrue);
    },
  );
}

String _decodePowerShell(String encoded) {
  final data = ByteData.sublistView(base64Decode(encoded));
  return String.fromCharCodes([
    for (var i = 0; i < data.lengthInBytes; i += 2)
      data.getUint16(i, Endian.little),
  ]);
}

class _VoicesTts extends FlutterTts {
  Object? voices = <Map<String, String>>[];
  @override
  Future<dynamic> get getVoices async => voices;
  @override
  Future<dynamic> stop() async => 1;
}

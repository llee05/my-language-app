import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'pronunciation_service.dart';

typedef VoiceSetupProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

Future<ProcessResult> _runProcess(String executable, List<String> arguments) =>
    Process.run(executable, arguments, runInShell: false);

class LinuxMandarinVoiceInstaller implements DesktopVoiceInstaller {
  LinuxMandarinVoiceInstaller({
    VoiceSetupProcessRunner? run,
    Future<bool> Function(String path)? fileExists,
  }) : _run = run ?? _runProcess,
       _fileExists = fileExists ?? _exists;

  final VoiceSetupProcessRunner _run;
  final Future<bool> Function(String path) _fileExists;
  Future<void>? _installing;

  static Future<bool> _exists(String path) => File(path).exists();

  @override
  Future<bool> isMandarinVoiceInstalled() async {
    for (final engine in ['espeak-ng', 'espeak']) {
      try {
        final result = await _run(engine, [
          '-q',
          '-v',
          engine == 'espeak-ng' ? 'cmn' : 'zh',
          '--stdin',
        ]).timeout(const Duration(seconds: 10));
        // Check the same engine playback would choose. A broken newer engine
        // must not be reported ready just because legacy eSpeak also exists.
        return result.exitCode == 0;
      } on ProcessException catch (error) {
        if (error.errorCode != 2) rethrow;
      }
    }
    return false;
  }

  @override
  Future<void> installMandarinVoice() =>
      _installing ??= _install().whenComplete(() => _installing = null);

  Future<void> _install() async {
    if (await isMandarinVoiceInstalled()) return;
    const managers = {
      '/usr/bin/apt-get': ['install', '-y', 'espeak-ng'],
      '/usr/bin/dnf': ['install', '-y', 'espeak-ng'],
      '/usr/bin/pacman': ['-S', '--needed', '--noconfirm', 'espeak-ng'],
      '/usr/bin/zypper': ['--non-interactive', 'install', 'espeak-ng'],
      '/sbin/apk': ['add', 'espeak-ng'],
    };
    if (!await _fileExists('/usr/bin/pkexec')) {
      throw const DesktopVoiceInstallationException(
        'The system installer needs PolicyKit (pkexec). Install espeak-ng with your package manager, then select Check again.',
      );
    }
    for (final manager in managers.entries) {
      if (!await _fileExists(manager.key)) continue;
      // Fixed absolute executable paths and arguments; no elevated shell or
      // user-controlled command text. PolicyKit supplies the password prompt.
      final result = await _run('/usr/bin/pkexec', [
        manager.key,
        ...manager.value,
      ]);
      if (result.exitCode != 0) {
        throw const DesktopVoiceInstallationException(
          'Installation was cancelled or failed. Check your internet connection and administrator approval, then try again.',
        );
      }
      return;
    }
    throw const DesktopVoiceInstallationException(
      'Automatic installation is unavailable for this Linux distribution. Install espeak-ng with your package manager, then select Check again.',
    );
  }
}

class WindowsMandarinVoiceInstallation {
  WindowsMandarinVoiceInstallation({
    VoiceSetupProcessRunner? run,
    String? windowsDirectory,
  }) : _run = run ?? _runProcess,
       _windowsDirectory =
           windowsDirectory ??
           Platform.environment['SystemRoot'] ??
           r'C:\Windows';

  final VoiceSetupProcessRunner _run;
  final String _windowsDirectory;
  Future<void>? _installing;

  Future<void> install() =>
      _installing ??= _install().whenComplete(() => _installing = null);

  Future<void> _install() async {
    // Windows TextToSpeech depends on the matching Basic language capability.
    // Keep the display language, locale, and default voice unchanged.
    const installScript = r'''
$ErrorActionPreference = 'Stop'
try {
  foreach ($name in @('Language.Basic~~~zh-CN~0.0.1.0', 'Language.TextToSpeech~~~zh-CN~0.0.1.0')) {
    $capability = Get-WindowsCapability -Online -Name $name
    if ($capability.State -ne 'Installed') {
      Add-WindowsCapability -Online -Name $name -ErrorAction Stop | Out-Null
    }
    if ((Get-WindowsCapability -Online -Name $name).State -ne 'Installed') { exit 1 }
  }
  exit 0
} catch { exit 1 }
''';
    final child = _encodePowerShell(installScript);
    final elevationScript =
        '''
\$ErrorActionPreference = 'Stop'
try {
  \$installer = Start-Process -FilePath (Join-Path \$PSHOME 'powershell.exe') -Verb RunAs -Wait -PassThru -ArgumentList '-NoProfile -NonInteractive -EncodedCommand $child'
  exit \$installer.ExitCode
} catch { exit 1 }
''';
    final result = await _run(
      p.windows.join(
        _windowsDirectory,
        'System32',
        'WindowsPowerShell',
        'v1.0',
        'powershell.exe',
      ),
      [
        '-NoProfile',
        '-NonInteractive',
        '-EncodedCommand',
        _encodePowerShell(elevationScript),
      ],
    );
    if (result.exitCode != 0) {
      throw const DesktopVoiceInstallationException(
        'Installation was cancelled or failed. Allow the Windows administrator prompt and check Windows Update, then try again.',
      );
    }
  }
}

String _encodePowerShell(String script) {
  final data = ByteData(script.codeUnits.length * 2);
  for (var index = 0; index < script.codeUnits.length; index++) {
    data.setUint16(index * 2, script.codeUnits[index], Endian.little);
  }
  return base64Encode(data.buffer.asUint8List());
}

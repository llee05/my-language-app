import 'dart:async';

import '../models/learning_progress.dart';

enum OfflineVoiceState { unavailable, notInstalled, downloading, ready, failed }

const kokoroOfflineVoiceDownloadBytes = 147031220;

class OfflineVoiceStatus {
  const OfflineVoiceStatus({
    required this.state,
    this.engine = PronunciationEngine.kokoro,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.currentFile,
    this.message,
  });

  const OfflineVoiceStatus.unavailable([
    String? message,
    PronunciationEngine engine = PronunciationEngine.kokoro,
  ]) : this(
         state: OfflineVoiceState.unavailable,
         engine: engine,
         message: message,
       );

  const OfflineVoiceStatus.notInstalled({
    PronunciationEngine engine = PronunciationEngine.kokoro,
    int totalBytes = 0,
  }) : this(
         state: OfflineVoiceState.notInstalled,
         engine: engine,
         totalBytes: totalBytes,
       );

  const OfflineVoiceStatus.ready({
    PronunciationEngine engine = PronunciationEngine.kokoro,
  }) : this(state: OfflineVoiceState.ready, engine: engine);

  final OfflineVoiceState state;
  final PronunciationEngine engine;
  final int downloadedBytes;
  final int totalBytes;
  final String? currentFile;
  final String? message;

  double? get progress {
    if (state != OfflineVoiceState.downloading || totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0, 1);
  }
}

class PronunciationVoice {
  const PronunciationVoice({
    required this.engine,
    required this.id,
    required this.speakerId,
    required this.label,
  });

  final PronunciationEngine engine;
  final String id;
  final int speakerId;
  final String label;
}

const _kokoroFemaleVoiceIds = <String>[
  'zf_001',
  'zf_002',
  'zf_003',
  'zf_004',
  'zf_005',
  'zf_006',
  'zf_007',
  'zf_008',
  'zf_017',
  'zf_018',
  'zf_019',
  'zf_021',
  'zf_022',
  'zf_023',
  'zf_024',
  'zf_026',
  'zf_027',
  'zf_028',
  'zf_032',
  'zf_036',
  'zf_038',
  'zf_039',
  'zf_040',
  'zf_042',
  'zf_043',
  'zf_044',
  'zf_046',
  'zf_047',
  'zf_048',
  'zf_049',
  'zf_051',
  'zf_059',
  'zf_060',
  'zf_067',
  'zf_070',
  'zf_071',
  'zf_072',
  'zf_073',
  'zf_074',
  'zf_075',
  'zf_076',
  'zf_077',
  'zf_078',
  'zf_079',
  'zf_083',
  'zf_084',
  'zf_085',
  'zf_086',
  'zf_087',
  'zf_088',
  'zf_090',
  'zf_092',
  'zf_093',
  'zf_094',
  'zf_099',
];

const _kokoroMaleVoiceIds = <String>[
  'zm_009',
  'zm_010',
  'zm_011',
  'zm_012',
  'zm_013',
  'zm_014',
  'zm_015',
  'zm_016',
  'zm_020',
  'zm_025',
  'zm_029',
  'zm_030',
  'zm_031',
  'zm_033',
  'zm_034',
  'zm_035',
  'zm_037',
  'zm_041',
  'zm_045',
  'zm_050',
  'zm_052',
  'zm_053',
  'zm_054',
  'zm_055',
  'zm_056',
  'zm_057',
  'zm_058',
  'zm_061',
  'zm_062',
  'zm_063',
  'zm_064',
  'zm_065',
  'zm_066',
  'zm_068',
  'zm_069',
  'zm_080',
  'zm_081',
  'zm_082',
  'zm_089',
  'zm_091',
  'zm_095',
  'zm_096',
  'zm_097',
  'zm_098',
  'zm_100',
];

final List<PronunciationVoice> kokoroMandarinVoices = List.unmodifiable([
  for (var index = 0; index < _kokoroFemaleVoiceIds.length; index++)
    PronunciationVoice(
      engine: PronunciationEngine.kokoro,
      id: _kokoroFemaleVoiceIds[index],
      speakerId: index + 3,
      label: 'Female ${_kokoroFemaleVoiceIds[index].substring(3)}',
    ),
  for (var index = 0; index < _kokoroMaleVoiceIds.length; index++)
    PronunciationVoice(
      engine: PronunciationEngine.kokoro,
      id: _kokoroMaleVoiceIds[index],
      speakerId: index + 58,
      label: 'Male ${_kokoroMaleVoiceIds[index].substring(3)}',
    ),
]);

PronunciationVoice resolvePronunciationVoice(
  PronunciationEngine engine,
  String? voiceId,
) {
  return resolvePronunciationVoices(
    engine,
    voiceId == null ? const [] : [voiceId],
  ).first;
}

List<PronunciationVoice> resolvePronunciationVoices(
  PronunciationEngine engine,
  Iterable<String> voiceIds,
) {
  final requestedIds = {
    for (final voiceId in voiceIds)
      if (voiceId.trim().isNotEmpty) voiceId.trim(),
  };
  if (requestedIds.isEmpty) return kokoroMandarinVoices;
  final resolved = [
    for (final voice in kokoroMandarinVoices)
      if (requestedIds.contains(voice.id)) voice,
  ];
  return resolved.isEmpty ? kokoroMandarinVoices : List.unmodifiable(resolved);
}

PronunciationVoice pickPronunciationVoice(
  List<PronunciationVoice> voices, {
  required int Function(int upperBound) randomIndex,
  String? previousVoiceId,
}) {
  if (voices.isEmpty) throw StateError('A pronunciation voice is required.');
  if (voices.length == 1) return voices.single;

  final previousIndex = voices.indexWhere(
    (voice) => voice.id == previousVoiceId,
  );
  if (previousIndex < 0) return voices[randomIndex(voices.length)];

  final nextIndex = randomIndex(voices.length - 1);
  return voices[nextIndex >= previousIndex ? nextIndex + 1 : nextIndex];
}

class OfflineVoiceNotInstalledException implements Exception {
  const OfflineVoiceNotInstalledException();

  @override
  String toString() => 'The offline Mandarin voice is not installed.';
}

abstract interface class PronunciationService {
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates;

  Future<OfflineVoiceStatus> checkOfflineVoice();

  Future<void> installOfflineVoice();

  Future<void> speakMandarin(String text);

  Future<void> stop();

  Future<void> dispose();
}

abstract interface class OfflinePronunciationManager {
  Stream<OfflineVoiceStatus> get voicePackUpdates;

  Future<OfflineVoiceStatus> checkVoicePack(PronunciationEngine engine);

  Future<void> installVoicePack(PronunciationEngine engine);

  List<PronunciationVoice> voicesFor(PronunciationEngine engine);

  Future<void> configurePronunciation({
    required PronunciationEngine engine,
    List<String> voiceIds = const [],
  });
}

Future<void> applyPronunciationSettings(
  PronunciationService service,
  LearnerSettings settings,
) async {
  if (service is! OfflinePronunciationManager) return;
  await (service as OfflinePronunciationManager).configurePronunciation(
    engine: settings.pronunciationEngine,
    voiceIds: settings.kokoroVoiceIds,
  );
}

typedef PronunciationServiceFactory = PronunciationService Function();

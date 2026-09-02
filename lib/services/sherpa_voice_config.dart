import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

sherpa_onnx.OfflineTtsConfig createSherpaVoiceConfig({
  required String modelDirectory,
  required int numThreads,
}) {
  String path(String name) => p.join(modelDirectory, name);

  return sherpa_onnx.OfflineTtsConfig(
    model: sherpa_onnx.OfflineTtsModelConfig(
      kokoro: sherpa_onnx.OfflineTtsKokoroModelConfig(
        model: path('model.int8.onnx'),
        voices: path('voices.bin'),
        tokens: path('tokens.txt'),
        dataDir: path('espeak-ng-data'),
        lexicon: '${path('lexicon-us-en.txt')},${path('lexicon-zh.txt')}',
      ),
      numThreads: numThreads,
      debug: false,
      provider: 'cpu',
    ),
    ruleFsts:
        '${path('phone-zh.fst')},${path('date-zh.fst')},${path('number-zh.fst')}',
    maxNumSenetences: 1,
  );
}

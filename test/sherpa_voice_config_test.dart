import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/sherpa_voice_config.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'builds Kokoro with voices, eSpeak data, lexicons, and Mandarin rules',
    () {
      final directory = p.join('models', 'kokoro');
      final config = createSherpaVoiceConfig(
        modelDirectory: directory,
        numThreads: 1,
      );

      expect(config.model.kokoro.model, p.join(directory, 'model.int8.onnx'));
      expect(config.model.kokoro.voices, p.join(directory, 'voices.bin'));
      expect(config.model.kokoro.tokens, p.join(directory, 'tokens.txt'));
      expect(config.model.kokoro.dataDir, p.join(directory, 'espeak-ng-data'));
      expect(
        config.model.kokoro.lexicon,
        '${p.join(directory, 'lexicon-us-en.txt')},'
        '${p.join(directory, 'lexicon-zh.txt')}',
      );
      expect(config.model.vits.model, isEmpty);
      expect(config.model.numThreads, 1);
      expect(
        config.ruleFsts,
        '${p.join(directory, 'phone-zh.fst')},'
        '${p.join(directory, 'date-zh.fst')},'
        '${p.join(directory, 'number-zh.fst')}',
      );
    },
  );
}

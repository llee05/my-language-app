import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/services/sherpa_voice_config.dart';
import 'package:path/path.dart' as p;

void main() {
  test('builds the existing Melo VITS configuration', () {
    final config = createSherpaVoiceConfig(
      engine: PronunciationEngine.melo,
      modelDirectory: p.join('models', 'melo'),
      numThreads: 2,
    );

    expect(
      config.model.vits.model,
      p.join('models', 'melo', 'model.int8.onnx'),
    );
    expect(config.model.vits.lexicon, p.join('models', 'melo', 'lexicon.txt'));
    expect(config.model.kokoro.model, isEmpty);
    expect(config.model.numThreads, 2);
    expect(
      config.ruleFsts,
      '${p.join('models', 'melo', 'date.fst')},'
      '${p.join('models', 'melo', 'number.fst')}',
    );
  });

  test(
    'builds Kokoro with voices, eSpeak data, lexicons, and Mandarin rules',
    () {
      final directory = p.join('models', 'kokoro');
      final config = createSherpaVoiceConfig(
        engine: PronunciationEngine.kokoro,
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
      expect(
        config.ruleFsts,
        '${p.join(directory, 'phone-zh.fst')},'
        '${p.join(directory, 'date-zh.fst')},'
        '${p.join(directory, 'number-zh.fst')}',
      );
    },
  );
}

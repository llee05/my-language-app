import 'package:mylanguageapp/models/ai_configuration.dart';
import 'package:mylanguageapp/repositories/ai_configuration_repository.dart';

const testAiConfiguration = AiConfiguration(
  provider: AiProvider.gemini,
  apiKey: 'personal-test-key',
  model: 'gemini-2.5-flash',
);

class MemoryAiConfigurationRepository implements AiConfigurationRepository {
  MemoryAiConfigurationRepository([this.configuration]);

  AiConfiguration? configuration;
  Object? loadError;
  Object? saveError;
  Object? clearError;
  Future<void>? saveGate;
  int clearCalls = 0;
  final saves = <AiConfiguration>[];

  @override
  Future<AiConfiguration?> load() async {
    if (loadError != null) throw loadError!;
    return configuration;
  }

  @override
  Future<void> save(AiConfiguration value) async {
    saves.add(value);
    await saveGate;
    if (saveError != null) throw saveError!;
    configuration = value;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    if (clearError != null) throw clearError!;
    configuration = null;
  }
}

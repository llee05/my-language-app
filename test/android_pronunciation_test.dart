import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/fallback_pronunciation_service.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';
import 'package:mylanguageapp/services/pronunciation_service_native.dart';
import 'package:mylanguageapp/services/pronunciation_service_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android pronunciation', () {
    test('always uses the system Mandarin voice without Kokoro', () async {
      final service = createAndroidAwarePronunciationService(isAndroid: true);

      expect(service, isA<SystemPronunciationService>());
      expect(service, isNot(isA<OfflinePronunciationManager>()));
      await service.dispose();
    });

    test('keeps the Kokoro chain with system fallback elsewhere', () {
      final service = createAndroidAwarePronunciationService(isAndroid: false);

      expect(service, isA<FallbackPronunciationService>());
      expect(service, isA<OfflinePronunciationManager>());
    });
  });
}

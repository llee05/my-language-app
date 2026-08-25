import 'pronunciation_service.dart';
import 'pronunciation_service_system.dart';
import 'pronunciation_service_system.dart'
    if (dart.library.io) 'pronunciation_service_native.dart'
    as platform;

export 'pronunciation_service.dart';

PronunciationService createDefaultPronunciationService() =>
    platform.createPlatformPronunciationService();

PronunciationService createSystemPronunciationService() =>
    SystemPronunciationService();

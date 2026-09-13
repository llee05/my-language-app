import 'speech_input_service.dart';
import 'speech_input_service_system.dart';

export 'speech_input_service.dart';

typedef SpeechInputServiceFactory = SpeechInputService Function();

SpeechInputService createSystemSpeechInputService() =>
    SystemSpeechInputService();

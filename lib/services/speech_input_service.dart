typedef SpeechInputResult = void Function(String transcript);
typedef SpeechInputError = void Function(String message);

abstract interface class SpeechInputService {
  Future<void> startListening({
    required SpeechInputResult onResult,
    SpeechInputError? onError,
    String? preferredLocaleId,
  });

  Future<void> stopListening();

  Future<void> cancelListening();

  Future<void> dispose();
}

class SpeechInputException implements Exception {
  const SpeechInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiConfigurationException implements Exception {
  const AiConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiRequestException implements Exception {
  const AiRequestException(this.message, {this.isRetryable = true});

  final String message;
  final bool isRetryable;

  @override
  String toString() => message;
}

import 'dart:convert';

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

// Provider reason codes are enum-like identifiers, e.g. API_KEY_INVALID.
final RegExp _providerCodePattern = RegExp(r'^[A-Za-z0-9._-]{1,80}$');

/// Extracts the provider's machine-readable failure reason, such as
/// `API_KEY_INVALID` or `PERMISSION_DENIED`, from a decoded error body.
///
/// Only identifier-like fields are trusted (`status`, `type`, `code`, and
/// `details[].reason`). Free-text fields, including `message`, could echo
/// user input, so they are never returned. Returns null when the body
/// carries no trustworthy reason.
String? providerErrorReason(Object? error) {
  if (error is! Map) return null;
  final reasons = <String>[];
  void collect(Object? value) {
    if (value is String &&
        _providerCodePattern.hasMatch(value) &&
        !reasons.contains(value)) {
      reasons.add(value);
    }
  }

  collect(error['status']);
  collect(error['type']);
  collect(error['code']);
  final details = error['details'];
  if (details is List) {
    for (final detail in details) {
      if (detail is Map) collect(detail['reason']);
    }
  }
  return reasons.isEmpty ? null : reasons.join(', ');
}

/// Builds a display-safe diagnostic suffix naming the HTTP status and the
/// provider's machine-readable reason for a failed response. Raw bodies are
/// never included because they can echo sensitive input.
String providerStatusDetail(int statusCode, List<int> bodyBytes) {
  Object? error;
  try {
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is Map) error = decoded['error'];
  } on FormatException {
    // Non-JSON bodies carry no trustworthy machine-readable reason.
  }
  final reason = providerErrorReason(error);
  return reason == null
      ? ' (HTTP $statusCode)'
      : ' (HTTP $statusCode: $reason)';
}

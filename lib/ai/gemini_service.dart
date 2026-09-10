import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_errors.dart';

class GeminiConfigurationException extends AiConfigurationException {
  const GeminiConfigurationException(super.message);
}

class GeminiRequestException extends AiRequestException {
  const GeminiRequestException(super.message, {super.isRetryable});
}

/// Gemini REST adapter used by the optional AI service.
///
/// Users can supply personal keys through Settings. Developer Dart defines are
/// embedded in the app; never distribute a shared key. Injected clients remain
/// owned by their caller; otherwise each request creates and closes its client.
class GeminiService {
  GeminiService({
    String apiKey = const String.fromEnvironment('GEMINI_API_KEY'),
    String model = const String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: defaultModel,
    ),
    http.Client? client,
    Duration timeout = const Duration(seconds: 60),
  }) : _apiKey = apiKey.trim(),
       _model = model.trim(),
       _clientOverride = client,
       _requestTimeout = timeout;

  static const defaultModel = 'gemini-2.5-flash';
  static final GeminiService instance = GeminiService();

  final String _apiKey;
  final String _model;
  final http.Client? _clientOverride;
  final Duration _requestTimeout;

  Future<String> chatText({
    required List<Map<String, String>> messages,
    int maxTokens = 2048,
    double temperature = 0.7,
    bool jsonResponse = false,
  }) async {
    if (_apiKey.isEmpty) {
      throw const GeminiConfigurationException(
        'Gemini is not configured for this build. '
        'Lessons and review are still available offline.',
      );
    }
    if (!RegExp(r'^gemini-[a-zA-Z0-9._-]+$').hasMatch(_model)) {
      throw const GeminiConfigurationException(
        'The Gemini model configuration is invalid.',
      );
    }

    final systemParts = <Map<String, String>>[];
    final contents = <Map<String, Object>>[];
    for (final message in messages) {
      final content = message['content'];
      if (content == null || content.trim().isEmpty) {
        throw ArgumentError('Chat messages must contain text.');
      }
      final part = {'text': content};
      final role = message['role'];
      if (role == 'system') {
        systemParts.add(part);
        continue;
      }
      if (role != 'user' && role != 'assistant') {
        throw ArgumentError('Unsupported chat role.');
      }
      final geminiRole = role == 'assistant' ? 'model' : 'user';
      // A new prompt after a failed send can leave consecutive user messages.
      if (contents.isNotEmpty && contents.last['role'] == geminiRole) {
        (contents.last['parts']! as List<Map<String, String>>).add(part);
      } else {
        contents.add({
          'role': geminiRole,
          'parts': <Map<String, String>>[part],
        });
      }
    }
    if (contents.isEmpty ||
        contents.first['role'] != 'user' ||
        contents.last['role'] != 'user') {
      throw ArgumentError('Chat must start and end with a user message.');
    }

    final url = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
    );
    final client = _clientOverride ?? http.Client();
    try {
      final request = http.Request('POST', url)
        ..followRedirects = false
        ..headers.addAll({
          'Content-Type': 'application/json; charset=utf-8',
          'x-goog-api-key': _apiKey,
        })
        ..body = jsonEncode({
          if (systemParts.isNotEmpty)
            'systemInstruction': {'parts': systemParts},
          'contents': contents,
          'generationConfig': {
            'maxOutputTokens': maxTokens,
            'temperature': temperature,
            if (jsonResponse) 'responseMimeType': 'application/json',
            // Keep short study replies from spending their output budget
            // on thinking. Other models use their own default settings.
            if (_model == 'gemini-2.5-flash' ||
                _model == 'gemini-2.5-flash-lite')
              'thinkingConfig': {'thinkingBudget': 0},
          },
        });
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Never surface raw API error bodies: they can echo sensitive input.
        // Identifier-like provider reasons are safe and make the failure
        // actionable, e.g. (HTTP 403: PERMISSION_DENIED, API_KEY_INVALID).
        final detail = providerStatusDetail(
          response.statusCode,
          response.bodyBytes,
        );
        throw switch (response.statusCode) {
          400 || 401 || 403 || 404 => GeminiConfigurationException(
            'Gemini could not accept this configuration. '
            'Check the API key, model, and API access.$detail',
          ),
          429 => GeminiRequestException(
            'Gemini’s usage limit was reached. Please try again later.$detail',
          ),
          _ => GeminiRequestException(
            'Gemini is unavailable right now. Please try again later.$detail',
          ),
        };
      }
      return _responseText(response.bodyBytes);
    } on TimeoutException {
      throw const GeminiRequestException(
        'Gemini took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const GeminiRequestException(
        'We couldn’t connect to Gemini. Check your internet connection and try again.',
      );
    } finally {
      if (_clientOverride == null) client.close();
    }
  }

  String _responseText(List<int> bytes) {
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      final feedback = data['promptFeedback'];
      if (feedback is Map && feedback['blockReason'] != null) {
        throw const GeminiRequestException(
          'Gemini couldn’t answer that prompt. Try rephrasing it.',
          isRetryable: false,
        );
      }
      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw const FormatException();
      }
      final candidate = candidates.first;
      if (candidate is! Map) throw const FormatException();
      final finishReason = candidate['finishReason'];
      if (finishReason == 'MAX_TOKENS') {
        throw const GeminiRequestException(
          'Gemini’s reply was cut short. Try a shorter prompt.',
          isRetryable: false,
        );
      }
      if (finishReason != null && finishReason != 'STOP') {
        throw const GeminiRequestException(
          'Gemini couldn’t answer that prompt. Try rephrasing it.',
          isRetryable: false,
        );
      }
      final content = candidate['content'];
      if (content is! Map) throw const FormatException();
      final parts = content['parts'];
      if (parts is! List) throw const FormatException();
      final text = StringBuffer();
      for (final part in parts) {
        if (part is! Map) throw const FormatException();
        if (part['thought'] == true) continue;
        final value = part['text'];
        if (value is String) text.write(value);
      }
      final result = text.toString().trim();
      if (result.isEmpty) throw const FormatException();
      return result;
    } on FormatException {
      throw const GeminiRequestException(
        'Gemini returned an unreadable reply. Please try again.',
      );
    }
  }
}

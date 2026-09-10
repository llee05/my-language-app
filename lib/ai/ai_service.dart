import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_configuration.dart';
import '../repositories/ai_configuration_repository.dart';
import 'ai_errors.dart';
import 'gemini_service.dart';

/// One active personal provider, read afresh for every request.
class AiService {
  const AiService({
    this.configurationRepository = const SecureAiConfigurationRepository(),
    AiConfiguration? configuration,
    http.Client? client,
    Duration timeout = const Duration(seconds: 60),
  }) : _configurationOverride = configuration,
       _clientOverride = client,
       _requestTimeout = timeout;

  final AiConfigurationRepository configurationRepository;
  final AiConfiguration? _configurationOverride;
  final http.Client? _clientOverride;
  final Duration _requestTimeout;

  Future<String> chatText({
    required List<Map<String, String>> messages,
    int maxTokens = 2048,
    double temperature = 0.7,
    bool jsonResponse = false,
  }) async {
    AiConfiguration? configuration = _configurationOverride;
    if (configuration == null) {
      try {
        configuration = await configurationRepository.load();
      } catch (_) {
        throw const AiConfigurationException(
          'Your saved AI settings could not be read. Open Settings to try again.',
        );
      }
    }
    if (configuration == null) {
      // Retain the documented developer-only Gemini launch configuration.
      const key = String.fromEnvironment('GEMINI_API_KEY');
      if (key.trim().isNotEmpty) {
        configuration = const AiConfiguration(
          provider: AiProvider.gemini,
          apiKey: key,
          model: String.fromEnvironment(
            'GEMINI_MODEL',
            defaultValue: GeminiService.defaultModel,
          ),
        );
      } else {
        throw const AiConfigurationException(
          'Choose an AI provider and add your API key in Settings. '
          'Lessons and review are still available offline.',
        );
      }
    }
    final error = configuration.validationError;
    if (error != null) throw AiConfigurationException(error);
    if (configuration.provider == AiProvider.gemini) {
      return GeminiService(
        apiKey: configuration.apiKey,
        model: configuration.model,
        client: _clientOverride,
        timeout: _requestTimeout,
      ).chatText(
        messages: messages,
        maxTokens: maxTokens,
        temperature: temperature,
        jsonResponse: jsonResponse,
      );
    }

    final system = <String>[];
    final conversation = <Map<String, String>>[];
    for (final message in messages) {
      final role = message['role'];
      final content = message['content'];
      if (content == null ||
          content.trim().isEmpty ||
          !['system', 'user', 'assistant'].contains(role)) {
        throw ArgumentError('Invalid chat message.');
      }
      if (role == 'system') {
        system.add(content);
      } else if (conversation.isNotEmpty && conversation.last['role'] == role) {
        conversation.last['content'] =
            '${conversation.last['content']}\n\n$content';
      } else {
        conversation.add({'role': role!, 'content': content});
      }
    }
    if (conversation.isEmpty ||
        conversation.first['role'] != 'user' ||
        conversation.last['role'] != 'user') {
      throw ArgumentError('Chat must start and end with a user message.');
    }
    final isAnthropic = configuration.provider == AiProvider.anthropic;
    final isOpenAi = configuration.provider == AiProvider.openai;
    final client = _clientOverride ?? http.Client();
    try {
      final request = http.Request('POST', Uri.parse(configuration.endpoint))
        // Never forward a personal key to a redirected destination.
        ..followRedirects = false
        ..headers.addAll({
          'Content-Type': 'application/json; charset=utf-8',
          if (isAnthropic) ...{
            'x-api-key': configuration.apiKey.trim(),
            'anthropic-version': '2023-06-01',
          } else
            'Authorization': 'Bearer ${configuration.apiKey.trim()}',
        })
        ..body = jsonEncode({
          'model': configuration.model.trim(),
          if (isAnthropic && system.isNotEmpty) 'system': system.join('\n\n'),
          'messages': [
            if (!isAnthropic && system.isNotEmpty)
              {'role': 'system', 'content': system.join('\n\n')},
            ...conversation,
          ],
          // Avoid model-specific sampling/JSON switches on compatible APIs;
          // the tutor and lesson prompts already specify their JSON format.
          if (isOpenAi)
            'max_completion_tokens': maxTokens
          else
            'max_tokens': maxTokens,
          'stream': false,
        });
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw switch (response.statusCode) {
          400 || 401 || 403 || 404 || 422 => const AiConfigurationException(
            'The provider could not accept these settings. Check your API key, model, and endpoint.',
          ),
          429 => const AiRequestException(
            'The provider’s usage limit was reached. Try again later.',
          ),
          _ => const AiRequestException(
            'The AI provider is unavailable right now. Try again later.',
          ),
        };
      }
      return _responseText(response.bodyBytes, isAnthropic: isAnthropic);
    } on TimeoutException {
      throw const AiRequestException(
        'The AI provider took too long to respond. Try again.',
      );
    } on http.ClientException {
      throw const AiRequestException(
        'Couldn’t connect to the AI provider. Check your internet connection.',
      );
    } finally {
      if (_clientOverride == null) client.close();
    }
  }

  String _responseText(List<int> bytes, {required bool isAnthropic}) {
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map) throw const FormatException();
      String text;
      if (isAnthropic) {
        if (data['stop_reason'] != 'end_turn' &&
            data['stop_reason'] != 'stop_sequence') {
          throw const AiRequestException(
            'The provider did not return a complete reply. Try a shorter or different prompt.',
            isRetryable: false,
          );
        }
        final content = data['content'];
        if (content is! List) throw const FormatException();
        text = content
            .whereType<Map>()
            .where((part) => part['type'] == 'text')
            .map((part) => part['text'])
            .whereType<String>()
            .join();
      } else {
        final choices = data['choices'];
        if (choices is! List || choices.isEmpty || choices.first is! Map) {
          throw const FormatException();
        }
        final choice = choices.first as Map;
        if (choice['finish_reason'] != 'stop') {
          throw const AiRequestException(
            'The provider did not return a complete reply. Try a shorter or different prompt.',
            isRetryable: false,
          );
        }
        final message = choice['message'];
        if (message is! Map || message['content'] is! String) {
          throw const FormatException();
        }
        text = message['content'] as String;
      }
      if (text.trim().isEmpty) throw const FormatException();
      return text.trim();
    } on FormatException {
      throw const AiRequestException(
        'The AI provider returned an unreadable reply. Please try again.',
      );
    }
  }
}

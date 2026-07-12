import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Client for an Ollama server running on the local machine.
class OllamaService {
  OllamaService._();

  static final OllamaService instance = OllamaService._();

  static const _configuredUrl = String.fromEnvironment(
    'OLLAMA_URL',
    defaultValue: 'http://127.0.0.1:11434',
  );
  static const _configuredModel = String.fromEnvironment('OLLAMA_MODEL');

  String? _detectedModel;

  Uri _uri(String path) => Uri.parse('$_configuredUrl$path');

  /// Starts the local Ollama server when running as a desktop app.
  ///
  /// This is intentionally a no-op for mobile platforms and remote Ollama URLs.
  Future<void> ensureRunning() async {
    if (await _isRunning()) return;

    final host = Uri.parse(_configuredUrl).host;
    final isLocalHost = host == '127.0.0.1' || host == 'localhost';
    final isDesktop =
        Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    if (!isLocalHost || !isDesktop) return;

    await Process.start('ollama', const [
      'serve',
    ], mode: ProcessStartMode.detached);

    // Give the server a few seconds to bind its port before the tutor is used.
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await _isRunning()) return;
    }
  }

  Future<bool> _isRunning() async {
    try {
      final response = await http
          .get(_uri('/api/tags'))
          .timeout(const Duration(milliseconds: 500));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<String> _model() async {
    if (_configuredModel.isNotEmpty) return _configuredModel;
    if (_detectedModel != null) return _detectedModel!;

    final url = _uri('/api/tags');
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode >= 400) {
      throw http.ClientException(
        'Ollama returned ${response.statusCode}: ${response.body}',
        url,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['models'] as List<dynamic>? ?? const [];
    if (models.isEmpty) {
      throw StateError('Ollama is running, but no models are installed.');
    }

    _detectedModel = (models.first as Map<String, dynamic>)['name'] as String?;
    if (_detectedModel == null || _detectedModel!.isEmpty) {
      throw const FormatException('Ollama returned an invalid model list.');
    }
    return _detectedModel!;
  }

  Future<String> chatText({
    required List<Map<String, String>> messages,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    final url = _uri('/api/chat');
    final response = await http
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': await _model(),
            'messages': messages,
            'stream': false,
            // Avoid paying the model-loading cost again for subsequent lessons.
            'keep_alive': '30m',
            'options': {'num_predict': maxTokens, 'temperature': temperature},
          }),
        )
        .timeout(const Duration(minutes: 2));

    if (response.statusCode >= 400) {
      throw http.ClientException(
        'Ollama returned ${response.statusCode}: ${response.body}',
        url,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('Ollama response did not include text.');
    }
    return content.trim();
  }
}

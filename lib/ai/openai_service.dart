import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A minimal OpenAI API client for Chat Completions (GPT-style).
///
/// Usage:
/// 1. Put OPENAI_API_KEY=your_key in a `.env` file at project root (do NOT commit).
/// 2. Call `await OpenAIService.ensureInitialized()` once (e.g. in `main()`).
/// 3. Use `OpenAIService.instance.chatCompletion(...)` to call the API.
class OpenAIService {
  OpenAIService._();

  static final OpenAIService instance = OpenAIService._();
  String? _apiKey;
  final _base = 'https://api.openai.com/v1';

  /// Ensure API key is loaded from environment if present.
  Future<void> ensureInitialized() async {
    if (dotenv.isInitialized) {
      _apiKey ??= dotenv.env['OPENAI_API_KEY'];
    }
  }

  /// Set the API key programmatically (useful for tests or secure storage flows)
  void setApiKey(String key) => _apiKey = key;

  /// Send a chat completion request and return the raw decoded JSON response.
  ///
  /// Example:
  /// final resp = await OpenAIService.instance.chatCompletion(
  ///   messages: [ {'role':'user','content':'Hello'} ],
  /// );
  Future<Map<String, dynamic>> chatCompletion({
    required List<Map<String, String>> messages,
    String model = 'gpt-4o-mini',
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    if (_apiKey == null) throw StateError('OpenAI API key is not set');

    final url = Uri.parse('$_base/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
    });

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    );

    if (resp.statusCode >= 400) {
      throw http.ClientException('OpenAI API error', url);
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}

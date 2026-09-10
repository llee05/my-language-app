// Diagnostic: replicates the exact Gemini request made by
// lib/ai/gemini_service.dart and prints Google's real error response,
// which the app intentionally hides so error bodies never echo the key.
//
// Usage (run from the repository root):
//   GEMINI_DEBUG_KEY=YOUR_KEY dart run tool/gemini_debug.dart [model]
//
// The key is read from the environment, never stored or logged.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final key = Platform.environment['GEMINI_DEBUG_KEY']?.trim() ?? '';
  final model = (args.isNotEmpty ? args[0] : 'gemini-3.6-flash').trim();
  if (key.isEmpty) {
    stderr.writeln('Set GEMINI_DEBUG_KEY to the key saved in the app.');
    exitCode = 2;
    return;
  }

  final url = Uri.https(
    'generativelanguage.googleapis.com',
    '/v1beta/models/$model:generateContent',
  );
  final request = http.Request('POST', url)
    ..followRedirects = false
    ..headers.addAll({
      'Content-Type': 'application/json; charset=utf-8',
      'x-goog-api-key': key,
    })
    ..body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Reply with OK.'},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 256,
        'temperature': 0,
        if (model == 'gemini-2.5-flash' || model == 'gemini-2.5-flash-lite')
          'thinkingConfig': {'thinkingBudget': 0},
      },
    });

  final client = http.Client();
  try {
    final response = await http.Response.fromStream(await client.send(request));
    stdout.writeln('HTTP ${response.statusCode}');
    // Redact the key from anything Google echoes back.
    final body = utf8.decode(response.bodyBytes).replaceAll(key, '[REDACTED]');
    stdout.writeln(body);
  } finally {
    client.close();
  }
}

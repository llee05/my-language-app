import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mylanguageapp/ai/ollama_service.dart';

void main() {
  test('desktop uses local Ollama when no endpoint is configured', () {
    expect(
      resolveOllamaEndpoint(
        configuredUrl: '',
        isMobile: false,
        requireHttps: false,
      ),
      Uri.parse('http://127.0.0.1:11434'),
    );
  });

  test('mobile requires an explicit endpoint', () {
    expect(
      () => resolveOllamaEndpoint(
        configuredUrl: '',
        isMobile: true,
        requireHttps: false,
      ),
      throwsA(isA<OllamaConfigurationException>()),
    );
  });

  test('Android release endpoints must use HTTPS', () {
    expect(
      () => resolveOllamaEndpoint(
        configuredUrl: 'http://10.0.2.2:11434',
        isMobile: true,
        requireHttps: true,
      ),
      throwsA(isA<OllamaConfigurationException>()),
    );
    expect(
      resolveOllamaEndpoint(
        configuredUrl: 'https://ollama.example.test',
        isMobile: true,
        requireHttps: true,
      ),
      Uri.parse('https://ollama.example.test'),
    );
  });

  test('embedded endpoint credentials are rejected', () {
    expect(
      () => resolveOllamaEndpoint(
        configuredUrl: 'https://user:secret@ollama.example.test',
        isMobile: true,
        requireHttps: true,
      ),
      throwsA(isA<OllamaConfigurationException>()),
    );
  });

  test('empty hosts, query strings, and fragments are rejected', () {
    for (final configuredUrl in [
      'http://:11434',
      'https://ollama.example.test?token=value',
      'https://ollama.example.test#settings',
    ]) {
      expect(
        () => resolveOllamaEndpoint(
          configuredUrl: configuredUrl,
          isMobile: true,
          requireHttps: false,
        ),
        throwsA(isA<OllamaConfigurationException>()),
        reason: configuredUrl,
      );
    }
  });

  test('API paths are appended after an endpoint base path', () {
    expect(
      buildOllamaApiUri(
        Uri.parse('https://ollama.example.test/proxy/'),
        '/api/tags',
      ),
      Uri.parse('https://ollama.example.test/proxy/api/tags'),
    );
  });

  group('OllamaService chatText', () {
    test('detects the installed model, caches it, and parses the reply',
        () async {
      var tagRequests = 0;
      final chatBodies = <Map<String, dynamic>>[];
      final service = OllamaService.test(
        endpoint: Uri.parse('http://127.0.0.1:11434'),
        client: MockClient((request) async {
          if (request.url.path == '/api/tags') {
            tagRequests++;
            return http.Response(
              jsonEncode({
                'models': [
                  {'name': 'qwen3:4b'},
                  {'name': 'llama3'},
                ],
              }),
              200,
            );
          }
          expect(request.url, Uri.parse('http://127.0.0.1:11434/api/chat'));
          chatBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'message': {'content': '  你好，很高兴认识你。  '},
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final first = await service.chatText(
        messages: [
          {'role': 'user', 'content': '你好'},
        ],
        maxTokens: 420,
        temperature: 0.45,
      );
      final second = await service.chatText(
        messages: [
          {'role': 'user', 'content': '再见'},
        ],
      );

      expect(first, '你好，很高兴认识你。');
      expect(second, '你好，很高兴认识你。');
      expect(tagRequests, 1, reason: 'the detected model should be cached');
      expect(chatBodies, hasLength(2));
      expect(chatBodies.first['model'], 'qwen3:4b');
      expect(chatBodies.first['stream'], isFalse);
      expect(chatBodies.first['keep_alive'], '30m');
      expect(chatBodies.first['options'], {
        'num_predict': 420,
        'temperature': 0.45,
      });
      expect(chatBodies.first['messages'], [
        {'role': 'user', 'content': '你好'},
      ]);
      expect(chatBodies.last['options']['num_predict'], 512);
    });

    test('uses the configured model without querying /api/tags', () async {
      var tagsRequested = false;
      final service = OllamaService.test(
        endpoint: Uri.parse('http://127.0.0.1:11434'),
        model: 'llama3',
        client: MockClient((request) async {
          if (request.url.path == '/api/tags') {
            tagsRequested = true;
          }
          return http.Response(
            jsonEncode({
              'message': {'content': 'ok'},
            }),
            200,
          );
        }),
      );

      final reply = await service.chatText(
        messages: const [
          {'role': 'user', 'content': 'hi'},
        ],
      );

      expect(reply, 'ok');
      expect(tagsRequested, isFalse);
    });

    test('surfaces HTTP failures as client exceptions', () async {
      final service = OllamaService.test(
        endpoint: Uri.parse('http://127.0.0.1:11434'),
        model: 'llama3',
        client: MockClient(
          (_) async => http.Response('model unavailable', 503),
        ),
      );

      await expectLater(
        service.chatText(messages: const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsA(
          isA<http.ClientException>().having(
            (error) => error.message,
            'message',
            contains('Ollama returned 503: model unavailable'),
          ),
        ),
      );
    });

    test('rejects a response without text content', () async {
      final service = OllamaService.test(
        endpoint: Uri.parse('http://127.0.0.1:11434'),
        model: 'llama3',
        client: MockClient(
          (_) async => http.Response(jsonEncode({'message': {}}), 200),
        ),
      );

      await expectLater(
        service.chatText(messages: const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsFormatException,
      );
    });

    test('fails when no models are installed', () async {
      final service = OllamaService.test(
        endpoint: Uri.parse('http://127.0.0.1:11434'),
        client: MockClient(
          (_) async => http.Response(jsonEncode({'models': []}), 200),
        ),
      );

      await expectLater(
        service.chatText(messages: const [
          {'role': 'user', 'content': 'hi'},
        ]),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Ollama is running, but no models are installed.',
          ),
        ),
      );
    });
  });
}

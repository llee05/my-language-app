import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mylanguageapp/ai/ai_errors.dart';
import 'package:mylanguageapp/ai/ai_service.dart';
import 'package:mylanguageapp/models/ai_configuration.dart';

import 'ai_test_support.dart';

const _messages = [
  {'role': 'system', 'content': 'Teach Mandarin. Return JSON.'},
  {'role': 'user', 'content': '你好'},
  {'role': 'assistant', 'content': '你好！'},
  {'role': 'user', 'content': 'Explain 的'},
];

http.Response _reply(Object? value, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), status);

Map<String, Object> _completion(String text) => {
  'choices': [
    {
      'finish_reason': 'stop',
      'message': {'content': text},
    },
  ],
};

AiConfiguration _configuration(AiProvider provider) => AiConfiguration(
  provider: provider,
  apiKey: 'key-for-${provider.name}',
  model: provider.defaultModel.isEmpty
      ? 'model/example'
      : provider.defaultModel,
  customEndpoint: provider == AiProvider.custom
      ? 'https://custom.example/proxy/v1/chat/completions'
      : '',
);

void main() {
  for (final provider in AiProvider.values.where(
    (p) => p != AiProvider.gemini && p != AiProvider.anthropic,
  )) {
    test(
      '${provider.label} sends chat history only to its selected endpoint',
      () async {
        final configuration = _configuration(provider);
        final client = MockClient((request) async {
          expect(request.url.toString(), configuration.endpoint);
          expect(request.followRedirects, isFalse);
          expect(
            request.headers['authorization'],
            'Bearer ${configuration.apiKey}',
          );
          expect(request.headers.containsKey('x-api-key'), isFalse);
          final body = jsonDecode(utf8.decode(request.bodyBytes));
          expect(body['messages'], _messages);
          expect(body['model'], configuration.model);
          expect(
            body[provider == AiProvider.openai
                ? 'max_completion_tokens'
                : 'max_tokens'],
            4096,
          );
          expect(body['stream'], isFalse);
          return _reply(_completion('  我的书 · wǒ de shū  '));
        });
        addTearDown(client.close);
        expect(
          await AiService(
            configuration: configuration,
            client: client,
          ).chatText(messages: _messages, maxTokens: 4096),
          '我的书 · wǒ de shū',
        );
      },
    );
  }

  test(
    'Anthropic uses its own authentication, system prompt, and response format',
    () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
        expect(request.headers['x-api-key'], 'key-for-anthropic');
        expect(request.headers['anthropic-version'], '2023-06-01');
        expect(request.headers.containsKey('authorization'), isFalse);
        final body = jsonDecode(utf8.decode(request.bodyBytes));
        expect(body['system'], _messages.first['content']);
        expect(body['messages'], _messages.skip(1).toList());
        expect(body['max_tokens'], 2048);
        return _reply({
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'thinking', 'thinking': 'private thoughts'},
            {'type': 'text', 'text': '你好'},
            {'type': 'text', 'text': '！'},
          ],
        });
      });
      addTearDown(client.close);
      expect(
        await AiService(
          configuration: _configuration(AiProvider.anthropic),
          client: client,
        ).chatText(messages: _messages),
        '你好！',
      );
    },
  );

  test(
    'the next request uses a replaced key/provider and removal stops requests',
    () async {
      final repository = MemoryAiConfigurationRepository(testAiConfiguration);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'generativelanguage.googleapis.com') {
          expect(request.followRedirects, isFalse);
          expect(request.headers['x-goog-api-key'], 'personal-test-key');
          return _reply({
            'candidates': [
              {
                'finishReason': 'STOP',
                'content': {
                  'parts': [
                    {'text': '好'},
                  ],
                },
              },
            ],
          });
        }
        expect(request.headers['authorization'], 'Bearer key-for-openai');
        return _reply(_completion('好'));
      });
      addTearDown(client.close);
      final service = AiService(
        configurationRepository: repository,
        client: client,
      );
      await service.chatText(messages: _messages);
      await repository.save(_configuration(AiProvider.openai));
      await service.chatText(messages: _messages);
      await repository.clear();
      await expectLater(
        service.chatText(messages: _messages),
        throwsA(isA<AiConfigurationException>()),
      );
      expect(requests, hasLength(2));
      expect(requests.last.url.host, 'api.openai.com');
    },
  );

  test('credentials and invalid endpoints never reach the network', () async {
    final client = MockClient((_) async => fail('Unexpected request'));
    addTearDown(client.close);
    for (final endpoint in [
      'http://example.test/v1',
      'https://user:secret@example.test',
      'https://example.test?key=secret',
      'https://example.test#fragment',
      'not a URL',
    ]) {
      await expectLater(
        AiService(
          configuration: AiConfiguration(
            provider: AiProvider.custom,
            apiKey: 'test-key',
            model: 'model',
            customEndpoint: endpoint,
          ),
          client: client,
        ).chatText(messages: _messages),
        throwsA(isA<AiConfigurationException>()),
      );
    }
    for (final key in ['', 'key\nvalue', 'key value']) {
      await expectLater(
        AiService(
          configuration: AiConfiguration(
            provider: AiProvider.openai,
            apiKey: key,
            model: 'model',
          ),
          client: client,
        ).chatText(messages: _messages),
        throwsA(isA<AiConfigurationException>()),
      );
    }
  });

  test(
    'storage failures fail closed without leaking the storage error',
    () async {
      final repository = MemoryAiConfigurationRepository()
        ..loadError = StateError('private key');
      final client = MockClient((_) async => fail('Unexpected request'));
      addTearDown(client.close);
      await expectLater(
        AiService(
          configurationRepository: repository,
          client: client,
        ).chatText(messages: _messages),
        throwsA(
          isA<AiConfigurationException>().having(
            (e) => e.message,
            'message',
            isNot(contains('private key')),
          ),
        ),
      );
    },
  );

  test('HTTP errors include the provider machine-readable reason', () async {
    final client = MockClient(
      (_) async => _reply({
        'error': {
          'type': 'invalid_request_error',
          'code': 'invalid_api_key',
          'message': 'Incorrect API key provided: key-for-custom.',
        },
      }, 401),
    );
    addTearDown(client.close);
    await expectLater(
      AiService(
        configuration: _configuration(AiProvider.custom),
        client: client,
      ).chatText(messages: _messages),
      throwsA(
        isA<AiConfigurationException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('HTTP 401'),
            contains('invalid_request_error'),
            contains('invalid_api_key'),
            isNot(contains('key-for-custom.')),
          ),
        ),
      ),
    );
  });

  for (final status in [302, 400, 401, 403, 404, 422, 429, 500]) {
    test('HTTP $status is sanitized and never follows redirects', () async {
      var count = 0;
      final client = MockClient((request) async {
        count++;
        expect(request.followRedirects, isFalse);
        return http.Response(
          'private key and prompt',
          status,
          headers: {'location': 'https://untrusted.example'},
        );
      });
      addTearDown(client.close);
      await expectLater(
        AiService(
          configuration: _configuration(AiProvider.custom),
          client: client,
        ).chatText(messages: _messages),
        throwsA(
          predicate(
            (e) =>
                (e is AiConfigurationException || e is AiRequestException) &&
                !e.toString().contains('private key'),
          ),
        ),
      );
      expect(count, 1);
    });
  }

  test(
    'truncated, refused, and malformed responses do not become answers',
    () async {
      for (final response in [
        http.Response('invalid JSON with private key', 200),
        _reply(null),
        _reply({'choices': []}),
        _reply(_completion(' ')),
        _reply({
          'choices': [
            {
              'finish_reason': 'length',
              'message': {'content': 'partial'},
            },
          ],
        }),
        _reply({
          'choices': [
            {'finish_reason': 'content_filter'},
          ],
        }),
      ]) {
        final client = MockClient((_) async => response);
        addTearDown(client.close);
        await expectLater(
          AiService(
            configuration: _configuration(AiProvider.openai),
            client: client,
          ).chatText(messages: _messages),
          throwsA(isA<AiRequestException>()),
        );
      }
    },
  );

  test('network failures and hung requests remain retryable', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('private key'),
    );
    addTearDown(client.close);
    await expectLater(
      AiService(
        configuration: _configuration(AiProvider.openai),
        client: client,
      ).chatText(messages: _messages),
      throwsA(
        isA<AiRequestException>().having(
          (e) => e.isRetryable,
          'retryable',
          isTrue,
        ),
      ),
    );
    final pending = Completer<http.Response>();
    final slowClient = MockClient((_) => pending.future);
    addTearDown(slowClient.close);
    await expectLater(
      AiService(
        configuration: _configuration(AiProvider.openai),
        client: slowClient,
        timeout: const Duration(milliseconds: 1),
      ).chatText(messages: _messages),
      throwsA(
        isA<AiRequestException>().having(
          (e) => e.message,
          'message',
          contains('too long'),
        ),
      ),
    );
    pending.complete(_reply(_completion('late')));
  });
}

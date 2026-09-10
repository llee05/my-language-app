import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mylanguageapp/ai/gemini_service.dart';

const _messages = [
  {'role': 'user', 'content': '你好'},
];

http.Response _reply(Object? data, {int status = 200}) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status);

Map<String, Object> _candidate(List<Object> parts, {String reason = 'STOP'}) =>
    {
      'candidates': [
        {
          'finishReason': reason,
          'content': {'role': 'model', 'parts': parts},
        },
      ],
    };

void main() {
  test('missing key fails before any network request', () async {
    final client = MockClient((_) async => fail('Unexpected network request'));
    addTearDown(client.close);
    final service = GeminiService(apiKey: '  ', client: client);

    await expectLater(
      service.chatText(messages: _messages),
      throwsA(isA<GeminiConfigurationException>()),
    );
  });

  test(
    'invalid model configuration fails without exposing its value',
    () async {
      final client = MockClient(
        (_) async => fail('Unexpected network request'),
      );
      addTearDown(client.close);
      for (final model in [
        '',
        'models/gemini-2.5-flash',
        'gemini-x?key=secret',
      ]) {
        await expectLater(
          GeminiService(
            apiKey: 'test-key',
            model: model,
            client: client,
          ).chatText(messages: _messages),
          throwsA(
            isA<GeminiConfigurationException>().having(
              (error) => error.toString(),
              'message',
              'The Gemini model configuration is invalid.',
            ),
          ),
        );
      }
    },
  );

  test(
    'sends authenticated Gemini history and reads Mandarin text parts',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-3.6-flash:generateContent',
        );
        expect(request.url.hasQuery, isFalse);
        expect(request.headers['x-goog-api-key'], 'test-key');
        final body = jsonDecode(utf8.decode(request.bodyBytes));
        expect(body['systemInstruction'], {
          'parts': [
            {'text': 'Be a Mandarin tutor.'},
          ],
        });
        expect(body['contents'], [
          {
            'role': 'user',
            'parts': [
              {'text': '你好'},
            ],
          },
          {
            'role': 'model',
            'parts': [
              {'text': '你好！'},
            ],
          },
          {
            'role': 'user',
            'parts': [
              {'text': 'Help me practise.'},
            ],
          },
        ]);
        expect(body['generationConfig'], {
          'maxOutputTokens': 2048,
          'temperature': 0.45,
          'responseMimeType': 'application/json',
        });
        return _reply(
          _candidate([
            {'text': 'private thought', 'thought': true},
            {'text': '  你好，'},
            {'text': '很高兴认识你。  '},
          ]),
        );
      });
      addTearDown(client.close);
      final service = GeminiService(apiKey: ' test-key ', client: client);

      expect(
        await service.chatText(
          messages: [
            {'role': 'system', 'content': 'Be a Mandarin tutor.'},
            ..._messages,
            {'role': 'assistant', 'content': '你好！'},
            {'role': 'user', 'content': 'Help me practise.'},
          ],
          temperature: 0.45,
          jsonResponse: true,
        ),
        '你好，很高兴认识你。',
      );
    },
  );

  test('retired-default 2.5 models keep their zero thinking budget', () async {
    final client = MockClient((request) async {
      expect(
        request.url.path,
        '/v1beta/models/gemini-2.5-flash:generateContent',
      );
      final body = jsonDecode(utf8.decode(request.bodyBytes));
      expect(body['generationConfig'], {
        'maxOutputTokens': 2048,
        'temperature': 0.7,
        'thinkingConfig': {'thinkingBudget': 0},
      });
      return _reply(
        _candidate([
          {'text': '好'},
        ]),
      );
    });
    addTearDown(client.close);
    final service = GeminiService(
      apiKey: 'test-key',
      model: 'gemini-2.5-flash',
      client: client,
    );
    expect(await service.chatText(messages: _messages), '好');
  });

  test(
    'model override and consecutive user prompts work without discovery',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/v1beta/models/gemini-test-model:generateContent',
        );
        final body = jsonDecode(request.body);
        expect(body.containsKey('systemInstruction'), isFalse);
        expect(body['contents'], [
          {
            'role': 'user',
            'parts': [
              {'text': '你好'},
              {'text': 'Try this instead.'},
            ],
          },
        ]);
        expect(body['generationConfig'], {
          'maxOutputTokens': 4096,
          'temperature': 0.7,
        });
        return _reply(
          _candidate([
            {'text': '好'},
          ]),
        );
      });
      addTearDown(client.close);
      final service = GeminiService(
        apiKey: 'test-key',
        model: ' gemini-test-model ',
        client: client,
      );
      for (var i = 0; i < 2; i++) {
        expect(
          await service.chatText(
            messages: [
              ..._messages,
              {'role': 'user', 'content': 'Try this instead.'},
            ],
            maxTokens: 4096,
          ),
          '好',
        );
      }
      expect(requests, 2);
    },
  );

  test('invalid messages fail before making a request', () async {
    final client = MockClient((_) async => fail('Unexpected network request'));
    addTearDown(client.close);
    final service = GeminiService(apiKey: 'test-key', client: client);
    for (final messages in <List<Map<String, String>>>[
      [],
      [
        {'role': 'system', 'content': 'Only instructions'},
      ],
      [
        {'role': 'assistant', 'content': 'Only a greeting'},
      ],
      [
        {'role': 'tool', 'content': 'Not supported'},
      ],
      [
        {'role': 'user'},
      ],
      [
        {'role': 'user', 'content': ' '},
      ],
    ]) {
      await expectLater(
        service.chatText(messages: messages),
        throwsArgumentError,
      );
    }
  });

  for (final status in [400, 401, 403, 404, 429, 500, 503]) {
    test(
      'HTTP $status is actionable and does not expose the API body',
      () async {
        final client = MockClient(
          (_) async => _reply({
            'error': {'message': 'secret-key and private prompt'},
          }, status: status),
        );
        addTearDown(client.close);
        final service = GeminiService(apiKey: 'test-key', client: client);

        await expectLater(
          service.chatText(messages: _messages),
          throwsA(
            (status < 429
                    ? isA<GeminiConfigurationException>()
                    : isA<GeminiRequestException>())
                .having(
                  (error) => error.toString(),
                  'message',
                  isNot(
                    anyOf(contains('secret-key'), contains('private prompt')),
                  ),
                ),
          ),
        );
      },
    );
  }

  test(
    'configuration errors include the provider machine-readable reason',
    () async {
      final client = MockClient(
        (_) async => _reply({
          'error': {
            'code': 403,
            'message': 'API key not valid. Please pass a valid API key.',
            'status': 'PERMISSION_DENIED',
            'details': [
              {
                '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
                'reason': 'API_KEY_INVALID',
              },
            ],
          },
        }, status: 403),
      );
      addTearDown(client.close);
      final service = GeminiService(apiKey: 'test-key', client: client);

      await expectLater(
        service.chatText(messages: _messages),
        throwsA(
          isA<GeminiConfigurationException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('HTTP 403'),
              contains('PERMISSION_DENIED'),
              contains('API_KEY_INVALID'),
              isNot(contains('Please pass a valid API key')),
            ),
          ),
        ),
      );
    },
  );

  test('non-JSON error bodies still name the HTTP status', () async {
    final client = MockClient((_) async => http.Response('gateway error', 502));
    addTearDown(client.close);
    await expectLater(
      GeminiService(
        apiKey: 'test-key',
        client: client,
      ).chatText(messages: _messages),
      throwsA(
        isA<GeminiRequestException>().having(
          (error) => error.message,
          'message',
          contains('HTTP 502'),
        ),
      ),
    );
  });

  test('network exceptions are sanitized and retryable', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('private detail'),
    );
    addTearDown(client.close);
    await expectLater(
      GeminiService(
        apiKey: 'test-key',
        client: client,
      ).chatText(messages: _messages),
      throwsA(
        isA<GeminiRequestException>()
            .having((error) => error.isRetryable, 'retryable', isTrue)
            .having(
              (error) => error.message,
              'message',
              contains('internet connection'),
            ),
      ),
    );
  });

  test('hung requests time out', () async {
    final pending = Completer<http.Response>();
    final client = MockClient((_) => pending.future);
    addTearDown(client.close);
    await expectLater(
      GeminiService(
        apiKey: 'test-key',
        client: client,
        timeout: const Duration(milliseconds: 1),
      ).chatText(messages: _messages),
      throwsA(
        isA<GeminiRequestException>().having(
          (error) => error.message,
          'message',
          contains('too long'),
        ),
      ),
    );
    pending.complete(
      _reply(
        _candidate([
          {'text': 'Late reply'},
        ]),
      ),
    );
  });

  test(
    'blocked and truncated replies are not shown as successful answers',
    () async {
      for (final data in [
        {
          'promptFeedback': {'blockReason': 'SAFETY'},
        },
        _candidate([
          {'text': 'partial text'},
        ], reason: 'SAFETY'),
        _candidate([
          {'text': '{"chinese":'},
        ], reason: 'MAX_TOKENS'),
      ]) {
        final client = MockClient((_) async => _reply(data));
        addTearDown(client.close);
        await expectLater(
          GeminiService(
            apiKey: 'test-key',
            client: client,
          ).chatText(messages: _messages),
          throwsA(
            isA<GeminiRequestException>().having(
              (error) => error.isRetryable,
              'retryable',
              isFalse,
            ),
          ),
        );
      }
    },
  );

  test('malformed and empty responses produce safe errors', () async {
    for (final response in [
      http.Response('not JSON: private prompt', 200),
      http.Response.bytes([0xff], 200),
      _reply(null),
      _reply([]),
      _reply({}),
      _reply({'candidates': []}),
      _reply({
        'candidates': ['bad candidate'],
      }),
      _reply({
        'candidates': [
          {'content': 'bad content'},
        ],
      }),
      _reply(_candidate(['bad part'])),
      _reply(
        _candidate([
          {'text': 42},
        ]),
      ),
      _reply(
        _candidate([
          {'text': '  '},
        ]),
      ),
      _reply(
        _candidate([
          {'text': 'Only thoughts', 'thought': true},
        ]),
      ),
    ]) {
      final client = MockClient((_) async => response);
      addTearDown(client.close);
      await expectLater(
        GeminiService(
          apiKey: 'test-key',
          client: client,
        ).chatText(messages: _messages),
        throwsA(
          isA<GeminiRequestException>().having(
            (error) => error.message,
            'message',
            'Gemini returned an unreadable reply. Please try again.',
          ),
        ),
      );
    }
  });
}

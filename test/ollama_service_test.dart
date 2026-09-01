import 'package:flutter_test/flutter_test.dart';
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
}

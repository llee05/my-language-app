enum AiProvider {
  gemini(
    'Google Gemini',
    'https://generativelanguage.googleapis.com/v1beta',
    'gemini-2.5-flash',
  ),
  openai(
    'OpenAI',
    'https://api.openai.com/v1/chat/completions',
    'gpt-4.1-mini',
  ),
  anthropic('Anthropic / Claude', 'https://api.anthropic.com/v1/messages', ''),
  openrouter('OpenRouter', 'https://openrouter.ai/api/v1/chat/completions', ''),
  deepseek('DeepSeek', 'https://api.deepseek.com/chat/completions', ''),
  groq('Groq', 'https://api.groq.com/openai/v1/chat/completions', ''),
  mistral('Mistral', 'https://api.mistral.ai/v1/chat/completions', ''),
  xai('xAI / Grok', 'https://api.x.ai/v1/chat/completions', ''),
  custom('Other / OpenAI-compatible', '', '');

  const AiProvider(this.label, this.endpoint, this.defaultModel);

  final String label;
  final String endpoint;
  final String defaultModel;
}

class AiConfiguration {
  const AiConfiguration({
    required this.provider,
    required this.apiKey,
    required this.model,
    this.customEndpoint = '',
  });

  final AiProvider provider;
  final String apiKey;
  final String model;
  final String customEndpoint;

  String get endpoint =>
      provider == AiProvider.custom ? customEndpoint.trim() : provider.endpoint;

  String? get validationError {
    if (apiKey.trim().isEmpty) return 'Enter an API key for this provider.';
    if (RegExp(r'[^\x21-\x7e]').hasMatch(apiKey.trim())) {
      return 'The API key must not contain spaces or line breaks.';
    }
    if (model.trim().isEmpty ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(model.trim())) {
      return 'Enter the model ID from your provider.';
    }
    if (provider == AiProvider.gemini &&
        !RegExp(r'^gemini-[a-zA-Z0-9._-]+$').hasMatch(model.trim())) {
      return 'Enter a Gemini model ID, such as gemini-2.5-flash.';
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        RegExp(r'\s').hasMatch(endpoint)) {
      return 'Enter a complete HTTPS endpoint without credentials, a query, or a fragment.';
    }
    return null;
  }

  Map<String, String> toJson() => {
    'provider': provider.name,
    'apiKey': apiKey.trim(),
    'model': model.trim(),
    'customEndpoint': provider == AiProvider.custom
        ? customEndpoint.trim()
        : '',
  };

  factory AiConfiguration.fromJson(Object? value) {
    if (value is! Map ||
        value['provider'] is! String ||
        value['apiKey'] is! String ||
        value['model'] is! String ||
        value['customEndpoint'] is! String) {
      throw const FormatException('Invalid saved AI settings.');
    }
    final providers = AiProvider.values.where(
      (p) => p.name == value['provider'],
    );
    if (providers.isEmpty) throw const FormatException('Invalid AI provider.');
    final configuration = AiConfiguration(
      provider: providers.single,
      apiKey: (value['apiKey'] as String).trim(),
      model: (value['model'] as String).trim(),
      customEndpoint: value['customEndpoint'] as String,
    );
    if (configuration.validationError != null) {
      throw const FormatException('Invalid saved AI settings.');
    }
    return configuration;
  }
}

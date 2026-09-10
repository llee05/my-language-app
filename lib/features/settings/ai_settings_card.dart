part of '../../main.dart';

typedef AiConnectionTest = Future<void> Function(AiConfiguration configuration);

class AiSettingsCard extends StatefulWidget {
  const AiSettingsCard({
    super.key,
    required this.repository,
    this.testConnection,
    this.enabled = true,
  });

  final AiConfigurationRepository repository;
  final AiConnectionTest? testConnection;
  final bool enabled;

  @override
  State<AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends State<AiSettingsCard> {
  final _keyController = TextEditingController();
  final _modelController = TextEditingController(
    text: AiProvider.gemini.defaultModel,
  );
  AiConfiguration? _saved;
  AiProvider _provider = AiProvider.gemini;
  final _endpointController = TextEditingController();
  bool _loading = true;
  bool _loadFailed = false;
  bool _busy = false;
  bool _showKey = false;
  String? _error;
  String? _notice;

  bool get _canEdit => widget.enabled && !_busy && !_loading && !_loadFailed;
  bool get _canRemove =>
      widget.enabled && !_busy && !_loading && (_saved != null || _loadFailed);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _provider = saved?.provider ?? AiProvider.gemini;
        _endpointController.text = saved?.customEndpoint ?? '';
        _modelController.text = saved?.model ?? AiProvider.gemini.defaultModel;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AiConfiguration? _draft() {
    final key = _keyController.text.trim();
    final model = _modelController.text.trim();
    final destination = _provider == AiProvider.custom
        ? _endpointController.text.trim()
        : _provider.endpoint;
    final canUseSaved =
        _saved?.provider == _provider && _saved?.endpoint == destination;
    final configuration = AiConfiguration(
      provider: _provider,
      customEndpoint: _endpointController.text.trim(),
      apiKey: key.isEmpty && canUseSaved ? _saved!.apiKey : key,
      model: model.isEmpty ? _provider.defaultModel : model,
    );
    final error = configuration.validationError;
    if (error != null) {
      setState(() {
        _error = error;
        _notice = null;
      });
      return null;
    }
    return configuration;
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    final configuration = _draft();
    if (configuration == null) return;
    await _perform(() async {
      await widget.repository.save(configuration);
      if (!mounted) return;
      setState(() {
        _saved = configuration;
        _keyController.clear();
        _showKey = false;
        _modelController.text = configuration.model;
        _notice = 'AI settings saved. Your next AI request will use them.';
      });
    }, 'Your API key could not be saved securely. Please try again.');
  }

  Future<void> _test() async {
    if (!_canEdit) return;
    final configuration = _draft();
    if (configuration == null) return;
    await _perform(
      () async {
        final testConnection = widget.testConnection;
        if (testConnection != null) {
          await testConnection(configuration);
        } else {
          await AiService(configuration: configuration).chatText(
            messages: const [
              {'role': 'user', 'content': 'Reply with OK.'},
            ],
            maxTokens: 256,
            temperature: 0,
          );
        }
        if (mounted) {
          setState(
            () => _notice = 'Connection successful. Save to keep any changes.',
          );
        }
      },
      'The connection test failed. Check your key, model, and internet connection.',
    );
  }

  Future<void> _remove() async {
    if (!_canRemove) return;
    await _perform(() async {
      await widget.repository.clear();
      if (!mounted) return;
      setState(() {
        _saved = null;
        _loadFailed = false;
        _provider = AiProvider.gemini;
        _endpointController.clear();
        _keyController.clear();
        _modelController.text = AiProvider.gemini.defaultModel;
        _showKey = false;
        _notice = 'Your saved API key was removed from this device.';
      });
    }, 'Your API key could not be removed. Please try again.');
  }

  Future<void> _perform(Future<void> Function() action, String error) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (failure) {
      // Configuration and request errors carry user-safe copy plus the
      // provider's machine-readable reason. Anything else (storage,
      // unexpected) keeps generic copy so platform errors, which can contain
      // credentials, are never displayed or logged.
      final String shown;
      if (failure is AiConfigurationException) {
        shown = failure.message;
      } else if (failure is AiRequestException) {
        shown = failure.message;
      } else {
        shown = error;
      }
      if (mounted) setState(() => _error = shown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edited(String _) => setState(() {
    _error = null;
    _notice = null;
  });

  @override
  Widget build(BuildContext context) => _SettingsCard(
    title: 'AI provider',
    subtitle: 'Use your own API key for the tutor and lesson examples.',
    child: _loading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : _loadFailed
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your saved AI settings could not be read from secure storage.',
              ),
              TextButton(
                key: const Key('ai-settings-retry'),
                onPressed: widget.enabled && !_busy ? _load : null,
                child: const Text('Try again'),
              ),
              TextButton(
                key: const Key('ai-remove'),
                onPressed: _canRemove ? _remove : null,
                child: const Text('Remove saved AI settings'),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.red)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your API key, messages, and lesson prompts go directly to the selected provider. '
                'Your key’s usage limits and any API charges apply. '
                'Lessons and review still work without AI.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AiProvider>(
                key: ValueKey('ai-provider-${_provider.name}'),
                initialValue: _provider,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: [
                  for (final provider in AiProvider.values)
                    DropdownMenuItem(
                      value: provider,
                      child: Text(provider.label),
                    ),
                ],
                onChanged: _canEdit
                    ? (provider) {
                        if (provider == null || provider == _provider) return;
                        setState(() {
                          _provider = provider;
                          _keyController.clear();
                          _modelController.text = provider.defaultModel;
                          _endpointController.clear();
                          _showKey = false;
                          _error = null;
                          _notice = null;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              if (_provider == AiProvider.custom) ...[
                TextField(
                  key: const Key('ai-endpoint'),
                  controller: _endpointController,
                  enabled: _canEdit,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  onChanged: (value) {
                    _keyController.clear();
                    _edited(value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Chat completions endpoint',
                    hintText: 'https://provider.example/v1/chat/completions',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use an OpenAI-compatible HTTPS endpoint you trust. '
                  'Your key will be sent to this address.',
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text('Requests go to ${Uri.parse(_provider.endpoint).host}.'),
                const SizedBox(height: 16),
              ],
              Text(
                _saved == null
                    ? 'No personal key saved.'
                    : 'A ${_saved!.provider.label} key is saved securely on this device.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ai-api-key'),
                controller: _keyController,
                enabled: _canEdit,
                obscureText: !_showKey,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: _edited,
                decoration: InputDecoration(
                  labelText: 'API key',
                  hintText:
                      _saved?.provider != _provider ||
                          (_provider == AiProvider.custom &&
                              _saved?.endpoint !=
                                  _endpointController.text.trim())
                      ? 'Paste a key for the selected provider'
                      : 'Leave blank to keep your saved key',
                  suffixIcon: IconButton(
                    tooltip: _showKey ? 'Hide API key' : 'Show API key',
                    onPressed: _canEdit
                        ? () => setState(() => _showKey = !_showKey)
                        : null,
                    icon: Icon(
                      _showKey ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('ai-model'),
                controller: _modelController,
                enabled: _canEdit,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: _edited,
                decoration: InputDecoration(
                  labelText: 'Model ID',
                  hintText: _provider.defaultModel.isEmpty
                      ? 'Enter a text model from your provider'
                      : _provider.defaultModel,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const Key('ai-save'),
                    onPressed: _canEdit ? _save : null,
                    child: const Text('Save AI settings'),
                  ),
                  OutlinedButton(
                    key: const Key('ai-test'),
                    onPressed: _canEdit ? _test : null,
                    child: const Text('Test connection'),
                  ),
                  if (_saved != null)
                    TextButton(
                      key: const Key('ai-remove'),
                      onPressed: _canRemove ? _remove : null,
                      child: const Text('Remove key'),
                    ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_error != null || _notice != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error ?? _notice!,
                  key: Key(
                    _error != null ? 'ai-settings-error' : 'ai-settings-notice',
                  ),
                  style: TextStyle(
                    color: _error != null ? AppColors.red : AppColors.teal,
                  ),
                ),
              ],
            ],
          ),
  );
}

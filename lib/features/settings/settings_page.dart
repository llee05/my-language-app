part of '../../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.profile,
    required this.onProfileChanged,
    required this.onResetOnboarding,
    required this.onResetAllData,
    required this.developmentRepository,
    required this.settingsRepository,
    this.pronunciationService,
  });

  final LearnerProfile profile;
  final Future<void> Function(LearnerProfile profile) onProfileChanged;
  final Future<void> Function() onResetOnboarding;
  final Future<void> Function() onResetAllData;
  final DevelopmentRepository developmentRepository;
  final SettingsRepository settingsRepository;
  final PronunciationService? pronunciationService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _nameController;
  late int _hskLevel;
  late int _dailyTarget;
  bool _saving = false;
  bool _loadingPreferences = true;
  bool _preferencesLoadFailed = false;
  bool _saveFailed = false;
  bool _resetting = false;
  bool _showPinyin = true;
  bool _soundEnabled = true;
  bool _reminderEnabled = false;
  int _reminderHour = 18;
  List<String> _kokoroVoiceIds = const [];
  late final Future<String> _databasePath;
  late final PronunciationService _pronunciationService;
  late final OfflinePronunciationManager? _offlineVoiceManager;
  late final bool _ownsPronunciationService;
  StreamSubscription<OfflineVoiceStatus>? _offlineVoiceSubscription;
  OfflineVoiceStatus? _kokoroVoiceStatus;
  bool _checkingKokoroVoice = false;

  static const _targets = [5, 10, 15, 20, 30];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _hskLevel = widget.profile.hskLevel;
    _dailyTarget = widget.profile.dailyWordTarget;
    _databasePath = widget.developmentRepository.databasePath();
    _ownsPronunciationService = widget.pronunciationService == null;
    _pronunciationService =
        widget.pronunciationService ?? createSystemPronunciationService();
    final service = _pronunciationService;
    _offlineVoiceManager = service is OfflinePronunciationManager
        ? service as OfflinePronunciationManager
        : null;
    _offlineVoiceSubscription =
        (_offlineVoiceManager?.voicePackUpdates ??
                _pronunciationService.offlineVoiceUpdates)
            .listen(_handleOfflineVoiceUpdate);
    _loadPreferences();
    unawaited(_loadVoicePackStatus());
  }

  void _handleOfflineVoiceUpdate(OfflineVoiceStatus status) {
    if (!mounted) return;
    setState(() {
      _kokoroVoiceStatus = status;
      _checkingKokoroVoice = false;
    });
  }

  Future<void> _loadVoicePackStatus() async {
    if (mounted) {
      setState(() {
        _checkingKokoroVoice = true;
      });
    }
    try {
      final manager = _offlineVoiceManager;
      final status = manager == null
          ? await _pronunciationService.checkOfflineVoice()
          : await manager.checkVoicePack(PronunciationEngine.kokoro);
      if (!mounted) return;
      _handleOfflineVoiceUpdate(status);
    } catch (error) {
      debugPrint('${PronunciationEngine.kokoro.name} voice status check failed: $error');
      if (!mounted) return;
      _handleOfflineVoiceUpdate(
        OfflineVoiceStatus(
          state: OfflineVoiceState.failed,
          engine: PronunciationEngine.kokoro,
          message: 'The Kokoro status could not be checked.',
        ),
      );
    }
  }

  Future<void> _installVoicePack() async {
    if (_kokoroVoiceStatus?.state == OfflineVoiceState.downloading) return;
    _handleOfflineVoiceUpdate(
      OfflineVoiceStatus(
        state: OfflineVoiceState.downloading,
        engine: PronunciationEngine.kokoro,
        totalBytes: kokoroOfflineVoiceDownloadBytes,
      ),
    );
    try {
      final manager = _offlineVoiceManager;
      if (manager == null) {
        await _pronunciationService.installOfflineVoice();
      } else {
        await manager.installVoicePack(PronunciationEngine.kokoro);
      }
      await _loadVoicePackStatus();
    } catch (error) {
      debugPrint('${PronunciationEngine.kokoro.name} voice installation failed: $error');
      if (!mounted || _kokoroVoiceStatus?.state == OfflineVoiceState.failed) {
        return;
      }
      _handleOfflineVoiceUpdate(
        OfflineVoiceStatus(
          state: OfflineVoiceState.failed,
          engine: PronunciationEngine.kokoro,
          message: 'Kokoro could not be installed. Try again.',
        ),
      );
    }
  }

  Future<void> _loadPreferences() async {
    if (!_loadingPreferences && mounted) {
      setState(() {
        _loadingPreferences = true;
        _preferencesLoadFailed = false;
      });
    }
    try {
      final settings = await widget.settingsRepository.load();
      if (!mounted) return;
      final kokoroVoiceIds = _canonicalKokoroVoiceIds(settings.kokoroVoiceIds);
      setState(() {
        _showPinyin = settings.showPinyin;
        _soundEnabled = settings.soundEnabled;
        _reminderEnabled = settings.reminderEnabled;
        _reminderHour = settings.reminderHour;
        _kokoroVoiceIds = kokoroVoiceIds;
        _loadingPreferences = false;
        _preferencesLoadFailed = false;
      });
    } catch (error) {
      debugPrint('Settings preferences load failed: $error');
      if (!mounted) return;
      setState(() {
        _loadingPreferences = false;
        _preferencesLoadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    unawaited(_offlineVoiceSubscription?.cancel());
    if (_ownsPronunciationService) {
      unawaited(_pronunciationService.dispose());
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.onProfileChanged(
        LearnerProfile(
          name: name,
          hskLevel: _hskLevel,
          dailyWordTarget: _dailyTarget,
        ),
      );
      await widget.settingsRepository.save(
        LearnerSettings(
          showPinyin: _showPinyin,
          soundEnabled: _soundEnabled,
          reminderEnabled: _reminderEnabled,
          reminderHour: _reminderHour,
          pronunciationEngine: PronunciationEngine.kokoro,
          kokoroVoiceIds: _kokoroVoiceIds,
        ),
      );
      await _applyPronunciationSelection();
      if (mounted) _showSaveSuccess();
    } catch (error) {
      debugPrint('Settings save failed: $error');
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyPronunciationSelection() async {
    final manager = _offlineVoiceManager;
    if (manager == null) return;
    try {
      await manager.configurePronunciation(
        engine: PronunciationEngine.kokoro,
        voiceIds: _kokoroVoiceIds,
      );
    } catch (error) {
      debugPrint('Pronunciation selection could not be applied: $error');
    }
  }

  void _showSaveSuccess() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Settings saved.')));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _resetOnboarding() => _withResetGuard(() async {
    final confirmed = await _confirm(
      title: 'Reset learner setup?',
      message:
          'Your learner profile will be removed. Lessons and other local data will be kept.',
      action: 'Reset setup',
    );
    if (confirmed) await _performOnboardingReset();
  });

  Future<void> _retryOnboardingReset() =>
      _withResetGuard(_performOnboardingReset);

  Future<void> _performOnboardingReset() async {
    try {
      await widget.onResetOnboarding();
    } catch (error) {
      debugPrint('Learner setup reset failed: $error');
      if (mounted) {
        _showRetrySnackBar(
          message: _AppErrorCopy.resetSetup,
          onRetry: _retryOnboardingReset,
        );
      }
    }
  }

  Future<void> _resetAllData() => _withResetGuard(() async {
    final confirmed = await _confirm(
      title: 'Reset all local data?',
      message:
          'This permanently removes the learner profile, generated lessons, and all other local app data.',
      action: 'Reset everything',
    );
    if (confirmed) await _performAllDataReset();
  });

  Future<void> _retryAllDataReset() => _withResetGuard(_performAllDataReset);

  Future<void> _performAllDataReset() async {
    try {
      await widget.onResetAllData();
    } catch (error) {
      debugPrint('Local data reset failed: $error');
      if (mounted) {
        _showRetrySnackBar(
          message: _AppErrorCopy.resetData,
          onRetry: _retryAllDataReset,
        );
      }
    }
  }

  Future<void> _withResetGuard(Future<void> Function() action) async {
    if (!mounted || _resetting) return;
    setState(() => _resetting = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  void _showRetrySnackBar({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Try again',
          onPressed: () => unawaited(onRetry()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          'Manage your learning preferences and local test data.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          title: 'Learner profile',
          subtitle: 'Changes are saved locally and used on your next launch.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'HSK level',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var level = 1; level <= 6; level++)
                    ChoiceChip(
                      label: Text('HSK $level'),
                      selected: _hskLevel == level,
                      onSelected: (_) => setState(() => _hskLevel = level),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Daily word target',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in _targets)
                    ChoiceChip(
                      label: Text('$target words'),
                      selected: _dailyTarget == target,
                      onSelected: (_) => setState(() => _dailyTarget = target),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: 'Learning preferences',
          subtitle: 'These preferences are restored on your next launch.',
          child: _loadingPreferences
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _preferencesLoadFailed
              ? _AppErrorState(
                  key: const Key('settings-preferences-error'),
                  title: _AppErrorCopy.preferencesTitle,
                  message: _AppErrorCopy.preferencesMessage,
                  onRetry: _loadPreferences,
                  retryKey: const Key('settings-preferences-retry'),
                  compact: true,
                )
              : Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show pinyin'),
                        value: _showPinyin,
                        onChanged: (value) =>
                            setState(() => _showPinyin = value),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sound'),
                        value: _soundEnabled,
                        onChanged: (value) =>
                            setState(() => _soundEnabled = value),
                      ),
                    ),
                  ],
                ),
        ),
        if (_shouldShowOfflineVoiceCard) ...[
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Offline Mandarin voices',
            subtitle:
                'Download the local Kokoro engine. Lessons use the system Mandarin voice whenever the pack is unavailable.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVoicePackSection(),
                if (_offlineVoiceManager != null &&
                    _kokoroVoiceStatus?.state ==
                        OfflineVoiceState.ready) ...[
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 22),
                  _buildPronunciationSelectors(),
                ],
              ],
            ),
          ),
        ],
        if (kDebugMode) ...[
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Developer tools',
            subtitle:
                'These controls are only included in debug builds and require confirmation.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String>(
                  future: _databasePath,
                  builder: (context, snapshot) => SelectableText(
                    'Database: ${snapshot.data ?? 'Loading…'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('settings-reset-onboarding'),
                      onPressed: _resetting ? null : _resetOnboarding,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Reset onboarding only'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('settings-reset-all'),
                      onPressed: _resetting ? null : _resetAllData,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Reset all local data'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_saveFailed)
          _AppInlineError(
            key: const Key('settings-save-error'),
            message: _AppErrorCopy.saveChanges,
            onRetry: _save,
            retryKey: const Key('settings-save-retry'),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('settings-save'),
              onPressed:
                  _saving || _loadingPreferences || _preferencesLoadFailed
                  ? null
                  : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save settings'),
            ),
          ),
      ],
    );
  }

  bool get _shouldShowOfflineVoiceCard {
    final status = _kokoroVoiceStatus;
    return status != null && status.state != OfflineVoiceState.unavailable;
  }

  Widget _buildVoicePackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kokoro',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Higher-quality int8 speech with 100 Mandarin voices.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        _buildOfflineVoiceControl(),
      ],
    );
  }

  Widget _buildOfflineVoiceControl() {
    final status = _kokoroVoiceStatus;
    if (_checkingKokoroVoice || status == null) {
      return const Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Checking voice pack…'),
        ],
      );
    }

    switch (status.state) {
      case OfflineVoiceState.ready:
        return Row(
          key: _voiceControlKey('ready'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.teal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: const Text(
                'Kokoro is installed and ready offline.',
              ),
            ),
          ],
        );
      case OfflineVoiceState.downloading:
        final progress = status.progress;
        final percent = progress == null ? null : (progress * 100).round();
        return Column(
          key: _voiceControlKey('downloading'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 10),
            Text(
              percent == null
                  ? status.message ?? 'Preparing the voice download…'
                  : '${status.message ?? 'Downloading…'} $percent% '
                        '(${_formatMegabytes(status.downloadedBytes)} of '
                        '${_formatMegabytes(status.totalBytes)} MB)',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        );
      case OfflineVoiceState.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status.message ??
                  'The offline voice could not be installed. Please try again.',
              style: const TextStyle(color: AppColors.red),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: _voiceControlKey('retry'),
              onPressed: () => _installVoicePack(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try download again'),
            ),
          ],
        );
      case OfflineVoiceState.notInstalled:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optional one-time download: 147 MB, about 215 MB installed. Installation needs about 600 MB of temporary free space.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: _voiceControlKey('download'),
              onPressed: () => _installVoicePack(),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download Kokoro'),
            ),
          ],
        );
      case OfflineVoiceState.unavailable:
        return const SizedBox.shrink();
    }
  }

  Key _voiceControlKey(String suffix) => Key('kokoro-voice-$suffix');

  Widget _buildPronunciationSelectors() {
    final voices = _availableKokoroVoices();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          key: const Key('kokoro-voice-picker'),
          child: OutlinedButton(
            onPressed: _openKokoroVoicePicker,
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            ),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kokoro voice pool',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _kokoroVoiceSummary(voices),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.text),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'A voice is chosen for each phrase. Select one voice to keep it consistent. Changes apply immediately; save settings to keep them after restarting.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  List<PronunciationVoice> _availableKokoroVoices() {
    final voices =
        _offlineVoiceManager?.voicesFor(PronunciationEngine.kokoro) ??
        kokoroMandarinVoices;
    return voices.isEmpty ? kokoroMandarinVoices : voices;
  }

  List<String> _canonicalKokoroVoiceIds(Iterable<String> voiceIds) {
    final voices = _availableKokoroVoices();
    final requestedIds = voiceIds.toSet();
    final selectedIds = [
      for (final voice in voices)
        if (requestedIds.contains(voice.id)) voice.id,
    ];
    if (selectedIds.isEmpty || selectedIds.length == voices.length) {
      return const [];
    }
    return List.unmodifiable(selectedIds);
  }

  String _kokoroVoiceSummary(List<PronunciationVoice> voices) {
    final selectedIds = _canonicalKokoroVoiceIds(_kokoroVoiceIds);
    if (selectedIds.isEmpty) return 'All ${voices.length} voices (random)';
    if (selectedIds.length > 1) {
      return '${selectedIds.length} voices (random)';
    }
    return voices.firstWhere((voice) => voice.id == selectedIds.single).label;
  }

  Future<void> _openKokoroVoicePicker() async {
    final voices = _availableKokoroVoices();
    final selectedIds = _canonicalKokoroVoiceIds(_kokoroVoiceIds);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _KokoroVoicePoolDialog(
        voices: voices,
        selectedVoiceIds: selectedIds.isEmpty
            ? {for (final voice in voices) voice.id}
            : selectedIds.toSet(),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _kokoroVoiceIds = _canonicalKokoroVoiceIds(result);
    });
    unawaited(_applyPronunciationSelection());
  }

  String _formatMegabytes(int bytes) =>
      (bytes / (1000 * 1000)).toStringAsFixed(1);
}

class _KokoroVoicePoolDialog extends StatefulWidget {
  const _KokoroVoicePoolDialog({
    required this.voices,
    required this.selectedVoiceIds,
  });

  final List<PronunciationVoice> voices;
  final Set<String> selectedVoiceIds;

  @override
  State<_KokoroVoicePoolDialog> createState() => _KokoroVoicePoolDialogState();
}

class _KokoroVoicePoolDialogState extends State<_KokoroVoicePoolDialog> {
  late Set<String> _selectedVoiceIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedVoiceIds = Set.of(widget.selectedVoiceIds);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visibleVoices = [
      for (final voice in widget.voices)
        if (query.isEmpty ||
            voice.label.toLowerCase().contains(query) ||
            voice.id.toLowerCase().contains(query))
          voice,
    ];
    final femaleVoices = visibleVoices
        .where((voice) => voice.id.startsWith('zf_'))
        .toList(growable: false);
    final maleVoices = visibleVoices
        .where((voice) => voice.id.startsWith('zm_'))
        .toList(growable: false);

    return AlertDialog(
      key: const Key('kokoro-voice-dialog'),
      title: const Text('Choose Kokoro voices'),
      content: SizedBox(
        width: 480,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('kokoro-voice-search'),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search voices',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${_selectedVoiceIds.length} of ${widget.voices.length} selected',
                      key: const Key('kokoro-voice-selected-count'),
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('kokoro-voice-select-all'),
                  onPressed: () => setState(() {
                    _selectedVoiceIds = {
                      for (final voice in widget.voices) voice.id,
                    };
                  }),
                  child: const Text('Select all'),
                ),
                TextButton(
                  key: const Key('kokoro-voice-clear-all'),
                  onPressed: () => setState(_selectedVoiceIds.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (_selectedVoiceIds.isEmpty)
              const Padding(
                key: Key('kokoro-voice-empty-error'),
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Choose at least one voice.',
                  style: TextStyle(color: AppColors.red, fontSize: 12),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: visibleVoices.isEmpty
                  ? const Center(child: Text('No matching voices.'))
                  : ListView(
                      children: [
                        ..._buildVoiceGroup('Female voices', femaleVoices),
                        ..._buildVoiceGroup('Male voices', maleVoices),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('kokoro-voice-apply'),
          onPressed: _selectedVoiceIds.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final voice in widget.voices)
                    if (_selectedVoiceIds.contains(voice.id)) voice.id,
                ]),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  List<Widget> _buildVoiceGroup(String title, List<PronunciationVoice> voices) {
    if (voices.isEmpty) return const [];
    return [
      Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      for (final voice in voices)
        CheckboxListTile(
          key: Key('kokoro-voice-choice-${voice.id}'),
          value: _selectedVoiceIds.contains(voice.id),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(voice.label),
          subtitle: Text(voice.id),
          onChanged: (selected) => setState(() {
            final nextIds = Set<String>.of(_selectedVoiceIds);
            if (selected ?? false) {
              nextIds.add(voice.id);
            } else {
              nextIds.remove(voice.id);
            }
            _selectedVoiceIds = nextIds;
          }),
        ),
    ];
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 760),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

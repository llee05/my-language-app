part of '../../main.dart';

enum _SettingsSaveTarget { profile, preferences }

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
  _SettingsSaveTarget? _savingTarget;
  bool _loadingPreferences = true;
  bool _preferencesLoadFailed = false;
  _SettingsSaveTarget? _saveFailureTarget;
  bool _resetting = false;
  bool _showPinyin = true;
  bool _soundEnabled = true;
  bool _reminderEnabled = false;
  int _reminderHour = 18;
  PronunciationEngine _pronunciationEngine = PronunciationEngine.melo;
  String? _pronunciationVoiceId;
  late final Future<String> _databasePath;
  late final PronunciationService _pronunciationService;
  late final OfflinePronunciationManager? _offlineVoiceManager;
  late final bool _ownsPronunciationService;
  StreamSubscription<OfflineVoiceStatus>? _offlineVoiceSubscription;
  OfflineVoiceStatus? _offlineVoiceStatus;
  OfflineVoiceStatus? _kokoroVoiceStatus;
  bool _checkingOfflineVoice = true;
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
    unawaited(_loadVoicePackStatus(PronunciationEngine.melo));
    if (_offlineVoiceManager != null) {
      unawaited(_loadVoicePackStatus(PronunciationEngine.kokoro));
    }
  }

  void _handleOfflineVoiceUpdate(OfflineVoiceStatus status) {
    if (!mounted) return;
    setState(() {
      switch (status.engine) {
        case PronunciationEngine.melo:
          _offlineVoiceStatus = status;
          _checkingOfflineVoice = false;
        case PronunciationEngine.kokoro:
          _kokoroVoiceStatus = status;
          _checkingKokoroVoice = false;
      }
    });
  }

  Future<void> _loadVoicePackStatus(PronunciationEngine engine) async {
    if (mounted) {
      setState(() {
        switch (engine) {
          case PronunciationEngine.melo:
            _checkingOfflineVoice = true;
          case PronunciationEngine.kokoro:
            _checkingKokoroVoice = true;
        }
      });
    }
    try {
      final manager = _offlineVoiceManager;
      final status = manager == null
          ? await _pronunciationService.checkOfflineVoice()
          : await manager.checkVoicePack(engine);
      if (!mounted) return;
      _handleOfflineVoiceUpdate(status);
    } catch (error) {
      debugPrint('${engine.name} voice status check failed: $error');
      if (!mounted) return;
      _handleOfflineVoiceUpdate(
        OfflineVoiceStatus(
          state: OfflineVoiceState.failed,
          engine: engine,
          message: 'The ${_engineName(engine)} status could not be checked.',
        ),
      );
    }
  }

  Future<void> _installVoicePack(PronunciationEngine engine) async {
    if (_voiceStatus(engine)?.state == OfflineVoiceState.downloading) return;
    _handleOfflineVoiceUpdate(
      OfflineVoiceStatus(
        state: OfflineVoiceState.downloading,
        engine: engine,
        totalBytes: _downloadBytes(engine),
      ),
    );
    try {
      final manager = _offlineVoiceManager;
      if (manager == null) {
        await _pronunciationService.installOfflineVoice();
      } else {
        await manager.installVoicePack(engine);
      }
      await _loadVoicePackStatus(engine);
    } catch (error) {
      debugPrint('${engine.name} voice installation failed: $error');
      if (!mounted || _voiceStatus(engine)?.state == OfflineVoiceState.failed) {
        return;
      }
      _handleOfflineVoiceUpdate(
        OfflineVoiceStatus(
          state: OfflineVoiceState.failed,
          engine: engine,
          message: '${_engineName(engine)} could not be installed. Try again.',
        ),
      );
    }
  }

  OfflineVoiceStatus? _voiceStatus(PronunciationEngine engine) =>
      switch (engine) {
        PronunciationEngine.melo => _offlineVoiceStatus,
        PronunciationEngine.kokoro => _kokoroVoiceStatus,
      };

  bool _checkingVoiceStatus(PronunciationEngine engine) => switch (engine) {
    PronunciationEngine.melo => _checkingOfflineVoice,
    PronunciationEngine.kokoro => _checkingKokoroVoice,
  };

  int _downloadBytes(PronunciationEngine engine) => switch (engine) {
    PronunciationEngine.melo => meloOfflineVoiceDownloadBytes,
    PronunciationEngine.kokoro => kokoroOfflineVoiceDownloadBytes,
  };

  String _engineName(PronunciationEngine engine) => switch (engine) {
    PronunciationEngine.melo => 'MeloTTS',
    PronunciationEngine.kokoro => 'Kokoro',
  };

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
      setState(() {
        _showPinyin = settings.showPinyin;
        _soundEnabled = settings.soundEnabled;
        _reminderEnabled = settings.reminderEnabled;
        _reminderHour = settings.reminderHour;
        _pronunciationEngine = settings.pronunciationEngine;
        _pronunciationVoiceId = settings.pronunciationVoiceId;
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

  Future<void> _save(_SettingsSaveTarget target) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _savingTarget != null) return;
    setState(() {
      _savingTarget = target;
      if (_saveFailureTarget == target) _saveFailureTarget = null;
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
          pronunciationEngine: _pronunciationEngine,
          pronunciationVoiceId: _pronunciationVoiceId,
        ),
      );
      await _applyPronunciationSelection();
      if (mounted) _showSaveSuccess(target);
    } catch (error) {
      debugPrint('Settings save failed: $error');
      if (mounted) setState(() => _saveFailureTarget = target);
    } finally {
      if (mounted) setState(() => _savingTarget = null);
    }
  }

  Future<void> _applyPronunciationSelection() async {
    final manager = _offlineVoiceManager;
    if (manager == null) return;
    try {
      await manager.configurePronunciation(
        engine: _pronunciationEngine,
        voiceId: _pronunciationVoiceId,
      );
    } catch (error) {
      debugPrint('Pronunciation selection could not be applied: $error');
    }
  }

  void _showSaveSuccess(_SettingsSaveTarget target) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (target) {
            _SettingsSaveTarget.profile => 'Profile changes saved.',
            _SettingsSaveTarget.preferences => 'Preferences saved.',
          }),
        ),
      );
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
              const SizedBox(height: 22),
              if (_saveFailureTarget == _SettingsSaveTarget.profile)
                _AppInlineError(
                  key: const Key('settings-profile-save-error'),
                  message: _AppErrorCopy.saveChanges,
                  onRetry: () => _save(_SettingsSaveTarget.profile),
                  retryKey: const Key('settings-profile-save-retry'),
                )
              else
                FilledButton.icon(
                  onPressed: _savingTarget != null
                      ? null
                      : () => _save(_SettingsSaveTarget.profile),
                  icon: _savingTarget == _SettingsSaveTarget.profile
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _savingTarget == _SettingsSaveTarget.profile
                        ? 'Saving…'
                        : 'Save changes',
                  ),
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
                    const SizedBox(height: 18),
                    if (_saveFailureTarget == _SettingsSaveTarget.preferences)
                      _AppInlineError(
                        key: const Key('settings-preferences-save-error'),
                        message: _AppErrorCopy.saveChanges,
                        onRetry: () => _save(_SettingsSaveTarget.preferences),
                        retryKey: const Key('settings-preferences-save-retry'),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _savingTarget != null
                              ? null
                              : () => _save(_SettingsSaveTarget.preferences),
                          icon: _savingTarget == _SettingsSaveTarget.preferences
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _savingTarget == _SettingsSaveTarget.preferences
                                ? 'Saving…'
                                : 'Save preferences',
                          ),
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
                'Download either local engine. Lessons use the system Mandarin voice whenever the selected pack is unavailable.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVoicePackSection(PronunciationEngine.melo),
                if (_offlineVoiceManager != null) ...[
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 22),
                  _buildVoicePackSection(PronunciationEngine.kokoro),
                  if (_kokoroVoiceStatus?.state == OfflineVoiceState.ready) ...[
                    const SizedBox(height: 22),
                    const Divider(),
                    const SizedBox(height: 22),
                    _buildPronunciationSelectors(),
                  ],
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
      ],
    );
  }

  bool get _shouldShowOfflineVoiceCard {
    if (_offlineVoiceManager != null) {
      final meloStatus = _offlineVoiceStatus;
      final kokoroStatus = _kokoroVoiceStatus;
      if (meloStatus == null || kokoroStatus == null) return false;
      return meloStatus.state != OfflineVoiceState.unavailable ||
          kokoroStatus.state != OfflineVoiceState.unavailable;
    }
    final status = _offlineVoiceStatus;
    return status != null && status.state != OfflineVoiceState.unavailable;
  }

  Widget _buildVoicePackSection(PronunciationEngine engine) {
    final isKokoro = engine == PronunciationEngine.kokoro;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _engineName(engine),
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isKokoro
              ? 'Higher-quality int8 speech with 100 Mandarin voices.'
              : 'Compact, fast Mandarin and English speech.',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        _buildOfflineVoiceControl(engine),
      ],
    );
  }

  Widget _buildOfflineVoiceControl(PronunciationEngine engine) {
    final status = _voiceStatus(engine);
    if (_checkingVoiceStatus(engine) || status == null) {
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
          key: _voiceControlKey(engine, 'ready'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.teal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_engineName(engine)} is installed and ready offline.',
              ),
            ),
          ],
        );
      case OfflineVoiceState.downloading:
        final progress = status.progress;
        final percent = progress == null ? null : (progress * 100).round();
        return Column(
          key: _voiceControlKey(engine, 'downloading'),
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
              key: _voiceControlKey(engine, 'retry'),
              onPressed: () => _installVoicePack(engine),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try download again'),
            ),
          ],
        );
      case OfflineVoiceState.notInstalled:
        final isKokoro = engine == PronunciationEngine.kokoro;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKokoro
                  ? 'Optional one-time download: 147 MB, about 215 MB installed. Installation needs about 600 MB of temporary free space.'
                  : 'Optional one-time download: about 61 MB. No manual file setup is needed.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: _voiceControlKey(engine, 'download'),
              onPressed: () => _installVoicePack(engine),
              icon: const Icon(Icons.download_rounded),
              label: Text('Download ${_engineName(engine)}'),
            ),
          ],
        );
      case OfflineVoiceState.unavailable:
        return const SizedBox.shrink();
    }
  }

  Key _voiceControlKey(PronunciationEngine engine, String suffix) => Key(
    '${engine == PronunciationEngine.melo ? 'offline' : 'kokoro'}-voice-$suffix',
  );

  Widget _buildPronunciationSelectors() {
    final manager = _offlineVoiceManager;
    final voices =
        manager?.voicesFor(PronunciationEngine.kokoro) ?? kokoroMandarinVoices;
    final selectedVoice = voices.firstWhere(
      (voice) => voice.id == _pronunciationVoiceId,
      orElse: () => voices.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<PronunciationEngine>(
          key: const Key('pronunciation-engine-picker'),
          initialValue: _pronunciationEngine,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Speech engine',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: PronunciationEngine.melo,
              child: Text('MeloTTS'),
            ),
            DropdownMenuItem(
              value: PronunciationEngine.kokoro,
              child: Text('Kokoro'),
            ),
          ],
          onChanged: (engine) {
            if (engine == null) return;
            setState(() => _pronunciationEngine = engine);
            unawaited(_applyPronunciationSelection());
          },
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: const Key('kokoro-voice-picker'),
          child: DropdownButtonFormField<String>(
            key: ValueKey(
              'kokoro-${_pronunciationEngine.name}-${selectedVoice.id}',
            ),
            initialValue: selectedVoice.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kokoro voice',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final voice in voices)
                DropdownMenuItem(
                  value: voice.id,
                  child: Text(voice.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _pronunciationEngine == PronunciationEngine.kokoro
                ? (voiceId) {
                    if (voiceId == null) return;
                    setState(() => _pronunciationVoiceId = voiceId);
                    unawaited(_applyPronunciationSelection());
                  }
                : null,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Voice changes apply immediately. Use Save preferences above to keep the choice after restarting.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  String _formatMegabytes(int bytes) =>
      (bytes / (1000 * 1000)).toStringAsFixed(1);
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

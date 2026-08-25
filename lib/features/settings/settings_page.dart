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
  late final Future<String> _databasePath;
  late final PronunciationService _pronunciationService;
  late final bool _ownsPronunciationService;
  StreamSubscription<OfflineVoiceStatus>? _offlineVoiceSubscription;
  OfflineVoiceStatus? _offlineVoiceStatus;
  bool _checkingOfflineVoice = true;

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
    _offlineVoiceSubscription = _pronunciationService.offlineVoiceUpdates
        .listen(_handleOfflineVoiceUpdate);
    _loadPreferences();
    unawaited(_loadOfflineVoiceStatus());
  }

  void _handleOfflineVoiceUpdate(OfflineVoiceStatus status) {
    if (!mounted) return;
    setState(() {
      _offlineVoiceStatus = status;
      _checkingOfflineVoice = false;
    });
  }

  Future<void> _loadOfflineVoiceStatus() async {
    if (mounted) setState(() => _checkingOfflineVoice = true);
    try {
      final status = await _pronunciationService.checkOfflineVoice();
      if (!mounted) return;
      setState(() {
        _offlineVoiceStatus = status;
        _checkingOfflineVoice = false;
      });
    } catch (error) {
      debugPrint('Offline voice status check failed: $error');
      if (!mounted) return;
      setState(() {
        _offlineVoiceStatus = const OfflineVoiceStatus(
          state: OfflineVoiceState.failed,
          message: 'The offline voice status could not be checked.',
        );
        _checkingOfflineVoice = false;
      });
    }
  }

  Future<void> _installOfflineVoice() async {
    if (_offlineVoiceStatus?.state == OfflineVoiceState.downloading) return;
    setState(() {
      _offlineVoiceStatus = const OfflineVoiceStatus(
        state: OfflineVoiceState.downloading,
        totalBytes: 60480445,
      );
      _checkingOfflineVoice = false;
    });
    try {
      await _pronunciationService.installOfflineVoice();
      await _loadOfflineVoiceStatus();
    } catch (error) {
      debugPrint('Offline voice installation failed: $error');
      if (!mounted || _offlineVoiceStatus?.state == OfflineVoiceState.failed) {
        return;
      }
      setState(() {
        _offlineVoiceStatus = const OfflineVoiceStatus(
          state: OfflineVoiceState.failed,
          message:
              'The offline voice could not be installed. Please try again.',
        );
      });
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
      setState(() {
        _showPinyin = settings.showPinyin;
        _soundEnabled = settings.soundEnabled;
        _reminderEnabled = settings.reminderEnabled;
        _reminderHour = settings.reminderHour;
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
        ),
      );
      if (mounted) _showSaveSuccess(target);
    } catch (error) {
      debugPrint('Settings save failed: $error');
      if (mounted) setState(() => _saveFailureTarget = target);
    } finally {
      if (mounted) setState(() => _savingTarget = null);
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
        if (_offlineVoiceStatus != null &&
            _offlineVoiceStatus!.state != OfflineVoiceState.unavailable) ...[
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Offline Mandarin voice',
            subtitle:
                'MeloTTS runs on your device. Lessons fall back to the system Mandarin voice until it is ready.',
            child: _buildOfflineVoiceControl(),
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

  Widget _buildOfflineVoiceControl() {
    final status = _offlineVoiceStatus;
    if (_checkingOfflineVoice || status == null) {
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
        return const Row(
          key: Key('offline-voice-ready'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.teal),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'MeloTTS is installed. Pronunciation now works fully offline.',
              ),
            ),
          ],
        );
      case OfflineVoiceState.downloading:
        final progress = status.progress;
        final percent = progress == null ? null : (progress * 100).round();
        return Column(
          key: const Key('offline-voice-downloading'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 10),
            Text(
              percent == null
                  ? 'Preparing the voice download…'
                  : 'Downloading… $percent% '
                        '(${_formatMegabytes(status.downloadedBytes)} of 60.5 MB)',
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
              key: const Key('offline-voice-retry'),
              onPressed: _installOfflineVoice,
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
              'Optional one-time download: about 61 MB. No manual file setup is needed.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('offline-voice-download'),
              onPressed: _installOfflineVoice,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download offline voice'),
            ),
          ],
        );
      case OfflineVoiceState.unavailable:
        return const SizedBox.shrink();
    }
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

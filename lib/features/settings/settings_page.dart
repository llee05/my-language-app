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
  });

  final LearnerProfile profile;
  final Future<void> Function(LearnerProfile profile) onProfileChanged;
  final Future<void> Function() onResetOnboarding;
  final Future<void> Function() onResetAllData;
  final DevelopmentRepository developmentRepository;
  final SettingsRepository settingsRepository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _nameController;
  late int _hskLevel;
  late int _dailyTarget;
  bool _saving = false;
  bool _loadingPreferences = true;
  bool _showPinyin = true;
  bool _soundEnabled = true;
  bool _reminderEnabled = false;
  int _reminderHour = 18;
  late final Future<String> _databasePath;

  static const _targets = [5, 10, 15, 20, 30];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _hskLevel = widget.profile.hskLevel;
    _dailyTarget = widget.profile.dailyWordTarget;
    _databasePath = widget.developmentRepository.databasePath();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final settings = await widget.settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _showPinyin = settings.showPinyin;
      _soundEnabled = settings.soundEnabled;
      _reminderEnabled = settings.reminderEnabled;
      _reminderHour = settings.reminderHour;
      _loadingPreferences = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  Future<void> _resetOnboarding() async {
    final confirmed = await _confirm(
      title: 'Reset learner setup?',
      message:
          'Your learner profile will be removed. Lessons and other local data will be kept.',
      action: 'Reset setup',
    );
    if (confirmed) await widget.onResetOnboarding();
  }

  Future<void> _resetAllData() async {
    final confirmed = await _confirm(
      title: 'Reset all local data?',
      message:
          'This permanently removes the learner profile, generated lessons, and all other local app data.',
      action: 'Reset everything',
    );
    if (confirmed) await widget.onResetAllData();
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
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save changes'),
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
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Daily reminder'),
                        value: _reminderEnabled,
                        onChanged: (value) =>
                            setState(() => _reminderEnabled = value),
                      ),
                    ),
                    if (_reminderEnabled)
                      DropdownButtonFormField<int>(
                        initialValue: _reminderHour,
                        decoration: const InputDecoration(
                          labelText: 'Reminder time',
                        ),
                        items: [
                          for (var hour = 0; hour < 24; hour++)
                            DropdownMenuItem(
                              value: hour,
                              child: Text(
                                '${hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)}:00 '
                                '${hour < 12 ? 'AM' : 'PM'}',
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _reminderHour = value ?? 18),
                      ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save preferences'),
                      ),
                    ),
                  ],
                ),
        ),
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
                      onPressed: _resetOnboarding,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Reset onboarding only'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _resetAllData,
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

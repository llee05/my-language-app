part of '../../main.dart';

class LearnerSetupPage extends StatefulWidget {
  const LearnerSetupPage({super.key, required this.onComplete});

  final Future<void> Function(LearnerProfile profile) onComplete;

  @override
  State<LearnerSetupPage> createState() => _LearnerSetupPageState();
}

class _LearnerSetupPageState extends State<LearnerSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _hskLevel = 1;
  int _dailyTarget = 10;
  bool _saving = false;
  String? _saveError;

  static const _targets = [5, 10, 15, 20, 30];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget
          .onComplete(
            LearnerProfile(
              name: _nameController.text.trim(),
              hskLevel: _hskLevel,
              dailyWordTarget: _dailyTarget,
            ),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'Saving took too long. Close any other copy of HanziPath and try again.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Could not save your profile. Please try again.';
      });
      debugPrint('Failed to save learner profile: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 32,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SetupBrand(),
                      const SizedBox(height: 30),
                      Text(
                        'Build your learning path',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A few details help us shape your daily Mandarin practice.',
                        style: TextStyle(color: AppColors.muted, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      const _SetupLabel(number: '01', label: 'Your name'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _continue(),
                        decoration: const InputDecoration(
                          hintText: 'What should we call you?',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter your name to continue'
                            : null,
                      ),
                      const SizedBox(height: 26),
                      const _SetupLabel(
                        number: '02',
                        label: 'Current HSK level',
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose the level that feels closest to you.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var level = 1; level <= 6; level++)
                            ChoiceChip(
                              label: Text('HSK $level'),
                              selected: _hskLevel == level,
                              onSelected: (_) =>
                                  setState(() => _hskLevel = level),
                            ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const _SetupLabel(
                        number: '03',
                        label: 'Daily word target',
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pick a goal you can keep up every day.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final target in _targets)
                            ChoiceChip(
                              label: Text('$target words'),
                              selected: _dailyTarget == target,
                              onSelected: (_) =>
                                  setState(() => _dailyTarget = target),
                            ),
                        ],
                      ),
                      if (_saveError case final error?) ...[
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: AppColors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.red,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _continue,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            _saving ? 'Saving your path…' : 'Start learning',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupBrand extends StatelessWidget {
  const _SetupBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.darkRed,
          child: Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.text,
          ),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '汉字路',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 20,
                color: AppColors.text,
              ),
            ),
            Text(
              'HANZIPATH',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 2,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SetupLabel extends StatelessWidget {
  const _SetupLabel({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          number,
          style: const TextStyle(
            color: AppColors.red,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

part of '../../main.dart';

class _SystemVoiceSetup extends StatefulWidget {
  const _SystemVoiceSetup({required this.installer});

  final SystemVoiceInstaller installer;

  @override
  State<_SystemVoiceSetup> createState() => _SystemVoiceSetupState();
}

class _SystemVoiceSetupState extends State<_SystemVoiceSetup>
    with WidgetsBindingObserver {
  bool? _installed;
  bool _checking = false;
  bool _opening = false;
  String? _error;
  int _checkId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    final checkId = ++_checkId;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final installed = await widget.installer.isMandarinVoiceInstalled();
      if (!mounted || checkId != _checkId) return;
      setState(() => _installed = installed);
    } catch (_) {
      if (!mounted || checkId != _checkId) return;
      setState(() {
        _installed = null;
        _error = 'Could not check the Mandarin voice. Try again.';
      });
    } finally {
      if (mounted && checkId == _checkId) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _install() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      await widget.installer.openMandarinVoiceInstaller();
      // Opening Android's installer is not evidence of a completed download.
      // The lifecycle observer rechecks when the learner returns.
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not open the voice installer. Open Android settings '
            'and look for text-to-speech to install a Mandarin voice.';
      });
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _checking
              ? 'Checking Mandarin voice…'
              : _installed == true
              ? 'Mandarin voice installed for offline speech.'
              : 'An offline Mandarin voice has not been confirmed on this device.',
          key: const Key('system-voice-status'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose Chinese (Mandarin / China) in your device’s voice installer. '
          'A download may require internet access. Return here to check it is ready.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, key: const Key('system-voice-error')),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (_installed != true)
              FilledButton.icon(
                key: const Key('system-voice-install'),
                onPressed: _opening || _checking ? null : _install,
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  _opening ? 'Opening installer…' : 'Install Mandarin voice',
                ),
              ),
            TextButton(
              key: const Key('system-voice-check'),
              onPressed: _checking || _opening ? null : _check,
              child: const Text('Check again'),
            ),
          ],
        ),
      ],
    );
  }
}

void _showPronunciationError(
  BuildContext context,
  PronunciationService service,
  Object error,
) {
  final missing = error is MandarinVoiceUnavailableException;
  final installer = service is SystemVoiceInstaller
      ? service as SystemVoiceInstaller
      : null;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        missing
            ? 'No Chinese voice found on this device. Install a Mandarin '
                  'text-to-speech voice in your system settings.'
            : 'Mandarin audio is unavailable. Check your device '
                  'text-to-speech voices.',
      ),
      action: missing && installer != null
          ? SnackBarAction(
              label: 'Install voice',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Mandarin voice'),
                    content: SingleChildScrollView(
                      child: _SystemVoiceSetup(installer: installer),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            )
          : null,
    ),
  );
}

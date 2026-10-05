part of '../../main.dart';

class _DesktopVoiceSetup extends StatefulWidget {
  const _DesktopVoiceSetup({required this.installer});
  final DesktopVoiceInstaller installer;

  @override
  State<_DesktopVoiceSetup> createState() => _DesktopVoiceSetupState();
}

class _DesktopVoiceSetupState extends State<_DesktopVoiceSetup>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<_DesktopVoiceSetup> {
  bool? _installed;
  bool _checking = false;
  bool _installing = false;
  String? _error;
  int _operationId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void didUpdateWidget(covariant _DesktopVoiceSetup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.installer, widget.installer)) {
      _installed = null;
      _installing = false;
      unawaited(_check());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_installing) unawaited(_check());
  }

  bool _isCurrent(int id) => mounted && id == _operationId;

  Future<void> _check() async {
    if (_installing) return;
    final id = ++_operationId;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final installed = await widget.installer.isMandarinVoiceInstalled();
      if (!_isCurrent(id)) return;
      setState(() => _installed = installed);
    } catch (_) {
      if (!_isCurrent(id)) return;
      setState(() {
        _installed = null;
        _error = 'Could not check the fallback Mandarin voice. Try again.';
      });
    } finally {
      if (_isCurrent(id)) setState(() => _checking = false);
    }
  }

  Future<void> _install() async {
    if (_installing || _checking) return;
    final id = ++_operationId;
    setState(() {
      _installing = true;
      _installed = null;
      _error = null;
    });
    try {
      await widget.installer.installMandarinVoice();
      if (!_isCurrent(id)) return;
      final ready = await widget.installer.isMandarinVoiceInstalled();
      if (!_isCurrent(id)) return;
      setState(() {
        _installed = ready;
        if (!ready) {
          _error =
              'The installer finished, but Mandarin speech is not ready yet. Restart the app or your computer if requested, then select Check again.';
        }
      });
    } catch (error) {
      if (!_isCurrent(id)) return;
      setState(() {
        _error = error is DesktopVoiceInstallationException
            ? error.message
            : 'Mandarin speech could not be installed. Check your connection and administrator approval, then try again.';
      });
    } finally {
      if (_isCurrent(id)) setState(() => _installing = false);
    }
  }

  @override
  void dispose() {
    _operationId++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Mandarin fallback',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          _installing
              ? 'Installing Mandarin voice…'
              : _checking
              ? 'Checking fallback Mandarin voice…'
              : _installed == true
              ? 'Fallback Mandarin voice is installed and ready offline.'
              : 'A fallback Mandarin voice has not been confirmed.',
          key: const Key('desktop-voice-status'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Install downloads system speech for missing words and full sentences. It needs internet access and may ask for administrator approval.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const Key('desktop-voice-error'),
            style: TextStyle(color: AppColors.red),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (_installed != true)
              FilledButton.icon(
                key: const Key('desktop-voice-install'),
                onPressed: _checking || _installing ? null : _install,
                icon: _installing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(
                  _installing ? 'Installing…' : 'Install Mandarin voice',
                ),
              ),
            TextButton(
              key: const Key('desktop-voice-check'),
              onPressed: _checking || _installing ? null : _check,
              child: const Text('Check again'),
            ),
          ],
        ),
      ],
    );
  }
}

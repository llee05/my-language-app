part of '../../main.dart';

/// Gives an in-place screen the same Back behavior as a pushed page. Local
/// history stacks with drawers and nested screens, so one Back action closes
/// only the top layer. Dialogs and pushed routes keep their own navigation.
class _BackNavigationScope extends StatefulWidget {
  const _BackNavigationScope({
    required this.active,
    required this.onBack,
    required this.child,
    this.blocked = false,
  });

  final bool active;
  final bool blocked;
  final VoidCallback onBack;
  final Widget child;

  @override
  State<_BackNavigationScope> createState() => _BackNavigationScopeState();
}

class _BackNavigationScopeState extends State<_BackNavigationScope> {
  ModalRoute<dynamic>? _route;
  LocalHistoryEntry? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _removeEntry();
      _route = route;
    }
    _syncEntry();
  }

  @override
  void didUpdateWidget(_BackNavigationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEntry();
  }

  void _syncEntry() {
    if (!widget.active) {
      _removeEntry();
      return;
    }
    // Register after the build so changing route history cannot rebuild an
    // ancestor mid-frame. Parent scopes register before their child scopes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active || _entry != null || _route == null) {
        return;
      }
      _entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (_entry == null) return;
          _entry = null;
          if (mounted) widget.onBack();
        },
      );
      _route!.addLocalHistoryEntry(_entry!);
    });
  }

  void _removeEntry() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PopScope<Object?>(canPop: !widget.blocked, child: widget.child);
}

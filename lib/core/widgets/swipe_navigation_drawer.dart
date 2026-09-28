part of '../../main.dart';

/// Keeps the opening gesture above the page in the widget tree so horizontal
/// controls inside the page can win their own gestures.
class _SwipeNavigationDrawer extends StatefulWidget {
  const _SwipeNavigationDrawer({
    super.key,
    required this.drawer,
    required this.child,
  });

  final Widget drawer;
  final Widget child;

  @override
  State<_SwipeNavigationDrawer> createState() => _SwipeNavigationDrawerState();
}

class _SwipeNavigationDrawerState extends State<_SwipeNavigationDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _focusScope = FocusScopeNode();
  LocalHistoryEntry? _historyEntry;
  double _drawerWidth = 304;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 246),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) _removeHistoryEntry();
        });
  }

  void _ensureHistoryEntry() {
    if (_historyEntry != null) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    _historyEntry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        if (_historyEntry == null) return;
        _historyEntry = null;
        if (mounted) _controller.animateBack(0, curve: Curves.easeOut);
      },
    );
    route.addLocalHistoryEntry(_historyEntry!);
    _focusScope.requestFocus();
  }

  void _removeHistoryEntry() {
    final entry = _historyEntry;
    _historyEntry = null;
    entry?.remove();
  }

  void open() {
    _ensureHistoryEntry();
    _controller.animateTo(1, curve: Curves.easeOut);
  }

  void close() {
    _controller.animateBack(0, curve: Curves.easeOut);
  }

  void _settle([double velocity = 0]) {
    if (velocity.abs() >= 365 ? velocity > 0 : _controller.value >= 0.5) {
      open();
    } else {
      close();
    }
  }

  @override
  void dispose() {
    _removeHistoryEntry();
    _controller.dispose();
    _focusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _drawerWidth = min(
          DrawerTheme.of(context).width ?? 304,
          constraints.maxWidth,
        );
        final scrimColor = DrawerTheme.of(context).scrimColor ?? Colors.black54;
        final direction = Directionality.of(context) == TextDirection.ltr
            ? 1.0
            : -1.0;
        return GestureDetector(
          onHorizontalDragStart: (_) => _controller.stop(),
          onHorizontalDragUpdate: (details) {
            _controller.value += direction * details.delta.dx / _drawerWidth;
            if (_controller.value > 0) _ensureHistoryEntry();
          },
          onHorizontalDragEnd: (details) =>
              _settle(direction * details.velocity.pixelsPerSecond.dx),
          onHorizontalDragCancel: _settle,
          child: AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (context, child) {
              final visible = _controller.value > 0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeFocus(
                    excluding: visible,
                    child: ExcludeSemantics(excluding: visible, child: child!),
                  ),
                  if (visible) ...[
                    ModalBarrier(
                      color: scrimColor.withValues(
                        alpha: scrimColor.a * _controller.value,
                      ),
                      onDismiss: close,
                      semanticsLabel: MaterialLocalizations.of(
                        context,
                      ).modalBarrierDismissLabel,
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Transform.translate(
                        offset: Offset(
                          direction * _drawerWidth * (_controller.value - 1),
                          0,
                        ),
                        child: SizedBox(
                          width: _drawerWidth,
                          height: double.infinity,
                          child: FocusScope(
                            node: _focusScope,
                            child: widget.drawer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

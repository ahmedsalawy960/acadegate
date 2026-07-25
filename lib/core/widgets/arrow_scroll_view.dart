import 'package:flutter/material.dart';

/// Scrollable area with visible arrow buttons when content overflows.
///
/// Use [axis] = horizontal for city chip rows, vertical for long pages.
class ArrowScrollView extends StatefulWidget {
  final Axis axis;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double scrollStep;
  final Color? arrowColor;
  final double? height;

  const ArrowScrollView({
    super.key,
    required this.child,
    this.axis = Axis.horizontal,
    this.padding = EdgeInsets.zero,
    this.scrollStep = 180,
    this.arrowColor,
    this.height,
  });

  @override
  State<ArrowScrollView> createState() => _ArrowScrollViewState();
}

class _ArrowScrollViewState extends State<ArrowScrollView> {
  final _controller = ScrollController();
  bool _canStart = false;
  bool _canEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateArrows);
    _controller.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final canStart = pos.pixels > 2;
    final canEnd = pos.pixels < pos.maxScrollExtent - 2;
    if (canStart != _canStart || canEnd != _canEnd) {
      setState(() {
        _canStart = canStart;
        _canEnd = canEnd;
      });
    }
  }

  Future<void> _scrollBy(double delta) async {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _arrowButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final color = widget.arrowColor ?? const Color(0xFF1A237E);
    return Material(
      color: enabled ? color.withValues(alpha: 0.1) : Colors.transparent,
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: enabled ? null : '',
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          icon,
          color: enabled ? color : Colors.grey.shade300,
          size: 22,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final scroll = Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: widget.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: widget.axis,
        padding: widget.padding,
        child: widget.child,
      ),
    );

    if (widget.axis == Axis.horizontal) {
      // In RTL, "start" is visually right; arrows still mean previous/next content.
      final backIcon = isRtl ? Icons.chevron_right : Icons.chevron_left;
      final forwardIcon = isRtl ? Icons.chevron_left : Icons.chevron_right;
      return SizedBox(
        height: widget.height,
        child: Row(
          children: [
            _arrowButton(
              icon: backIcon,
              enabled: _canStart,
              onPressed: () => _scrollBy(-widget.scrollStep),
            ),
            Expanded(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _updateArrows();
                  return false;
                },
                child: scroll,
              ),
            ),
            _arrowButton(
              icon: forwardIcon,
              enabled: _canEnd,
              onPressed: () => _scrollBy(widget.scrollStep),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _arrowButton(
          icon: Icons.keyboard_arrow_up,
          enabled: _canStart,
          onPressed: () => _scrollBy(-widget.scrollStep),
        ),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _updateArrows();
              return false;
            },
            child: scroll,
          ),
        ),
        _arrowButton(
          icon: Icons.keyboard_arrow_down,
          enabled: _canEnd,
          onPressed: () => _scrollBy(widget.scrollStep),
        ),
      ],
    );
  }
}

/// Vertical list/page scroller with up/down arrows (keeps a [ScrollController]).
class ArrowListView extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsetsGeometry? padding;
  final double scrollStep;

  const ArrowListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.scrollStep = 240,
  });

  @override
  State<ArrowListView> createState() => _ArrowListViewState();
}

class _ArrowListViewState extends State<ArrowListView> {
  final _controller = ScrollController();
  bool _canUp = false;
  bool _canDown = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.removeListener(_update);
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final canUp = pos.pixels > 2;
    final canDown = pos.pixels < pos.maxScrollExtent - 2;
    if (canUp != _canUp || canDown != _canDown) {
      setState(() {
        _canUp = canUp;
        _canDown = canDown;
      });
    }
  }

  Future<void> _scrollBy(double delta) async {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.separatorBuilder == null
        ? ListView.builder(
            controller: _controller,
            padding: widget.padding,
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
          )
        : ListView.separated(
            controller: _controller,
            padding: widget.padding,
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
            separatorBuilder: widget.separatorBuilder!,
          );

    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _update();
            return false;
          },
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            child: list,
          ),
        ),
        if (_canUp)
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 2,
                color: Colors.white,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Up',
                  onPressed: () => _scrollBy(-widget.scrollStep),
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
              ),
            ),
          ),
        if (_canDown)
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 2,
                color: Colors.white,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Down',
                  onPressed: () => _scrollBy(widget.scrollStep),
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../locale/locale_extensions.dart';

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
  /// Stable id so scroll offset is restored after leaving and returning.
  final String? storageId;

  const ArrowScrollView({
    super.key,
    required this.child,
    this.axis = Axis.horizontal,
    this.padding = EdgeInsets.zero,
    this.scrollStep = 180,
    this.arrowColor,
    this.height,
    this.storageId,
  });

  @override
  State<ArrowScrollView> createState() => _ArrowScrollViewState();
}

class _ArrowScrollViewState extends State<ArrowScrollView> {
  ScrollController? _controller;
  bool _canStart = false;
  bool _canEnd = false;

  String _storageKey(BuildContext context) {
    final route = ModalRoute.of(context);
    final routeId = route?.settings.name ?? 'r${route?.hashCode ?? 0}';
    return 'ArrowScrollView:${widget.storageId ?? widget.axis.name}:$routeId';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final saved = PageStorage.maybeOf(context)
        ?.readState(context, identifier: _storageKey(context));
    final offset = saved is num ? saved.toDouble() : 0.0;
    _controller = ScrollController(
      initialScrollOffset: offset.isFinite && offset > 0 ? offset : 0.0,
    );
    _controller!.addListener(_updateArrows);
    _controller!.addListener(_persistOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  void _persistOffset() {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    PageStorage.maybeOf(context)?.writeState(
      context,
      c.offset,
      identifier: _storageKey(context),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_updateArrows);
    _controller?.removeListener(_persistOffset);
    _controller?.dispose();
    super.dispose();
  }

  void _updateArrows() {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final pos = c.position;
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
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final target = (c.offset + delta).clamp(
      0.0,
      c.position.maxScrollExtent,
    );
    await c.animateTo(
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
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final scroll = Scrollbar(
      controller: controller,
      thumbVisibility: true,
      trackVisibility: widget.axis == Axis.horizontal,
      child: SingleChildScrollView(
        key: PageStorageKey<String>(_storageKey(context)),
        controller: controller,
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
  final String? storageId;

  const ArrowListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.scrollStep = 240,
    this.storageId,
  });

  @override
  State<ArrowListView> createState() => _ArrowListViewState();
}

class _ArrowListViewState extends State<ArrowListView> {
  ScrollController? _controller;
  bool _canUp = false;
  bool _canDown = false;

  String _storageKey(BuildContext context) {
    final route = ModalRoute.of(context);
    final routeId = route?.settings.name ?? 'r${route?.hashCode ?? 0}';
    return 'ArrowListView:${widget.storageId ?? 'list'}:$routeId';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final saved = PageStorage.maybeOf(context)
        ?.readState(context, identifier: _storageKey(context));
    final offset = saved is num ? saved.toDouble() : 0.0;
    _controller = ScrollController(
      initialScrollOffset: offset.isFinite && offset > 0 ? offset : 0.0,
    );
    _controller!.addListener(_update);
    _controller!.addListener(_persistOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _persistOffset() {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    PageStorage.maybeOf(context)?.writeState(
      context,
      c.offset,
      identifier: _storageKey(context),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_update);
    _controller?.removeListener(_persistOffset);
    _controller?.dispose();
    super.dispose();
  }

  void _update() {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final pos = c.position;
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
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final target = (c.offset + delta).clamp(
      0.0,
      c.position.maxScrollExtent,
    );
    await c.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    final pageKey = PageStorageKey<String>(_storageKey(context));
    final list = widget.separatorBuilder == null
        ? ListView.builder(
            key: pageKey,
            controller: controller,
            padding: widget.padding,
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
          )
        : ListView.separated(
            key: pageKey,
            controller: controller,
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
            controller: controller,
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

/// Wraps an existing scrollable (via [builder]) and overlays arrows
/// when content overflows — up/down or left/right.
class ArrowOverlayScroller extends StatefulWidget {
  final Axis axis;
  final double scrollStep;
  final double? height;
  final Color? arrowColor;
  final String? storageId;
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  const ArrowOverlayScroller({
    super.key,
    required this.builder,
    this.axis = Axis.vertical,
    this.scrollStep = 280,
    this.height,
    this.arrowColor,
    this.storageId,
  });

  @override
  State<ArrowOverlayScroller> createState() => _ArrowOverlayScrollerState();
}

class _ArrowOverlayScrollerState extends State<ArrowOverlayScroller> {
  ScrollController? _controller;
  bool _canStart = false;
  bool _canEnd = false;

  String _storageKey(BuildContext context) {
    final route = ModalRoute.of(context);
    final routeId = route?.settings.name ?? 'r${route?.hashCode ?? 0}';
    return 'ArrowOverlayScroller:${widget.storageId ?? widget.axis.name}:$routeId';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final saved = PageStorage.maybeOf(context)
        ?.readState(context, identifier: _storageKey(context));
    final offset = saved is num ? saved.toDouble() : 0.0;
    _controller = ScrollController(
      initialScrollOffset: offset.isFinite && offset > 0 ? offset : 0.0,
    );
    _controller!.addListener(_update);
    _controller!.addListener(_persistOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _persistOffset() {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    PageStorage.maybeOf(context)?.writeState(
      context,
      c.offset,
      identifier: _storageKey(context),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_update);
    _controller?.removeListener(_persistOffset);
    _controller?.dispose();
    super.dispose();
  }

  void _update() {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final pos = c.position;
    final canStart = pos.pixels > 2;
    final canEnd = pos.maxScrollExtent > 2 &&
        pos.pixels < pos.maxScrollExtent - 2;
    if (canStart != _canStart || canEnd != _canEnd) {
      setState(() {
        _canStart = canStart;
        _canEnd = canEnd;
      });
    }
  }

  Future<void> _scrollBy(double delta) async {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final target = (c.offset + delta).clamp(
      0.0,
      c.position.maxScrollExtent,
    );
    await c.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    final color = widget.arrowColor ?? const Color(0xFF1A237E);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final overflow = _canStart || _canEnd;
    final content = NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == widget.axis) _update();
        return false;
      },
      child: widget.builder(context, controller),
    );

    final body = widget.height == null
        ? content
        : SizedBox(height: widget.height, child: content);

    if (!overflow) return body;

    if (widget.axis == Axis.horizontal) {
      return SizedBox(
        height: widget.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            body,
            PositionedDirectional(
              start: 2,
              child: _CircleNavButton(
                icon: isRtl ? Icons.chevron_right : Icons.chevron_left,
                enabled: _canStart,
                tooltip: context.t('السابق', 'Previous'),
                color: color,
                onPressed: () => _scrollBy(-widget.scrollStep),
              ),
            ),
            PositionedDirectional(
              end: 2,
              child: _CircleNavButton(
                icon: isRtl ? Icons.chevron_left : Icons.chevron_right,
                enabled: _canEnd,
                tooltip: context.t('التالي', 'Next'),
                color: color,
                onPressed: () => _scrollBy(widget.scrollStep),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        body,
        if (_canStart)
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(
              child: _CircleNavButton(
                icon: Icons.keyboard_arrow_up,
                enabled: true,
                tooltip: context.t('أعلى', 'Up'),
                color: color,
                onPressed: () => _scrollBy(-widget.scrollStep),
              ),
            ),
          ),
        if (_canEnd)
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Center(
              child: _CircleNavButton(
                icon: Icons.keyboard_arrow_down,
                enabled: true,
                tooltip: context.t('أسفل', 'Down'),
                color: color,
                onPressed: () => _scrollBy(widget.scrollStep),
              ),
            ),
          ),
      ],
    );
  }
}

/// Left/right overlay for a [PageView] carousel.
class CarouselNavArrows extends StatelessWidget {
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool show;
  final Color color;

  const CarouselNavArrows({
    super.key,
    required this.onPrevious,
    required this.onNext,
    this.show = true,
    this.color = const Color(0xFF1A237E),
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      children: [
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: _CircleNavButton(
              icon: isRtl ? Icons.chevron_right : Icons.chevron_left,
              enabled: true,
              tooltip: context.t('السابق', 'Previous'),
              color: color,
              onPressed: onPrevious,
            ),
          ),
        ),
        PositionedDirectional(
          end: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: _CircleNavButton(
              icon: isRtl ? Icons.chevron_left : Icons.chevron_right,
              enabled: true,
              tooltip: context.t('التالي', 'Next'),
              color: color,
              onPressed: onNext,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _CircleNavButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: enabled ? 0.96 : 0.55),
      elevation: enabled ? 2 : 0,
      shadowColor: Colors.black26,
      shape: CircleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.22)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          icon,
          size: 26,
          color: enabled ? color : Colors.grey.shade400,
        ),
      ),
    );
  }
}

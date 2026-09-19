// Web-only implementation — dart:html is expected here.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Plays an MP4 with a real HTML &lt;video&gt; element (web).
class NetworkFilmView extends StatefulWidget {
  final String url;
  final bool loop;
  final VoidCallback? onEnded;

  const NetworkFilmView({
    super.key,
    required this.url,
    this.loop = true,
    this.onEnded,
  });

  @override
  State<NetworkFilmView> createState() => _NetworkFilmViewState();
}

class _NetworkFilmViewState extends State<NetworkFilmView> {
  late final String _viewType;
  bool _endedFired = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'product-film-${widget.url.hashCode}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final video = html.VideoElement()
        ..src = widget.url
        ..autoplay = true
        ..loop = widget.loop
        ..controls = true
        ..setAttribute('playsinline', 'true')
        ..setAttribute('controlslist', 'nodownload');
      video.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'contain'
        ..backgroundColor = '#000';
      video.onEnded.listen((_) {
        if (!mounted || _endedFired || widget.loop) return;
        _endedFired = true;
        widget.onEnded?.call();
      });
      video.play();
      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}

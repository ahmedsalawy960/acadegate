import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Plays an MP4 via video_player (Windows: Media Foundation).
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
  VideoPlayerController? _controller;
  String? _error;
  bool _ready = false;
  bool _endedFired = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<File> _cachedFile() async {
    final dir = await getTemporaryDirectory();
    final name =
        'guide_${widget.url.hashCode.toUnsigned(32).toRadixString(16)}.mp4';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    if (await file.exists() && await file.length() > 1000) return file;
    final res = await http.get(Uri.parse(widget.url));
    if (res.statusCode < 200 ||
        res.statusCode >= 300 ||
        res.bodyBytes.length < 1000) {
      throw Exception('تعذر تنزيل مقطع الفيديو (${res.statusCode})');
    }
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return file;
  }

  Future<VideoPlayerController> _createController() async {
    if (!kIsWeb && Platform.isWindows) {
      final file = await _cachedFile();
      return VideoPlayerController.file(file);
    }
    return VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
  }

  Future<void> _open() async {
    VideoPlayerController? controller;
    try {
      controller = await _createController();
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      if (!controller.value.isInitialized) {
        throw Exception('تعذر تهيئة مشغّل الفيديو');
      }
      await controller.setLooping(widget.loop);
      controller.addListener(_onTick);
      await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      try {
        await controller?.dispose();
      } catch (_) {}
      _controller = null;
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || widget.loop || _endedFired) return;
    final v = c.value;
    if (!v.isInitialized || v.duration <= Duration.zero) return;
    if (v.position >= v.duration - const Duration(milliseconds: 250) &&
        !v.isPlaying) {
      _endedFired = true;
      widget.onEnded?.call();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final c = _controller;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تعذر تشغيل الفيديو داخل التطبيق.\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح في المتصفح'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_ready || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    final playing = _controller!.value.isPlaying;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio == 0
                  ? 16 / 9
                  : _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          Positioned(
            bottom: 12,
            child: IconButton.filled(
              onPressed: _toggle,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xCC0D7377),
                foregroundColor: Colors.white,
              ),
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
          ),
        ],
      ),
    );
  }
}

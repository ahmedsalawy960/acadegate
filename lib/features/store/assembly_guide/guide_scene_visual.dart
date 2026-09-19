import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/storage/storage_service.dart';

/// رابط يصلح كصورة مشهد (وليس بحث يوتيوب أو صفحة ويب).
bool isLikelyRasterImageUrl(String? url) {
  final u = (url ?? '').trim().toLowerCase();
  if (u.isEmpty) return false;
  if (u.contains('youtube.com') ||
      u.contains('youtu.be') ||
      u.contains('vimeo.com') ||
      u.contains('search_query=')) {
    return false;
  }
  if (u.contains('firebasestorage') ||
      u.contains('googleapis.com') ||
      u.contains('alt=media')) {
    return true;
  }
  return u.contains('.png') ||
      u.contains('.jpg') ||
      u.contains('.jpeg') ||
      u.contains('.webp') ||
      u.contains('.gif');
}

bool looksLikeImageBytes(List<int> bytes) {
  if (bytes.length < 12) return false;
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) return true;
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45) {
    return true;
  }
  return false;
}

/// مشهد أنيميشن: صورة Storage إن وُجدت، وإلا إطار مرسوم يظهر فوراً.
class GuideSceneVisual extends StatefulWidget {
  final String? imageUrl;
  final String productName;
  final String title;
  final String body;
  final int index;
  final int total;
  final BoxFit fit;

  const GuideSceneVisual({
    super.key,
    required this.imageUrl,
    required this.productName,
    required this.title,
    required this.body,
    required this.index,
    required this.total,
    this.fit = BoxFit.cover,
  });

  @override
  State<GuideSceneVisual> createState() => _GuideSceneVisualState();
}

class _GuideSceneVisualState extends State<GuideSceneVisual> {
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _bytes;
  bool _loading = false;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant GuideSceneVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _startLoad(notify: true);
    }
  }

  void _startLoad({bool notify = false}) {
    final url = (widget.imageUrl ?? '').trim();
    _loadGen++;
    final gen = _loadGen;
    final cached = url.isNotEmpty ? _cache[url] : null;
    final loading = cached == null && isLikelyRasterImageUrl(url);
    void apply() {
      _bytes = cached;
      _loading = loading;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
    if (loading) _load(url, gen);
  }

  Future<void> _load(String url, int gen) async {
    Uint8List? data;
    try {
      data = await StorageService.instance.downloadBytes(url);
    } catch (_) {}
    if (data == null || !looksLikeImageBytes(data)) {
      data = null;
    }
    if (!mounted || gen != _loadGen) return;
    if (data != null) _cache[url] = data;
    setState(() {
      _bytes = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(
      painter: GuideScenePainter(
        productName: widget.productName,
        title: widget.title,
        body: widget.body,
        index: widget.index,
        total: widget.total,
      ),
      child: const SizedBox.expand(),
    );

    if (_bytes != null) {
      return SizedBox.expand(
        child: Image.memory(
          _bytes!,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        if (_loading)
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white70,
              ),
            ),
          ),
      ],
    );
  }
}

class GuideScenePainter extends CustomPainter {
  final String productName;
  final String title;
  final String body;
  final int index;
  final int total;

  const GuideScenePainter({
    required this.productName,
    required this.title,
    required this.body,
    required this.index,
    required this.total,
  });

  static const _palettes = [
    [Color(0xFF071018), Color(0xFF0D7377), Color(0xFFC45C26)],
    [Color(0xFF120B1A), Color(0xFF3D5A80), Color(0xFFE09F3E)],
    [Color(0xFF0B1A12), Color(0xFF2A9D8F), Color(0xFFE76F51)],
    [Color(0xFF1A1008), Color(0xFF7B2D26), Color(0xFFF4A261)],
    [Color(0xFF0A1224), Color(0xFF1B4B8A), Color(0xFF48CAE4)],
  ];

  static Future<Uint8List> renderPng({
    required String productName,
    required String title,
    required String body,
    required int index,
    required int total,
    int width = 1280,
    int height = 720,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    GuideScenePainter(
      productName: productName,
      title: title,
      body: body,
      index: index,
      total: total,
    ).paint(canvas, Size(width.toDouble(), height.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return bytes!.buffer.asUint8List();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _palettes[index.abs() % _palettes.length];
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette[0], palette[1].withValues(alpha: 0.85), palette[0]],
        ).createShader(rect),
    );

    void glow(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }

    glow(Offset(size.width * 0.18, size.height * 0.28), size.width * 0.28, palette[1]);
    glow(Offset(size.width * 0.82, size.height * 0.22), size.width * 0.22, palette[2]);
    glow(Offset(size.width * 0.72, size.height * 0.78), size.width * 0.3, palette[1]);

    final flask = Path()
      ..moveTo(size.width * 0.12, size.height * 0.22)
      ..lineTo(size.width * 0.18, size.height * 0.22)
      ..lineTo(size.width * 0.22, size.height * 0.48)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.72,
        size.width * 0.15,
        size.height * 0.78,
      )
      ..quadraticBezierTo(
        size.width * 0.04,
        size.height * 0.72,
        size.width * 0.08,
        size.height * 0.48,
      )
      ..close();
    canvas.drawPath(
      flask,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      flask,
      Paint()
        ..color = palette[2].withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final n = '${index + 1}'.padLeft(2, '0');
    _text(
      canvas,
      n,
      Offset(size.width * 0.08, size.height * 0.08),
      size.width * 0.84,
      64,
      FontWeight.w800,
      palette[2].withValues(alpha: 0.9),
      TextAlign.right,
    );
    _text(
      canvas,
      productName,
      Offset(size.width * 0.08, size.height * 0.42),
      size.width * 0.84,
      22,
      FontWeight.w500,
      Colors.white70,
      TextAlign.right,
    );
    _text(
      canvas,
      title,
      Offset(size.width * 0.08, size.height * 0.50),
      size.width * 0.84,
      36,
      FontWeight.w800,
      Colors.white,
      TextAlign.right,
    );
    if (body.trim().isNotEmpty) {
      _text(
        canvas,
        body.trim(),
        Offset(size.width * 0.08, size.height * 0.64),
        size.width * 0.84,
        18,
        FontWeight.w400,
        Colors.white.withValues(alpha: 0.88),
        TextAlign.right,
        maxLines: 3,
      );
    }
    _text(
      canvas,
      '${index + 1} / $total',
      Offset(size.width * 0.08, size.height * 0.90),
      size.width * 0.84,
      14,
      FontWeight.w600,
      Colors.white54,
      TextAlign.left,
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double maxWidth,
    double fontSize,
    FontWeight weight,
    Color color,
    TextAlign align, {
    int maxLines = 2,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant GuideScenePainter oldDelegate) {
    return oldDelegate.productName != productName ||
        oldDelegate.title != title ||
        oldDelegate.body != body ||
        oldDelegate.index != index ||
        oldDelegate.total != total;
  }
}

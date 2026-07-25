import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays images imported from DOCX (Firebase URL or inline data URI).
class ManuscriptImportImage extends StatelessWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;

  const ManuscriptImportImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  static Uint8List? decodeDataUri(String url) {
    if (!url.startsWith('data:')) return null;
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(url.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  static bool isVectorMime(String url) {
    return url.contains('image/x-emf') ||
        url.contains('image/x-wmf') ||
        url.toLowerCase().contains('.emf') ||
        url.toLowerCase().contains('.wmf');
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    if (isVectorMime(trimmed)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined,
              size: 40, color: Colors.blue.shade700),
          Text(
            'Structure (EMF)',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'محفوظة في ملف Word المُصدَّر',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            ),
          ),
        ],
      );
    }

    if (trimmed.startsWith('data:')) {
      final bytes = decodeDataUri(trimmed);
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 32),
        );
      }
      return const Icon(Icons.broken_image, size: 32);
    }

    if (trimmed.startsWith('http')) {
      return Image.network(
        trimmed,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 32),
      );
    }

    return const SizedBox.shrink();
  }
}

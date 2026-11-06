import 'package:flutter/material.dart';

/// يفعّل تحديد ونسخ النص داخل الشاشة.
/// يجب وضعه داخل الـ Route (تحت Overlay) — وليس حول MaterialApp.
class AcadeGateSelectable extends StatelessWidget {
  final Widget child;

  const AcadeGateSelectable({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SelectionArea(child: child);
}

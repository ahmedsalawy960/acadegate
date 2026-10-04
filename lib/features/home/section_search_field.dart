import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';

class SectionSearchField extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String? hint;

  const SectionSearchField({
    super.key,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFFF4F7FB), fontSize: 15),
      cursorColor: const Color(0xFFF4F7FB),
      decoration: InputDecoration(
        hintText: hint ??
            context.t(
              'ابحث داخل هذا القسم...',
              'Search within this section...',
            ),
        hintStyle: const TextStyle(color: Color(0xFFB7C3D6)),
        prefixIcon: const Icon(Icons.search, color: Color(0xFFB7C3D6)),
        suffixIcon: query.trim().isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, color: Color(0xFFB7C3D6)),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: const Color(0xFF12284F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A3F6E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A3F6E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC2410C), width: 1.4),
        ),
      ),
    );
  }
}

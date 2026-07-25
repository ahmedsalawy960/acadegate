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
      decoration: InputDecoration(
        hintText: hint ??
            context.t(
              'ابحث داخل هذا القسم...',
              'Search within this section...',
            ),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: query.trim().isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'citation_formatter.dart';
import 'publish_models.dart';

/// Explicit reference-style selector (APA / IEEE / Vancouver / …).
class CitationStylePicker extends StatelessWidget {
  final PublishCitationStyle value;
  final ValueChanged<PublishCitationStyle> onChanged;
  final bool enabled;

  const CitationStylePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode != 'en';

    return DropdownButtonFormField<PublishCitationStyle>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.t('نوع تنسيق المراجع', 'Reference style'),
        helperText: CitationFormatter.styleShortDescription(
          value,
          arabic: arabic,
        ),
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.format_quote_outlined),
        border: const OutlineInputBorder(),
      ),
      items: PublishCitationStyle.values
          .map(
            (style) => DropdownMenuItem(
              value: style,
              child: Text(
                CitationFormatter.styleMenuLabel(style, arabic: arabic),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: enabled
          ? (style) {
              if (style != null) onChanged(style);
            }
          : null,
    );
  }
}

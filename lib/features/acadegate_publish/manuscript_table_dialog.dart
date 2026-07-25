import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';

Future<({List<List<String>> rows, String caption})?> showManuscriptTableDialog(
  BuildContext context, {
  List<List<String>>? existingRows,
  String? existingCaption,
}) async {
  return showDialog<({List<List<String>> rows, String caption})>(
    context: context,
    builder: (ctx) => _TableDialog(
      initialRows: existingRows,
      initialCaption: existingCaption,
    ),
  );
}

class _TableDialog extends StatefulWidget {
  final List<List<String>>? initialRows;
  final String? initialCaption;

  const _TableDialog({this.initialRows, this.initialCaption});

  @override
  State<_TableDialog> createState() => _TableDialogState();
}

class _TableDialogState extends State<_TableDialog> {
  late int _rows;
  late int _cols;
  late List<List<TextEditingController>> _cells = [];
  late final TextEditingController _captionCtrl;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialRows;
    _rows = existing?.length ?? 3;
    _cols = existing?.isNotEmpty == true ? existing!.first.length : 3;
    _captionCtrl = TextEditingController(text: widget.initialCaption ?? '');
    _initCells(existing);
  }

  void _initCells(List<List<String>>? existing) {
    for (final row in _cells) {
      for (final c in row) {
        c.dispose();
      }
    }
    _cells = List.generate(
      _rows,
      (r) => List.generate(
        _cols,
        (c) => TextEditingController(
          text: existing != null &&
                  r < existing.length &&
                  c < existing[r].length
              ? existing[r][c]
              : '',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    for (final row in _cells) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _resize(int rows, int cols) {
    setState(() {
      _rows = rows.clamp(1, 20);
      _cols = cols.clamp(1, 10);
      final old = _cells
          .map((row) => row.map((c) => c.text).toList())
          .toList();
      _initCells(old);
    });
  }

  void _save() {
    final rows = _cells.map((row) => row.map((c) => c.text.trim()).toList()).toList();
    Navigator.pop(context, (rows: rows, caption: _captionCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('جدول', 'Table')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _rows,
                      decoration: InputDecoration(
                        labelText: context.t('صفوف', 'Rows'),
                        border: const OutlineInputBorder(),
                      ),
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                      ),
                      onChanged: (v) => _resize(v ?? _rows, _cols),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _cols,
                      decoration: InputDecoration(
                        labelText: context.t('أعمدة', 'Columns'),
                        border: const OutlineInputBorder(),
                      ),
                      items: List.generate(
                        8,
                        (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                      ),
                      onChanged: (v) => _resize(_rows, v ?? _cols),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(_rows, (r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: List.generate(_cols, (c) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: c < _cols - 1 ? 6 : 0),
                          child: TextField(
                            controller: _cells[r][c],
                            decoration: InputDecoration(
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: _captionCtrl,
                decoration: InputDecoration(
                  labelText: context.t('تعليق الجدول', 'Table caption'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.t('حفظ', 'Save')),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'manuscript_draft_chat_service.dart';
import 'publish_models.dart';

class _ChatTurn {
  final bool user;
  final String text;
  final List<DraftChatHit> hits;
  final bool usedCloudAi;

  const _ChatTurn({
    required this.user,
    required this.text,
    this.hits = const [],
    this.usedCloudAi = false,
  });
}

class ManuscriptDraftChatPanel extends StatefulWidget {
  final PublishManuscript manuscript;
  final Color brand;

  const ManuscriptDraftChatPanel({
    super.key,
    required this.manuscript,
    this.brand = const Color(0xFF4A148C),
  });

  @override
  State<ManuscriptDraftChatPanel> createState() =>
      _ManuscriptDraftChatPanelState();
}

class _ManuscriptDraftChatPanelState extends State<ManuscriptDraftChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_ChatTurn>[];
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> _suggestions(BuildContext context) => [
        context.t('هل الملخص يطابق النتائج؟', 'Does the abstract match the results?'),
        context.t('أين جدول 3؟', 'Where is Table 3?'),
        context.t('أين الشكل 1؟', 'Where is Figure 1?'),
        context.t('أين قسم المناقشة؟', 'Where is the Discussion?'),
      ];

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _turns.add(_ChatTurn(user: true, text: text));
      _busy = true;
    });
    _jumpToEnd();
    try {
      final reply = await ManuscriptDraftChatService.instance.ask(
        manuscript: widget.manuscript,
        question: text,
      );
      if (!mounted) return;
      setState(() {
        _turns.add(_ChatTurn(
          user: false,
          text: reply.text,
          hits: reply.hits,
          usedCloudAi: reply.usedCloudAi,
        ));
        _busy = false;
      });
      _jumpToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _turns.add(_ChatTurn(user: false, text: '$e'));
        _busy = false;
      });
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final index =
        ManuscriptDraftChatService.instance.indexOf(widget.manuscript);
    return Column(
      children: [
        Material(
          color: widget.brand.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('اسأل مسودتك المرفوعة', 'Ask this uploaded draft'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: widget.brand,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  index.isEmpty
                      ? context.t(
                          'ارفع PDF أو Word أولاً حتى تُجاب الأسئلة من ملفك أنت لا من نماذج عامة.',
                          'Upload a PDF or Word file first so answers come from your file, not generic models.',
                        )
                      : index.inventoryLine,
                  style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6), height: 1.35),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: [
              if (_turns.isEmpty) ...[
                Text(
                  context.t(
                    'اسأل عن هذه الورقة كما رُفعت: تطابق الملخص مع النتائج، موضع جدول أو شكل، أو محتوى قسم.',
                    'Ask about this uploaded paper: abstract vs results, a table or figure location, or a section.',
                  ),
                  style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions(context)
                      .map(
                        (s) => ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 13)),
                          onPressed: _busy ? null : () => _send(s),
                        ),
                      )
                      .toList(),
                ),
              ],
              for (final turn in _turns) _bubble(context, turn),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.brand,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.t('أقرأ ملفك…', 'Reading your file…'),
                        style: TextStyle(color: const Color(0xFFB7C3D6)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_busy,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: context.t(
                        'مثال: هل الملخص يطابق النتائج؟',
                        'e.g. Does the abstract match the results?',
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : () => _send(_input.text),
                  style: IconButton.styleFrom(backgroundColor: widget.brand),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(BuildContext context, _ChatTurn turn) {
    final bg = turn.user ? widget.brand : Colors.grey.shade100;
    final fg = turn.user ? Colors.white : Colors.black87;
    return Align(
      alignment: turn.user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                turn.text,
                style: TextStyle(color: fg, height: 1.45),
              ),
              if (turn.usedCloudAi)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.t(
                      'التحليل الإضافي مقيّد بمقتطفات هذا الملف.',
                      'Further analysis is limited to excerpts of this file.',
                    ),
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ),
              for (final hit in turn.hits.take(5))
                if (hit.tablePreview.isNotEmpty)
                  _tablePreview(context, hit, turn.user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tablePreview(BuildContext context, DraftChatHit hit, bool onBrand) {
    final rows = hit.tablePreview;
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    if (cols == 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: onBrand ? Colors.white.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.black12, width: 0.5),
        children: [
          for (final row in rows.take(4))
            TableRow(
              children: [
                for (var c = 0; c < cols; c++)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      c < row.length ? row[c] : '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: onBrand ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<void> showManuscriptDraftChatSheet({
  required BuildContext context,
  required PublishManuscript manuscript,
  Color brand = const Color(0xFF4A148C),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.88;
      return SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ctx.t('اسأل المسودة', 'Ask the draft'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ManuscriptDraftChatPanel(
                manuscript: manuscript,
                brand: brand,
              ),
            ),
          ],
        ),
      );
    },
  );
}

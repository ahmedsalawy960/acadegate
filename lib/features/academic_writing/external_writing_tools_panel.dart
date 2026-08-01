import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../ai_advisor/ai_advisor_screen.dart';

class _ExternalTool {
  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final String url;
  final IconData icon;
  final Color color;

  const _ExternalTool({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.url,
    required this.icon,
    required this.color,
  });
}

/// External writing helpers + in-app editing agent entry.
class ExternalWritingToolsPanel extends StatelessWidget {
  final Color accent;

  const ExternalWritingToolsPanel({
    super.key,
    this.accent = const Color(0xFF2E7D32),
  });

  static const _tools = <_ExternalTool>[
    _ExternalTool(
      id: 'grammarly',
      titleAr: 'Grammarly',
      titleEn: 'Grammarly',
      subtitleAr: 'تدقيق إنجليزي',
      subtitleEn: 'English proofreading',
      url: 'https://app.grammarly.com/',
      icon: Icons.spellcheck,
      color: Color(0xFF15C39A),
    ),
    _ExternalTool(
      id: 'languagetool',
      titleAr: 'LanguageTool',
      titleEn: 'LanguageTool',
      subtitleAr: 'عربي + إنجليزي',
      subtitleEn: 'Arabic + English',
      url: 'https://languagetool.org/',
      icon: Icons.translate,
      color: Color(0xFF7566FF),
    ),
    _ExternalTool(
      id: 'deepl',
      titleAr: 'DeepL Write',
      titleEn: 'DeepL Write',
      subtitleAr: 'إعادة صياغة',
      subtitleEn: 'Rewriting',
      url: 'https://www.deepl.com/write',
      icon: Icons.auto_fix_high,
      color: Color(0xFF0F2B46),
    ),
    _ExternalTool(
      id: 'quillbot',
      titleAr: 'QuillBot',
      titleEn: 'QuillBot',
      subtitleAr: 'إعادة صياغة',
      subtitleEn: 'Paraphrasing',
      url: 'https://quillbot.com/',
      icon: Icons.sync_alt,
      color: Color(0xFF499557),
    ),
  ];

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تعذر فتح الرابط', 'Could not open the link'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openEditingAgent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiAdvisorScreen(
          initialMessage: context.t(
            'أريد تدقيقاً وتحريراً أكاديمياً عبر وكيل التحرير في AcadeGate. '
            'سألصق النص بعد هذه الرسالة — صحّح اللغة والأسلوب دون تغيير المعنى العلمي.',
            'I need academic editing and proofreading via the AcadeGate editing agent. '
            'I will paste the text next — fix language and style without changing the scholarly meaning.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: accent.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.extension_outlined, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t(
                      'أدوات التحرير والتدقيق',
                      'Editing & proofreading tools',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                'اختصارات لمواقع خارجية (قد تحتاج حساباً) + فحص داخل AcadeGate',
                'Shortcuts to external sites (may need an account) + in-app AcadeGate check',
              ),
              style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.35),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openEditingAgent(context),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                minimumSize: const Size(double.infinity, 46),
              ),
              icon: const Icon(Icons.smart_toy_outlined),
              label: Text(
                context.t(
                  'فحص داخل AcadeGate — وكيل التحرير',
                  'Check in AcadeGate — Editing agent',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tools.map((tool) {
                return ActionChip(
                  avatar: Icon(tool.icon, size: 18, color: tool.color),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(tool.titleAr, tool.titleEn),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        context.t(tool.subtitleAr, tool.subtitleEn),
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  onPressed: () => _openUrl(context, tool.url),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                'هذه الأدوات لا تعمل داخل التطبيق كامتداد — تُفتح خارجياً.',
                'These tools are not in-app extensions — they open externally.',
              ),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

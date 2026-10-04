import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import 'content_analysis_sheet_screen.dart';
import 'corpus_document_card_screen.dart';
import 'cronbach_screen.dart';
import 'face_validity_screen.dart';
import 'interview_protocol_screen.dart';
import 'research_tools_branding.dart';
import 'survey_builder_screen.dart';

/// مسار 2 — استوديو الأدوات: كمية + نوعية/نصية للكليات الأدبية.
class ResearchToolsStudioScreen extends StatelessWidget {
  const ResearchToolsStudioScreen({super.key});

  static const _brand = Color(ResearchToolsBranding.brand);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(ResearchToolsBranding.title),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ResearchToolsBranding.tagline,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ResearchToolsBranding.integrityNote,
                    style: TextStyle(height: 1.4, color: const Color(0xFFB7C3D6)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.t(
              '١) أدوات نوعية / نصية (آداب · إعلام · حقوق · تربية نوعية)',
              '1) Qualitative / textual (arts · media · law · qual. education)',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          _ToolCard(
            icon: Icons.record_voice_over_outlined,
            color: const Color(0xFFAD1457),
            title: context.t('بروتوكول المقابلة', 'Interview protocol'),
            subtitle: context.t(
              'أسئلة شبه مقنّنة + متابعة + أخلاقيات — للآداب والتربية النوعية',
              'Semi-structured questions + probes + ethics — arts & qualitative education',
            ),
            onTap: () => _open(context, const InterviewProtocolScreen()),
          ),
          _ToolCard(
            icon: Icons.category_outlined,
            color: const Color(0xFF6A1B9A),
            title: context.t('ورقة تحليل المضمون', 'Content-analysis sheet'),
            subtitle: context.t(
              'وحدة التحليل + رموز ترميز بتعريفات إجرائية — للإعلام والآداب',
              'Unit of analysis + codes with operational definitions — media & arts',
            ),
            onTap: () => _open(context, const ContentAnalysisSheetScreen()),
          ),
          _ToolCard(
            icon: Icons.library_books_outlined,
            color: const Color(0xFF5D4037),
            title: context.t('مدونة نصوص / وثائق', 'Text / document corpus'),
            subtitle: context.t(
              'اختيار المدونة الأدبية أو الوثائق القانونية بمعايير واضحة',
              'Build a literary corpus or legal document set with clear criteria',
            ),
            onTap: () => _open(context, const CorpusDocumentCardScreen()),
          ),
          const SizedBox(height: 14),
          Text(
            context.t(
              '٢) أدوات كمية / استبانة (تربية · تجارة · دراسات مسحية)',
              '2) Quantitative / survey (education · business · survey studies)',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          _ToolCard(
            icon: Icons.list_alt_outlined,
            color: const Color(0xFF4527A0),
            title: context.t('منشئ الاستبانة', 'Survey builder'),
            subtitle: context.t(
              'أبعاد وبنود ومقاييس ليكرت — ليس المسار الوحيد للأدبيين',
              'Dimensions, items, Likert scales — not the only path for literary researchers',
            ),
            onTap: () => _open(context, const SurveyBuilderScreen()),
          ),
          _ToolCard(
            icon: Icons.fact_check_outlined,
            color: const Color(0xFF1565C0),
            title: context.t('الصدق الظاهري وتحكيم الأداة', 'Face validity & review'),
            subtitle: context.t(
              'قائمة تحقق للمحكّمين — تنفع أي أداة (استبانة أو مقابلة أو ترميز)',
              'Expert checklist — useful for survey, interview, or coding sheets',
            ),
            onTap: () => _open(context, const FaceValidityScreen()),
          ),
          _ToolCard(
            icon: Icons.functions_outlined,
            color: const Color(0xFF2E7D32),
            title: context.t('ألفا كرونباخ (الثبات)', 'Cronbach’s α (reliability)'),
            subtitle: context.t(
              'لحساب ثبات بنود الاستبانة الكمية فقط — ليس لتحليل النصوص الأدبية',
              'For survey-item reliability only — not for literary text analysis',
            ),
            onTap: () => _open(context, const CronbachScreen()),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: acadegateInk(color),
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(height: 1.35)),
        trailing: const Icon(Icons.chevron_left),
        isThreeLine: true,
      ),
    );
  }
}

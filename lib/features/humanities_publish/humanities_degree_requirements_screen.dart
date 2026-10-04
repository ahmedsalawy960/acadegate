import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import 'humanities_publish_branding.dart';

/// متطلبات النشر ومنح الدرجة في الكليات الأدبية/الإنسانية المصرية (إرشاد لائحي عام).
class HumanitiesDegreePublishRequirementsScreen extends StatelessWidget {
  const HumanitiesDegreePublishRequirementsScreen({super.key});

  static const _brand = Color(HumanitiesPublishBranding.brand);

  static final _linkButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFF4F7FB),
    backgroundColor: const Color(0xFF1E3358),
    side: const BorderSide(color: Color(0xFFB7C3D6)),
  );

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t(
            'متطلبات الماجستير والدكتوراه',
            'Master’s & PhD requirements',
          ),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.t(
                  'إطار عام لكليات التربية والحقوق والآداب والإعلام: تختلف اللائحة الداخلية '
                  'حسب الجامعة والقسم — تحقق دائماً من مجلس الدراسات العليا لديك. '
                  'Scopus ليس الشرط الوحيد؛ الشائع مجلة عربية محكمة معتمدة أو دورية الكلية.',
                  'General frame for Education, Law, Arts, and Media faculties: bylaws differ '
                  'by university and department — always verify with your graduate board. '
                  'Scopus is not the only path; an approved Arabic peer-reviewed or faculty journal is common.',
                ),
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('١) النشر كشرط للدرجة', '1) Publishing as a degree condition'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _DegreeCard(
            brand: _brand,
            titleAr: 'الماجستير',
            titleEn: "Master's",
            bodyAr:
                'غالباً يكفي إتمام الرسالة والمناقشة بعد التمهيدي دون نشر دولي إلزامي.\n'
                'لكن بعض الكليات/الأقسام تشترط: قبول بحث مستل من الرسالة في مجلة محكمة، '
                'أو تقديم ما يفيد التقدم لمؤتمر الكلية السنوي قبل صلاحية العرض للمناقشة.',
            bodyEn:
                'Often the thesis + viva after preliminary courses is enough without mandatory international publishing.\n'
                'Some faculties/departments still require: acceptance of a thesis-derived paper in a peer-reviewed journal, '
                'or proof of submission to the faculty annual conference before viva eligibility.',
          ),
          _DegreeCard(
            brand: _brand,
            titleAr: 'الدكتوراه',
            titleEn: 'PhD',
            bodyAr:
                'شرط صارم في غالب الجامعات الحكومية: لا تشكيل لجنة الحكم والمناقشة '
                'إلا بعد مستخرج رسمي يثبت قبول أو نشر بحث مستل من الرسالة في مجلة علمية محكمة '
                'معتمدة من المجلس الأعلى للجامعات، أو في دورية تابعة للكلية/الجامعة.',
            bodyEn:
                'Strict in most public universities: the viva committee is not formed '
                'until official proof of acceptance/publication of a thesis-derived paper '
                'in an SCU-approved peer-reviewed journal, or a faculty/university periodical.',
          ),
          const SizedBox(height: 14),
          Text(
            context.t('٢) أين تُرفع الأبحاث؟', '2) Where are papers submitted?'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t(
                      'بنك المعرفة المصري (EKB) ومنصة مجلات الجامعات (مثل jssa.journals.ekb.eg) '
                      'هما المسار الإلكتروني الشائع للتحكيم والرفع في الكليات الحكومية.',
                      'Egyptian Knowledge Bank (EKB) and university journal platforms '
                      '(e.g. jssa.journals.ekb.eg) are the common e-peer-review upload path.',
                    ),
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _open('https://www.ekb.eg/'),
                    style: _linkButtonStyle,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(context.t('فتح بنك المعرفة', 'Open EKB')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open('https://jssa.journals.ekb.eg'),
                    style: _linkButtonStyle,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      context.t(
                        'مثال: مجلة البحث العلمي في الآداب (EKB)',
                        'Example: JSSA Arts journal (EKB)',
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(
                      'https://sites.google.com/view/scientificpublishingunit/',
                    ),
                    style: _linkButtonStyle,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      context.t(
                        'وحدة النشر — كلية البنات عين شمس',
                        'Publishing unit — ASU Women’s College',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('٣) المؤتمرات', '3) Conferences'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'يُعتد غالباً بمؤتمر تنظمه جهة أكاديمية معتمدة مع تحكيم علمي قبل إدراج البحث '
              'في كتاب المؤتمر (Proceedings) — كبديل أو مكمل لمتطلبات بعض اللوائح. '
              'لا تعتمد مؤتمرات غير محكمة.',
              'Usually only conferences hosted by an accredited academic body with peer review '
              'before proceedings count — as alternative or complement under some bylaws. '
              'Avoid non-reviewed events.',
            ),
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 14),
          Text(
            context.t(
              '٤) متطلبات أخرى شائعة لمنح الدرجة',
              '4) Other common degree requirements',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final e in [
            (
              'تمهيدي / ساعات دراسية',
              'Preliminary courses',
              'اجتياز سنة تمهيدية أو دبلوم ممهد بنجاح وفق حد أدنى للتقدير.',
              'Pass preliminary year/diploma with the minimum grade set by the department.',
            ),
            (
              'لغة أجنبية',
              'Foreign language',
              'TOEFL محلي/دولي أو دورات مركز اللغات؛ أقسام آداب قد تشترط لغة ثانية.',
              'Local/intl TOEFL or language-centre courses; some Arts departments need a second language.',
            ),
            (
              'حاسب / تفكير نقدي / أخلاقيات',
              'ICT / critical thinking / ethics',
              'بعض الجامعات تشترط دورات حاسب أو مقررات تفكير نقدي وأخلاقيات بحث.',
              'Some universities require ICT courses or critical-thinking / research-ethics modules.',
            ),
            (
              'خلو من السرقات الأدبية',
              'Plagiarism clearance',
              'فحص تشابه بنسب المجلس الأعلى/الجامعة قبل المناقشة.',
              'Similarity check within SCU/university limits before the viva.',
            ),
          ])
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.check_circle_outline, color: acadegateInk(_brand)),
                title: Text(
                  context.t(e.$1, e.$2),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(context.t(e.$3, e.$4)),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'مصادر استرشاد (غير ملزمة): وحدة النشر بكلية البنات عين شمس، '
              'شروط الدراسات العليا العامة، لائحة قسمك.',
              'Guidance sources (non-binding): ASU Women’s College publishing unit, '
              'general postgraduate rules, your department bylaws.',
            ),
            style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _DegreeCard extends StatelessWidget {
  final Color brand;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;

  const _DegreeCard({
    required this.brand,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(titleAr, titleEn),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: acadegateInk(brand),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(context.t(bodyAr, bodyEn), style: const TextStyle(height: 1.45)),
          ],
        ),
      ),
    );
  }
}

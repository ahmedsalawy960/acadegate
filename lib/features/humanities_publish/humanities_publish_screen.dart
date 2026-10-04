import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../acadegate_publish/publish_hub_screen.dart';
import 'humanities_acceptance_letter_screen.dart';
import 'humanities_citation_guide_screen.dart';
import 'humanities_degree_requirements_screen.dart';
import 'humanities_journal_picker_screen.dart';
import 'humanities_publish_branding.dart';
import 'humanities_publish_storage.dart';
import 'humanities_yearbook_upload_guide_screen.dart';

/// مسار 11 — نشر أكاديمي إنساني (حوليات / مجلات عربية / مؤتمرات).
class HumanitiesPublishScreen extends StatefulWidget {
  final String? initialFacultyId;

  const HumanitiesPublishScreen({super.key, this.initialFacultyId});

  @override
  State<HumanitiesPublishScreen> createState() => _HumanitiesPublishScreenState();
}

class _HumanitiesPublishScreenState extends State<HumanitiesPublishScreen> {
  static const _brand = Color(HumanitiesPublishBranding.brand);
  String? _selectedOutletName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final d = await HumanitiesPublishStorage.instance.loadOrCreate(
      facultyId: widget.initialFacultyId,
    );
    if (widget.initialFacultyId != null &&
        widget.initialFacultyId!.isNotEmpty &&
        d.facultyId != widget.initialFacultyId) {
      d.facultyId = widget.initialFacultyId!;
      await HumanitiesPublishStorage.instance.save(d);
    }
    if (!mounted) return;
    setState(() {
      _selectedOutletName = d.outlet?.nameAr;
      _loading = false;
    });
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t(
            HumanitiesPublishBranding.titleAr,
            HumanitiesPublishBranding.titleEn,
          ),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                          context.t(
                            HumanitiesPublishBranding.taglineAr,
                            HumanitiesPublishBranding.taglineEn,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.t(
                            HumanitiesPublishBranding.integrityAr,
                            HumanitiesPublishBranding.integrityEn,
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: const Color(0xFFB7C3D6),
                            height: 1.4,
                          ),
                        ),
                        if (_selectedOutletName != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            context.t(
                              'المنفذ الحالي: $_selectedOutletName',
                              'Current outlet: $_selectedOutletName',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _brand,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _PathCard(
                  color: const Color(0xFFBF360C),
                  icon: Icons.school_outlined,
                  title: context.t(
                    '٠) متطلبات الماجستير والدكتوراه',
                    '0) Master’s & PhD requirements',
                  ),
                  subtitle: context.t(
                    'متى يُشترط النشر · EKB · مؤتمرات · لغة وتشابه',
                    'When publishing is required · EKB · conferences · language & similarity',
                  ),
                  onTap: () =>
                      _open(const HumanitiesDegreePublishRequirementsScreen()),
                ),
                _PathCard(
                  color: const Color(0xFF6A1B9A),
                  icon: Icons.library_books_outlined,
                  title: context.t(
                    '١) اختيار مجلة عربية محكمة / حولية',
                    '1) Pick Arabic peer-reviewed journal / annals',
                  ),
                  subtitle: context.t(
                    'تربية · آداب · حقوق · إعلام · EKB · دار المنظومة',
                    'Education · Arts · Law · Media · EKB · Mandumah',
                  ),
                  onTap: () => _open(
                    HumanitiesJournalPickerScreen(
                      initialFacultyId: widget.initialFacultyId,
                    ),
                  ),
                ),
                _PathCard(
                  color: const Color(0xFF1565C0),
                  icon: Icons.format_quote_outlined,
                  title: context.t(
                    '٢) شروط الاقتباس والتوثيق',
                    '2) Citation & referencing rules',
                  ),
                  subtitle: context.t(
                    'APA عربي · Chicago · توثيق قانوني + أمثلة قابلة للنسخ',
                    'APA Arabic · Chicago · legal citations + copyable examples',
                  ),
                  onTap: () => _open(const HumanitiesCitationGuideScreen()),
                ),
                _PathCard(
                  color: const Color(0xFF2E7D32),
                  icon: Icons.mail_outline,
                  title: context.t(
                    '٣) خطاب تقديم / قبول / مذكرة ترقية',
                    '3) Cover / acceptance / promotion letter',
                  ),
                  subtitle: context.t(
                    'قالب عربي جاهز للنسخ حسب المنفذ المختار',
                    'Arabic template ready to copy for the selected outlet',
                  ),
                  onTap: () => _open(const HumanitiesAcceptanceLetterScreen()),
                ),
                _PathCard(
                  color: const Color(0xFF00838F),
                  icon: Icons.cloud_upload_outlined,
                  title: context.t(
                    '٤) رفع على موقع الحولية',
                    '4) Upload to the yearbook site',
                  ),
                  subtitle: context.t(
                    'قائمة تحقق خطوة بخطوة + فتح رابط المنفذ',
                    'Step-by-step checklist + open the outlet link',
                  ),
                  onTap: () =>
                      _open(const HumanitiesYearbookUploadGuideScreen()),
                ),
                _PathCard(
                  color: _brand,
                  icon: Icons.edit_document,
                  title: context.t(
                    '٥) محرر المخطوطة (مسار النشر العام)',
                    '5) Manuscript editor (main publish path)',
                  ),
                  subtitle: context.t(
                    'تنسيق APA/IEEE وتصدير Word — مكمّل للمنفذ العربي',
                    'APA/IEEE formatting and Word export — complements the Arabic outlet',
                  ),
                  onTap: () => _open(const PublishHubScreen()),
                ),
              ],
            ),
    );
  }
}

class _PathCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PathCard({
    required this.color,
    required this.icon,
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
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: acadegateInk(color),
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../smart_labs/smart_labs_screen.dart';
import 'humanities_hub_screen.dart';

/// بوابة جمع البيانات: ميدان إنساني أو مختبر علمي — بدل توجيه الجميع للمعامل.
class FieldOrLabGatewayScreen extends StatelessWidget {
  const FieldOrLabGatewayScreen({super.key});

  static const _brand = Color(0xFF4E342E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('جمع البيانات', 'Data collection')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.t(
              'اختر نوع بحثك. الكليات الأدبية والتربوية والقانونية تستخدم الميدان '
              '(استبانة، مقابلات، أرشيف، نصوص) — وليس أجهزة المختبر.',
              'Choose your research type. Education, law, and arts use field methods '
              '(surveys, interviews, archives, texts) — not lab equipment.',
            ),
            style: const TextStyle(height: 1.55, color: Color(0xFFB7C3D6)),
          ),
          const SizedBox(height: 20),
          _ChoiceCard(
            color: const Color(0xFF5D4037),
            icon: Icons.menu_book_rounded,
            title: context.t(
              'بوابة البحث الإنساني والتربوي',
              'Humanities & education portal',
            ),
            subtitle: context.t(
              'تربية · حقوق · آداب · تجارة · إعلام — مسار كامل بدون معامل',
              'Education · Law · Arts · Business · Media — full path, no labs',
            ),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const HumanitiesHubScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            color: const Color(0xFF6A1B9A),
            icon: Icons.science_rounded,
            title: context.t(
              'مختبرات وتحليل عينات',
              'Labs & sample analysis',
            ),
            subtitle: context.t(
              'علوم · طب · هندسة · زراعة — حجز أجهزة وطلبات تحليل',
              'Science · Medicine · Engineering · Agriculture — equipment & samples',
            ),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SmartLabsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: acadegateInk(color),
                radius: 28,
                child: Icon(icon, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: acadegateInk(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        height: 1.4,
                        fontSize: 13,
                        color: const Color(0xFFB7C3D6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

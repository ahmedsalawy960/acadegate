import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'matchmaking_screen.dart';

/// شريط ترويجي للمطابقة الذكية — يُستخدم في قسم المشرفين ورحلة الاختيار.
class SmartMatchPromoBanner extends StatelessWidget {
  final bool compact;

  const SmartMatchPromoBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF283593);

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 12 : 16),
      color: brand.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: brand.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MatchmakingScreen(supervisorJourney: true),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: brand, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                        'المطابقة الذكية — اختر مشرفاً',
                        'Smart matching — choose a supervisor',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: brand,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(
                        'أكمل ملفك → نسبة توافق % → تواصل مع المشرف',
                        'Complete profile → match % → contact supervisor',
                      ),
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: Colors.grey[700],
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: brand),
            ],
          ),
        ),
      ),
    );
  }
}

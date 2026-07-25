import 'package:flutter/material.dart';

import '../config/app_environment.dart';
import '../locale/locale_extensions.dart';

/// شريط علوي يوضح أن النسخة تجريبية (لا تظهر في الإنتاج).
class BetaShell extends StatelessWidget {
  final Widget child;

  const BetaShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!AppEnvironment.isBeta) return child;

    return Column(
      children: [
        Material(
          color: const Color(0xFFE65100),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t(
                        AppEnvironment.betaLabelAr,
                        AppEnvironment.betaLabelEn,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

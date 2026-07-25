import 'package:flutter/material.dart';

import '../../core/locale/app_translate.dart';

class VivaCommitteeMember {
  final String id;
  final String nameAr;
  final String nameEn;
  final String roleAr;
  final String roleEn;
  final IconData icon;
  final Color color;

  String get displayName => appTr(nameAr, nameEn);
  String get displayRole => appTr(roleAr, roleEn);

  const VivaCommitteeMember({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.roleAr,
    required this.roleEn,
    required this.icon,
    required this.color,
  });
}

class VivaCommittee {
  VivaCommittee._();

  static const members = <VivaCommitteeMember>[
    VivaCommitteeMember(
      id: 'supervisor',
      nameAr: 'أ.د. نادية حسن',
      nameEn: 'Prof. Nadia Hassan',
      roleAr: 'المشرف الرئيسي',
      roleEn: 'Main supervisor',
      icon: Icons.school_outlined,
      color: Color(0xFF1565C0),
    ),
    VivaCommitteeMember(
      id: 'external',
      nameAr: 'أ.د. كريم منصور',
      nameEn: 'Prof. Karim Mansour',
      roleAr: 'مناقش خارجي',
      roleEn: 'External examiner',
      icon: Icons.balance_outlined,
      color: Color(0xFF6A1B9A),
    ),
    VivaCommitteeMember(
      id: 'methodology',
      nameAr: 'د. ليلى عمر',
      nameEn: 'Dr. Layla Omar',
      roleAr: 'خبيرة المنهجية',
      roleEn: 'Methodology expert',
      icon: Icons.analytics_outlined,
      color: Color(0xFF00695C),
    ),
  ];

  static VivaCommitteeMember byId(String id) =>
      members.firstWhere((m) => m.id == id);
}

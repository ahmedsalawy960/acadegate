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

/// أدوار اللجنة فقط — لا أسماء مشرفين مختلقة.
/// اسم المشرف يُستخدم فقط إن وُجد مطبوعاً على الرسالة.
class VivaCommittee {
  VivaCommittee._();

  static const memberIds = ['supervisor', 'external', 'methodology'];

  /// توافق مع الاستدعاءات القديمة — أدوار فقط بدون أسماء مختلقة.
  static List<VivaCommitteeMember> get members => lineup();

  static List<VivaCommitteeMember> lineup({String? supervisorFromThesis}) {
    final printed = supervisorFromThesis?.trim() ?? '';
    final supervisorName = printed.length >= 4;
    return [
      VivaCommitteeMember(
        id: 'supervisor',
        nameAr: supervisorName ? printed : 'المشرف الرئيسي',
        nameEn: supervisorName ? printed : 'Main supervisor',
        roleAr: supervisorName
            ? 'المشرف الرئيسي (من الرسالة)'
            : 'دور المشرف — بلا اسم مختلق',
        roleEn: supervisorName
            ? 'Main supervisor (from the thesis)'
            : 'Supervisor role — no invented name',
        icon: Icons.school_outlined,
        color: const Color(0xFF1565C0),
      ),
      const VivaCommitteeMember(
        id: 'external',
        nameAr: 'المناقش الخارجي',
        nameEn: 'External examiner',
        roleAr: 'يمتحن الأصالة والحدود',
        roleEn: 'Tests originality and limits',
        icon: Icons.balance_outlined,
        color: Color(0xFF6A1B9A),
      ),
      const VivaCommitteeMember(
        id: 'methodology',
        nameAr: 'خبير المنهجية',
        nameEn: 'Methodology examiner',
        roleAr: 'يمتحن التصميم والعينة والتحليل',
        roleEn: 'Tests design, sample, and analysis',
        icon: Icons.analytics_outlined,
        color: Color(0xFF00695C),
      ),
    ];
  }

  static VivaCommitteeMember byId(
    String id, {
    String? supervisorFromThesis,
  }) {
    final all = lineup(supervisorFromThesis: supervisorFromThesis);
    return all.firstWhere(
      (m) => m.id == id,
      orElse: () => all.first,
    );
  }
}

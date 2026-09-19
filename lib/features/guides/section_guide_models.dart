import 'package:flutter/material.dart';

/// محتوى دليل قسم للمستخدم المبتدئ (عربي / إنجليزي).
class SectionGuide {
  final String id;
  final String titleAr;
  final String titleEn;
  final String introAr;
  final String introEn;
  final List<SectionGuideStep> steps;
  final List<SectionGuideNote> notes;

  const SectionGuide({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.introAr,
    required this.introEn,
    required this.steps,
    this.notes = const [],
  });

  String title(bool en) => en ? titleEn : titleAr;
  String intro(bool en) => en ? introEn : introAr;
}

class SectionGuideStep {
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final IconData icon;

  const SectionGuideStep({
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    this.icon = Icons.check_circle_outline,
  });

  String title(bool en) => en ? titleEn : titleAr;
  String body(bool en) => en ? bodyEn : bodyAr;
}

class SectionGuideNote {
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;

  const SectionGuideNote({
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
  });

  String title(bool en) => en ? titleEn : titleAr;
  String body(bool en) => en ? bodyEn : bodyAr;
}

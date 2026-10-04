/// كليات ومسارات البحث الإنساني / التربوي / القانوني (مقابل المسار المعملي).
class HumanitiesFaculties {
  HumanitiesFaculties._();

  /// كليات يُفضَّل لها بوابة البحث الإنساني بدل المختبرات كمسار افتراضي.
  static const Set<String> facultyIds = {
    'Education',
    'Law',
    'Arts',
    'Business',
    'MassCommunication',
    'Tourism',
    'PhysicalEducation',
    'FineArts',
    'ProfessionalStudies',
  };

  static bool isHumanities(String? facultyId) {
    final id = facultyId?.trim() ?? '';
    if (id.isEmpty) return false;
    return facultyIds.contains(id);
  }
}

/// مسار داخل البوابة (أدق من الكلية وحدها للتجربة والإرشاد).
enum HumanitiesTrack {
  education,
  law,
  arts,
  business,
  media,
  other,
}

extension HumanitiesTrackX on HumanitiesTrack {
  String get id => name;

  String get facultyId => switch (this) {
        HumanitiesTrack.education => 'Education',
        HumanitiesTrack.law => 'Law',
        HumanitiesTrack.arts => 'Arts',
        HumanitiesTrack.business => 'Business',
        HumanitiesTrack.media => 'MassCommunication',
        HumanitiesTrack.other => 'Arts',
      };

  String titleAr() => switch (this) {
        HumanitiesTrack.education => 'تربية',
        HumanitiesTrack.law => 'حقوق / قانون',
        HumanitiesTrack.arts => 'آداب وإنسانيات',
        HumanitiesTrack.business => 'تجارة وإدارة',
        HumanitiesTrack.media => 'إعلام',
        HumanitiesTrack.other => 'أخرى (إنساني)',
      };

  String titleEn() => switch (this) {
        HumanitiesTrack.education => 'Education',
        HumanitiesTrack.law => 'Law',
        HumanitiesTrack.arts => 'Arts & humanities',
        HumanitiesTrack.business => 'Business',
        HumanitiesTrack.media => 'Media',
        HumanitiesTrack.other => 'Other (humanities)',
      };

  String blurbAr() => switch (this) {
        HumanitiesTrack.education =>
          'خطط بحث · استبانات · صدق وثبات · إحصاء تربوي · مناقشة',
        HumanitiesTrack.law =>
          'خطة قانونية · تشريع وأحكام · أسانيد · صياغة أكاديمية',
        HumanitiesTrack.arts =>
          'موضوع · أدبيات · أرشيف/نصوص · نقد · تدقيق لغوي',
        HumanitiesTrack.business =>
          'مقترح · استبانة إدارية · تحليل كمي · كتابة فصول',
        HumanitiesTrack.media =>
          'إطار نظري · تحليل مضمون · مقابلات · تحرير',
        HumanitiesTrack.other =>
          'مسار إنساني عام: موضوع · مشرف · ميدان · كتابة · مناقشة',
      };

  String blurbEn() => switch (this) {
        HumanitiesTrack.education =>
          'Proposals · surveys · validity · education stats · viva',
        HumanitiesTrack.law =>
          'Legal proposal · statutes & cases · authorities · academic drafting',
        HumanitiesTrack.arts =>
          'Topic · literature · archive/texts · critique · language polish',
        HumanitiesTrack.business =>
          'Proposal · management survey · quantitative analysis · chapters',
        HumanitiesTrack.media =>
          'Theory · content analysis · interviews · editing',
        HumanitiesTrack.other =>
          'General humanities path: topic · supervisor · field · writing · viva',
      };

  static HumanitiesTrack? fromId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final t in HumanitiesTrack.values) {
      if (t.id == raw) return t;
    }
    return null;
  }

  static HumanitiesTrack fromFacultyId(String? facultyId) {
    return switch (facultyId?.trim()) {
      'Education' || 'PhysicalEducation' => HumanitiesTrack.education,
      'Law' => HumanitiesTrack.law,
      'Arts' || 'FineArts' || 'Tourism' => HumanitiesTrack.arts,
      'Business' => HumanitiesTrack.business,
      'MassCommunication' => HumanitiesTrack.media,
      'ProfessionalStudies' => HumanitiesTrack.other,
      _ => HumanitiesTrack.education,
    };
  }
}

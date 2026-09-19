import '../../core/locale/app_translate.dart';
import 'user_role.dart';

/// Org / facility credentials for lab managers and other service providers.
/// Filling fields does not auto-grant Managed Verified.
class ProviderOrgProfile {
  const ProviderOrgProfile({
    this.orgName = '',
    this.affiliation = '',
    this.jobTitle = '',
    this.licenseNo = '',
    this.taxOrNationalId = '',
    this.officialEmail = '',
    this.officialPhone = '',
    this.website = '',
    this.city = '',
    this.servicesNote = '',
    this.proofUrl = '',
  });

  final String orgName;
  final String affiliation;
  final String jobTitle;
  final String licenseNo;
  final String taxOrNationalId;
  final String officialEmail;
  final String officialPhone;
  final String website;
  final String city;
  final String servicesNote;
  final String proofUrl;

  bool get hasCoreIdentity =>
      orgName.trim().length >= 3 &&
      (licenseNo.trim().isNotEmpty ||
          taxOrNationalId.trim().isNotEmpty ||
          affiliation.trim().length >= 3);

  factory ProviderOrgProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProviderOrgProfile();
    return ProviderOrgProfile(
      orgName: map['orgName']?.toString() ?? '',
      affiliation: map['affiliation']?.toString() ?? '',
      jobTitle: map['jobTitle']?.toString() ?? '',
      licenseNo: map['licenseNo']?.toString() ?? '',
      taxOrNationalId: map['taxOrNationalId']?.toString() ?? '',
      officialEmail: map['officialEmail']?.toString() ?? '',
      officialPhone: map['officialPhone']?.toString() ?? '',
      website: map['website']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      servicesNote: map['servicesNote']?.toString() ?? '',
      proofUrl: map['proofUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'orgName': orgName.trim(),
        'affiliation': affiliation.trim(),
        'jobTitle': jobTitle.trim(),
        'licenseNo': licenseNo.trim(),
        'taxOrNationalId': taxOrNationalId.trim(),
        'officialEmail': officialEmail.trim(),
        'officialPhone': officialPhone.trim(),
        'website': website.trim(),
        'city': city.trim(),
        'servicesNote': servicesNote.trim(),
        'proofUrl': proofUrl.trim(),
      };

  String? validateForSave() {
    if (orgName.trim().length < 3) {
      return appTr(
        'أدخل اسم المنشأة / الجهة (٣ أحرف على الأقل)',
        'Enter the organization / facility name (at least 3 characters)',
      );
    }
    if (licenseNo.trim().isEmpty &&
        taxOrNationalId.trim().isEmpty &&
        affiliation.trim().length < 3) {
      return appTr(
        'أدخل ترخيصاً أو رقماً تعريفياً أو جهة الانتساب',
        'Enter a license, ID number, or affiliation',
      );
    }
    final email = officialEmail.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      return appTr('البريد الرسمي غير صالح', 'Official email is invalid');
    }
    return null;
  }

  static String sectionTitle(String role, {required bool isAr}) {
    switch (role) {
      case UserRole.labManager:
        return isAr ? 'بيانات المختبر / الجهة' : 'Lab / facility details';
      case UserRole.supervisor:
        return isAr ? 'بيانات المشرف المهنية' : 'Supervisor professional details';
      case UserRole.writer:
        return isAr ? 'بيانات مقدّم خدمة الكتابة' : 'Writing provider details';
      case UserRole.ideaPublisher:
        return isAr ? 'بيانات ناشر الأفكار' : 'Idea publisher details';
      default:
        return isAr ? 'بيانات مقدّم الخدمة' : 'Service provider details';
    }
  }

  static String orgLabel(String role, {required bool isAr}) {
    switch (role) {
      case UserRole.labManager:
        return isAr ? 'اسم المختبر / المركز *' : 'Lab / center name *';
      case UserRole.supervisor:
        return isAr ? 'الجهة / القسم *' : 'Institution / department *';
      case UserRole.writer:
        return isAr ? 'الاسم التجاري / المكتب *' : 'Trade name / office *';
      default:
        return isAr ? 'اسم الجهة / المنشأة *' : 'Organization name *';
    }
  }
}

import '../../core/locale/app_translate.dart';

/// Business entity fields for merchant accounts (not auto-Verified).
class MerchantBusinessProfile {
  const MerchantBusinessProfile({
    this.legalName = '',
    this.tradeName = '',
    this.jobTitle = '',
    this.commercialRegisterNo = '',
    this.taxId = '',
    this.officialEmail = '',
    this.officialPhone = '',
    this.website = '',
    this.city = '',
    this.address = '',
    this.proofUrl = '',
  });

  final String legalName;
  final String tradeName;
  final String jobTitle;
  final String commercialRegisterNo;
  final String taxId;
  final String officialEmail;
  final String officialPhone;
  final String website;
  final String city;
  final String address;
  final String proofUrl;

  bool get hasCoreIdentity =>
      legalName.trim().length >= 3 &&
      (commercialRegisterNo.trim().isNotEmpty || taxId.trim().isNotEmpty);

  bool get isSubstantiallyComplete =>
      hasCoreIdentity &&
      officialEmail.contains('@') &&
      officialPhone.trim().length >= 8;

  factory MerchantBusinessProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MerchantBusinessProfile();
    return MerchantBusinessProfile(
      legalName: map['legalName']?.toString() ?? '',
      tradeName: map['tradeName']?.toString() ?? '',
      jobTitle: map['jobTitle']?.toString() ?? '',
      commercialRegisterNo: map['commercialRegisterNo']?.toString() ?? '',
      taxId: map['taxId']?.toString() ?? '',
      officialEmail: map['officialEmail']?.toString() ?? '',
      officialPhone: map['officialPhone']?.toString() ?? '',
      website: map['website']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      proofUrl: map['proofUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'legalName': legalName.trim(),
        'tradeName': tradeName.trim(),
        'jobTitle': jobTitle.trim(),
        'commercialRegisterNo': commercialRegisterNo.trim(),
        'taxId': taxId.trim(),
        'officialEmail': officialEmail.trim(),
        'officialPhone': officialPhone.trim(),
        'website': website.trim(),
        'city': city.trim(),
        'address': address.trim(),
        'proofUrl': proofUrl.trim(),
      };

  String? validateForSave() {
    if (legalName.trim().length < 3) {
      return appTr(
        'أدخل الاسم القانوني للمنشأة (٣ أحرف على الأقل)',
        'Enter the legal entity name (at least 3 characters)',
      );
    }
    if (commercialRegisterNo.trim().isEmpty && taxId.trim().isEmpty) {
      return appTr(
        'أدخل السجل التجاري أو الرقم الضريبي (أو كليهما)',
        'Enter commercial register or tax ID (or both)',
      );
    }
    final email = officialEmail.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      return appTr('بريد المنشأة غير صالح', 'Official email is invalid');
    }
    return null;
  }
}

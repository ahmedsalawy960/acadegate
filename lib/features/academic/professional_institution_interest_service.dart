import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'professional_institutions_catalog.dart';

/// Stores user interest / partnership-era applications for professional programs.
class ProfessionalInstitutionInterestService {
  ProfessionalInstitutionInterestService._();

  static final ProfessionalInstitutionInterestService instance =
      ProfessionalInstitutionInterestService._();

  final _db = FirebaseFirestore.instance;
  static const collection = 'professional_program_interests';

  /// Saves an interest or in-app application intent.
  Future<void> submitInterest({
    required ProfessionalInstitution institution,
    required String programAbbr,
    required String fullName,
    required String phone,
    String notes = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول لتسجيل الاهتمام أو التقديم');
    }

    await _db.collection(collection).add({
      'userId': user.uid,
      'userEmail': user.email ?? '',
      'institutionId': institution.id,
      'institutionNameAr': institution.nameAr,
      'institutionNameEn': institution.nameEn,
      'programAbbr': programAbbr,
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'notes': notes.trim(),
      'partnershipStatus': institution.partnershipStatus.name,
      'isPartneredApplication': institution.isPartnered,
      'status': institution.isPartnered ? 'submitted' : 'interest_pending_partnership',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

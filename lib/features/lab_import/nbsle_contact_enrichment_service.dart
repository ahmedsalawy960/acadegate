import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../academic/academic_models.dart';
import 'nbsle_device_detail.dart';

/// Pulls NBSLE device-page contacts into a lab (on open or during sync).
class NbsleContactEnrichmentService {
  NbsleContactEnrichmentService._();

  static final NbsleContactEnrichmentService instance =
      NbsleContactEnrichmentService._();

  final _db = FirebaseFirestore.instance;

  Future<AcademicLab> enrichIfNeeded(AcademicLab lab) async {
    if (!lab.isNbsleImport) return lab;
    // Need the full role list (Lab / Faculty / University), not only one flattened contact.
    final hasRoleBreakdown = lab.contacts
            .where(
              (c) =>
                  c.role.toLowerCase().contains('lab') ||
                  c.role.toLowerCase().contains('faculty') ||
                  c.role.toLowerCase().contains('university'),
            )
            .length >=
        2;
    if (hasRoleBreakdown) return lab;
    final url = lab.sourceUrl.trim();
    if (url.isEmpty || !url.contains('/device/')) return lab;
    if (kIsWeb) return lab;

    try {
      final detail = await NbsleDeviceDetailClient.instance.fetch(url);
      if (detail.contacts.isEmpty &&
          detail.bestEmail.isEmpty &&
          detail.bestPhone.isEmpty) {
        return lab;
      }

      final contacts = detail.contacts
          .map(
            (c) => LabContactPerson(
              role: c.role,
              name: c.name,
              email: c.email,
              phone: NbsleContactPerson.cleanPhone(c.phone),
            ),
          )
          .where((c) => c.name.isNotEmpty || c.hasUsableContact)
          .toList();

      final email = lab.contactEmail.contains('@')
          ? lab.contactEmail
          : detail.bestEmail;
      final phone = lab.contactPhone.trim().length >= 8
          ? lab.contactPhone
          : detail.bestPhone;
      final name = lab.contactName.trim().isNotEmpty
          ? lab.contactName
          : detail.bestName;

      if (lab.id != null && lab.id!.isNotEmpty) {
        await _db.collection('labs').doc(lab.id).set({
          if (email.contains('@')) 'contactEmail': email,
          if (phone.length >= 8) 'contactPhone': phone,
          if (name.isNotEmpty) 'contactName': name,
          if (contacts.isNotEmpty)
            'contacts': contacts.map((c) => c.toMap()).toList(),
          'nbsleContactsEnrichedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return AcademicLab(
        id: lab.id,
        name: lab.name,
        location: lab.location,
        equipment: lab.equipment,
        tags: lab.tags,
        city: lab.city,
        university: lab.university,
        ratingAvg: lab.ratingAvg,
        ratingsCount: lab.ratingsCount,
        defaultWaitDays: lab.defaultWaitDays,
        equipmentList: lab.equipmentList,
        ownerId: lab.ownerId,
        approvalStatus: lab.approvalStatus,
        labType: lab.labType,
        category: lab.category,
        facultyId: lab.facultyId,
        facultyNameAr: lab.facultyNameAr,
        description: lab.description,
        acceptsExternalSamples: lab.acceptsExternalSamples,
        contactEmail: email,
        contactPhone: phone,
        contactName: name,
        contacts: contacts,
        sampleServices: lab.sampleServices,
        importSource: lab.importSource,
        sourceUrl: lab.sourceUrl,
        nbsleLabId: lab.nbsleLabId,
        equipmentCountHint: lab.equipmentCountHint,
      );
    } catch (e) {
      debugPrint('NBSLE contact enrich failed: $e');
      return lab;
    }
  }
}

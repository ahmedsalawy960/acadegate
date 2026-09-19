import 'package:acadegate/core/directory/profile_claim_service.dart';
import 'package:acadegate/features/store/add_product_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileClaimEvidence.validateForSubmit', () {
    ProfileClaimEvidence base({String proofUrl = 'https://example.com/p.pdf'}) {
      return ProfileClaimEvidence(
        legalName: 'شركة الاختبار للتجارة',
        jobTitle: 'مدير المبيعات',
        officialEmail: 'sales@example.com',
        proofUrl: proofUrl,
      );
    }

    test('accepts complete evidence with proof', () {
      expect(ProfileClaimEvidence.validateForSubmit(base()), isNull);
    });

    test('rejects missing proof', () {
      final err = ProfileClaimEvidence.validateForSubmit(base(proofUrl: ''));
      expect(err, isNotNull);
      expect(err!.toLowerCase(), anyOf(contains('proof'), contains('إثبات')));
    });

    test('rejects short legal name', () {
      final err = ProfileClaimEvidence.validateForSubmit(
        const ProfileClaimEvidence(
          legalName: 'ab',
          jobTitle: 'Manager',
          officialEmail: 'a@b.com',
          proofUrl: 'https://x/y',
        ),
      );
      expect(err, isNotNull);
    });

    test('rejects invalid email', () {
      final err = ProfileClaimEvidence.validateForSubmit(
        const ProfileClaimEvidence(
          legalName: 'شركة الاختبار',
          jobTitle: 'Manager',
          officialEmail: 'not-an-email',
          proofUrl: 'https://x/y',
        ),
      );
      expect(err, isNotNull);
    });
  });

  group('AddProductScreen supplier linkage', () {
    test('accepts supplierId for managed profile products', () {
      const screen = AddProductScreen(
        categoryTitle: 'مستلزمات عامة',
        supplierId: 'sup_chem_01',
        storeNameHint: 'Test Supplier',
        contactHint: '0100',
      );
      expect(screen.supplierId, 'sup_chem_01');
      expect(screen.storeNameHint, 'Test Supplier');
      expect(screen.contactHint, '0100');
    });
  });
}

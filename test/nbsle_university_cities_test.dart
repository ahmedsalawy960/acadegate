import 'package:acadegate/features/lab_import/nbsle_university_cities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('الزقازيق and الشرقية are the same Sharqia area', () {
    expect(NbsleUniversityCities.canonicalCity('الزقازيق'), 'الشرقية');
    expect(NbsleUniversityCities.canonicalCity('الشرقية'), 'الشرقية');
    expect(NbsleUniversityCities.canonicalCity('Zagazig'), 'الشرقية');
    expect(
      NbsleUniversityCities.cityMatches('الزقازيق', 'الشرقية'),
      isTrue,
    );
    expect(
      NbsleUniversityCities.browseCities,
      contains('الشرقية'),
    );
    expect(
      NbsleUniversityCities.browseCities,
      isNot(contains('الزقازيق')),
    );
  });
}

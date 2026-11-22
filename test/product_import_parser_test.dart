import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:acadegate/features/store/bulk/merchant_product_bulk_service.dart';
import 'package:acadegate/features/store/bulk/product_import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

ProductImportParseResult _parseCsv(String csv) => ProductImportParser.parseBytes(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileName: 'products.csv',
    );

void main() {
  test('template parses with no errors', () {
    final result = _parseCsv(ProductImportParser.templateCsv());
    expect(result.rows, hasLength(2));
    expect(result.invalidCount, 0);
    expect(result.rows.first.category, 'مستلزمات ومواد كيميائية وكواشف');
    expect(result.rows.first.description, 'Analytical grade, for HPLC');
    expect(result.rows.last.fastShipping, isTrue);
    expect(result.rows.last.imageUrl, 'https://example.com/pipette.jpg');
  });

  test('sample chemicals supplier sheet imports cleanly', () {
    final bytes = File('seed_data/csv/sample_chemicals_supplier_products.csv')
        .readAsBytesSync();
    final result = ProductImportParser.parseBytes(
      bytes: bytes,
      fileName: 'sample_chemicals_supplier_products.csv',
    );
    expect(result.rows, hasLength(42));
    expect(result.invalidCount, 0);
    expect(result.rows.where((r) => r.warnings.isNotEmpty), isEmpty);
    expect(result.unknownColumns, isEmpty);
  });

  test('Arabic headers, BOM, semicolons and quoted newlines', () {
    final result = _parseCsv(
      '\uFEFFالاسم;السعر;الوصف;متوفر\n'
      'كأس زجاجي;١٢٥٠;"سطر أول\nسطر ثاني";لا\n',
    );
    final row = result.rows.single;
    expect(row.price, 1250);
    expect(row.description, 'سطر أول\nسطر ثاني');
    expect(row.inStock, isFalse);
    expect(row.category, isNull);
  });

  test('row errors and warnings are reported per row', () {
    final result = _parseCsv(
      'name,price,category,sku\n'
      ',100,,A1\n'
      'Beaker,abc,,A2\n'
      'Flask,50,unknown section,A2\n',
    );
    expect(result.invalidCount, 2);
    expect(result.rows[0].rowNumber, 2);
    expect(result.rows[1].errors.single, contains('abc'));
    expect(result.rows[2].isValid, isTrue);
    expect(result.rows[2].warnings, hasLength(2));
  });

  test('missing price column is rejected', () {
    expect(() => _parseCsv('name,sku\nA,1\n'), throwsFormatException);
  });

  test('price formats', () {
    expect(ProductImportParser.parsePrice('1,250'), 1250);
    expect(ProductImportParser.parsePrice('12,5'), 12.5);
    expect(ProductImportParser.parsePrice('1.250,75'), 1250.75);
    expect(ProductImportParser.parsePrice('450 EGP'), 450);
    expect(ProductImportParser.parsePrice('ج.م'), isNull);
  });

  test('bulk price adjustment', () {
    expect(MerchantProductBulkService.newPrice(200, BulkPriceMode.percent, 10), 220);
    expect(MerchantProductBulkService.newPrice(200, BulkPriceMode.add, -250), 0);
    expect(MerchantProductBulkService.newPrice(99.999, BulkPriceMode.setExact, 15.555), 15.56);
  });

  test('reseller margin', () {
    expect(MerchantProductBulkService.applyMarkup(278, 0), 278);
    expect(MerchantProductBulkService.applyMarkup(278, 15), 320);
    expect(MerchantProductBulkService.applyMarkup(1400, 12.5), 1575);
    expect(MerchantProductBulkService.applyMarkup(99.5, 0), 99.5);
  });

  test('store URL normalization', () {
    expect(MerchantProductBulkService.normalizeStoreUrl('shop.com/shop/'), 'https://shop.com');
    expect(MerchantProductBulkService.normalizeStoreUrl('not a url'), isNull);
  });
}

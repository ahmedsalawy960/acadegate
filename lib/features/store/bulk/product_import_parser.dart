import 'dart:convert';
import 'dart:typed_data';

import '../../../core/locale/app_translate.dart';
import '../../data_analysis/statistical_table_file_parser.dart';
import '../store_categories.dart';

/// One product parsed from a supplier's CSV / Excel sheet.
class ProductImportRow {
  /// 1-based row number in the source sheet (header is row 1).
  final int rowNumber;
  final String name;
  final num? price;
  /// Resolved [StoreCategory.title], or null to use the screen default.
  final String? category;
  final String description;
  final String sku;
  final String brand;
  final String unit;
  final String grade;
  final String originCountry;
  final String city;
  final bool inStock;
  final bool fastShipping;
  final String? imageUrl;
  final List<String> errors;
  final List<String> warnings;

  const ProductImportRow({
    required this.rowNumber,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    required this.sku,
    required this.brand,
    required this.unit,
    required this.grade,
    required this.originCountry,
    required this.city,
    required this.inStock,
    required this.fastShipping,
    required this.imageUrl,
    required this.errors,
    required this.warnings,
  });

  bool get isValid => errors.isEmpty;
}

class ProductImportParseResult {
  final List<ProductImportRow> rows;
  final List<String> unknownColumns;

  const ProductImportParseResult({
    required this.rows,
    required this.unknownColumns,
  });

  int get validCount => rows.where((r) => r.isValid).length;
  int get invalidCount => rows.length - validCount;
}

class ProductImportParser {
  ProductImportParser._();

  static const supportedExtensions = ['csv', 'txt', 'xlsx'];

  static const _headerAliases = <String, List<String>>{
    'name': ['name', 'product', 'product_name', 'title', 'الاسم', 'اسم', 'اسم_المنتج', 'المنتج'],
    'price': ['price', 'unit_price', 'السعر', 'سعر'],
    'category': ['category', 'section', 'القسم', 'قسم', 'التصنيف', 'تصنيف'],
    'description': ['description', 'details', 'الوصف', 'وصف', 'التفاصيل'],
    'sku': ['sku', 'code', 'item_code', 'الكود', 'كود', 'رمز', 'رمز_المنتج'],
    'brand': ['brand', 'manufacturer', 'الماركة', 'ماركة', 'العلامة', 'العلامة_التجارية', 'الشركة_المصنعة'],
    'unit': ['unit', 'pack', 'pack_size', 'الوحدة', 'وحدة', 'العبوة'],
    'grade': ['grade', 'purity', 'الدرجة', 'النقاء'],
    'origin': ['origin', 'origin_country', 'country', 'بلد_المنشأ', 'المنشأ', 'بلد'],
    'city': ['city', 'المدينة', 'مدينة'],
    'instock': ['in_stock', 'instock', 'stock', 'available', 'متوفر', 'التوفر', 'متاح'],
    'fastshipping': ['fast_shipping', 'fastshipping', 'express', 'شحن_سريع'],
    'imageurl': ['image', 'image_url', 'imageurl', 'photo', 'صورة', 'الصورة', 'رابط_الصورة'],
  };

  /// Header row + two example rows. Category accepts the Arabic section title
  /// or its id (e.g. `chemicals`).
  static String templateCsv() {
    final buffer = StringBuffer()
      ..writeln(
        'name,price,category,description,sku,brand,unit,grade,origin_country,city,in_stock,fast_shipping,image_url',
      )
      ..writeln(
        'Ethanol absolute 99.9%,450,chemicals,"Analytical grade, for HPLC",ETH-2500,Merck,2.5L,AR,Germany,Cairo,yes,no,',
      )
      ..writeln(
        'ماصة دقيقة 100-1000 ميكرولتر,1850,مستهلكات وأدوات مختبر,ماصة قابلة للتعقيم,PIP-1000,Dragon Lab,1 pc,,China,Giza,نعم,نعم,https://example.com/pipette.jpg',
      );
    return buffer.toString();
  }

  static ProductImportParseResult parseBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xls')) {
      throw FormatException(
        appTr(
          'صيغة xls القديمة غير مدعومة — احفظ الملف كـ xlsx أو CSV UTF-8',
          'Legacy .xls is not supported — save as .xlsx or CSV UTF-8',
        ),
      );
    }
    final grid = lower.endsWith('.xlsx')
        ? StatisticalTableFileParser.xlsxFirstSheetGrid(bytes)
        : _csvGrid(_decodeText(bytes));
    return parseGrid(grid);
  }

  static ProductImportParseResult parseGrid(List<List<String>> grid) {
    if (grid.isEmpty) {
      throw FormatException(appTr('الملف فارغ', 'The file is empty'));
    }

    final headers = grid.first;
    final columns = <String, int>{};
    final unknown = <String>[];
    for (var i = 0; i < headers.length; i++) {
      final key = _canonicalHeader(headers[i]);
      if (key == null) {
        if (headers[i].trim().isNotEmpty) unknown.add(headers[i].trim());
        continue;
      }
      columns.putIfAbsent(key, () => i);
    }

    if (!columns.containsKey('name') || !columns.containsKey('price')) {
      throw FormatException(
        appTr(
          'يجب أن يحتوي الصف الأول على عمودي الاسم (name) والسعر (price) على الأقل',
          'The header row must include at least name and price columns',
        ),
      );
    }

    final rows = <ProductImportRow>[];
    final seenSkus = <String, int>{};
    for (var r = 1; r < grid.length; r++) {
      final cells = grid[r];
      if (cells.every((c) => c.trim().isEmpty)) continue;
      final row = _rowFromCells(r + 1, cells, columns, seenSkus);
      rows.add(row);
    }

    if (rows.isEmpty) {
      throw FormatException(appTr('لا توجد صفوف منتجات', 'No product rows found'));
    }
    return ProductImportParseResult(rows: rows, unknownColumns: unknown);
  }

  static ProductImportRow _rowFromCells(
    int rowNumber,
    List<String> cells,
    Map<String, int> columns,
    Map<String, int> seenSkus,
  ) {
    String cell(String key) {
      final i = columns[key];
      if (i == null || i >= cells.length) return '';
      return cells[i].trim();
    }

    final errors = <String>[];
    final warnings = <String>[];

    final name = cell('name');
    if (name.isEmpty) {
      errors.add(appTr('الاسم مطلوب', 'Name is required'));
    } else if (name.length > 300) {
      errors.add(appTr('الاسم أطول من 300 حرف', 'Name exceeds 300 characters'));
    }

    final rawPrice = cell('price');
    final price = parsePrice(rawPrice);
    if (rawPrice.isEmpty) {
      errors.add(appTr('السعر مطلوب', 'Price is required'));
    } else if (price == null) {
      errors.add(appTr('سعر غير صالح: $rawPrice', 'Invalid price: $rawPrice'));
    } else if (price < 0) {
      errors.add(appTr('السعر لا يمكن أن يكون سالباً', 'Price cannot be negative'));
    }

    String? category;
    final rawCategory = cell('category');
    if (rawCategory.isNotEmpty) {
      category = resolveCategoryTitle(rawCategory);
      if (category == null) {
        warnings.add(
          appTr(
            'قسم غير معروف «$rawCategory» — سيُستخدم القسم الافتراضي',
            'Unknown category "$rawCategory" — default will be used',
          ),
        );
      }
    }

    final sku = cell('sku');
    if (sku.isNotEmpty) {
      final key = sku.toLowerCase();
      final firstRow = seenSkus[key];
      if (firstRow != null) {
        warnings.add(
          appTr(
            'SKU مكرر مع الصف $firstRow',
            'Duplicate SKU with row $firstRow',
          ),
        );
      } else {
        seenSkus[key] = rowNumber;
      }
    }

    var imageUrl = cell('imageurl');
    if (imageUrl.isNotEmpty) {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        warnings.add(
          appTr(
            'رابط الصورة غير صالح وتم تجاهله',
            'Invalid image URL was ignored',
          ),
        );
        imageUrl = '';
      }
    }

    return ProductImportRow(
      rowNumber: rowNumber,
      name: name,
      price: price,
      category: category,
      description: cell('description'),
      sku: sku,
      brand: cell('brand'),
      unit: cell('unit'),
      grade: cell('grade'),
      originCountry: cell('origin'),
      city: cell('city'),
      inStock: _parseBool(cell('instock'), fallback: true),
      fastShipping: _parseBool(cell('fastshipping'), fallback: false),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Accepts category id, current Arabic title, or a legacy alias.
  static String? resolveCategoryTitle(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final byId = storeCategoryById(value.toLowerCase());
    if (byId != null) return byId.title;
    return storeCategoryByTitle(value)?.title;
  }

  /// Parses prices like `1,250`, `1.250,50`, `١٢٥٠`, `450 EGP`.
  static num? parsePrice(String raw) {
    var v = _westernDigits(raw)
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll(RegExp(r'[^0-9.,\-]'), '');
    if (v.isEmpty) return null;
    final hasComma = v.contains(',');
    final hasDot = v.contains('.');
    if (hasComma && hasDot) {
      // Whichever separator comes last is the decimal mark.
      if (v.lastIndexOf(',') > v.lastIndexOf('.')) {
        v = v.replaceAll('.', '').replaceAll(',', '.');
      } else {
        v = v.replaceAll(',', '');
      }
    } else if (hasComma) {
      final parts = v.split(',');
      final looksLikeThousands =
          parts.length > 1 && parts.skip(1).every((p) => p.length == 3);
      v = looksLikeThousands ? parts.join() : v.replaceAll(',', '.');
    }
    return num.tryParse(v);
  }

  static bool _parseBool(String raw, {required bool fallback}) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return fallback;
    const truthy = ['1', 'true', 'yes', 'y', 'نعم', 'متوفر', 'متاح', 'صح'];
    const falsy = ['0', 'false', 'no', 'n', 'لا', 'غير متوفر', 'غير متاح', 'نفذ'];
    if (truthy.contains(v)) return true;
    if (falsy.contains(v)) return false;
    return fallback;
  }

  static String? _canonicalHeader(String header) {
    final normalized = header
        .replaceAll('\uFEFF', '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-]+'), '_');
    for (final entry in _headerAliases.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return null;
  }

  static String _westernDigits(String s) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final out = StringBuffer();
    for (final ch in s.split('')) {
      final e = eastern.indexOf(ch);
      final p = persian.indexOf(ch);
      out.write(e >= 0 ? '$e' : (p >= 0 ? '$p' : ch));
    }
    return out.toString();
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // Excel "CSV (Comma delimited)" on Arabic Windows saves as cp1256.
      throw FormatException(
        appTr(
          'ترميز الملف غير مدعوم — من Excel اختر «CSV UTF-8» عند الحفظ أو ارفع ملف xlsx مباشرة',
          'Unsupported file encoding — save as "CSV UTF-8" in Excel or upload the .xlsx directly',
        ),
      );
    }
  }

  /// RFC 4180 style: quoted fields may contain delimiters, quotes and newlines.
  static List<List<String>> _csvGrid(String content) {
    final text = content.replaceFirst('\uFEFF', '');
    final firstLineEnd = text.indexOf(RegExp(r'[\r\n]'));
    final header = firstLineEnd < 0 ? text : text.substring(0, firstLineEnd);
    final delimiter = header.contains('\t')
        ? '\t'
        : (header.split(';').length > header.split(',').length ? ';' : ',');

    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == delimiter) {
        endField();
      } else if (ch == '\r') {
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      } else if (ch == '\n') {
        endRow();
      } else {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }
}

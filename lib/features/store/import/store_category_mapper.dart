import '../store_categories.dart';
import 'egypt_store_suppliers_catalog.dart';
import 'woocommerce_store_api_client.dart';

/// Maps WooCommerce category names / product text → AcadeGate store titles.
///
/// Keyword hints may refine placement **only within** the supplier's
/// [EgyptStoreSupplier.categoryIds]. Cross-section dumping is blocked.
String mapImportedProductCategory({
  required WooImportedProduct product,
  required String fallbackTitle,
  String? supplierId,
}) {
  final fallback = storeCategoryLegacyAliases[fallbackTitle.trim()] ??
      fallbackTitle.trim();
  final allowed = _allowedTitlesForSupplier(supplierId, fallback);
  final mapped = _mapByKeywords(product);

  if (allowed.isEmpty) {
    return mapped.isNotEmpty ? mapped : fallback;
  }
  if (mapped.isNotEmpty && allowed.contains(mapped)) {
    return mapped;
  }
  if (fallback.isNotEmpty && allowed.contains(fallback)) {
    return fallback;
  }
  return allowed.first;
}

Set<String> _allowedTitlesForSupplier(String? supplierId, String fallbackTitle) {
  final titles = <String>{};
  if (fallbackTitle.trim().isNotEmpty) {
    titles.add(fallbackTitle.trim());
  }
  final supplier = supplierId == null || supplierId.isEmpty
      ? null
      : egyptStoreSupplierById(supplierId);
  if (supplier != null) {
    for (final id in supplier.categoryIds) {
      final title = storeCategoryById(id)?.title;
      if (title != null && title.isNotEmpty) titles.add(title);
    }
    if (supplier.defaultCategoryTitle.trim().isNotEmpty) {
      titles.add(supplier.defaultCategoryTitle.trim());
    }
  }
  // Normalize via legacy aliases so old/new chemical titles both match.
  return titles.map((t) => storeCategoryLegacyAliases[t] ?? t).toSet();
}

String _mapByKeywords(WooImportedProduct product) {
  final cats = product.categoryNames.join(' ').toLowerCase();
  final name = product.name.toLowerCase();
  final haystack = '$cats $name ${product.description}'.toLowerCase();

  bool inCats(String token) => cats.contains(token.toLowerCase());
  bool inName(String token) => name.contains(token.toLowerCase());
  bool has(String token) => haystack.contains(token.toLowerCase());

  // 1) Veterinary / agriculture — before generic medical "rapid test"
  if (has('veterinary') ||
      has('canine') ||
      has('feline') ||
      has('poultry') ||
      has('livestock') ||
      has('بيطر') ||
      has('دواجن') ||
      has('أعلاف') ||
      has('feed additive') ||
      (has('زراع') && !has('cell culture'))) {
    return _titleById('agriculture');
  }

  // 2) Molecular biology / biotech research (not clinical CBC)
  if (has('elisa kit') ||
      has('pcr') ||
      has('qpcr') ||
      has('cdna') ||
      has('rnase') ||
      has('dnase') ||
      has('cell culture') ||
      has('fetal bovine') ||
      has('agarose') ||
      has('western blot') ||
      has('molecular biology') ||
      has('بيولوجيا جزي') ||
      has('تقنية حيوية')) {
    return _titleById('biology');
  }

  // 3) Clinical / medical diagnostics & human analyzers
  if (inCats('rapid test') ||
      inCats('hematology') ||
      inCats('biochemistry reagent') ||
      has('hematology') ||
      has('cbc') ||
      has('clinical chemistry') ||
      has('coagulation') ||
      has('immunoassay') ||
      has('human devices') ||
      has('semi-auto chemistry') ||
      has('طبي') ||
      has('صيدل') ||
      has('أسنان') ||
      has('dental') ||
      has('علاج طبيعي') ||
      has('physiotherapy') ||
      (has('rapid test') && !has('veterinary'))) {
    return _titleById('medical');
  }

  // 4) Lab glassware / plasticware / tips → consumables
  if (has('glassware') ||
      has('volumetric flask') ||
      has('erlenmeyer') ||
      has('beaker') ||
      has('pipette tip') ||
      has('filter tip') ||
      has('centrifuge tube') ||
      has('petri') ||
      has('microplate') ||
      has('cryovial') ||
      has('plasticware') ||
      has('زجاج') ||
      has('مستهلك')) {
    return _titleById('consumables');
  }

  // 5) Fine chemicals / solvents / reagents (avoid bare "acid"/"salt" alone)
  if (has('solvent') ||
      has('hplc') ||
      has('reagent') ||
      has('chemical') ||
      has('مذيب') ||
      has('كاشف') ||
      has('كيمي') ||
      has('buffer') ||
      has('fisher chemical') ||
      has('thermo scientific') ||
      inName('sulfonic') ||
      inName('chloride') ||
      inName('sulfate') ||
      inName('nitrate') ||
      (has('acid') && (has('pure') || has('analysis') || has('%'))) ||
      (has('salt') && (has('sodium') || has('potassium') || has('ion pair')))) {
    return _titleById('chemicals');
  }

  // 6) Safety / PPE (use سلامة — not سلام — to avoid false Arabic matches)
  if (has('safety') ||
      has('ppe') ||
      has('glove') ||
      has('goggle') ||
      has('respirator') ||
      has('سلامة') ||
      has('معدات وقاية') ||
      has('قفاز')) {
    return _titleById('safety');
  }

  // 7) Field / survey meters
  if (has('survey') ||
      has('gps') ||
      has('theodolite') ||
      has('field meter') ||
      has('مسح') ||
      has('ميدان')) {
    return _titleById('field');
  }

  // 8) Computing / research software & workstations
  if (has('laptop') ||
      has('workstation') ||
      has('gpu') ||
      has('software') ||
      has('matlab') ||
      has('حاسب') ||
      has('برمج')) {
    return _titleById('computing');
  }

  // 9) Engineering electronics (narrow + DIY/lab electronics)
  if (has('arduino') ||
      has('raspberry') ||
      has('esp32') ||
      has('esp8266') ||
      has('stm32') ||
      has('fpga') ||
      has('plc') ||
      has('oscilloscope') ||
      has('multimeter') ||
      has('solid state relay') ||
      has('stepper motor') ||
      has('servo motor') ||
      has('breadboard') ||
      has('development board') ||
      has('cnc') ||
      has('3d printer') ||
      has('jetson') ||
      has('robotic arm') ||
      has('concrete') ||
      has('geotech') ||
      has('خرسانة') ||
      has('تربة') ||
      has('هندس') ||
      has('إلكترون') ||
      inCats('relay') ||
      inCats('arduino') ||
      inCats('motor')) {
    return _titleById('engineering');
  }

  // 10) Physics / materials testing
  if (has('instron') ||
      has('materials testing') ||
      has('hardness tester') ||
      has('ndts') ||
      has('اختبار مواد') ||
      has('فيزياء')) {
    return _titleById('physics_materials');
  }

  // 11) Instruments / measurement devices
  if (has('analyzer') ||
      has('centrifuge') ||
      has('spectrophotometer') ||
      has('microscope') ||
      has('balance') ||
      has('incubator') ||
      has('autoclave') ||
      has('ph meter') ||
      has('conductivity') ||
      has('turbidity') ||
      has('جهاز') ||
      has('قياس') ||
      inCats('devices') ||
      inCats('instrument')) {
    return _titleById('instruments');
  }

  // 12) Books
  if (has('book') || has('textbook') || has('كتاب') || has('مرجع')) {
    return _titleById('books');
  }

  // 13) Research writing / documentation / thesis print
  if (has('stationery') ||
      has('notebook') ||
      has('binder') ||
      has('folder') ||
      has('archival') ||
      has('thesis') ||
      has('dissertation') ||
      has('book binding') ||
      has('hard cover binding') ||
      has('قرطاس') ||
      has('دفتر') ||
      has('ملف أرشيف') ||
      has('تجليد') ||
      has('أطروح') ||
      has('رسالة ماجستير') ||
      has('رسالة دكتوراه')) {
    return _titleById('office');
  }

  return '';
}

String _titleById(String id) {
  return storeCategoryById(id)?.title ?? '';
}

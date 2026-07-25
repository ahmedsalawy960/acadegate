/// استخراج قواعد التنسيق من نص الدليل محلياً — بدون API ولا اشتراك.
class JournalGuidelinesHeuristic {
  JournalGuidelinesHeuristic._();

  static Map<String, dynamic>? extract(String pageText) {
    final text = pageText.trim();
    if (text.length < 15) return null;

    final lower = text.toLowerCase();

    final rules = <String, dynamic>{
      'found': false,
      'confidence': 'high',
      'keyRequirements': <String>[],
      'sectionOrder': <String>[],
      'acceptedFileFormats': <String>[],
      'excerpt': text.replaceAll(RegExp(r'\s+'), ' ').substring(
            0,
            text.length > 350 ? 350 : text.length,
          ),
    };

    if (_has(
      text,
      r'single[\s-]?spaced|single\s+spacing|تباعد\s*مفرد|سطر\s*واحد|تباعد\s*سطر\s*واحد',
    )) {
      rules['lineSpacing'] = 1.0;
      rules['lineSpacingLabel'] = 'single';
      (rules['keyRequirements'] as List).add('Single-spaced / تباعد مفرد');
      rules['found'] = true;
    } else if (_has(
      text,
      r'double[\s-]?spaced|double\s+spacing|تباعد\s*مزدوج|سطرين',
    )) {
      rules['lineSpacing'] = 2.0;
      rules['lineSpacingLabel'] = 'double';
      (rules['keyRequirements'] as List).add('Double-spaced / تباعد مزدوج');
      rules['found'] = true;
    } else if (_has(text, r'1\.5[\s-]?spaced|one and a half|تباعد\s*1\.5')) {
      rules['lineSpacing'] = 1.5;
      rules['lineSpacingLabel'] = '1.5';
      rules['found'] = true;
    }

    final fontPt = RegExp(
      r'(\d{1,2})[\s-]?(?:point|pt|نقطة)',
      caseSensitive: false,
    ).firstMatch(text);
    if (fontPt != null) {
      rules['bodyFontSizePt'] = int.parse(fontPt.group(1)!);
      (rules['keyRequirements'] as List)
          .add('${fontPt.group(1)}-point font');
      rules['found'] = true;
    }

    if (_has(text, r'times new roman|تايمز')) {
      rules['fontFamily'] = 'Times New Roman';
      rules['found'] = true;
    } else if (_has(text, r'\barial\b|أريال')) {
      rules['fontFamily'] = 'Arial';
      rules['found'] = true;
    }

    final abstractMax = RegExp(
      r'abstract[^.]{0,120}?(\d{2,4})\s*words?',
      caseSensitive: false,
    ).firstMatch(text) ??
        RegExp(
          r'contain\s+(\d{2,4})\s*words',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'ملخص[^.]{0,80}?(\d{2,4})\s*كلمة',
          caseSensitive: false,
        ).firstMatch(text);
    if (abstractMax != null) {
      final n = int.parse(abstractMax.group(1)!);
      if (n >= 50 && n <= 5000) {
        rules['abstractMaxWords'] = n;
        (rules['keyRequirements'] as List).add('Abstract max $n words');
        rules['found'] = true;
      }
    }

    final apc = RegExp(
      r'(?:processing charge|apc|fee|رسوم).{0,40}(\$\s*[\d,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (apc != null) {
      rules['articleProcessingCharge'] = apc.group(1)!.replaceAll(' ', '');
      rules['found'] = true;
    }

    if (_has(
      text,
      r'without\s+\[\s*\]|without\s+square\s+brackets|listed\s+as\s+1\.|as\s+1\.\s*,\s*2\.\s*,\s*3\.',
    )) {
      rules['citationStyle'] = 'vancouver';
      rules['referenceListPlainNumber'] = true;
      (rules['keyRequirements'] as List)
          .add('References as 1., 2., 3. without brackets in list');
      rules['found'] = true;
    } else if (_has(text, r'\[\s*\d+\s*\]|vancouver|numbered\s+references?')) {
      rules['citationStyle'] = 'vancouver';
      (rules['keyRequirements'] as List)
          .add('Numbered references (Vancouver/IEEE)');
      rules['found'] = true;
    } else if (_has(text, r'\bieee\b')) {
      rules['citationStyle'] = 'ieee';
      (rules['keyRequirements'] as List).add('IEEE citation style');
      rules['found'] = true;
    } else if (_has(text, r'\bapa\b|american psychological association')) {
      rules['citationStyle'] = 'apa';
      (rules['keyRequirements'] as List).add('APA citation style');
      rules['found'] = true;
    }

    final formats = <String>[];
    if (_has(text, r'microsoft word|\.docx?|وورد')) {
      formats.add('Microsoft Word');
    }
    if (_has(text, r'\brtf\b')) formats.add('RTF');
    if (_has(text, r'openoffice')) formats.add('OpenOffice');
    if (formats.isNotEmpty) {
      rules['acceptedFileFormats'] = formats;
      rules['found'] = true;
    }

    for (final name in const [
      'Title',
      'Abstract',
      'Introduction',
      'Experimental',
      'Methods',
      'Results',
      'Discussion',
      'Conclusion',
      'References',
    ]) {
      if (lower.contains(name.toLowerCase())) {
        (rules['sectionOrder'] as List).add(name);
      }
    }
    if ((rules['sectionOrder'] as List).length >= 3) {
      rules['found'] = true;
    }

    if (_has(
      text,
      r'author|manuscript|submission|مؤلف|تقديم|مخطوطة|دليل',
    )) {
      (rules['keyRequirements'] as List).add('Author guide text recognized');
      if (rules['found'] != true &&
          (rules['lineSpacing'] != null || rules['bodyFontSizePt'] != null)) {
        rules['found'] = true;
      }
    }

    return rules['found'] == true ? rules : null;
  }

  static bool _has(String text, String pattern) =>
      RegExp(pattern, caseSensitive: false).hasMatch(text);
}

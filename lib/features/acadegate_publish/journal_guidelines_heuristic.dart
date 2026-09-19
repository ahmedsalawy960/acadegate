/// استخراج قواعد التنسيق من نص الدليل محلياً — بدون API ولا اشتراك.
class JournalGuidelinesHeuristic {
  JournalGuidelinesHeuristic._();

  static Map<String, dynamic> merge(
    Map<String, dynamic>? heuristic,
    Map<String, dynamic>? richer,
  ) {
    if (heuristic == null || heuristic['found'] != true) {
      return Map<String, dynamic>.from(richer ?? const {});
    }
    if (richer == null || richer['found'] != true) {
      return Map<String, dynamic>.from(heuristic);
    }
    final out = Map<String, dynamic>.from(heuristic);
    richer.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      if (key == 'keyRequirements' && value is List) {
        final prev = out[key] is List ? List<dynamic>.from(out[key] as List) : <dynamic>[];
        out[key] = {...prev, ...value}.toList();
        return;
      }
      out[key] = value;
    });
    out['found'] = true;
    return out;
  }

  static Map<String, dynamic>? extract(
    String pageText, {
    bool requireDistinctive = true,
  }) {
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

    if (_has(
      text,
      r'(?:font|typeface|type face)[^.]{0,40}times new roman|times new roman[^.]{0,40}(?:font|typeface)|تايمز',
    )) {
      rules['fontFamily'] = 'Times New Roman';
    } else if (_has(
      text,
      r'(?:font|typeface)[^.]{0,30}\barial\b|\barial\b[^.]{0,30}(?:font|typeface)|أريال',
    )) {
      rules['fontFamily'] = 'Arial';
    }

    final fontPt = RegExp(
      r'(?:font|typeface|text)[^.\d]{0,40}(\d{1,2})[\s-]?(?:point|pt|نقطة)|'
      r'(\d{1,2})[\s-]?(?:point|pt|نقطة)[^.]{0,30}(?:font|typeface)',
      caseSensitive: false,
    ).firstMatch(text);
    if (fontPt != null) {
      final pt = int.parse(fontPt.group(1) ?? fontPt.group(2)!);
      if (pt >= 8 && pt <= 16) {
        rules['bodyFontSizePt'] = pt;
        (rules['keyRequirements'] as List).add('$pt-point font');
        rules['found'] = true;
      }
    }
    if (rules['fontFamily'] != null &&
        (rules['bodyFontSizePt'] != null || rules['lineSpacing'] != null)) {
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
    }

    if (_has(text, r'\bacs\b|american chemical society|superscript numbers')) {
      rules['citationStyle'] = 'acs';
      (rules['keyRequirements'] as List).add('ACS citation style');
      rules['found'] = true;
    } else if (_has(
      text,
      r'without\s+\[\s*\]|without\s+square\s+brackets|listed\s+as\s+1\.|as\s+1\.\s*,\s*2\.\s*,\s*3\.',
    )) {
      rules['citationStyle'] = 'vancouver';
      rules['referenceListPlainNumber'] = true;
      (rules['keyRequirements'] as List)
          .add('References as 1., 2., 3. without brackets in list');
      rules['found'] = true;
    } else if (_has(
      text,
      r'(?:in-?text|cit(?:e|ation|ations)|references?)[^.]{0,80}'
      r'(?:numbered|\[\s*\d+\s*\]|vancouver)|'
      r'numbered\s+(?:in-?text\s+)?references?|'
      r'vancouver\s+style',
    )) {
      rules['citationStyle'] = 'vancouver';
      (rules['keyRequirements'] as List)
          .add('Numbered references (Vancouver/IEEE)');
      rules['found'] = true;
    } else if (_has(text, r'\bieee\s+(?:style|citation|format)\b|\bcite\b.{0,40}\bieee\b')) {
      rules['citationStyle'] = 'ieee';
      (rules['keyRequirements'] as List).add('IEEE citation style');
      rules['found'] = true;
    } else if (_has(
      text,
      r'\bapa\s+(?:style|format|citation)|american psychological association',
    )) {
      rules['citationStyle'] = 'apa';
      (rules['keyRequirements'] as List).add('APA citation style');
      rules['found'] = true;
    } else if (_has(text, r'\bharvard\s+(?:style|referencing|citation)\b')) {
      rules['citationStyle'] = 'harvard';
      rules['found'] = true;
    } else     if (_has(text, r'\bchicago\s+(?:style|manual|citation)\b')) {
      rules['citationStyle'] = 'chicago';
      rules['found'] = true;
    }

    final refExample = _extractReferenceExample(text);
    if (refExample != null) {
      rules['referenceExample'] = refExample;
      (rules['keyRequirements'] as List)
          .add('Reference sample: $refExample');
      rules['found'] = true;
    }
    final inTextExample = _extractInTextExample(text);
    if (inTextExample != null) {
      rules['inTextExample'] = inTextExample;
      (rules['keyRequirements'] as List)
          .add('In-text sample: $inTextExample');
      rules['found'] = true;
    }

    if (_has(text, r'two[\s-]?column|double[\s-]?column|2[\s-]?column|عمودين')) {
      rules['columns'] = 2;
      (rules['keyRequirements'] as List).add('Two-column layout');
      rules['found'] = true;
    } else if (_has(text, r'single[\s-]?column|one[\s-]?column|عمود واحد')) {
      rules['columns'] = 1;
      rules['found'] = true;
    }

    if (_has(text, r'\ba4\b')) {
      rules['paperSize'] = 'a4';
      rules['found'] = true;
    } else if (_has(text, r'letter[\s-]?size|8\.5\s*[×x]\s*11')) {
      rules['paperSize'] = 'letter';
      rules['found'] = true;
    }

    final indent = RegExp(
      r'(?:first[\s-]?line|indent)[^.\d]{0,40}(\d(?:\.\d+)?)\s*(?:cm|inch|in)',
      caseSensitive: false,
    ).firstMatch(text);
    if (indent != null) {
      var n = double.parse(indent.group(1)!);
      if (RegExp(r'cm', caseSensitive: false).hasMatch(indent.group(0)!)) {
        // already cm
      } else {
        n = n * 2.54;
      }
      rules['firstLineIndentCm'] = n;
      rules['found'] = true;
    } else if (_has(text, r'first[\s-]?line indent|مسافة أول السطر')) {
      rules['firstLineIndentCm'] = 1.27;
      rules['found'] = true;
    }

    if (_has(text, r'numbered headings|headings? (?:are )?numbered|ترقيم العناوين')) {
      rules['headingNumbered'] = true;
      rules['found'] = true;
    }
    if (_has(text, r'uppercase headings|headings? in capital|عناوين بأحرف كبيرة')) {
      rules['headingUppercase'] = true;
      rules['found'] = true;
    }
    if (_has(
      text,
      r'sections?\s+and\s+sub-?sections?\s+should\s+not\s+be\s+numbered|'
      r'do\s+not\s+number\s+(?:sections?|headings?)|'
      r'should\s+not\s+be\s+numbered',
    )) {
      rules['headingNumbered'] = false;
      (rules['keyRequirements'] as List)
          .add('Do not number sections or sub-sections');
      rules['found'] = true;
    }

    if (_has(
      text,
      r'title[^.]{0,80}(?:bold\s+)?upper\s*case|'
      r'(?:typed?|types?)\s+in\s+bold\s+upper\s*case|'
      r'bold\s+upper\s*case\s+letters',
    )) {
      rules['titleUppercase'] = true;
      rules['headingUppercase'] = true;
      rules['titleAlign'] = 'center';
      (rules['keyRequirements'] as List)
          .add('Title in bold uppercase, centered');
      rules['found'] = true;
    }

    final keywords = RegExp(
      r'(?:key\s*words?|keywords)[^.\d]{0,40}(\d)\s*[-–to]+\s*(\d)',
      caseSensitive: false,
    ).firstMatch(text);
    if (keywords != null) {
      rules['keywordsMin'] = int.parse(keywords.group(1)!);
      rules['keywordsMax'] = int.parse(keywords.group(2)!);
      (rules['keyRequirements'] as List).add(
        'Keywords ${keywords.group(1)}-${keywords.group(2)}',
      );
      rules['found'] = true;
    }

    final maxRefs = RegExp(
      r'(?:number\s+of\s+)?references?\s+should\s+not\s+exceed\s+(\d{1,3})|'
      r'should\s+not\s+exceed\s+(\d{1,3})\s+references?',
      caseSensitive: false,
    ).firstMatch(text);
    if (maxRefs != null) {
      rules['maxReferences'] =
          int.parse(maxRefs.group(1) ?? maxRefs.group(2)!);
      (rules['keyRequirements'] as List)
          .add('At most ${rules['maxReferences']} references');
      rules['found'] = true;
    }

    final maxFigs = RegExp(
      r'total\s+number\s+of.{0,50}?(?:schemes?|tables?|figures?).{0,40}?'
      r'(?:should\s+not\s+exceed|not\s+more\s+than)\s+(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(text);
    if (maxFigs != null) {
      rules['maxFiguresAndTables'] = int.parse(maxFigs.group(1)!);
      (rules['keyRequirements'] as List).add(
        'At most ${rules['maxFiguresAndTables']} schemes/tables/figures',
      );
      rules['found'] = true;
    }

    final figWidth = RegExp(
      r'(?:widths?\s+of\s+)?(?:tables?\s+and\s+)?figures?[^.]{0,60}?'
      r'(\d(?:\.\d+)?)\s*(?:inches?|in)\s*(?:\((\d+(?:\.\d+)?)\s*cm\))?',
      caseSensitive: false,
    ).firstMatch(text);
    if (figWidth != null) {
      final cm = figWidth.group(2);
      rules['figureMaxWidthCm'] =
          cm != null ? double.parse(cm) : double.parse(figWidth.group(1)!) * 2.54;
      rules['found'] = true;
    }

    final running = RegExp(
      r'(?:running\s+title|short\s+running\s+title)[^.\d]{0,40}(\d{2,3})\s*characters',
      caseSensitive: false,
    ).firstMatch(text);
    if (running != null) {
      rules['runningTitleMaxChars'] = int.parse(running.group(1)!);
      rules['runningHeader'] = true;
      rules['found'] = true;
    }

    if (_has(
      text,
      r'do\s+not\s+use\s+et\s+al|include\s+names\s+of\s+all\s+the\s+authors',
    )) {
      rules['noEtAlInReferences'] = true;
      (rules['keyRequirements'] as List)
          .add('List all authors; do not use et al.');
      rules['found'] = true;
    }

    if (_has(
      text,
      r'reference numbers in the text should appear sequentially in square brackets|'
      r'sequentially in square brackets\s*\[|'
      r'listed in the References section as\s*1\.\s*,\s*2\.\s*,\s*3',
    )) {
      rules['citationStyle'] = 'ieee';
      rules['referenceListPlainNumber'] = true;
      rules['inTextExample'] ??= '[1]';
      (rules['keyRequirements'] as List).add(
        'In-text [n]; list as 1., 2., 3. without brackets',
      );
      rules['found'] = true;
    }

    if (_has(text, r'legends should be typed below')) {
      (rules['keyRequirements'] as List)
          .add('Figure legends below the figure');
      rules['found'] = true;
    }
    if (_has(text, r'page numbers?|ترقيم الصفحات')) {
      rules['pageNumbers'] = true;
    }
    if (_has(text, r'running head|running title|ترويسة')) {
      rules['runningHeader'] = true;
      rules['found'] = true;
    }

    final titlePt = RegExp(
      r'title[^.]{0,40}?(\d{1,2})\s*(?:point|pt|نقطة)',
      caseSensitive: false,
    ).firstMatch(text);
    if (titlePt != null) {
      rules['titleFontSizePt'] = int.parse(titlePt.group(1)!);
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

    if (_has(
      text,
      r'author guidelines|instructions for authors|manuscript|submission|مؤلف|تقديم|مخطوطة|دليل',
    )) {
      if (rules['lineSpacing'] != null || rules['bodyFontSizePt'] != null) {
        rules['found'] = true;
      }
    }

    if (requireDistinctive) {
      return _isDistinctive(rules) ? rules : null;
    }
    return rules['found'] == true ? rules : null;
  }

  static bool _isDistinctive(Map<String, dynamic> rules) {
    if (rules['found'] != true) return false;
    var n = 0;
    if (rules['citationStyle'] != null) n++;
    if (rules['lineSpacing'] != null) n++;
    if (rules['bodyFontSizePt'] != null) n++;
    if (rules['columns'] != null) n++;
    if (rules['firstLineIndentCm'] != null) n++;
    if (rules['abstractMaxWords'] != null) n++;
    if (rules['headingNumbered'] == true || rules['headingNumbered'] == false) {
      n++;
    }
    if (rules['titleUppercase'] == true) n++;
    if (rules['maxReferences'] != null) n++;
    if (rules['maxFiguresAndTables'] != null) n++;
    if (rules['keywordsMin'] != null) n++;
    if ((rules['referenceExample']?.toString() ?? '').trim().length >= 20) n++;
    if ((rules['inTextExample']?.toString() ?? '').trim().length >= 4) n++;
    return n >= 1;
  }

  static String? _extractReferenceExample(String text) {
    final labeled = RegExp(
      r'(?:example|e\.g\.|for example|as follows|شكل\s*المرجع|مثال)[:\s]+([^\n]{40,280})',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null && _looksLikeReferenceSample(labeled.group(1)!)) {
      return labeled.group(1)!.trim();
    }
    final numbered = RegExp(
      r'(?:^|\n)\s*((?:\[\d+\]|\d+\.)\s+[A-Z][A-Za-z\-]+[^\n]{30,240})',
    ).firstMatch(text);
    if (numbered != null && _looksLikeReferenceSample(numbered.group(1)!)) {
      return numbered.group(1)!.trim();
    }
    final acs = RegExp(
      r'(?:^|\n)\s*([A-Z][A-Za-z\-]+,\s*[A-Z]\.;[^\n]{30,240})',
    ).firstMatch(text);
    if (acs != null && _looksLikeReferenceSample(acs.group(1)!)) {
      return acs.group(1)!.trim();
    }
    return null;
  }

  static String? _extractInTextExample(String text) {
    final labeled = RegExp(
      r'(?:in[\s-]?text|cit(?:e|ation)|اقتباس)[^.\n]{0,80}'
      r'(superscript numbers?|\[\d+\]|\([A-Z][A-Za-z\-]+[^)]{0,40}(?:19|20)\d{2}\))',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null) return labeled.group(1)!.trim();
    return null;
  }

  static bool _looksLikeReferenceSample(String raw) {
    final t = raw.trim();
    if (t.length < 40) return false;
    if (!RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t)) return false;
    return RegExp(r'[A-Z][A-Za-z\-]{2,}').hasMatch(t);
  }

  static bool _has(String text, String pattern) =>
      RegExp(pattern, caseSensitive: false).hasMatch(text);
}

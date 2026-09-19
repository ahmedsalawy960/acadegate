/// ملف CAD مولَّد (STEP/STL) من PartWork أو ty\e.
class CadGeneratedAsset {
  final String provider; // partwork | tye
  final String format; // step | stl | ...
  final String url;
  final String? storagePath;
  final String? thumbnailUrl;
  final String? note;
  final String? error;

  const CadGeneratedAsset({
    required this.provider,
    required this.format,
    required this.url,
    this.storagePath,
    this.thumbnailUrl,
    this.note,
    this.error,
  });

  bool get hasFile => url.trim().isNotEmpty && (error == null || error!.isEmpty);

  String get providerLabel {
    switch (provider) {
      case 'partwork':
        return 'PartWork';
      case 'tye':
        return 'ty\\e';
      default:
        return provider;
    }
  }

  Map<String, dynamic> toMap() => {
        'provider': provider,
        'format': format,
        'url': url,
        if (storagePath != null) 'storagePath': storagePath,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (note != null) 'note': note,
      };

  factory CadGeneratedAsset.fromMap(Map<String, dynamic> m) {
    return CadGeneratedAsset(
      provider: m['provider']?.toString() ?? '',
      format: m['format']?.toString() ?? '',
      url: m['url']?.toString() ?? '',
      storagePath: m['storagePath']?.toString(),
      thumbnailUrl: m['thumbnailUrl']?.toString(),
      note: m['note']?.toString(),
      error: m['error']?.toString(),
    );
  }
}

class CadGenerateResult {
  final List<CadGeneratedAsset> assets;
  final List<({String provider, String error})> errors;
  final String? promptUsed;

  const CadGenerateResult({
    this.assets = const [],
    this.errors = const [],
    this.promptUsed,
  });

  bool get hasAssets => assets.any((a) => a.hasFile);
}

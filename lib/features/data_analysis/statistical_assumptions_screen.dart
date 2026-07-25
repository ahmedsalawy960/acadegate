import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
import '../ai_advisor/advisor_agent.dart';
import '../ai_advisor/advisor_agent_registry.dart';
import '../ai_advisor/ai_advisor_screen.dart';
import 'statistical_assumptions_engine.dart';
import 'statistical_assumptions_models.dart';
import 'statistical_data_analyzer.dart';
import 'statistical_dataset.dart';
import 'statistical_dataset_loader.dart';

class StatisticalAssumptionsScreen extends StatefulWidget {
  const StatisticalAssumptionsScreen({super.key});

  @override
  State<StatisticalAssumptionsScreen> createState() =>
      _StatisticalAssumptionsScreenState();
}

class _StatisticalAssumptionsScreenState
    extends State<StatisticalAssumptionsScreen> {
  static const _brand = Color(0xFF00838F);

  final _engine = StatisticalAssumptionsEngine.instance;
  final _analyzer = StatisticalDataAnalyzer.instance;
  final _loader = StatisticalDatasetLoader.instance;

  final _sampleController = TextEditingController(text: '60');
  final _groupCountController = TextEditingController(text: '2');
  final _effectController = TextEditingController(text: '0.5');
  final _shapiroController = TextEditingController();
  final _skewController = TextEditingController();
  final _kurtController = TextEditingController();
  final _variableController = TextEditingController(text: 'score');
  final _groupVarController = TextEditingController(text: 'group');

  int _step = 0;
  DataInputMode _mode = DataInputMode.fromFile;
  StatisticalDataset? _dataset;
  String? _depColumn;
  String? _groupColumn;
  String? _secondColumn;
  bool _loadingFile = false;

  StatisticalTestType _testType = StatisticalTestType.independentTTest;
  NormalityStatus _normality = NormalityStatus.unknown;
  bool _homogeneityOk = true;
  bool _linearityOk = true;
  final bool _independenceOk = true;
  double _alpha = 0.05;
  double _power = 0.8;

  StatisticalAssumptionsReport? _report;

  @override
  void dispose() {
    _sampleController.dispose();
    _groupCountController.dispose();
    _effectController.dispose();
    _shapiroController.dispose();
    _skewController.dispose();
    _kurtController.dispose();
    _variableController.dispose();
    _groupVarController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _loadingFile = true);
    try {
      final dataset = await _loader.pickAndLoad();
      if (!mounted) return;
      _applyLoadedDataset(dataset);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم تحميل ${dataset.fileName} — ${dataset.rowCount} صف',
              'Loaded ${dataset.fileName} — ${dataset.rowCount} rows',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _loadingFile = false);
    }
  }

  void _loadSampleCsv() {
    final dataset = _loader.loadSample();
    _applyLoadedDataset(dataset);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'تم تحميل مثال CSV — group × score',
            'Sample CSV loaded — group × score',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyLoadedDataset(StatisticalDataset dataset) {
    setState(() {
      _dataset = dataset;
      _mode = DataInputMode.fromFile;
      _step = 0;
      _report = null;
      _depColumn = dataset.numericColumnNames.isNotEmpty
          ? dataset.numericColumnNames.first
          : null;
      _groupColumn = dataset.categoricalColumnNames.isNotEmpty
          ? dataset.categoricalColumnNames.first
          : null;
      _secondColumn = dataset.numericColumnNames.length > 1
          ? dataset.numericColumnNames[1]
          : null;
    });
  }

  void _applyRealDataToForm(RealDataAnalysis data) {
    _sampleController.text = '${data.sampleSize}';
    if (data.groupCount != null) {
      _groupCountController.text = '${data.groupCount}';
    }
    if (data.observedEffectSize != null) {
      _effectController.text = data.observedEffectSize!.toStringAsFixed(3);
    }
    if (data.shapiroP != null) {
      _shapiroController.text = data.shapiroP!.toStringAsFixed(4);
    }
    if (data.skewness != null) {
      _skewController.text = data.skewness!.toStringAsFixed(3);
    }
    if (data.kurtosis != null) {
      _kurtController.text = data.kurtosis!.toStringAsFixed(3);
    }
    _normality = data.normality;
    _homogeneityOk = data.homogeneityOk;
    _linearityOk = data.linearityOk;
    if (_depColumn != null) _variableController.text = _depColumn!;
    if (_groupColumn != null) _groupVarController.text = _groupColumn!;
  }

  StatisticalAssumptionsInput _buildInput({bool fromReal = false}) {
    double? parseOptional(String text) {
      final t = text.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t.replaceAll(',', '.'));
    }

    return StatisticalAssumptionsInput(
      testType: _testType,
      sampleSize: int.tryParse(_sampleController.text.trim()) ?? 30,
      groupCount: int.tryParse(_groupCountController.text.trim()),
      effectSize: parseOptional(_effectController.text),
      alpha: _alpha,
      desiredPower: _power,
      normality: _normality,
      shapiroP: parseOptional(_shapiroController.text),
      skewness: parseOptional(_skewController.text),
      kurtosis: parseOptional(_kurtController.text),
      homogeneityOk: _homogeneityOk,
      linearityOk: _linearityOk,
      independenceOk: _independenceOk,
      variableName: _variableController.text.trim().isEmpty
          ? 'score'
          : _variableController.text.trim(),
      groupVariableName: _groupVarController.text.trim().isEmpty
          ? 'group'
          : _groupVarController.text.trim(),
      fromRealData: fromReal,
    );
  }

  void _runAnalysis() {
    if (_mode == DataInputMode.fromFile && _dataset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'ارفع ملف CSV أولاً أو اضغط «مثال CSV»',
              'Upload a CSV file first or tap «Sample CSV»',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _step = 0);
      return;
    }

    RealDataAnalysis? real;
    StatisticalAssumptionsInput input;

    if (_mode == DataInputMode.fromFile && _dataset != null) {
      real = _analyzer.analyze(
        dataset: _dataset!,
        mapping: ColumnMapping(
          dependentColumn: _depColumn,
          groupColumn: _groupColumn,
          secondNumericColumn: _secondColumn,
        ),
        testType: _testType,
        alpha: _alpha,
      );
      _applyRealDataToForm(real);
      input = StatisticalAssumptionsInput.fromAnalysis(
        testType: _testType,
        data: real,
        dependentColumn: _depColumn ?? 'score',
        groupColumn: _groupColumn ?? 'group',
        alpha: _alpha,
        desiredPower: _power,
      );
    } else {
      input = _buildInput();
    }

    setState(() {
      _report = _engine.analyze(input, realData: real);
      _step = 2;
    });
  }

  bool _canProceedFromDataStep() {
    if (_mode == DataInputMode.manual) return true;
    if (_dataset == null) return false;
    return _depColumn != null &&
        (_testTypeNeedsGroup() ? _groupColumn != null : true) &&
        (_testTypeNeedsSecondNumeric() ? _secondColumn != null : true);
  }

  bool _testTypeNeedsGroup() {
    return _testType == StatisticalTestType.independentTTest ||
        _testType == StatisticalTestType.oneWayAnova ||
        _testType == StatisticalTestType.chiSquare;
  }

  bool _testTypeNeedsSecondNumeric() {
    return _testType == StatisticalTestType.pairedTTest ||
        _testType == StatisticalTestType.pearsonCorrelation ||
        _testType == StatisticalTestType.linearRegression;
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('تم نسخ الكود', 'Code copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _askDataAgent() {
    final report = _report;
    if (report == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiAdvisorScreen(initialMessage: report.advisorPrompt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agent =
        AdvisorAgentRegistry.instance.byId(AdvisorAgentId.dataAnalysis);

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t(
            'معالج الافتراضات الإحصائية',
            'Statistical assumptions wizard',
          ),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('رفع CSV', 'Upload CSV'),
            icon: _loadingFile
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_file),
            onPressed: _loadingFile ? null : _pickFile,
          ),
          IconButton(
            tooltip: context.t('مثال CSV', 'Sample CSV'),
            icon: const Icon(Icons.table_view_outlined),
            onPressed: _loadingFile ? null : _loadSampleCsv,
          ),
        ],
      ),
      floatingActionButton: _step < 2 && _dataset == null && _mode == DataInputMode.fromFile
          ? FloatingActionButton.extended(
              onPressed: _loadingFile ? null : _pickFile,
              backgroundColor: _brand,
              icon: const Icon(Icons.upload_file),
              label: Text(context.t('رفع CSV', 'Upload CSV')),
            )
          : null,
      body: Column(
        children: [
          _buildHeader(agent),
          _buildStepIndicator(),
          if (_dataset != null) _buildLoadedFileBanner(),
          if (_dataset == null && _step < 2 && _mode == DataInputMode.fromFile)
            _buildUploadPrompt(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_step == 0) ...[
                  _buildDataStep(),
                  const SizedBox(height: 12),
                  _buildTestStep(),
                ],
                if (_step == 1) _buildReviewStep(),
                if (_step == 2 && _report != null) _buildReport(_report!),
              ],
            ),
          ),
          _buildNavBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(AdvisorAgent agent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: _brand.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(agent.icon, color: _brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(
                'ارفع CSV/TSV أو أدخل يدوياً — Shapiro-Wilk، Levene، t/ANOVA حقيقية',
                'Upload CSV/TSV or enter manually — real Shapiro-Wilk, Levene, t/ANOVA',
              ),
              style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedFileBanner() {
    final dataset = _dataset!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t(
                'CSV: ${dataset.fileName} (${dataset.rowCount} صف)',
                'CSV: ${dataset.fileName} (${dataset.rowCount} rows)',
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade900,
              ),
            ),
          ),
          TextButton(
            onPressed: _pickFile,
            child: Text(context.t('تغيير', 'Change')),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPrompt() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _loadingFile ? null : _pickFile,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 48, color: _brand),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    'اضغط لرفع ملف CSV',
                    'Tap to upload a CSV file',
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _brand,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t(
                    'أو استخدم أيقونة ↑ في الشريط العلوي — أو «مثال CSV»',
                    'Or use the ↑ icon in the app bar — or «Sample CSV»',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadSampleCsv,
                  icon: const Icon(Icons.table_view_outlined),
                  label: Text(context.t('مثال CSV جاهز', 'Ready sample CSV')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final labels = [
      context.t('البيانات والتحليل', 'Data & analysis'),
      context.t('المراجعة', 'Review'),
      context.t('النتائج', 'Results'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i <= _step;
          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: active ? _brand : Colors.grey.shade300,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: active ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDataStep() {
    final dataset = _dataset;

    return Column(
      children: [
        if (_mode == DataInputMode.fromFile) ...[
          Card(
            elevation: 2,
            color: _brand.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.upload_file, color: _brand, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t(
                            '① ارفع ملف CSV أولاً',
                            '① Upload a CSV file first',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: _brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loadingFile ? null : _pickFile,
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _loadingFile
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_file, size: 28),
                      label: Text(
                        context.t(
                          'اختر ملف CSV / TSV',
                          'Choose CSV / TSV file',
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _loadSampleCsv,
                    icon: const Icon(Icons.table_view_outlined),
                    label: Text(
                      context.t(
                        'أو جرّب مثال CSV مدمج',
                        'Or try built-in sample CSV',
                      ),
                    ),
                  ),
                  Text(
                    context.t(
                      'Excel: احفظ الورقة كـ CSV UTF-8 ثم ارفعها',
                      'Excel: save sheet as CSV UTF-8 then upload',
                    ),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('مصدر البيانات', 'Data source'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SegmentedButton<DataInputMode>(
                  segments: [
                    ButtonSegment(
                      value: DataInputMode.fromFile,
                      label: Text(context.t('من ملف CSV', 'From CSV file')),
                      icon: const Icon(Icons.upload_file, size: 18),
                    ),
                    ButtonSegment(
                      value: DataInputMode.manual,
                      label: Text(context.t('يدوي', 'Manual')),
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) {
                    setState(() => _mode = s.first);
                  },
                ),
              ],
            ),
          ),
        ),
        if (dataset != null && _mode == DataInputMode.fromFile) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dataset.fileName} — ${dataset.rowCount} ${context.t('صف', 'rows')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t('معاينة', 'Preview'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: dataset.headers
                          .map((h) => DataColumn(label: Text(h)))
                          .toList(),
                      rows: dataset.rows
                          .take(5)
                          .map(
                            (row) => DataRow(
                              cells: row
                                  .map((c) => DataCell(Text(c)))
                                  .toList(),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _columnDropdown(
                    label: context.t('المتغير الرقمي (Y)', 'Numeric variable (Y)'),
                    value: _depColumn,
                    options: dataset.numericColumnNames,
                    onChanged: (v) => setState(() => _depColumn = v),
                  ),
                  if (_testTypeNeedsGroup())
                    _columnDropdown(
                      label: context.t(
                        'متغير المجموعة / فئة',
                        'Group / category variable',
                      ),
                      value: _groupColumn,
                      options: [
                        ...dataset.categoricalColumnNames,
                        ...dataset.numericColumnNames,
                      ],
                      onChanged: (v) => setState(() => _groupColumn = v),
                    ),
                  if (_testTypeNeedsSecondNumeric())
                    _columnDropdown(
                      label: context.t(
                        'متغير رقمي ثانٍ (X)',
                        'Second numeric (X)',
                      ),
                      value: _secondColumn,
                      options: dataset.numericColumnNames,
                      onChanged: (v) => setState(() => _secondColumn = v),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _columnDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTestStep() {
    final isEnglish = LocaleService.instance.isEnglish;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                '② اختر نوع التحليل',
                '② Choose analysis type',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            RadioGroup<StatisticalTestType>(
              groupValue: _testType,
              onChanged: (v) {
                if (v != null) setState(() => _testType = v);
              },
              child: Column(
                children: StatisticalTestType.values.map((type) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<StatisticalTestType>(value: type),
                    title: Text(type.label(isEnglish)),
                    onTap: () => setState(() => _testType = type),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final fromFile = _mode == DataInputMode.fromFile && _dataset != null;

    return Column(
      children: [
        if (fromFile)
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: Icon(Icons.verified, color: Colors.green.shade700),
              title: Text(
                context.t(
                  'سيتم حساب الافتراضات من بياناتك',
                  'Assumptions will be computed from your data',
                ),
              ),
              subtitle: Text(_dataset!.fileName),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('العينة والقوة', 'Sample & power'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sampleController,
                  readOnly: fromFile,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.t('حجم العينة (n)', 'Sample size (n)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (!fromFile) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _effectController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.t(
                        'حجم الأثر المتوقع',
                        'Expected effect size',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _shapiroController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.t(
                        'Shapiro-Wilk p (اختياري)',
                        'Shapiro-Wilk p (optional)',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(context.t('مستوى الدلالة α', 'Significance α')),
                Slider(
                  value: _alpha,
                  min: 0.01,
                  max: 0.1,
                  divisions: 9,
                  label: _alpha.toStringAsFixed(2),
                  activeColor: _brand,
                  onChanged: (v) => setState(() => _alpha = v),
                ),
                Text(context.t('القوة الإحصائية', 'Statistical power')),
                Slider(
                  value: _power,
                  min: 0.6,
                  max: 0.95,
                  divisions: 7,
                  label: _power.toStringAsFixed(2),
                  activeColor: _brand,
                  onChanged: (v) => setState(() => _power = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReport(StatisticalAssumptionsReport report) {
    final isEnglish = LocaleService.instance.isEnglish;
    final real = report.realData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (real != null && real.fromRealData)
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dataset, color: Colors.teal.shade800),
                      const SizedBox(width: 8),
                      Text(
                        context.t(
                          'نتائج من بياناتك الحقيقية',
                          'Results from your real data',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900,
                        ),
                      ),
                    ],
                  ),
                  if (real.fileName != null)
                    Text('${real.fileName} • n=${real.sampleSize}'),
                  const SizedBox(height: 8),
                  ...real.findings.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            f.passed ? Icons.check : Icons.warning_amber,
                            size: 16,
                            color: f.passed ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${f.label(isEnglish)}: ${f.value}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (real.columnSummaries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.t('الوصفيات', 'Descriptives'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...real.columnSummaries.map(
                      (s) => Text(
                        '${s.column}: n=${s.n}, M=${s.mean.toStringAsFixed(2)}, '
                        'SD=${s.std.toStringAsFixed(2)}, '
                        '${s.normalityTestName} p=${s.normalityP?.toStringAsFixed(4) ?? "—"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          color: _brand.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.displayRecommendedTest(isEnglish),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: _brand,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('بديل: ', 'Alternative: ') +
                      report.displayAlternativeTest(isEnglish),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.t('فحص الافتراضات', 'Assumption checks'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...report.assumptions.map((a) => _assumptionTile(a, isEnglish)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              report.power.currentSampleAdequate
                  ? Icons.check_circle
                  : Icons.warning_amber,
              color: report.power.currentSampleAdequate
                  ? Colors.green
                  : Colors.orange,
            ),
            title: Text(context.t('قوة العينة', 'Sample power')),
            subtitle: Text(report.power.displayInterpretation(isEnglish)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.t('أكواد SPSS / R', 'SPSS / R code'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...report.codeSnippets.map((s) => _codeCard(s, isEnglish)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _askDataAgent,
          style: FilledButton.styleFrom(
            backgroundColor: _brand,
            minimumSize: const Size(double.infinity, 48),
          ),
          icon: const Icon(Icons.smart_toy_outlined),
          label: Text(
            context.t(
              'اسأل وكيل تحليل البيانات',
              'Ask the Data Analysis agent',
            ),
          ),
        ),
      ],
    );
  }

  Widget _assumptionTile(AssumptionCheck check, bool isEnglish) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          check.passed ? Icons.check_circle : Icons.error_outline,
          color: check.passed ? Colors.green : Colors.orange,
        ),
        title: Text(check.displayTitle(isEnglish)),
        subtitle: Text(check.displayAdvice(isEnglish)),
      ),
    );
  }

  Widget _codeCard(CodeSnippet snippet, bool isEnglish) {
    final lang = snippet.language == CodeLanguage.spss ? 'SPSS' : 'R';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(lang, style: const TextStyle(fontSize: 11))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    snippet.displayCaption(isEnglish),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyCode(snippet.code),
                  icon: const Icon(Icons.copy, size: 20),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                snippet.code.trim(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_step > 0 && _step < 2)
              OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: Text(context.t('السابق', 'Back')),
              ),
            const Spacer(),
            if (_step == 0)
              FilledButton(
                onPressed: _canProceedFromDataStep()
                    ? () => setState(() => _step++)
                    : null,
                style: FilledButton.styleFrom(backgroundColor: _brand),
                child: Text(context.t('التالي', 'Next')),
              ),
            if (_step == 1)
              FilledButton.icon(
                onPressed: _runAnalysis,
                style: FilledButton.styleFrom(backgroundColor: _brand),
                icon: const Icon(Icons.analytics_outlined),
                label: Text(context.t('تحليل', 'Analyze')),
              ),
            if (_step == 2)
              TextButton(
                onPressed: () => setState(() {
                  _step = 0;
                  _report = null;
                }),
                child: Text(context.t('بداية جديدة', 'Start over')),
              ),
          ],
        ),
      ),
    );
  }
}

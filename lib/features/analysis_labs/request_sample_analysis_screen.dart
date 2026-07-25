import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import 'sample_analysis_request_service.dart';

const sampleTypes = [
  'مواد صلبة',
  'سوائل',
  'مسحوق',
  'أنسجة حيوية',
  'ماء/تربة',
  'غذاء/دواء',
  'أخرى',
];

String sampleTypeLabel(String type) {
  return switch (type) {
    'مواد صلبة' => appTr('مواد صلبة', 'Solid materials'),
    'سوائل' => appTr('سوائل', 'Liquids'),
    'مسحوق' => appTr('مسحوق', 'Powder'),
    'أنسجة حيوية' => appTr('أنسجة حيوية', 'Biological tissues'),
    'ماء/تربة' => appTr('ماء/تربة', 'Water/soil'),
    'غذاء/دواء' => appTr('غذاء/دواء', 'Food/drug'),
    'أخرى' => appTr('أخرى', 'Other'),
    _ => type,
  };
}

Future<bool?> openSampleAnalysisRequestScreen(
  BuildContext context, {
  required AcademicLab lab,
  SampleAnalysisService? preselectedService,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => RequestSampleAnalysisScreen(
        lab: lab,
        preselectedService: preselectedService,
      ),
    ),
  );
}

class RequestSampleAnalysisScreen extends StatefulWidget {
  final AcademicLab lab;
  final SampleAnalysisService? preselectedService;

  const RequestSampleAnalysisScreen({
    super.key,
    required this.lab,
    this.preselectedService,
  });

  @override
  State<RequestSampleAnalysisScreen> createState() =>
      _RequestSampleAnalysisScreenState();
}

class _RequestSampleAnalysisScreenState
    extends State<RequestSampleAnalysisScreen> {
  final _researchController = TextEditingController();
  final _notesController = TextEditingController();
  final _countController = TextEditingController(text: '1');

  late final List<SampleAnalysisService> _services;
  String? _selectedServiceId;
  String _specialty = facultyCategoryIds().first;
  String _sampleType = sampleTypes.first;
  bool _saving = false;

  SampleAnalysisService? get _selectedService {
    final id = _selectedServiceId;
    if (id == null) return null;
    for (final service in _services) {
      if (service.id == id) return service;
    }
    return null;
  }

  List<SampleAnalysisService> _buildServices() {
    List<SampleAnalysisService> raw;
    if (widget.lab.sampleServices.isNotEmpty) {
      raw = List<SampleAnalysisService>.of(widget.lab.sampleServices);
    } else {
      raw = widget.lab.devices
          .map(
            (device) => SampleAnalysisService(
              id: device.id.isNotEmpty ? device.id : device.name,
              name: appTr(
                'تحليل — ${device.name}',
                'Analysis — ${device.name}',
              ),
              description: appTr(
                'تحليل عينة باستخدام ${device.name}',
                'Sample analysis using ${device.name}',
              ),
              turnaroundDays: device.waitDays,
              priceFrom: device.costPerSession,
              sampleTypes: sampleTypes,
              specialties: widget.lab.tags,
            ),
          )
          .toList();
    }
    if (raw.isEmpty) {
      raw = [
        SampleAnalysisService(
          id: 'general',
          name: appTr('تحليل عينات عام', 'General sample analysis'),
          description: appTr(
            'تواصل مع المختبر لتحديد نوع التحليل',
            'Contact the lab to confirm the analysis type',
          ),
          turnaroundDays: widget.lab.defaultWaitDays,
          sampleTypes: sampleTypes,
          specialties: widget.lab.tags,
        ),
      ];
    }

    // Dropdown requires unique values — keep first occurrence per id.
    final seen = <String>{};
    final unique = <SampleAnalysisService>[];
    for (final service in raw) {
      final id = service.id.isNotEmpty ? service.id : service.name;
      if (!seen.add(id)) continue;
      unique.add(
        id == service.id
            ? service
            : SampleAnalysisService(
                id: id,
                name: service.name,
                description: service.description,
                specialties: service.specialties,
                sampleTypes: service.sampleTypes,
                turnaroundDays: service.turnaroundDays,
                priceFrom: service.priceFrom,
              ),
      );
    }
    return unique;
  }

  String? _resolveServiceId(SampleAnalysisService? preferred) {
    if (_services.isEmpty) return null;
    if (preferred != null) {
      for (final service in _services) {
        if (service.id == preferred.id || service.name == preferred.name) {
          return service.id;
        }
      }
    }
    return _services.first.id;
  }

  @override
  void initState() {
    super.initState();
    _services = _buildServices();
    _selectedServiceId = _resolveServiceId(widget.preselectedService);
  }

  @override
  void dispose() {
    _researchController.dispose();
    _notesController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final service = _selectedService;
    if (service == null) {
      _showError(context.t('اختر نوع التحليل', 'Choose an analysis type'));
      return;
    }

    setState(() => _saving = true);
    try {
      await SampleAnalysisRequestService.instance.submit(
        lab: widget.lab,
        service: service,
        specialty: _specialty,
        sampleType: _sampleType,
        sampleCount: int.tryParse(_countController.text.trim()) ?? 1,
        researchTitle: _researchController.text,
        notes: _notesController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم إرسال طلب تحليل العينة — تابعه من لوحة المساهمة',
              'Sample analysis request sent — track it from the contributor hub',
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;
    final selectedId = _selectedServiceId != null &&
            _services.any((s) => s.id == _selectedServiceId)
        ? _selectedServiceId
        : null;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('طلب تحليل عينة', 'Request sample analysis')),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(lab.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(lab.labTypeLabel, style: TextStyle(color: Colors.grey[600])),
          if (lab.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(lab.description),
          ],
          if (lab.isUnowned) ...[
            const SizedBox(height: 8),
            Text(
              context.t(
                'سيصل الطلب لمديري المنصة حتى يُربط المختبر بمالك.',
                'The request will reach platform admins until the lab is claimed.',
              ),
              style: TextStyle(color: Colors.orange[900], height: 1.35),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: InputDecoration(
              labelText: context.t(
                'نوع التحليل / الخدمة',
                'Analysis type / service',
              ),
              border: const OutlineInputBorder(),
            ),
            items: _services
                .map(
                  (service) => DropdownMenuItem<String>(
                    value: service.id,
                    child: Text(
                      service.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedServiceId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _specialty,
            decoration: InputDecoration(
              labelText: context.t('التخصص', 'Specialty'),
              border: const OutlineInputBorder(),
            ),
            items: facultyCategoryIds()
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(L10nLookup.facultyTitleStatic(id)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _specialty = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sampleType,
            decoration: InputDecoration(
              labelText: context.t('نوع العينة', 'Sample type'),
              border: const OutlineInputBorder(),
            ),
            items: sampleTypes
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(sampleTypeLabel(type)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _sampleType = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.t('عدد العينات', 'Number of samples'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _researchController,
            decoration: InputDecoration(
              labelText: context.t(
                'عنوان البحث / الغرض من التحليل',
                'Research title / purpose of analysis',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.t(
                'تفاصيل إضافية (طريقة الحفظ، مواصفات...)',
                'Additional details (storage method, specs...)',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_selectedService != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.purple[50],
              child: ListTile(
                leading: Icon(Icons.info_outline, color: Colors.purple[800]),
                title: Text(
                  context.t(
                    'مدة متوقعة: ${_selectedService!.turnaroundDays} يوم'
                    '${_selectedService!.priceFrom > 0 ? ' • من ${_selectedService!.priceFrom} ج.م' : ''}',
                    'Expected turnaround: ${_selectedService!.turnaroundDays} days'
                    '${_selectedService!.priceFrom > 0 ? ' • from ${_selectedService!.priceFrom} EGP' : ''}',
                  ),
                ),
                subtitle: _selectedService!.description.isNotEmpty
                    ? Text(_selectedService!.description)
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purple[700],
              minimumSize: const Size.fromHeight(48),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(context.t('إرسال طلب التحليل', 'Submit analysis request')),
          ),
        ],
      ),
    );
  }
}

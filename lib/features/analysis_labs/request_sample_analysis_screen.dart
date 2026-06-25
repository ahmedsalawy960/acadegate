import 'package:flutter/material.dart';

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

  SampleAnalysisService? _selectedService;
  String _specialty = facultyCategoryIds().first;
  String _sampleType = sampleTypes.first;
  bool _saving = false;

  List<SampleAnalysisService> get _services {
    if (widget.lab.sampleServices.isNotEmpty) return widget.lab.sampleServices;
    return widget.lab.devices
        .map(
          (device) => SampleAnalysisService(
            id: device.id,
            name: 'تحليل — ${device.name}',
            description: 'تحليل عينة باستخدام ${device.name}',
            turnaroundDays: device.waitDays,
            priceFrom: device.costPerSession,
            sampleTypes: sampleTypes,
            specialties: widget.lab.tags,
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedService = widget.preselectedService ??
        (_services.isNotEmpty ? _services.first : null);
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
      _showError('اختر نوع التحليل');
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
        const SnackBar(
          content: Text('تم إرسال طلب تحليل العينة — تابعه من لوحة المساهمة'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب تحليل عينة'),
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
          const SizedBox(height: 20),
          DropdownButtonFormField<SampleAnalysisService>(
            initialValue: _selectedService,
            decoration: const InputDecoration(
              labelText: 'نوع التحليل / الخدمة',
              border: OutlineInputBorder(),
            ),
            items: _services
                .map(
                  (service) => DropdownMenuItem(
                    value: service,
                    child: Text(service.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedService = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _specialty,
            decoration: const InputDecoration(
              labelText: 'التخصص',
              border: OutlineInputBorder(),
            ),
            items: facultyCategoryIds()
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(facultyTitleForCategory(id)),
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
            decoration: const InputDecoration(
              labelText: 'نوع العينة',
              border: OutlineInputBorder(),
            ),
            items: sampleTypes
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _sampleType = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'عدد العينات',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _researchController,
            decoration: const InputDecoration(
              labelText: 'عنوان البحث / الغرض من التحليل',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'تفاصيل إضافية (طريقة الحفظ، مواصفات...)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_selectedService != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.purple[50],
              child: ListTile(
                leading: Icon(Icons.info_outline, color: Colors.purple[800]),
                title: Text(
                  'مدة متوقعة: ${_selectedService!.turnaroundDays} يوم'
                  '${_selectedService!.priceFrom > 0 ? ' • من ${_selectedService!.priceFrom} ج.م' : ''}',
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
                : const Text('إرسال طلب التحليل'),
          ),
        ],
      ),
    );
  }
}

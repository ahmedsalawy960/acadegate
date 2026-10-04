import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'cronbach_engine.dart';
import 'research_tools_branding.dart';

/// حاسبة ألفا كرونباخ — لصق درجات البنود سطراً لكل مستجيب.
class CronbachScreen extends StatefulWidget {
  const CronbachScreen({super.key});

  @override
  State<CronbachScreen> createState() => _CronbachScreenState();
}

class _CronbachScreenState extends State<CronbachScreen> {
  static const _brand = Color(ResearchToolsBranding.brand);
  final _controller = TextEditingController(
    text: '5 4 5 4 5\n'
        '4 4 3 4 4\n'
        '5 5 5 4 5\n'
        '3 3 4 3 3\n'
        '4 5 4 5 4\n'
        '5 4 4 5 5\n'
        '2 3 2 3 2\n'
        '4 4 5 4 4',
  );
  CronbachResult? _result;
  String? _parseErrorAr;
  String? _parseErrorEn;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _compute() {
    final parsed = CronbachEngine.parseMatrixText(_controller.text);
    if (parsed.$2 != null) {
      setState(() {
        _parseErrorAr = parsed.$2;
        _parseErrorEn = parsed.$3;
        _result = null;
      });
      return;
    }
    setState(() {
      _parseErrorAr = null;
      _parseErrorEn = null;
      _result = CronbachEngine.compute(parsed.$1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('ألفا كرونباخ', 'Cronbach’s alpha')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.t(
              'الصق درجات البنود: كل سطر = مستجيب واحد، والقيم مفصولة بمسافة أو فاصلة. '
              'المثال أدناه بيانات تجريبية فقط.',
              'Paste item scores: one line per respondent, values separated by space or comma. '
              'The sample below is demo data only.',
            ),
            style: const TextStyle(height: 1.45, color: Color(0xFFB7C3D6)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 12,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: context.t('مصفوفة الدرجات', 'Score matrix'),
              alignLabelWithHint: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,;\s\n\r\t\-#]')),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _brand),
            onPressed: _compute,
            icon: const Icon(Icons.calculate_outlined),
            label: Text(context.t('احسب α', 'Compute α')),
          ),
          if (_parseErrorAr != null) ...[
            const SizedBox(height: 12),
            Text(
              context.t(_parseErrorAr!, _parseErrorEn ?? ''),
              style: const TextStyle(color: Colors.red, height: 1.4),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _brand.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!result.ok)
                      Text(
                        context.t(result.errorAr ?? '', result.errorEn ?? ''),
                        style: const TextStyle(color: Colors.red, height: 1.4),
                      )
                    else ...[
                      Text(
                        'α = ${CronbachEngine.roundAlpha(result.alpha).toStringAsFixed(3)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t(
                          'مستجيبون: ${result.nRespondents} · بنود: ${result.kItems}',
                          'Respondents: ${result.nRespondents} · Items: ${result.kItems}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t(
                          result.interpretationAr,
                          result.interpretationEn,
                        ),
                        style: const TextStyle(height: 1.45),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            context.t(
              'ملاحظة: α يعتمد على تجانس البنود وحجم العينة. استخدمه مع الصدق '
              '(محكمين/بناء) ولا تعتمد عليه وحده.',
              'Note: α depends on item homogeneity and sample size. Use it with '
              'validity evidence (experts/construct) — not alone.',
            ),
            style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6), height: 1.4),
          ),
        ],
      ),
    );
  }
}

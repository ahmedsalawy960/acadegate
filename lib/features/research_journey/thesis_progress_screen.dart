import 'package:flutter/material.dart';

import 'package:acadegate/core/widgets/acadegate_app_bar.dart';



import '../../core/locale/locale_extensions.dart';

import '../../core/locale/locale_service.dart';

import 'thesis_progress.dart';

import 'thesis_progress_engine.dart';

import 'thesis_progress_navigation.dart';

import 'thesis_progress_templates.dart';



class ThesisProgressScreen extends StatefulWidget {

  const ThesisProgressScreen({super.key});



  @override

  State<ThesisProgressScreen> createState() => _ThesisProgressScreenState();

}



class _ThesisProgressScreenState extends State<ThesisProgressScreen> {

  static const _brand = Color(0xFF1A237E);



  final _engine = ThesisProgressEngine.instance;

  ThesisProgress? _progress;

  bool _loading = true;

  bool _syncing = false;



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    setState(() => _loading = true);

    final progress = await ThesisProgressService.instance.load();

    if (!mounted) return;

    setState(() {

      _progress = progress;

      _loading = false;

    });

  }



  Future<void> _refreshSmart() async {

    setState(() => _syncing = true);

    await ThesisProgressService.instance.refreshFromApp();

    await _load();

    if (!mounted) return;

    setState(() => _syncing = false);

  }



  Future<void> _toggle(ThesisProgressItem item, bool done) async {

    final progress = _progress;

    if (progress == null) return;



    final updated = progress.items

        .map(

          (e) => e.id == item.id

              ? e.copyWith(done: done, autoTracked: false)

              : e,

        )

        .toList();

    final next = progress.copyWithItems(updated);

    setState(() => _progress = next);

    await ThesisProgressService.instance.save(next);

  }



  Future<void> _pickDate(ThesisProgressItem item) async {

    final picked = await showDatePicker(

      context: context,

      initialDate: item.dueDate ?? DateTime.now().add(const Duration(days: 30)),

      firstDate: DateTime.now().subtract(const Duration(days: 30)),

      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),

    );

    if (picked == null || _progress == null) return;



    final updated = _progress!.items

        .map((e) => e.id == item.id ? e.copyWith(dueDate: picked) : e)

        .toList();

    final next = _progress!.copyWithItems(updated);

    setState(() => _progress = next);

    await ThesisProgressService.instance.save(next);

  }



  Future<void> _addCustomItem() async {

    final controller = TextEditingController();

    final title = await showDialog<String>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: Text(context.t('بند مخصص', 'Custom item')),

        content: TextField(

          controller: controller,

          decoration: InputDecoration(

            labelText: context.t('اسم البند', 'Item name'),

          ),

          autofocus: true,

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx),

            child: Text(context.t('إلغاء', 'Cancel')),

          ),

          FilledButton(

            onPressed: () => Navigator.pop(ctx, controller.text),

            child: Text(context.t('إضافة', 'Add')),

          ),

        ],

      ),

    );

    controller.dispose();

    if (title == null || title.trim().isEmpty) return;

    await ThesisProgressService.instance.addCustomItem(title);

    await _load();

  }



  Future<void> _changeTemplate() async {

    final isEnglish = LocaleService.instance.isEnglish;

    final selected = await showDialog<String>(

      context: context,

      builder: (ctx) => SimpleDialog(

        title: Text(context.t('اختر مسار الرسالة', 'Choose thesis plan')),

        children: ThesisProgressTemplates.choices

            .map(

              (c) => SimpleDialogOption(

                onPressed: () => Navigator.pop(ctx, c.id),

                child: Text(isEnglish ? c.labelEn : c.labelAr),

              ),

            )

            .toList(),

      ),

    );

    if (selected == null) return;

    await ThesisProgressService.instance.applyTemplate(selected);

    await _load();

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AcadeGateAppBar(

        title: Text(context.t('تقدم الرسالة', 'Thesis progress')),

        backgroundColor: _brand,

        foregroundColor: Colors.white,

        actions: [

          IconButton(

            tooltip: context.t('تحديث ذكي', 'Smart refresh'),

            onPressed: _syncing ? null : _refreshSmart,

            icon: _syncing

                ? const SizedBox(

                    width: 20,

                    height: 20,

                    child: CircularProgressIndicator(

                      strokeWidth: 2,

                      color: Colors.white,

                    ),

                  )

                : const Icon(Icons.auto_awesome),

          ),

        ],

      ),

      floatingActionButton: FloatingActionButton.extended(

        onPressed: _addCustomItem,

        backgroundColor: _brand,

        icon: const Icon(Icons.add),

        label: Text(context.t('بند مخصص', 'Custom item')),

      ),

      body: _loading

          ? const Center(child: CircularProgressIndicator())

          : _buildBody(context, _progress!),

    );

  }



  Widget _buildBody(BuildContext context, ThesisProgress progress) {

    final step = _engine.nextStep(progress);

    final isEnglish = LocaleService.instance.isEnglish;



    return ListView(

      padding: const EdgeInsets.all(16),

      children: [

        Card(

          color: _brand.withValues(alpha: 0.06),

          child: Padding(

            padding: const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  '${progress.percent.toStringAsFixed(0)}%',

                  style: const TextStyle(

                    fontSize: 36,

                    fontWeight: FontWeight.bold,

                    color: _brand,

                  ),

                ),

                Text(

                  context.t(

                    '${progress.completedCount} من ${progress.items.length} مكتمل',

                    '${progress.completedCount} of ${progress.items.length} complete',

                  ),

                ),

                const SizedBox(height: 10),

                LinearProgressIndicator(

                  value: progress.items.isEmpty

                      ? 0

                      : progress.completedCount / progress.items.length,

                  minHeight: 8,

                  borderRadius: BorderRadius.circular(4),

                  color: _brand,

                ),

                const SizedBox(height: 10),

                Text(

                  ThesisProgressTemplates.label(progress.templateId, isEnglish),

                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),

                ),

                TextButton(

                  onPressed: _changeTemplate,

                  child: Text(context.t('تغيير المسار', 'Change plan')),

                ),

              ],

            ),

          ),

        ),

        const SizedBox(height: 12),

        Card(

          color: const Color(0xFF00695C).withValues(alpha: 0.08),

          child: Padding(

            padding: const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Row(

                  children: [

                    const Icon(Icons.lightbulb_outline, color: Color(0xFF00695C)),

                    const SizedBox(width: 8),

                    Expanded(

                      child: Text(

                        step.allComplete

                            ? context.t('أحسنت!', 'Well done!')

                            : context.t('الخطوة التالية', 'Next step'),

                        style: const TextStyle(

                          fontWeight: FontWeight.bold,

                          color: Color(0xFF00695C),

                        ),

                      ),

                    ),

                  ],

                ),

                const SizedBox(height: 8),

                Text(

                  step.advice.title(isEnglish),

                  style: const TextStyle(fontWeight: FontWeight.w600),

                ),

                const SizedBox(height: 6),

                Text(

                  step.advice.tip(isEnglish),

                  style: TextStyle(color: Colors.grey[800], height: 1.45),

                ),

                if (!step.allComplete) ...[

                  const SizedBox(height: 12),

                  FilledButton.icon(

                    onPressed: () async {

                      await ThesisProgressNavigation.openActivity(

                        context,

                        step.activityId,

                      );

                      await _refreshSmart();

                    },

                    style: FilledButton.styleFrom(

                      backgroundColor: const Color(0xFF00695C),

                    ),

                    icon: const Icon(Icons.arrow_forward),

                    label: Text(context.t('اذهب للخطوة', 'Go to step')),

                  ),

                ],

              ],

            ),

          ),

        ),

        const SizedBox(height: 16),

        Text(

          context.t(

            'البنود تُحدَّث تلقائياً عند استخدام أقسام التطبيق (✨) أو يدوياً (☑)',

            'Items update automatically when you use app sections (✨) or manually (☑)',

          ),

          style: TextStyle(fontSize: 12, color: Colors.grey[600]),

        ),

        const SizedBox(height: 12),

        ...progress.items.map((item) {

          return Card(

            child: CheckboxListTile(

              value: item.done,

              onChanged: (v) => _toggle(item, v ?? false),

              title: Row(

                children: [

                  Expanded(child: Text(item.title)),

                  if (item.autoTracked && item.done)

                    Tooltip(

                      message: context.t('اكتمل تلقائياً', 'Auto-completed'),

                      child: const Icon(Icons.auto_awesome, size: 16, color: Colors.teal),

                    ),

                  if (item.isCustom)

                    Padding(

                      padding: const EdgeInsets.only(left: 6),

                      child: Icon(Icons.edit_note, size: 16, color: Colors.grey[500]),

                    ),

                ],

              ),

              subtitle: item.dueDate != null

                  ? Text(

                      context.t(

                        'موعد: ${item.dueDate!.toLocal().toString().split(' ').first}',

                        'Due: ${item.dueDate!.toLocal().toString().split(' ').first}',

                      ),

                    )

                  : null,

              secondary: item.kind == ThesisItemKind.deadline

                  ? IconButton(

                      icon: const Icon(Icons.event),

                      onPressed: () => _pickDate(item),

                    )

                  : null,

            ),

          );

        }),

        const SizedBox(height: 64),

      ],

    );

  }

}



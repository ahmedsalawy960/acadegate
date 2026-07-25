import 'package:flutter/material.dart';



import '../../core/locale/locale_extensions.dart';

import '../../core/locale/locale_service.dart';

import 'thesis_progress.dart';

import 'thesis_progress_engine.dart';

import 'thesis_progress_screen.dart';



class ThesisProgressHomeCard extends StatefulWidget {

  const ThesisProgressHomeCard({super.key});



  @override

  State<ThesisProgressHomeCard> createState() => _ThesisProgressHomeCardState();

}



class _ThesisProgressHomeCardState extends State<ThesisProgressHomeCard> {

  ThesisProgress? _progress;

  String? _nextLine;



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    final progress = await ThesisProgressService.instance.load();

    if (!mounted) return;

    final isEnglish = LocaleService.instance.isEnglish;

    setState(() {

      _progress = progress;

      _nextLine = ThesisProgressEngine.instance.nextStepLine(progress, isEnglish);

    });

  }



  @override

  Widget build(BuildContext context) {

    final progress = _progress;

    if (progress == null) {

      return const SizedBox(

        height: 4,

        child: LinearProgressIndicator(),

      );

    }



    return Card(

      margin: const EdgeInsets.only(bottom: 16),

      child: InkWell(

        onTap: () async {

          await Navigator.push(

            context,

            MaterialPageRoute(

              builder: (_) => const ThesisProgressScreen(),

            ),

          );

          _load();

        },

        borderRadius: BorderRadius.circular(12),

        child: Padding(

          padding: const EdgeInsets.all(14),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                children: [

                  const Icon(Icons.timeline, color: Color(0xFF1A237E)),

                  const SizedBox(width: 8),

                  Expanded(

                    child: Text(

                      context.t('تقدم الرسالة', 'Thesis progress'),

                      style: const TextStyle(fontWeight: FontWeight.bold),

                    ),

                  ),

                  Text('${progress.percent.toStringAsFixed(0)}%'),

                ],

              ),

              const SizedBox(height: 8),

              LinearProgressIndicator(

                value: progress.items.isEmpty

                    ? 0

                    : progress.completedCount / progress.items.length,

                borderRadius: BorderRadius.circular(4),

                color: const Color(0xFF1A237E),

              ),

              if (_nextLine != null) ...[

                const SizedBox(height: 8),

                Text(

                  context.t('الخطوة التالية:', 'Next step:'),

                  style: TextStyle(

                    fontSize: 11,

                    fontWeight: FontWeight.bold,

                    color: Colors.grey[700],

                  ),

                ),

                Text(

                  _nextLine!,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.35),

                ),

              ],

              const SizedBox(height: 4),

              Text(

                context.t(

                  'تحديث ذكي من نشاطك في التطبيق',

                  'Smart sync from your app activity',

                ),

                style: TextStyle(fontSize: 11, color: Colors.grey[600]),

              ),

            ],

          ),

        ),

      ),

    );

  }

}



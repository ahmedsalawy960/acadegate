import 'thesis_progress.dart';
import 'thesis_progress_activity.dart';
import 'thesis_progress_signals.dart';

class ThesisProgressEngine {
  ThesisProgressEngine._();

  static final ThesisProgressEngine instance = ThesisProgressEngine._();

  final _signals = ThesisProgressSignals.instance;

  Future<ThesisProgress> syncFromApp(ThesisProgress progress) async {
    final signalMap = await _signals.collect(progress);
    final items = progress.items.map((item) {
      if (item.done || item.activityId == null) return item;
      if (signalMap[item.activityId!] == true) {
        return item.copyWith(done: true, autoTracked: true);
      }
      return item;
    }).toList();

    return progress.copyWithItems(items);
  }

  ThesisNextStep nextStep(ThesisProgress progress) {
    final pending = progress.items.where((i) => !i.done).toList();
    if (pending.isEmpty) {
      return ThesisNextStep.allDone();
    }

    final next = pending.first;
    final advice = ThesisActivityCatalog.adviceFor(next.activityId, next.title);

    return ThesisNextStep(
      itemTitle: next.title,
      activityId: next.activityId,
      advice: advice,
    );
  }

  String nextStepLine(ThesisProgress progress, bool isEnglish) {
    final step = nextStep(progress);
    if (step.allComplete) {
      return step.advice.tip(isEnglish);
    }
    return '${step.advice.title(isEnglish)} — ${step.advice.tip(isEnglish)}';
  }
}

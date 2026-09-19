import 'package:acadegate/features/ai_advisor/advisor_router.dart';
import 'package:acadegate/features/ai_advisor/advisor_agent.dart';
import 'package:acadegate/features/ai_advisor/catalog_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HPLC in Sharqia plus supervisor is a live catalog request', () {
    final intent = CatalogIntentParser.parse(
      'أريد HPLC في الشرقية + مشرف كيمياء تحليلية',
    );
    expect(intent.isCatalogRequest, isTrue);
    expect(intent.wantsLabs, isTrue);
    expect(intent.wantsSupervisors, isTrue);
    expect(intent.city, 'الشرقية');
    expect(intent.equipmentQuery.toUpperCase(), contains('HPLC'));
    expect(intent.supervisorQuery, contains('كيمياء'));
  });

  test('Zagazig is the same catalog city as Sharqia', () {
    final intent = CatalogIntentParser.parse(
      'I need HPLC in Zagazig and a supervisor',
    );
    expect(intent.city, 'الشرقية');
    expect(intent.wantsLabs, isTrue);
  });

  test('a methods question does not open the catalog', () {
    final intent = CatalogIntentParser.parse(
      'ما الفرق بين المنهج الكمي والنوعي في رسالة الماجستير؟',
    );
    expect(intent.isCatalogRequest, isFalse);
  });

  test('a supervisor-only match question stays on the match agent', () {
    expect(
      CatalogIntentParser.parse(
        'ما المشرف الأنسب لفكرتي في تحليل البيانات الزراعية؟',
      ).isCatalogRequest,
      isFalse,
    );
    expect(
      AdvisorRouter.instance
          .route('ما المشرف الأنسب لفكرتي في تحليل البيانات الزراعية؟')
          .primary,
      AdvisorAgentId.supervisorMatch,
    );
  });

  test('router sends catalog questions to the live catalog agent', () {
    final plan = AdvisorRouter.instance.route(
      'أريد HPLC في الشرقية ومشرف كيمياء تحليلية',
    );
    expect(plan.primary, AdvisorAgentId.catalogExecute);
  });
}

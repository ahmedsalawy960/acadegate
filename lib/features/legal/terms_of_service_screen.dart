import 'package:flutter/material.dart';

import '../../core/config/app_contact_info.dart';
import '../../core/locale/locale_extensions.dart';
import 'legal_doc_widgets.dart';

/// شروط استخدام المنصة — حسابات، متجر، Escrow، محتوى، ومسؤوليات.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return LegalDocScaffold(
      title: context.t('شروط الاستخدام', 'Terms of Service'),
      children: [
        LegalIntro(
          text: isAr
              ? 'باستخدامك AcadeGate («المنصة») فإنك توافق على هذه الشروط. إن لم توافق، يرجى عدم إنشاء حساب أو استخدام الخدمات المدفوعة/الحساسة.'
              : 'By using AcadeGate (“the Platform”) you agree to these Terms. If you do not agree, do not create an account or use paid/sensitive services.',
        ),
        LegalMeta(
          effectiveDate: isAr
              ? 'سريان: 16 سبتمبر 2026'
              : 'Effective: 16 September 2026',
          version: isAr ? 'الإصدار 1.1' : 'Version 1.1',
        ),
        LegalSection(
          title: isAr ? '1. طبيعة الخدمة' : '1. Nature of the service',
          body: isAr
              ? 'AcadeGate منصة رقمية عربية تربط رحلة الدراسات العليا والبحث: مشرفون، أفكار بحثية، مختبرات، متجر معدات، مساعدة واستشارة في الكتابة، مجتمع، والمساعد الأكاديمي. المنصة وسيط تقني؛ لسنا جامعة ولا جهة اعتماد أكاديمي رسمي ولا ضامناً لنتيجة بحثية أو قبول إشراف. لا نكتب البحث بدلاً من الباحث.'
              : 'AcadeGate is an Arabic digital platform connecting postgraduate and research journeys: supervisors, research ideas, labs, an equipment store, writing help and consultation, community, and an Academic Assistant. We are a technical intermediary—not a university, accreditation body, or guarantor of research outcomes or supervision acceptance. We do not write the research in place of the researcher.',
        ),
        LegalSection(
          title: isAr ? '2. الأهلية والحساب' : '2. Eligibility & accounts',
          body: isAr
              ? 'يجب أن تكون قادراً قانوناً على التعاقد في ولايتك. تقدّم معلومات صحيحة وتحافظ على سرية بيانات الدخول. أنت مسؤول عن النشاط عبر حسابك. لا يجوز إنشاء حساب مدير من التطبيق؛ أدوار الإدارة تُعيَّن داخلياً فقط. نحتفظ بتعليق أو إنهاء الحسابات المخالِفة.'
              : 'You must be legally able to contract in your jurisdiction. Provide accurate information and keep credentials confidential. You are responsible for activity on your account. Admin accounts cannot be self-created in the app; admin roles are assigned internally. We may suspend or terminate accounts that violate these Terms.',
        ),
        LegalSection(
          title: isAr ? '3. الأدوار والبوابات' : '3. Roles & portals',
          body: isAr
              ? 'قد تستخدم بوابة المستخدم و/أو بوابة مقدم الخدمة حسب دورك (طالب، مشرف، تاجر، مسؤول مختبر، ناشر أفكار…). صلاحيات النشر والطلبات تختلف حسب الدور وقواعد الاعتماد. المحتوى العام يظهر عادة بعد موافقة إدارية حيث ينطبق.'
              : 'You may use the user and/or provider portal according to your role (student, supervisor, merchant, lab manager, idea publisher…). Publishing and order permissions differ by role and approval rules. Public content usually appears only after admin approval where applicable.',
        ),
        LegalSection(
          title: isAr ? '4. المتجر والموردون' : '4. Store & suppliers',
          body: isAr
              ? 'المتجر سوق لمعدات ومستلزمات أكاديمية. البائعون مسؤولون عن دقة الأوصاف والأسعار والتوفر والجودة والشحن والامتثال للقوانين (بما فيها المواد المقيدة). قد تعرض المنصة بيانات دليلية عامة مستقاة من مواقع/كتالوجات معلنة؛ ذلك لا يعني موافقة الشركة أو اعتماد AcadeGate لها كمورد Partner ما لم تظهر حالة Partner صراحة. قوائم الدليل قد تحيلك للتواصل المباشر خارج الضمان. يمكنك الإبلاغ عن أخطاء البيانات من بطاقة المورد/المنتج.'
              : 'The store is a marketplace for academic equipment and supplies. Sellers are responsible for accurate descriptions, pricing, availability, quality, shipping, and legal compliance (including restricted materials). The Platform may show public directory data from published websites/catalogs; that does not mean company consent or AcadeGate Partner endorsement unless Partner status is shown. Directory listings may require direct contact outside escrow. You can report data errors from the supplier/product card.',
        ),
        LegalSection(
          title: isAr ? '5. الطلبات والدفع والضمان (Escrow)' : '5. Orders, payment & escrow',
          body: isAr
              ? 'عند إنشاء طلب متجر يُتحقق من السعر من سجلات المنصة. قد يكون الدفع عبر بوابة إلكترونية (مثل Paymob) أو تحويل يدوي. في نموذج الضمان تُحتجز المبالغ وفق حالة الدفع المعتمدة حتى تأكيد الاستلام أو الاسترداد وفق الإجراءات. التحويل اليدوي يعتمد على تأكيد البائع؛ المخاطر الإضافية لهذا المسار على عاتق الطرفين. النزاعات تُعالَج أولاً عبر الدعم والرسائل داخل المنصة.'
              : 'When a store order is created, price is verified against Platform records. Payment may be via an electronic gateway (e.g. Paymob) or manual transfer. Under escrow, funds are held per payment status until delivery confirmation or refund per procedures. Manual transfers rely on seller confirmation; extra risk of that path rests with the parties. Disputes should first use in-app support and messaging.',
        ),
        LegalSection(
          title: isAr ? '6. طلبات عرض السعر (RFQ)' : '6. RFQs',
          body: isAr
              ? 'طلبات عرض السعر غير ملزِمة حتى يُبرم اتفاق واضح بين المشتري والبائع (عبر طلب مدفوع أو تعاقد صريح). الردود والأسعار المقدّمة مسؤولية البائع.'
              : 'Quote requests are non-binding until a clear agreement is formed between buyer and seller (via a paid order or explicit contract). Quoted prices and responses are the seller’s responsibility.',
        ),
        LegalSection(
          title: isAr ? '7. المختبرات والكتابة والخدمات الأخرى' : '7. Labs, writing & other services',
          body: isAr
              ? 'حجوزات الأجهزة وطلبات التحليل ومساعدة الكتابة تخضع لشروط مقدم الخدمة المعروضة عند الطلب. المساعدة والاستشارة مراجعة وتوجيه وتدقيق لنص كتبه الباحث. لا يكتب التطبيق ولا مقدم الخدمة الرسالة أو البحث بدلاً من الباحث. الباحث مسؤول عن الأصالة والامتثال لقواعد جامعته.'
              : 'Equipment bookings, sample analysis, and writing help follow the provider’s terms shown at request. Help and consultation mean review, guidance, and proofreading of text the researcher wrote. Neither the app nor the provider writes the thesis or paper in place of the researcher. The researcher remains responsible for originality and institutional rules.',
        ),
        LegalSection(
          title: isAr ? '8. المساعد الأكاديمي' : '8. Academic Assistant',
          body: isAr
              ? 'مخرجات المساعد الأكاديمي إرشادية وقد تحتوي أخطاء. لا تعتمد عليها وحدها في قرارات أكاديمية أو طبية أو قانونية حرجة. أنت مسؤول عن مراجعة المحتوى قبل استخدامه في رسائل أو أبحاث.'
              : 'Academic Assistant outputs are guidance and may contain errors. Do not rely on them alone for critical academic, medical, or legal decisions. You must review content before using it in theses or research.',
        ),
        LegalSection(
          title: isAr ? '9. المحتوى والملكية الفكرية' : '9. Content & IP',
          body: isAr
              ? 'تحتفظ بحقوق محتواك. بمنحك ترخيصاً غير حصري للمنصة لعرضه وتشغيله وتأمينه ضمن الخدمة. تتعهد أن محتواك لا ينتهك حقوق الغير ولا يتضمن مواد محظورة أو مضللة. محتوى المنصة وعلاماتها التجارية ملك AcadeGate أو مرخّصيها.'
              : 'You retain rights to your content and grant the Platform a non-exclusive licence to host, display, and secure it for the service. You warrant your content does not infringe others’ rights or include prohibited/misleading material. Platform content and trademarks belong to AcadeGate or its licensors.',
        ),
        LegalSection(
          title: isAr ? '10. السلوك المحظور' : '10. Prohibited conduct',
          body: isAr
              ? 'يُحظر: الاحتيال أو التلاعب بالأسعار/الطلبات؛ بيع مواد محظورة أو خطرة دون تصريح؛ انتحال الهوية؛ التحرش؛ نشر برامج خبيثة؛ محاولة اختراق القواعد أو الحسابات؛ استخدام المنصة للغش الأكاديمي المنهجي؛ أو أي نشاط غير قانوني.'
              : 'Prohibited: fraud or order/price manipulation; selling banned/hazardous items without authorisation; impersonation; harassment; malware; attempting to bypass security rules or accounts; using the Platform for systematic academic cheating; or any unlawful activity.',
        ),
        LegalSection(
          title: isAr ? '11. الاعتدال والإيقاف' : '11. Moderation & suspension',
          body: isAr
              ? 'قد نراجع أو نرفض أو نعلّق أو نحذف محتوى وطلبات وحسابات لحماية المستخدمين والامتثال للقانون. قرارات الاعتماد الإداري نهائية ضمن حدود معقولة مع إمكانية التواصل مع الدعم.'
              : 'We may review, reject, suspend, or delete content, orders, and accounts to protect users and comply with law. Admin approval decisions are final within reason, with support contact available.',
        ),
        LegalSection(
          title: isAr ? '12. إخلاء المسؤولية' : '12. Disclaimers',
          body: isAr
              ? 'تُقدَّم الخدمة «كما هي» و«حسب التوفر» في حدود القانون. لا نضمن عدم الانقطاع أو خلوّها من الأخطاء أو ملاءمتها لغرض معيّن. العلاقات التعاقدية الأساسية للشراء والتحليل والكتابة تكون بينك وبين مقدم الخدمة ما لم يُنص صراحة على خلاف ذلك.'
              : 'The service is provided “as is” and “as available” to the extent permitted by law. We do not warrant uninterrupted or error-free operation or fitness for a particular purpose. Primary purchase/analysis/writing contracts are between you and the provider unless expressly stated otherwise.',
        ),
        LegalSection(
          title: isAr ? '13. تحديد المسؤولية' : '13. Limitation of liability',
          body: isAr
              ? 'إلى أقصى حد يسمح به القانون، لا نتحمل مسؤولية غير مباشرة أو تبعية أو فقدان أرباح/بيانات ناتج عن استخدام المنصة. مسؤوليتنا الإجمالية المرتبطة بطلب متجر معيّن لا تتجاوز عادة قيمة الرسوم التي حصّلتها المنصة عن ذلك الطلب إن وُجدت، مع استثناء حالات الغش أو الإهمال الجسيم حيث لا يجوز استبعادها قانوناً.'
              : 'To the fullest extent permitted by law, we are not liable for indirect, consequential, or lost-profit/data damages arising from Platform use. Our aggregate liability related to a given store order typically will not exceed fees we actually collected on that order, if any—except for fraud or gross negligence where exclusion is not allowed.',
        ),
        LegalSection(
          title: isAr ? '14. التعويض' : '14. Indemnity',
          body: isAr
              ? 'توافق على تعويض AcadeGate عن المطالبات الناشئة عن محتواك أو معاملاتك أو مخالفتك لهذه الشروط أو حقوق الغير، في حدود ما يسمح به القانون.'
              : 'You agree to indemnify AcadeGate against claims arising from your content, transactions, or breach of these Terms or third-party rights, to the extent permitted by law.',
        ),
        LegalSection(
          title: isAr ? '15. القانون والنزاعات' : '15. Governing law & disputes',
          body: isAr
              ? 'تخضع هذه الشروط لقوانين جمهورية مصر العربية ما لم يفرض قانون ملزم خلاف ذلك. يُسعى لحل النزاع ودياً عبر الدعم أولاً، ثم للجهات القضائية المختصة في مصر.'
              : 'These Terms are governed by the laws of the Arab Republic of Egypt unless mandatory law provides otherwise. Disputes should first seek amicable resolution via support, then competent Egyptian courts.',
        ),
        LegalSection(
          title: isAr ? '16. التعديلات' : '16. Changes',
          body: isAr
              ? 'قد نعدّل الشروط بنشر نسخة محدّثة داخل التطبيق. الاستمرار بعد السريان يعدّ قبولاً. إن لم توافق، توقف عن الاستخدام واطلب إغلاق الحساب.'
              : 'We may amend these Terms by publishing an updated version in the app. Continued use after the effective date constitutes acceptance. If you disagree, stop using the service and request account closure.',
        ),
        LegalSection(
          title: isAr ? '17. التواصل' : '17. Contact',
          body: isAr
              ? 'للاستفسارات: ${AppContactInfo.supportEmail} — أو صفحة المساعدة والدعم.'
              : 'Questions: ${AppContactInfo.supportEmail} — or Help & Support.',
        ),
      ],
    );
  }
}

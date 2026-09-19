import 'package:flutter/material.dart';

import '../../core/config/app_contact_info.dart';
import '../../core/locale/locale_extensions.dart';
import 'legal_doc_widgets.dart';
import 'privacy_rights_screen.dart';

/// سياسة خصوصية شاملة للمنصة (حسابات · متجر · Escrow · رسائل · AI).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return LegalDocScaffold(
      title: context.t('سياسة الخصوصية', 'Privacy Policy'),
      children: [
        LegalIntro(
          text: isAr
              ? 'توضح هذه السياسة كيف تجمع AcadeGate («المنصة»، «نحن») بياناتك الشخصية وتعالجها وتحميها عند استخدام التطبيق أو الخدمات المرتبطة به، بما في ذلك المتجر الأكاديمي، الضمان المالي (Escrow)، الرسائل، المجتمع، والمساعد الذكي.'
              : 'This policy explains how AcadeGate (“the Platform”, “we”) collects, processes, and protects your personal data when you use the app or related services, including the academic store, escrow payments, messaging, community, and the AI advisor.',
        ),
        LegalMeta(
          effectiveDate: isAr
              ? 'سريان: 16 سبتمبر 2026'
              : 'Effective: 16 September 2026',
          version: isAr ? 'الإصدار 2.1' : 'Version 2.1',
        ),
        LegalSection(
          title: isAr ? '1. المسؤول عن المعالجة' : '1. Data controller',
          body: isAr
              ? 'المسؤول عن معالجة البيانات الشخصية في إطار تشغيل المنصة هو مشروع AcadeGate. للاستفسارات المتعلقة بالخصوصية أو طلبات الحقوق راسلنا على ${AppContactInfo.supportEmail} أو عبر صفحة «المساعدة والدعم».'
              : 'The controller of personal data for operating the Platform is the AcadeGate project. For privacy questions or rights requests, contact ${AppContactInfo.supportEmail} or use Help & Support.',
        ),
        LegalSection(
          title: isAr ? '2. نطاق التطبيق' : '2. Scope',
          body: isAr
              ? 'تسري هذه السياسة على مستخدمي بوابة الباحث/الطالب وبوابة مقدم الخدمة والزوار الذين يتصفحون كمشاركين محدودين. قد تظهر بعض المحتويات العامة (منتجات معتمدة، ملفات مشرفين منشورة، منشورات مجتمع) لغير المسجّلين.'
              : 'This policy applies to user-portal and provider-portal accounts and to limited guest browsing. Some public content (approved products, published supervisor profiles, community posts) may be visible without signing in.',
        ),
        LegalSection(
          title: isAr ? '3. البيانات التي نجمعها' : '3. Data we collect',
          body: isAr
              ? '• بيانات الحساب: الاسم المعروض، البريد الإلكتروني، معرّف Firebase، الدور (طالب، مشرف، تاجر، مسؤول مختبر، ناشر أفكار…)، وتوكن الإشعارات عند التفعيل.\n'
                  '• الملف الأكاديمي: الجامعة، التخصص، الاهتمام البحثي، المدينة، المهارات، المنهجية، ولغة البحث — إن أدخلتها.\n'
                  '• بيانات المعاملات: طلبات المتجر، حالة الدفع والضمان، طلبات عرض السعر (RFQ)، حجوزات المختبر، طلبات الكتابة والإشراف، وعناوين/ملاحظات التسليم إن لزم الأمر.\n'
                  '• المحتوى الذي تنشره: منتجات، أفكار بحثية، منشورات وردود المجتمع، أسئلة المنتجات، ومرفقات المساعد الذكي.\n'
                  '• بيانات تقنية: نوع الجهاز/المنصة، سجلات أعطال وتشغيل أساسية، وعنوان IP عبر مزوّدي الاستضافة عند الاقتضاء.\n'
                  '• تسجيل الدخول الاجتماعي: عند استخدام Google أو Facebook أو Apple نستلم المعرّف الأساسي والبريد والاسم حسب إذن المزوّد.'
              : '• Account data: display name, email, Firebase UID, role (student, supervisor, merchant, lab manager, idea publisher…), and notification tokens when enabled.\n'
                  '• Academic profile: university, specialization, research interest, city, skills, methodology, and preferred language — if you provide them.\n'
                  '• Transaction data: store orders, payment/escrow status, RFQs, lab bookings, writing and supervision requests, and delivery notes when needed.\n'
                  '• Content you publish: products, research ideas, community posts/replies, product Q&A, and AI advisor attachments.\n'
                  '• Technical data: device/platform, basic crash/ops logs, and IP address via hosting providers where applicable.\n'
                  '• Social login: with Google, Facebook, or Apple we receive basic identity, email, and name as permitted by the provider.',
        ),
        LegalSection(
          title: isAr ? '4. أغراض المعالجة والأساس' : '4. Purposes and legal basis',
          body: isAr
              ? 'نعالج البيانات لـ: إنشاء الحساب وتأمينه؛ تقديم الخدمات الأكاديمية والتجارية؛ مطابقة المشرفين/المختبرات/المنتجات؛ تنفيذ طلبات المتجر والضمان؛ تمكين الرسائل والإشعارات؛ تشغيل المساعد الذكي؛ مراجعة المحتوى ومنع الإساءة؛ تحسين المنصة؛ والامتثال للالتزامات القانونية. الأساس يشمل تنفيذ العقد (تقديم الخدمة)، والمصلحة المشروعة (الأمان ومنع الاحتيال)، والموافقة حيث يطلبها القانون (مثل بعض استخدامات التسويق أو التحليلات غير الأساسية).'
              : 'We process data to: create and secure accounts; deliver academic and commerce services; match supervisors/labs/products; fulfil store orders and escrow; enable messaging and notifications; run the AI advisor; moderate content and prevent abuse; improve the Platform; and comply with law. Bases include contract performance, legitimate interests (security/fraud prevention), and consent where required (e.g. certain marketing or non-essential analytics).',
        ),
        LegalSection(
          title: isAr ? '5. المتجر والمدفوعات والضمان (Escrow)' : '5. Store, payments & escrow',
          body: isAr
              ? 'عند الشراء قد نعالج بيانات الطلب والمبلغ وطريقة الدفع وحالة الضمان (مثل قيد الانتظار / محجوز / مُفرج / مسترد). المدفوعات الإلكترونية تُعالَج عبر بوابات دفع مثل Paymob أو تحويل يدوي يُؤكدّه البائع وفق القواعد المعتمدة. لا نخزّن أرقام بطاقات كاملة داخل Firestore. بيانات التحويل اليدوي التي تتبادلها مع البائع تُعدّ مسؤولية الطرفين ضمن حدود المنصة.'
              : 'When you buy, we may process order details, amount, payment method, and escrow status (e.g. pending / held / released / refunded). Card payments are handled by gateways such as Paymob; manual transfers are confirmed by the seller under applicable rules. We do not store full card numbers in Firestore. Manual-transfer details you exchange with a seller remain the parties’ responsibility within Platform limits.',
        ),
        LegalSection(
          title: isAr ? '6. المساعد الذكي (AI)' : '6. AI advisor',
          body: isAr
              ? 'عند استخدام AcadeGate AI قد تُرسل أسئلتك والمرفقات (نص/صورة/PDF ضمن الحدود) إلى مزوّد نماذج ذكاء اصطناعي (مثل Google Gemini عبر Cloud Functions) لتوليد الردود. لا تستخدم هذه المدخلات لبيع بياناتك الشخصية لأطراف إعلانية. تجنّب رفع بيانات حساسة غير ضرورية (هويات مرضى، أسرار تجارية، بيانات قاصرين). قد تُحفظ المحادثات لحسابك المسجّل لتحسين التجربة.'
              : 'When you use AcadeGate AI, your prompts and attachments (text/image/PDF within limits) may be sent to an AI provider (e.g. Google Gemini via Cloud Functions) to generate replies. Inputs are not sold for advertising. Avoid uploading unnecessary sensitive data (patient identifiers, trade secrets, children’s data). Conversations may be stored for signed-in users to improve continuity.',
        ),
        LegalSection(
          title: isAr ? '7. المشاركة والمعالجون' : '7. Sharing & processors',
          body: isAr
              ? 'لا نبيع بياناتك الشخصية. قد نشارك بيانات ضرورية مع: Firebase / Google Cloud (مصادقة، قواعد بيانات، تخزين، دوال، إشعارات)؛ مزوّدي الدخول الاجتماعي؛ بوابات الدفع؛ ومزوّدي الدعم أو الاستضافة عند الحاجة التشغيلية. يظهر المحتوى العام للمستخدمين الآخرين حسب حالة الاعتماد والنشر. قد نكشف بيانات إذا طُلب قانوناً أو لحماية الحقوق والأمان.'
              : 'We do not sell your personal data. We may share necessary data with: Firebase / Google Cloud (auth, database, storage, functions, messaging); social login providers; payment gateways; and support/hosting vendors as needed. Public content is visible to other users per approval/publishing status. We may disclose data if required by law or to protect rights and safety.',
        ),
        LegalSection(
          title: isAr ? '8. النقل الدولي' : '8. International transfers',
          body: isAr
              ? 'قد تُعالَج بياناتك على خوادم خارج مصر عبر مزوّدي البنية السحابية. باستخدام المنصة تقرّ بإمكانية هذا النقل وفق عقود المزوّدين وضوابط الأمان المعمول بها.'
              : 'Your data may be processed on servers outside Egypt via cloud providers. By using the Platform you acknowledge such transfers under provider contracts and applicable security controls.',
        ),
        LegalSection(
          title: isAr ? '9. الاحتفاظ' : '9. Retention',
          body: isAr
              ? 'نحتفظ ببيانات الحساب والطلبات طالما الحساب نشط أو حسب ما يلزم لتقديم الخدمة ومنع الاحتيال والامتثال القانوني (مثل سجلات المعاملات). بعد طلب حذف الحساب نعطل الوصول ونحذف أو نُجهّل البيانات الشخصية حيث أمكن، مع الإبقاء على حد أدنى من السجلات غير الشخصية أو الملزمة قانوناً لفترة معقولة.'
              : 'We retain account and order data while the account is active or as needed to provide the service, prevent fraud, and meet legal duties (e.g. transaction records). After an account-deletion request we disable access and delete or anonymise personal data where feasible, keeping minimal non-personal or legally required records for a reasonable period.',
        ),
        LegalSection(
          title: isAr ? '10. الأمان' : '10. Security',
          body: isAr
              ? 'نستخدم مصادقة Firebase، وقواعد أمان Firestore وStorage، وتقييد العمليات الحساسة على الخادم حيث ينطبق. لا توجد منظومة أمان مطلقة؛ يرجى استخدام كلمة مرور قوية وعدم مشاركة حسابك.'
              : 'We use Firebase Authentication, Firestore and Storage security rules, and server-side controls for sensitive actions where applicable. No system is perfectly secure; use a strong password and do not share your account.',
        ),
        LegalSection(
          title: isAr ? '11. حقوقك' : '11. Your rights',
          body: isAr
              ? 'بحسب القانون المعمول به (بما في ذلك قانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020 حيث ينطبق) يمكنك طلب: الاطلاع، التصحيح، الحذف، تقييد المعالجة، أو الاعتراض على معالجة معيّنة. يمكنك تحديث ملفك داخل التطبيق، وحذف محتوى تملكه عند توفر الأداة، وإرسال طلب رسمي عبر شاشة «حقوق الخصوصية» أو ${AppContactInfo.supportEmail}. قد نطلب التحقق من هويتك قبل تنفيذ الطلبات.\n\nنسخة ويب ثابتة: ${AppContactInfo.privacyUrl}'
              : 'Subject to applicable law (including Egypt’s Personal Data Protection Law No. 151 of 2020 where it applies), you may request access, correction, deletion, restriction, or objection to certain processing. You can update your profile in-app, delete owned content where tools exist, and submit a formal request via the Privacy rights screen or ${AppContactInfo.supportEmail}. We may verify identity before fulfilling requests.\n\nStatic web copy: ${AppContactInfo.privacyUrl}',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyRightsScreen()),
            ),
            icon: const Icon(Icons.manage_accounts_outlined),
            label: Text(
              context.t('فتح طلب حقوق الخصوصية', 'Open privacy rights request'),
            ),
          ),
        ),
        LegalSection(
          title: isAr ? '12. الأطفال' : '12. Children',
          body: isAr
              ? 'المنصة موجّهة لطلاب الدراسات العليا والباحثين والمؤسسات. لا نجمع عن قصد بيانات أطفال دون السن القانوني للموافقة في ولايتك. إن علمت بإنشاء حساب لقاصر دون موافقة مناسبة، تواصل معنا لحذفه.'
              : 'The Platform targets postgraduate students, researchers, and institutions. We do not knowingly collect data from children below the age of digital consent in your jurisdiction. If you learn of an underage account without proper consent, contact us to remove it.',
        ),
        LegalSection(
          title: isAr ? '13. الروابط الخارجية' : '13. Third-party links',
          body: isAr
              ? 'قد تحتوي المنصة على روابط لمواقع موردين أو مصادر علمية. سياسات تلك المواقع منفصلة ولسنا مسؤولين عن ممارساتها.'
              : 'The Platform may link to supplier or scientific sites. Their policies are separate and we are not responsible for their practices.',
        ),
        LegalSection(
          title: isAr ? '14. التحديثات' : '14. Updates',
          body: isAr
              ? 'قد نحدّث هذه السياسة. تاريخ السريان والإصدار يظهران أعلى الصفحة. استمرار الاستخدام بعد النشر يعني الاطلاع على النسخة المحدّثة. للتغييرات الجوهرية قد نعرض إشعاراً داخل التطبيق عند الإمكان.'
              : 'We may update this policy. The effective date and version appear above. Continued use after publication means you have reviewed the update. For material changes we may show an in-app notice when feasible.',
        ),
        LegalSection(
          title: isAr ? '15. التواصل' : '15. Contact',
          body: isAr
              ? 'البريد: ${AppContactInfo.supportEmail}\nأو عبر «المساعدة والدعم» في التذييل.'
              : 'Email: ${AppContactInfo.supportEmail}\nor Help & Support in the app footer.',
        ),
      ],
    );
  }
}

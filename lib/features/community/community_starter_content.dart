import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../moderation/approval_status.dart';
import 'community_data.dart';

/// One official starter post. Arabic and English texts are stored together
/// in one post, Arabic first.
class StarterPost {
  const StarterPost({
    required this.id,
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.tags,
  });

  final String id;
  final String type;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final List<String> tags;

  String get title => '$titleAr | $titleEn';
  String get body => '$bodyAr\n\n———\n\n$bodyEn';
}

/// One official study circle (with its linked open research room).
class StarterCircle {
  const StarterCircle({
    required this.id,
    required this.roomId,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
  });

  final String id;
  final String roomId;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;

  String get title => '$titleAr | $titleEn';
  String get description => '$descriptionAr\n\n$descriptionEn';
}

const String kStarterAuthorName = 'فريق AcadeGate | AcadeGate Team';

const List<StarterPost> kStarterPosts = [
  StarterPost(
    id: 'starter_welcome',
    type: CommunityPostType.discussion,
    titleAr: 'أهلاً بك في مجتمع AcadeGate الأكاديمي',
    titleEn: 'Welcome to the AcadeGate academic community',
    bodyAr:
        r'''هذا المكان للباحثين وطلاب الدراسات العليا من كل الكليات: اسأل، شارك خبرتك، وتعرّف على زملاء في تخصصك.
كيف تستفيد منه:
1. اختر غرفة كليتك، أو اكتب في «الجميع» لو سؤالك عام.
2. اكتب عنواناً واضحاً يشرح المشكلة في جملة واحدة.
3. اذكر ما جرّبته بالفعل، وإن أمكن رابط المصدر (DOI أو رابط https).
4. لا تنشر بيانات شخصية أو بيانات مرضى أو ملفات غير منشورة.
5. احترم زملاءك. المنشورات تُراجع قبل ظهورها، ويمكنك الإبلاغ عن أي محتوى غير مناسب.
الأبحاث والكتابة تبقى عملك أنت، والمجتمع هنا ليساعدك بالنقاش والخبرة.''',
    bodyEn:
        r'''This is a place for researchers and postgraduate students from every faculty: ask, share what you know, and meet peers in your field.
How to use it:
1. Pick your faculty room, or post to "Everyone" if your question is general.
2. Write a clear title that states the problem in one sentence.
3. Say what you already tried and, if you can, link the source (a DOI or an https link).
4. Do not post personal data, patient data or unpublished files.
5. Be kind. Posts are reviewed before they appear, and you can report anything inappropriate.
Your research and your writing stay yours. The community is here to help through discussion and experience.''',
    tags: ['ترحيب', 'بداية', 'welcome'],
  ),
  StarterPost(
    id: 'starter_journal_experience',
    type: CommunityPostType.question,
    titleAr: 'شاركنا تجربتك مع النشر في مجلة: المدة، الرسوم، جودة المراجعة',
    titleEn:
        'Share your journal experience: time to decision, fees, review quality',
    bodyAr:
        r'''اختيار المجلة المناسبة أصعب من كتابة البحث أحياناً. لو نشرت أو قدّمت لمجلة، شاركنا باختصار:
- اسم المجلة والتخصص
- المدة من التقديم حتى القرار الأول
- هل هناك رسوم نشر؟ كم تقريباً؟
- جودة تعليقات المحكّمين
- نصيحة واحدة لمن سيقدّم بعدك
هذه تجارب شخصية وليست تقييماً رسمياً للمجلة. تأكد دائماً من تعليمات المجلة نفسها قبل التقديم.''',
    bodyEn:
        r'''Choosing the right journal can be harder than writing the paper. If you have submitted to a journal, tell us briefly:
- Journal name and field
- Time from submission to first decision
- Publication fees, and roughly how much
- Quality of the reviewers' comments
- One tip for the next author
These are personal experiences, not an official rating. Always check the journal's own instructions before you submit.''',
    tags: ['نشر', 'مجلات', 'journal experience'],
  ),
  StarterPost(
    id: 'starter_thesis_tips',
    type: CommunityPostType.discussion,
    titleAr: 'نصائح الرسالة: ما الذي تتمنى لو عرفته في أول سنة؟',
    titleEn: 'Thesis tips: what do you wish you had known in your first year?',
    bodyAr:
        r'''اكتب نصيحة واحدة عن رسالتك (ماجستير أو دكتوراه) تتمنى لو سمعتها مبكراً: التعامل مع المشرف، تنظيم المراجع، إدارة الوقت، الاستعداد للمناقشة، أو أي شيء آخر.
نصيحة قصيرة ومحددة تفيد أكثر من نصيحة عامة. وإذا كنت في بداية الطريق، اكتب سؤالك هنا وسيرد عليك من مرّ بنفس المرحلة.''',
    bodyEn:
        r'''Share one tip about your master's or PhD thesis that you wish you had heard early: working with your supervisor, organizing references, managing time, preparing for the defense, or anything else.
A short, specific tip helps more than a general one. If you are just starting, post your question here and someone who has been through it will answer.''',
    tags: ['رسالة', 'نصائح', 'thesis tips'],
  ),
];

const List<StarterCircle> kStarterCircles = [
  StarterCircle(
    id: 'starter_circle_literature_review',
    roomId: 'starter_room_literature_review',
    titleAr: 'نكتب مراجعة الأدبيات معاً',
    titleEn: 'Writing the literature review together',
    descriptionAr:
        'مجموعة أسبوعية صغيرة لمن يكتب مراجعة الأدبيات في رسالته أو بحثه. كل عضو يشارك خطوة من عمله (سؤال البحث، خريطة المصادر، مقارنة الدراسات) ونتبادل الملاحظات. الكتابة تبقى لصاحبها، والمجموعة للنقاش وتبادل الخبرة.',
    descriptionEn:
        'A small weekly group for anyone writing the literature review of a thesis or paper. Members share one step of their own work (research question, source map, comparing studies) and swap feedback. The writing stays with its author; the group is for discussion and shared experience.',
  ),
  StarterCircle(
    id: 'starter_circle_statistics_hour',
    roomId: 'starter_room_statistics_hour',
    titleAr: 'مساعدة الإحصاء: اسأل عن تحليل نتائجك',
    titleEn: 'Statistics help: ask about analyzing your results',
    descriptionAr:
        'مكان لأسئلة اختيار الاختبار الإحصائي وتفسير النتائج وتجهيز البيانات. اذكر نوع بياناتك وسؤال بحثك وما جرّبته، ويشارك الأعضاء خبرتهم. القرار الإحصائي النهائي مسؤولية الباحث ومشرفه.',
    descriptionEn:
        "A place for questions about choosing a statistical test, interpreting results and preparing data. Say what kind of data you have, your research question and what you tried, and members share their experience. The final statistical decision is the researcher's and the supervisor's responsibility.",
  ),
  StarterCircle(
    id: 'starter_circle_academic_writing',
    roomId: 'starter_room_academic_writing',
    titleAr: 'الكتابة الأكاديمية: نراجع فقراتنا معاً',
    titleEn: 'Academic writing: reviewing our paragraphs together',
    descriptionAr:
        'مجموعة صغيرة لتبادل الملاحظات على الكتابة الأكاديمية. كل عضو يشارك فقرة من كتابته (مقدمة، مراجعة أدبيات، مناقشة) ويقول ما يريد تحسينه: الوضوح، الترتيب، أو الأسلوب. نعلّق على بعضنا باحترام. الكتابة تبقى لصاحبها، والمجموعة للملاحظات وتبادل الخبرة.',
    descriptionEn:
        'A small group for swapping feedback on academic writing. Members share a paragraph of their own (an introduction, a literature review, a discussion) and say what they want to improve: clarity, structure or style. We comment on each other respectfully. The writing stays with its author; the group is for feedback and shared experience.',
  ),
  StarterCircle(
    id: 'starter_circle_start_research',
    roomId: 'starter_room_start_research',
    titleAr: 'ابدأ بحثك: أفكار وأسئلة بحثية',
    titleEn: 'Start your research: ideas and research questions',
    descriptionAr:
        'مكان لمن يبدأ بحثه ويريد تحويل فكرة عامة إلى سؤال بحثي واضح. اكتب مجالك وما يشغلك، وما قرأته حتى الآن، ويشارك الأعضاء أسئلتهم وخبرتهم. اختيار الموضوع النهائي قرارك أنت ومشرفك.',
    descriptionEn:
        'A place for anyone starting a study who wants to turn a general idea into a clear research question. Say your field, what interests you and what you have read so far, and members share their questions and experience. The final choice of topic is yours and your supervisor\'s.',
  ),
];

class StarterSeedResult {
  const StarterSeedResult({
    this.postsCreated = 0,
    this.postsApproved = 0,
    this.postsSkipped = 0,
    this.circlesCreated = 0,
    this.circlesSkipped = 0,
  });

  final int postsCreated;
  final int postsApproved;
  final int postsSkipped;
  final int circlesCreated;
  final int circlesSkipped;
}

/// Creates the official starter posts (approved) and study circles.
///
/// Admin only: the screen that calls it sits behind AdminAccessGate and the
/// Firestore rules decide on every write. Every item has a fixed document id,
/// so running it again never duplicates anything and never overrides an
/// admin decision (an item that was rejected or deleted-and-recreated by hand
/// is left alone).
class CommunityStarterSeeder {
  CommunityStarterSeeder._();

  static final CommunityStarterSeeder instance = CommunityStarterSeeder._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<StarterSeedResult> seed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('not signed in');
    }

    var postsCreated = 0;
    var postsApproved = 0;
    var postsSkipped = 0;
    for (final post in kStarterPosts) {
      final ref = _db.collection('community_posts').doc(post.id);
      final snap = await ref.get();
      if (!snap.exists) {
        // Same shape the normal "new post" form writes, so the create rule
        // (status must be pending) accepts it; approval is a second step.
        await ref.set({
          'roomId': 'general',
          'type': post.type,
          'title': post.title,
          'body': post.body,
          'authorId': user.uid,
          'authorName': kStarterAuthorName,
          'tags': post.tags,
          'upvotesCount': 0,
          'repliesCount': 0,
          'approvalStatus': ApprovalStatus.pending,
          'audienceScope': PostAudienceScope.app,
          'isStarterContent': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        postsCreated++;
      } else if (snap.data()?['isStarterContent'] == true &&
          snap.data()?['approvalStatus'] == ApprovalStatus.pending) {
        // A previous run stopped between create and approve: finish it.
      } else {
        postsSkipped++;
        continue;
      }
      await ref.update({
        'approvalStatus': ApprovalStatus.approved,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      postsApproved++;
    }

    var circlesCreated = 0;
    var circlesSkipped = 0;
    for (final circle in kStarterCircles) {
      final circleRef = _db.collection('study_circles').doc(circle.id);
      if ((await circleRef.get()).exists) {
        circlesSkipped++;
        continue;
      }
      final roomRef = _db.collection('research_rooms').doc(circle.roomId);
      if (!(await roomRef.get()).exists) {
        await roomRef.set({
          'title': 'غرفة: ${circle.title}',
          'description': circle.description,
          'creatorId': user.uid,
          'creatorName': kStarterAuthorName,
          'isPasswordProtected': false,
          'discussionsCount': 0,
          'membersCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await roomRef.collection('members').doc(user.uid).set({
          'role': 'owner',
          'grantedAt': FieldValue.serverTimestamp(),
          'method': 'create',
        });
      }
      // The circle is written last, so a failed run is retried from here.
      await circleRef.set({
        'title': circle.title,
        'description': circle.description,
        'facultyCategory': '',
        'specialization': '',
        'researchInterest': '',
        'creatorId': user.uid,
        'creatorName': kStarterAuthorName,
        'researchRoomId': circle.roomId,
        'membersCount': 1,
        'isStarterContent': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await circleRef.collection('members').doc(user.uid).set({
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      circlesCreated++;
    }

    return StarterSeedResult(
      postsCreated: postsCreated,
      postsApproved: postsApproved,
      postsSkipped: postsSkipped,
      circlesCreated: circlesCreated,
      circlesSkipped: circlesSkipped,
    );
  }
}

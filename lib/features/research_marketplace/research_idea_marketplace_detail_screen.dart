import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
import '../academic/academic_models.dart';
import '../moderation/delete_content_button.dart';
import '../research_fund/research_fund_models.dart';
import '../research_supply_chain/research_supply_chain_screen.dart';
import '../topic_bank/topic_adoption_screen.dart';
import 'research_idea_favorites_service.dart';
import 'research_marketplace_service.dart';
import 'submit_proposal_screen.dart';

String _degreeLevelLabel(BuildContext context, String level) {
  switch (level.toLowerCase()) {
    case 'phd':
      return context.t('دكتوراه', 'PhD');
    case 'masters':
      return context.t('ماجستير', 'Master\'s');
    case 'both':
      return context.t('ماجستير أو دكتوراه', 'Master\'s or PhD');
    default:
      return level;
  }
}

class ResearchIdeaMarketplaceDetailScreen extends StatefulWidget {
  final AcademicResearchIdea idea;

  const ResearchIdeaMarketplaceDetailScreen({
    super.key,
    required this.idea,
  });

  @override
  State<ResearchIdeaMarketplaceDetailScreen> createState() =>
      _ResearchIdeaMarketplaceDetailScreenState();
}

class _ResearchIdeaMarketplaceDetailScreenState
    extends State<ResearchIdeaMarketplaceDetailScreen> {
  bool _isVoting = false;
  bool _isPublisher = false;
  bool _claimLoading = false;
  bool _hasVoted = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!widget.idea.isFromFirebase) return;
    final ideaId = (widget.idea.id ?? '').trim();
    if (ideaId.isEmpty) return;
    try {
      final results = await Future.wait([
        ResearchMarketplaceService.instance.isIdeaPublisher(ideaId),
        ResearchMarketplaceService.instance.hasUserVoted(ideaId).first,
      ]);
      if (!mounted) return;
      setState(() {
        _isPublisher = results[0];
        _hasVoted = results[1];
      });
    } catch (_) {
      // Ignore bootstrap failures — vote/claim still usable.
    }
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleVote() async {
    if (_isVoting) return;
    if (!widget.idea.isFromFirebase || (widget.idea.id ?? '').isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'التصويت غير متاح لهذه الفكرة',
            'Voting is not available for this idea',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isVoting = true);
    try {
      await ResearchMarketplaceService.instance.toggleVote(widget.idea);
      if (!mounted) return;
      setState(() => _hasVoted = !_hasVoted);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _claimTopic() async {
    setState(() => _claimLoading = true);
    try {
      await ResearchMarketplaceService.instance.claimIdea(widget.idea);
      if (!mounted) return;
      final openPath = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('تم اختيار الموضوع', 'Topic claimed')),
          content: Text(context.t(
            'أصبح الموضوع ملكك. هل تريد بناء مسار البحث الذكي الآن '
            '(مشرف · مختبر · متجر · كتابة · AI)؟',
            'The topic is now yours. Build the smart research path now '
            '(supervisor · lab · store · writing · AI)?',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('لاحقاً', 'Later')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.t('مسار البحث الذكي', 'Smart research path')),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (openPath == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ResearchSupplyChainScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'تم اختيار الموضوع — يمكنك فتح مسار البحث الذكي من الصفحة الرئيسية',
              'Topic claimed — open Smart Research Path from home anytime',
            )),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _claimLoading = false);
    }
  }

  Future<void> _releaseTopic() async {
    setState(() => _claimLoading = true);
    try {
      await ResearchMarketplaceService.instance.releaseIdea(widget.idea);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'تم إلغاء حجز الموضوع — أصبح متاحاً للآخرين',
            'Topic released — it is available for others again',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _claimLoading = false);
    }
  }

  Future<void> _openProposalForm() async {
    if (!widget.idea.isFromFirebase) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'التقديم متاح للأفكار المضافة في Firebase. انشر فكرة جديدة من زر (+).',
            'Submission is available for Firebase ideas. Publish a new idea with (+).',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitProposalScreen(idea: widget.idea),
      ),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'تم إرسال مقترحك بنجاح',
            'Your proposal was submitted successfully',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _respondProposal(String proposalId, {required bool accept}) async {
    try {
      await ResearchMarketplaceService.instance.respondToProposal(
        ideaId: widget.idea.id!,
        proposalId: proposalId,
        accept: accept,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept
                ? context.t('تم قبول المقترح', 'Proposal accepted')
                : context.t('تم رفض المقترح', 'Proposal rejected')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.idea.isFromFirebase) {
      return _buildScaffold(context, widget.idea);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('research_ideas')
          .doc(widget.idea.id)
          .snapshots(),
      builder: (context, snapshot) {
        AcademicResearchIdea idea = widget.idea;
        try {
          final doc = snapshot.data;
          if (doc != null && doc.exists) {
            final data = doc.data();
            if (data != null) {
              idea = AcademicResearchIdea.fromMap(data, id: doc.id);
            }
          }
        } catch (_) {
          idea = widget.idea;
        }
        return _buildScaffold(context, idea);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, AcademicResearchIdea idea) {
    final canInteract = idea.isFromFirebase && idea.isPubliclyVisible;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMyClaim = idea.claimedBy.isNotEmpty && idea.claimedBy == uid;
    final canClaim = canInteract && idea.isAvailableForClaim && uid.isNotEmpty;
    final canRelease = canInteract &&
        idea.isClaimed &&
        (isMyClaim || _isPublisher);

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('تفاصيل الفكرة', 'Idea details')),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          if ((idea.id ?? '').isNotEmpty) _FavoriteIdeaButton(idea: idea),
          ...deleteAppBarActions(
            collection: 'research_ideas',
            documentId: idea.id,
            ownerId: idea.publisherId,
            itemLabel: idea.title,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    idea.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    idea.provider,
                    style: TextStyle(color: const Color(0xFFB7C3D6), fontSize: 15),
                  ),
                  if (idea.titleEn.isNotEmpty &&
                      idea.titleEn.trim() != idea.title.trim()) ...[
                    const SizedBox(height: 6),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        idea.titleEn,
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFB7C3D6),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(idea.isClaimed
                            ? context.t('تم اختياره', 'Claimed')
                            : idea.isOpen
                                ? context.t('مفتوحة للتقديم', 'Open for submission')
                                : context.t('مغلقة', 'Closed')),
                        backgroundColor: idea.isClaimed
                            ? Colors.blue.withValues(alpha: 0.12)
                            : idea.isOpen
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.12),
                      ),
                      if (idea.isClaimed && idea.claimedByName.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.person, size: 16),
                          label: Text(
                            isMyClaim
                                ? context.t('اخترته أنت', 'Claimed by you')
                                : context.t(
                                    'اختيار: ${idea.claimedByName}',
                                    'Claimed by ${idea.claimedByName}',
                                  ),
                          ),
                          backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                        ),
                      Chip(
                        label: Text(context.t(
                          '${idea.votesCount} تصويت',
                          '${idea.votesCount} votes',
                        )),
                      ),
                      Chip(
                        label: Text(context.t(
                          '${idea.proposalsCount} مقترح',
                          '${idea.proposalsCount} proposals',
                        )),
                      ),
                      if (idea.budget.isNotEmpty)
                        Chip(label: Text(idea.budget)),
                      if (idea.degreeLevel.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.school_outlined, size: 16),
                          label: Text(_degreeLevelLabel(context, idea.degreeLevel)),
                          backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                        ),
                      if (idea.isSyncedImport)
                        Chip(
                          avatar: const Icon(Icons.cloud_sync_outlined, size: 16),
                          label: Text(context.t('مزامنة حية', 'Live sync')),
                          backgroundColor: Colors.teal.withValues(alpha: 0.12),
                        ),
                      if (canInteract)
                        _FundEligibilityChip(idea: idea),
                    ],
                  ),
                  if (idea.sourceUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _openSource(idea.sourceUrl),
                      icon: const Icon(Icons.link),
                      label: Text(context.t(
                        'المصدر الأصلي',
                        'Original source',
                      )),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    context.t('وصف المشكلة:', 'Problem description:'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(idea.details, style: const TextStyle(height: 1.5)),
                  if (idea.summaryEn.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          context.t(
                            'الملخص الأصلي بلغة المصدر',
                            'Original source abstract',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                idea.summaryEn,
                                style: const TextStyle(
                                  height: 1.5,
                                  color: Color(0xFFB7C3D6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _GroundedIdeaSections(
                    idea: idea,
                    onOpenUrl: _openSource,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: const Color(0xFF3A2E14),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x33EF6C00),
                        foregroundColor: Color(0xFFEF6C00),
                        child: Icon(Icons.fact_check_outlined),
                      ),
                      title: Text(
                        context.t(
                          'فحص التكرار واعتماد النقطة',
                          'Duplication check & adopt point',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF4F7FB),
                        ),
                      ),
                      subtitle: Text(
                        context.t(
                          'تشابه تقريبي · دراسات سابقة (يشمل Scholar) · أسئلة · حجز — بدون إلزام DOI',
                          'Approx. similarity · prior studies (incl. Scholar) · questions · claim — DOI not required',
                        ),
                        style: const TextStyle(color: Color(0xFFB7C3D6)),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Color(0xFFB7C3D6),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TopicAdoptionScreen(idea: idea),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x331A237E),
                        foregroundColor: Color(0xFF9FA8DA),
                        child: Icon(Icons.account_tree_outlined),
                      ),
                      title: Text(
                        context.t(
                          'ابنِ مسار البحث من هذه الفكرة',
                          'Build the research path from this idea',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF4F7FB),
                        ),
                      ),
                      subtitle: Text(
                        context.t(
                          'مشرف · مختبر · متجر · كتابة · خطة فصلية — تبدأ من عنوان الفكرة',
                          'Supervisor · lab · store · writing · semester plan — starting from the idea title',
                        ),
                        style: const TextStyle(color: Color(0xFFB7C3D6)),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Color(0xFFB7C3D6),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResearchSupplyChainScreen(
                              initialGoal: idea.title,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x3300695C),
                        foregroundColor: Color(0xFF4DB6AC),
                        child: Icon(Icons.share_outlined),
                      ),
                      title: Text(
                        context.t('شارك الفكرة', 'Share this idea'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF4F7FB),
                        ),
                      ),
                      subtitle: Text(
                        context.t(
                          'العنوان + نقطة انتهاء الدراسة + رابط الورقة',
                          'Title + where the study ended + paper link',
                        ),
                        style: const TextStyle(color: Color(0xFFB7C3D6)),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: Color(0xFFB7C3D6),
                      ),
                      onTap: () {
                        final link =
                            (idea.sourcePaper?.bestUrl.isNotEmpty == true)
                                ? idea.sourcePaper!.bestUrl
                                : idea.sourceUrl;
                        final parts = <String>[
                          context.t(
                            'فكرة بحثية من أكاديجيت:',
                            'Research idea from AcadeGate:',
                          ),
                          idea.title,
                          if (idea.titleEn.isNotEmpty &&
                              idea.titleEn.trim() != idea.title.trim())
                            idea.titleEn,
                          if (idea.whereItEndedQuote.isNotEmpty)
                            '"${idea.whereItEndedQuote}"',
                          if (link.isNotEmpty) link,
                        ];
                        SharePlus.instance.share(
                          ShareParams(text: parts.join('\n')),
                        );
                      },
                    ),
                  ),
                  if (idea.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: idea.tags
                          .map((tag) => Chip(label: Text(tag)))
                          .toList(),
                    ),
                  ],
                  if (!canInteract) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(context.t(
                        'هذه فكرة تجريبية. للتصويت والتقديم، أضف أفكاراً في Firebase أو انشر فكرة جديدة.',
                        'This is a demo idea. To vote and submit, add ideas in Firebase or publish a new one.',
                      )),
                    ),
                  ],
                  ManageContentActions(
                    collection: 'research_ideas',
                    documentId: idea.id,
                    ownerId: idea.publisherId,
                    itemLabel: idea.title,
                  ),
                  if (canInteract) ...[
                    const SizedBox(height: 24),
                    Text(
                      context.t('المقترحات المقدمة:', 'Submitted proposals:'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<ResearchProposal>>(
                      stream: ResearchMarketplaceService.instance
                          .proposalsStream(idea.id!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final proposals = snapshot.data ?? [];
                        if (proposals.isEmpty) {
                          return Text(context.t(
                            'لا توجد مقترحات بعد — كن الأول!',
                            'No proposals yet — be the first!',
                          ));
                        }

                        return Column(
                          children: proposals
                              .map(
                                (proposal) => Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    title: Text(
                                      proposal.authorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      proposal.summary,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: _isPublisher &&
                                            proposal.status == 'pending'
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: context.t('قبول', 'Accept'),
                                                icon: const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                ),
                                                onPressed: () =>
                                                    _respondProposal(
                                                  proposal.id!,
                                                  accept: true,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: context.t('رفض', 'Reject'),
                                                icon: const Icon(
                                                  Icons.cancel,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    _respondProposal(
                                                  proposal.id!,
                                                  accept: false,
                                                ),
                                              ),
                                            ],
                                          )
                                        : _ProposalStatusBadge(
                                            status: proposal.status,
                                          ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canClaim || canRelease) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _claimLoading
                            ? null
                            : (canRelease ? _releaseTopic : _claimTopic),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              canRelease ? const Color(0xFFB7C3D6) : const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _claimLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(canRelease ? Icons.lock_open : Icons.bookmark_add),
                        label: Text(
                          canRelease
                              ? context.t('إلغاء حجز الموضوع', 'Release topic claim')
                              : context.t('اختيار هذا الموضوع (حجز حصري)', 'Claim this topic (exclusive)'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: !canInteract ||
                                  _isVoting ||
                                  !idea.isOpen ||
                                  idea.isClaimed
                              ? null
                              : _toggleVote,
                          icon: _isVoting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _hasVoted
                                      ? Icons.thumb_up_alt
                                      : Icons.thumb_up_alt_outlined,
                                ),
                          label: Text(
                            _hasVoted
                                ? context.t('إلغاء التصويت', 'Remove vote')
                                : context.t('صوّت', 'Vote'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: idea.isOpen && !idea.isClaimed
                              ? _openProposalForm
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.send),
                          label: Text(
                            context.t('قدّم مقترحك', 'Submit your proposal'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalStatusBadge extends StatelessWidget {
  final String status;

  const _ProposalStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'accepted' => context.t('مقبول', 'Accepted'),
      'rejected' => context.t('مرفوض', 'Rejected'),
      _ => context.t('قيد المراجعة', 'Under review'),
    };

    final color = switch (status) {
      'accepted' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}

class _FundEligibilityChip extends StatelessWidget {
  final AcademicResearchIdea idea;

  const _FundEligibilityChip({required this.idea});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ResearchFundConfig>(
      stream: ResearchFundService.instance.watchConfig(),
      builder: (context, configSnap) {
        final config = configSnap.data ?? const ResearchFundConfig();
        if (!config.isConfigured) return const SizedBox.shrink();

        if (idea.funded) {
          final amount = idea.fundedAmount;
          final label = amount != null
              ? context.t(
                  'ممولة · $amount ${idea.fundedCurrency}',
                  'Funded · $amount ${idea.fundedCurrency}',
                )
              : context.t('ممولة', 'Funded');
          return Chip(
            avatar: const Icon(Icons.volunteer_activism, size: 16),
            label: Text(label),
            backgroundColor: const Color(0xFFBF360C).withValues(alpha: 0.12),
          );
        }

        if (idea.votesCount >= config.minVotes) {
          return Chip(
            avatar: const Icon(Icons.star_outline, size: 16),
            label: Text(context.t('مؤهلة للتمويل', 'Fund eligible')),
            backgroundColor: Colors.amber.withValues(alpha: 0.15),
          );
        }

        final remaining = (config.minVotes - idea.votesCount).clamp(0, config.minVotes);
        return Chip(
          avatar: const Icon(Icons.trending_up, size: 16),
          label: Text(context.t(
            '${idea.votesCount}/${config.minVotes} للتمويل · يتبقى $remaining',
            '${idea.votesCount}/${config.minVotes} to fund · $remaining left',
          )),
          backgroundColor: Colors.blueGrey.withValues(alpha: 0.1),
        );
      },
    );
  }
}

/// أقسام الفكرة المؤصلة (Phase 2): بطاقة «من حيث انتهت الدراسة»، وسوم
/// الأولويات القومية بمبرراتها، الدليل بلغة الواجهة، ومراجع البداية.
class _GroundedIdeaSections extends StatelessWidget {
  final AcademicResearchIdea idea;
  final Future<void> Function(String url) onOpenUrl;

  const _GroundedIdeaSections({
    required this.idea,
    required this.onOpenUrl,
  });

  static const _priorityLabels = <String, List<String>>{
    'water': ['المياه', 'Water'],
    'energy': ['الطاقة', 'Energy'],
    'agriculture': ['الزراعة', 'Agriculture'],
    'health': ['الصحة', 'Health'],
    'industry': ['الصناعة', 'Industry'],
    'digital': ['التحول الرقمي', 'Digital transformation'],
    'education': ['التعليم', 'Education'],
  };

  String _priorityLabel(BuildContext context, String id) {
    final pair = _priorityLabels[id];
    if (pair == null) return id;
    return context.t(pair[0], pair[1]);
  }

  String _sectionLabel(BuildContext context, String section) {
    switch (section) {
      case 'limitations':
        return context.t('قسم القيود', 'Limitations section');
      case 'future_work':
        return context.t('قسم العمل المستقبلي', 'Future work section');
      case 'conclusion':
        return context.t('قسم الخلاصة', 'Conclusion section');
      default:
        return section;
    }
  }

  Widget _sectionTitle(BuildContext context, String ar, String en) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        context.t(ar, en),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  Widget _bulletList(List<String> items, {bool ltr = false}) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(
                  child: Text(item, style: const TextStyle(height: 1.5)),
                ),
              ],
            ),
          ),
      ],
    );
    if (!ltr) return body;
    return Directionality(textDirection: TextDirection.ltr, child: body);
  }

  Widget _guideBody(BuildContext context, IdeaGuide guide, {bool ltr = false}) {
    final isAr = !ltr;
    String label(String ar, String en) => isAr ? ar : en;
    final children = <Widget>[];
    if (guide.problem.trim().isNotEmpty) {
      children.add(Text(
        label('المشكلة', 'Problem'),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ));
      children.add(const SizedBox(height: 4));
      children.add(Text(guide.problem, style: const TextStyle(height: 1.5)));
      children.add(const SizedBox(height: 12));
    }
    void listSection(String title, List<String> items) {
      if (items.isEmpty) return;
      children.add(Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ));
      children.add(const SizedBox(height: 4));
      children.add(_bulletList(items));
      children.add(const SizedBox(height: 12));
    }

    listSection(label('الأهداف', 'Objectives'), guide.objectives);
    listSection(label('المنهجية المقترحة', 'Proposed methodology'),
        guide.methodology);
    if (guide.milestones.isNotEmpty) {
      children.add(Text(
        label('المراحل الزمنية', 'Milestones'),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ));
      children.add(const SizedBox(height: 4));
      children.add(_bulletList([
        for (final m in guide.milestones)
          m.duration.isEmpty ? m.phase : '${m.phase} (${m.duration})',
      ]));
      children.add(const SizedBox(height: 12));
    }
    listSection(
        label('الأدوات والمهارات', 'Tools and skills'), guide.toolsAndSkills);
    listSection(label('المخرجات المتوقعة', 'Expected outputs'),
        guide.expectedOutputs);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    if (!ltr) return column;
    return Directionality(textDirection: TextDirection.ltr, child: column);
  }

  @override
  Widget build(BuildContext context) {
    if (!idea.hasGroundedGuide) return const SizedBox.shrink();
    final isEnglish = LocaleService.instance.isEnglish;
    final paper = idea.sourcePaper;
    final guide = isEnglish ? idea.guideEn : idea.guideAr;
    final children = <Widget>[const SizedBox(height: 20)];

    // 1) بطاقة «من حيث انتهت الدراسة»: الورقة المصدر + اقتباس حرفي + DOI.
    if (paper != null && paper.title.isNotEmpty) {
      children.add(_sectionTitle(
          context, 'من حيث انتهت الدراسة', 'Where the study ended'));
      children.add(
        Card(
          color: const Color(0xFF14302B),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    paper.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: Color(0xFFF4F7FB),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    [
                      if (paper.authors.isNotEmpty)
                        paper.authors.length > 3
                            ? '${paper.authors.take(3).join(', ')} et al.'
                            : paper.authors.join(', '),
                      if (paper.year != null) '${paper.year}',
                      if (paper.venue.isNotEmpty) paper.venue,
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFB7C3D6),
                    ),
                  ),
                ),
                if (idea.whereItEndedQuote.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        left: BorderSide(color: Colors.tealAccent, width: 3),
                      ),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '"${idea.whereItEndedQuote}"',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          color: Color(0xFFF4F7FB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t(
                      'اقتباس حرفي من ${_sectionLabel(context, idea.whereItEndedSection)} في الورقة',
                      'Verbatim quote from the paper\'s ${_sectionLabel(context, idea.whereItEndedSection)}',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB7C3D6),
                    ),
                  ),
                ],
                if (!isEnglish && idea.proposedNextStepAr.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    idea.proposedNextStepAr,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
                if (paper.bestUrl.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => onOpenUrl(paper.bestUrl),
                    icon: Icon(
                      paper.doiVerified
                          ? Icons.verified_outlined
                          : Icons.link,
                      size: 18,
                    ),
                    label: Text(
                      paper.doiVerified
                          ? context.t(
                              'الورقة المصدر (DOI موثّق)',
                              'Source paper (verified DOI)',
                            )
                          : context.t('الورقة المصدر', 'Source paper'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // 2) وسوم الأولويات القومية مع مبرر كل وسم من نص الورقة.
    if (idea.nationalPriorities.isNotEmpty) {
      children.add(const SizedBox(height: 16));
      children.add(_sectionTitle(
          context, 'الأولويات القومية', 'National priorities'));
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in idea.nationalPriorities)
              Chip(
                avatar: const Icon(Icons.flag_outlined, size: 16),
                label: Text(_priorityLabel(context, p.priority)),
                backgroundColor: Colors.teal.withValues(alpha: 0.15),
              ),
          ],
        ),
      );
      for (final p in idea.nationalPriorities) {
        if (p.justification.isEmpty) continue;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                '${_priorityLabel(context, p.priority)}: ${p.justification}',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Color(0xFFB7C3D6),
                ),
              ),
            ),
          ),
        );
      }
    }

    // 3) الدليل بلغة الواجهة: عربي كامل + ملخص إنجليزي، أو إنجليزي فقط.
    if (!guide.isEmpty) {
      children.add(const SizedBox(height: 20));
      children.add(_sectionTitle(
          context, 'دليل تنفيذ الفكرة', 'Idea execution guide'));
      children.add(_guideBody(context, guide, ltr: isEnglish));
      if (!isEnglish && idea.guideSummaryEn.isNotEmpty) {
        children.add(
          Theme(
            data:
                Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                context.t('ملخص الدليل بالإنجليزية', 'Guide summary in English'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      idea.guideSummaryEn,
                      style: const TextStyle(
                        height: 1.5,
                        color: Color(0xFFB7C3D6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 4) مراجع البداية + روابط فحص الحداثة.
    if (idea.starterReferences.isNotEmpty) {
      children.add(const SizedBox(height: 20));
      children.add(_sectionTitle(
          context, 'مراجع للبدء', 'Starter references'));
      children.add(
        Card(
          child: Column(
            children: [
              for (final ref in idea.starterReferences)
                ListTile(
                  dense: true,
                  leading: Icon(
                    ref.isSource
                        ? Icons.menu_book_outlined
                        : Icons.travel_explore_outlined,
                    size: 20,
                    color: const Color(0xFFB7C3D6),
                  ),
                  title: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      [
                        ref.title,
                        if (ref.year != null) '(${ref.year})',
                      ].join(' '),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                  subtitle: Text(
                    ref.isSource
                        ? context.t(
                            'الورقة المصدر', 'Source paper')
                        : context.t('أقرب عمل حديث (فحص الحداثة)',
                            'Nearest recent work (frontier check)'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: ref.bestUrl.isEmpty
                      ? null
                      : const Icon(Icons.open_in_new, size: 16),
                  onTap: ref.bestUrl.isEmpty
                      ? null
                      : () => onOpenUrl(ref.bestUrl),
                ),
            ],
          ),
        ),
      );
    }

    // 5) أحدث التطورات: أوراق حديثة تستشهد بالورقة المصدر (تتبع أسبوعي).
    if (idea.latestDevelopments.isNotEmpty) {
      children.add(const SizedBox(height: 20));
      children.add(_sectionTitle(
          context, 'أحدث التطورات على هذا البحث', 'Latest developments'));
      children.add(
        Card(
          child: Column(
            children: [
              for (final dev in idea.latestDevelopments)
                ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.trending_up,
                    size: 20,
                    color: Color(0xFFB7C3D6),
                  ),
                  title: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      [
                        dev.title,
                        if (dev.year != null) '(${dev.year})',
                      ].join(' '),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                  subtitle: dev.publishedDate.isEmpty
                      ? null
                      : Text(
                          dev.publishedDate,
                          style: const TextStyle(fontSize: 12),
                        ),
                  trailing: dev.bestUrl.isEmpty
                      ? null
                      : const Icon(Icons.open_in_new, size: 16),
                  onTap: dev.bestUrl.isEmpty
                      ? null
                      : () => onOpenUrl(dev.bestUrl),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// زر حفظ الفكرة في المفضلة (ظاهر للمسجّلين فقط).
class _FavoriteIdeaButton extends StatelessWidget {
  final AcademicResearchIdea idea;

  const _FavoriteIdeaButton({required this.idea});

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const SizedBox.shrink();
    }
    final ideaId = (idea.id ?? '').trim();
    return StreamBuilder<bool>(
      stream: ResearchIdeaFavoritesService.instance.watchIsFavorite(ideaId),
      builder: (context, snap) {
        final saved = snap.data == true;
        return IconButton(
          tooltip: context.t('احفظ الفكرة', 'Save idea'),
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () async {
            final nowSaved = await ResearchIdeaFavoritesService.instance
                .toggle(idea);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  nowSaved
                      ? context.t('حُفظت في أفكارك', 'Saved to your ideas')
                      : context.t('أُزيلت من المحفوظات', 'Removed from saved'),
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }
}

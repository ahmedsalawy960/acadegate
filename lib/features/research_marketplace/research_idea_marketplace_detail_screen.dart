import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import '../moderation/delete_content_button.dart';
import '../research_fund/research_fund_models.dart';
import 'research_marketplace_service.dart';
import 'submit_proposal_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _checkPublisher();
  }

  Future<void> _checkPublisher() async {
    if (!widget.idea.isFromFirebase) return;
    final isPub = await ResearchMarketplaceService.instance
        .isIdeaPublisher(widget.idea.id!);
    if (mounted) setState(() => _isPublisher = isPub);
  }

  Future<void> _toggleVote() async {
    setState(() => _isVoting = true);
    try {
      await ResearchMarketplaceService.instance.toggleVote(widget.idea);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'تم اختيار الموضوع — أصبح ملكك ولن يستطيع غيرك اختياره',
            'Topic claimed — it is now yours and others cannot claim it',
          )),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
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
        final idea = snapshot.hasData && snapshot.data!.exists
            ? AcademicResearchIdea.fromMap(
                snapshot.data!.data()!,
                id: snapshot.data!.id,
              )
            : widget.idea;
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
        actions: deleteAppBarActions(
          collection: 'research_ideas',
          documentId: idea.id,
          ownerId: idea.publisherId,
          itemLabel: idea.title,
        ),
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
                    style: TextStyle(color: Colors.grey[700], fontSize: 15),
                  ),
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
                      if (canInteract)
                        _FundEligibilityChip(idea: idea),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.t('وصف المشكلة:', 'Problem description:'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(idea.details, style: const TextStyle(height: 1.5)),
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
                              canRelease ? Colors.grey[700] : const Color(0xFF1A237E),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.thumb_up_alt_outlined),
                      label: canInteract
                          ? StreamBuilder<bool>(
                              stream: ResearchMarketplaceService.instance
                                  .hasUserVoted(idea.id!),
                              builder: (context, snapshot) {
                                final voted = snapshot.data ?? false;
                                return Text(voted
                                    ? context.t('إلغاء التصويت', 'Remove vote')
                                    : context.t('صوّت', 'Vote'));
                              },
                            )
                          : Text(context.t('صوّت', 'Vote')),
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
                      label: Text(context.t('قدّم مقترحك', 'Submit your proposal')),
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

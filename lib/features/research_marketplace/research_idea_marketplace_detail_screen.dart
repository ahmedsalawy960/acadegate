import 'package:flutter/material.dart';
import '../academic/academic_models.dart';
import '../moderation/delete_content_button.dart';
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

  Future<void> _openProposalForm() async {
    if (!widget.idea.isFromFirebase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'التقديم متاح للأفكار المضافة في Firebase. انشر فكرة جديدة من زر (+).',
          ),
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
        const SnackBar(
          content: Text('تم إرسال مقترحك بنجاح'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    final canInteract = idea.isFromFirebase && idea.isPubliclyVisible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الفكرة'),
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
                        label: Text(idea.isOpen ? 'مفتوحة للتقديم' : 'مغلقة'),
                        backgroundColor: idea.isOpen
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.12),
                      ),
                      Chip(
                        label: Text('${idea.votesCount} تصويت'),
                      ),
                      Chip(
                        label: Text('${idea.proposalsCount} مقترح'),
                      ),
                      if (idea.budget.isNotEmpty)
                        Chip(label: Text(idea.budget)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'وصف المشكلة:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                      child: const Text(
                        'هذه فكرة تجريبية. للتصويت والتقديم، أضف أفكاراً في Firebase أو انشر فكرة جديدة.',
                      ),
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
                    const Text(
                      'المقترحات المقدمة:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                          return const Text('لا توجد مقترحات بعد — كن الأول!');
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
                                    trailing: _ProposalStatusBadge(
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !canInteract || _isVoting || !idea.isOpen
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
                                return Text(voted ? 'إلغاء التصويت' : 'صوّت');
                              },
                            )
                          : const Text('صوّت'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: idea.isOpen ? _openProposalForm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text('قدّم مقترحك'),
                    ),
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
      'accepted' => 'مقبول',
      'rejected' => 'مرفوض',
      _ => 'قيد المراجعة',
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

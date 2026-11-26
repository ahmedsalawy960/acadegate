import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import 'community_data.dart';
import 'community_feed.dart';
import 'community_models.dart';
import 'community_papers.dart';
import 'community_post_detail_screen.dart';
import 'community_service.dart';

const Color _kPapersColor = Color(0xFF00695C);

/// Community tab: papers members discuss, with search and a way to add one.
class PapersTab extends StatefulWidget {
  const PapersTab({super.key});

  @override
  State<PapersTab> createState() => _PapersTabState();
}

class _PapersTabState extends State<PapersTab> {
  String _query = '';

  Future<void> _discuss(BuildContext context, {PaperSummary? paper}) async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreatePaperPostScreen(paper: paper)),
    );
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'تم إرسال منشورك للمراجعة، وهيظهر بعد الاعتماد.',
            'Your post was sent for review and will appear once approved.',
          )),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.t('ابحث بعنوان الورقة أو DOI',
                        'Search by paper title or DOI'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _kPapersColor),
                onPressed: () => _discuss(context),
                icon: const Icon(Icons.add),
                label: Text(context.t('ناقش ورقة', 'Discuss a paper')),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CommunityPost>>(
            stream: CommunityService.instance.watchPaperPosts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final papers =
                  filterPapers(groupPaperPosts(snapshot.data!), _query);
              if (papers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.trim().isEmpty
                          ? context.t(
                              'لسه مفيش ورقة متناقشة. اضغط «ناقش ورقة» والصق DOI أو رابط البحث.',
                              'No paper is being discussed yet. Tap "Discuss a paper" and paste a DOI or link.',
                            )
                          : context.t('مفيش ورقة مطابقة للبحث.',
                              'No paper matches your search.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: papers.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final paper = papers[i];
                  return ListTile(
                    leading: const Icon(Icons.article_outlined,
                        color: _kPapersColor),
                    title: Text(paper.title, maxLines: 2),
                    subtitle: Text(
                      '${paper.postsCount} ${context.t('منشور', 'posts')} · '
                      '${paper.repliesCount} ${context.t('رد', 'replies')}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaperDiscussionScreen(paper: paper),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// All posts about one paper.
class PaperDiscussionScreen extends StatelessWidget {
  const PaperDiscussionScreen({super.key, required this.paper});

  final PaperSummary paper;

  @override
  Widget build(BuildContext context) {
    final room = communityRoomById('general')!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('نقاش ورقة', 'Paper discussion')),
        backgroundColor: _kPapersColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPapersColor,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreatePaperPostScreen(paper: paper)),
        ),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(context.t('أضف للنقاش', 'Add to the discussion')),
      ),
      body: Column(
        children: [
          ListTile(
            title: Text(paper.title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(paper.key.startsWith('doi:')
                ? paper.key.substring(4)
                : paper.link),
            trailing: isSafeCommunityLink(paper.link)
                ? IconButton(
                    tooltip: context.t('فتح الورقة', 'Open the paper'),
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => launchUrl(
                      Uri.parse(paper.link.trim()),
                      mode: LaunchMode.externalApplication,
                    ),
                  )
                : null,
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<CommunityPost>>(
              stream: CommunityService.instance
                  .watchPaperPosts(paperKey: paper.key),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = applyCommunityFeedView(
                    snapshot.data!, CommunityFeedView.latest);
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final post = posts[i];
                    return ListTile(
                      title: Text(post.title, maxLines: 2),
                      subtitle: Text(
                        '${post.authorName} · ${post.repliesCount} ${context.t('رد', 'replies')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CommunityPostDetailScreen(post: post, room: room),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Form for a post about a paper. Link only: no file upload.
class CreatePaperPostScreen extends StatefulWidget {
  const CreatePaperPostScreen({super.key, this.paper});

  /// When set, the post joins this paper's discussion and the paper is locked.
  final PaperSummary? paper;

  @override
  State<CreatePaperPostScreen> createState() => _CreatePaperPostScreenState();
}

class _CreatePaperPostScreenState extends State<CreatePaperPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  final _paperTitleController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _kind = 'question';
  bool _submitting = false;

  static const _journalTag = 'journal-experience';

  @override
  void initState() {
    super.initState();
    final paper = widget.paper;
    if (paper != null) {
      _linkController.text = paper.key.startsWith('doi:')
          ? paper.key.substring(4)
          : paper.link;
      _paperTitleController.text = paper.title;
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    _paperTitleController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ref = normalizePaperInput(_linkController.text);
    if (ref == null) return;
    setState(() => _submitting = true);
    final error = await CommunityService.instance.createPaperPost(
      paper: ref,
      paperTitle: _paperTitleController.text,
      type: _kind == 'question'
          ? CommunityPostType.question
          : CommunityPostType.discussion,
      title: _titleController.text,
      body: _bodyController.text,
      tags: _kind == 'journal' ? const [_journalTag] : const [],
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.paper != null;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('منشور عن ورقة', 'Post about a paper')),
        backgroundColor: _kPapersColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _linkController,
              enabled: !locked,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.t('DOI أو رابط الورقة', 'Paper DOI or link'),
                helperText: context.t(
                    'روابط فقط، من غير رفع ملفات.', 'Links only, no file upload.'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => normalizePaperInput(v ?? '') == null
                  ? context.t('اكتب DOI صحيح أو رابط يبدأ بـ http:// أو https://',
                      'Enter a valid DOI or a link starting with http:// or https://')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _paperTitleController,
              enabled: !locked,
              maxLength: kCommunityTitleMaxLength,
              decoration: InputDecoration(
                labelText: context.t('عنوان الورقة', 'Paper title'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('مطلوب', 'Required')
                  : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'question', label: Text(context.t('سؤال', 'Question'))),
                ButtonSegment(
                    value: 'comment', label: Text(context.t('تعليق', 'Comment'))),
                ButtonSegment(
                    value: 'journal',
                    label: Text(context.t('تجربتي مع المجلة', 'Journal experience'))),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              maxLength: kCommunityTitleMaxLength,
              decoration: InputDecoration(
                labelText: context.t('عنوان المنشور', 'Post title'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('مطلوب', 'Required')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyController,
              maxLines: 8,
              maxLength: kCommunityPostBodyMaxLength,
              decoration: InputDecoration(
                labelText: context.t('اكتب بكلامك', 'Write in your own words'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('مطلوب', 'Required')
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kPapersColor),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t('إرسال للمراجعة', 'Send for review')),
            ),
          ],
        ),
      ),
    );
  }
}

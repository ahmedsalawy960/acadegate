import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/auth_guard.dart';
import '../moderation/approval_status.dart';
import 'product_qa_service.dart';
import 'store_catalog_service.dart';
import 'store_categories.dart';
import 'store_product_navigation.dart';
import 'store_theme.dart';

class ProductSimilarSection extends StatelessWidget {
  final String productId;
  final String categoryTitle;
  final String? createdBy;

  const ProductSimilarSection({
    super.key,
    required this.productId,
    required this.categoryTitle,
    this.createdBy,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryTitle.trim().isEmpty) return const SizedBox.shrink();
    final category = storeCategoryByTitle(categoryTitle);
    final titles = category != null
        ? storeCategoryQueryTitles(category).toSet()
        : {categoryTitle};

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('product')
          .where('approvalStatus', isEqualTo: ApprovalStatus.approved)
          .limit(40)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final similar = snapshot.data!.docs
            .where((d) {
              if (d.id == productId) return false;
              final data = d.data();
              if (!ApprovalStatus.isPublic(data['approvalStatus']?.toString())) {
                return false;
              }
              final cat = data['category']?.toString() ?? '';
              final canonical = storeCategoryLegacyAliases[cat] ?? cat;
              final sameCat =
                  titles.contains(cat) || titles.contains(canonical);
              final sameSeller = createdBy != null &&
                  createdBy!.isNotEmpty &&
                  data['createdBy']?.toString() == createdBy;
              return sameCat || sameSeller;
            })
            .map(StoreCatalogProduct.fromDoc)
            .take(8)
            .toList();
        if (similar.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              context.t('منتجات مشابهة', 'Similar products'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: similar.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final p = similar[i];
                  return SizedBox(
                    width: 130,
                    child: InkWell(
                      onTap: () => openStoreProductDetail(context, p),
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: (p.imageUrl ?? '').isNotEmpty
                                    ? Image.network(
                                        p.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.shopping_bag_outlined,
                                        ),
                                      )
                                    : const ColoredBox(
                                        color: Color(0xFFEEEEEE),
                                        child: Icon(Icons.shopping_bag_outlined),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class ProductQaSection extends StatefulWidget {
  final String productId;
  final String? sellerId;

  const ProductQaSection({
    super.key,
    required this.productId,
    this.sellerId,
  });

  @override
  State<ProductQaSection> createState() => _ProductQaSectionState();
}

class _ProductQaSectionState extends State<ProductQaSection> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final ok = await ensureLoggedIn(context);
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    try {
      await ProductQaService.instance.ask(
        productId: widget.productId,
        question: _controller.text,
      );
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _answer(ProductQaItem item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != widget.sellerId) return;
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('إجابة السؤال', 'Answer question')),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: ctx.t('اكتب الإجابة', 'Write the answer'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(ctx.t('نشر', 'Publish')),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    try {
      await ProductQaService.instance.answer(
        productId: widget.productId,
        qaId: item.id,
        answer: text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isSeller =
        uid != null && widget.sellerId != null && uid == widget.sellerId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          context.t('أسئلة وأجوبة', 'Q&A'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: context.t(
                    'اسأل عن النقاء، التوفر، الشحن…',
                    'Ask about purity, stock, shipping…',
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _ask,
              style: IconButton.styleFrom(
                backgroundColor: StoreTheme.accent,
              ),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<ProductQaItem>>(
          stream: ProductQaService.instance.watch(widget.productId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return Text(
                context.t(
                  'لا أسئلة بعد — كن أول من يسأل.',
                  'No questions yet — be the first to ask.',
                ),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              );
            }
            return Column(
              children: items.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q: ${item.question}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        if (item.hasAnswer)
                          Text(
                            'A: ${item.answer}',
                            style: TextStyle(color: Colors.grey[800]),
                          )
                        else if (isSeller)
                          TextButton(
                            onPressed: () => _answer(item),
                            child: Text(context.t('أجب', 'Answer')),
                          )
                        else
                          Text(
                            context.t('بانتظار إجابة المورد', 'Awaiting seller answer'),
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 12.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

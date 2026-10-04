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
  final String productName;
  final String brand;
  final String description;

  const ProductSimilarSection({
    super.key,
    required this.productId,
    required this.categoryTitle,
    this.productName = '',
    this.brand = '',
    this.description = '',
  });

  @override
  Widget build(BuildContext context) {
    if (categoryTitle.trim().isEmpty) return const SizedBox.shrink();
    final category = storeCategoryByTitle(categoryTitle);
    final titles = (category != null
            ? storeCategoryQueryTitles(category)
            : <String>[categoryTitle])
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(10)
        .toList();
    if (titles.isEmpty) return const SizedBox.shrink();
    final needle = _similarTokens('$productName $brand $description');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('product')
          .where('category', whereIn: titles)
          .limit(80)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final ranked = snapshot.data!.docs
            .where((d) {
              if (d.id == productId) return false;
              final data = d.data();
              return ApprovalStatus.isPublic(data['approvalStatus']?.toString());
            })
            .map(StoreCatalogProduct.fromDoc)
            .map((p) => (product: p, score: _similarScore(p, needle, brand)))
            .toList();
        final matched = ranked.where((e) => e.score > 0).toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        final similar = (matched.isNotEmpty ? matched : ranked)
            .take(8)
            .map((e) => e.product)
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

final _similarSplit = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

const _similarStop = {
  'the', 'and', 'for', 'with', 'from', 'plus', 'touch', 'device', 'devices',
  'جهاز', 'اجهزه', 'اجهزة', 'من', 'في', 'علي', 'مع', 'او', 'الي', 'هذا', 'هذه',
  'التي', 'الذي', 'عن', 'بعد', 'قبل', 'مواصفات', 'ضمان', 'صيانه', 'كتالوج',
  'اضغط', 'تحميل', 'للطلب', 'انظمه', 'جميع', 'انماط', 'برمجه', 'شاشه', 'تخزين',
  'نتيجه', 'هنا', 'لتحميل',
};

String _foldSimilar(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[\u064B-\u0652]'), '');
}

Set<String> _similarTokens(String raw) {
  final out = <String>{};
  for (final part in _foldSimilar(raw).split(_similarSplit)) {
    var token = part.trim();
    if (token.startsWith('ال') && token.length > 4) {
      token = token.substring(2);
    }
    final minLen = RegExp(r'[a-z0-9]').hasMatch(token) ? 3 : 2;
    if (token.length < minLen || _similarStop.contains(token)) continue;
    out.add(token);
  }
  return out;
}

int _similarScore(StoreCatalogProduct product, Set<String> needle, String brand) {
  if (needle.isEmpty && brand.trim().isEmpty) return 0;
  final hay = _similarTokens('${product.name} ${product.brand}');
  var score = 0;
  for (final token in needle) {
    if (hay.contains(token)) score += 3;
  }
  final wanted = _foldSimilar(brand).trim();
  final found = _foldSimilar(product.brand).trim();
  if (wanted.length >= 2 && wanted == found) score += 5;
  return score;
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
                style: TextStyle(color: StoreTheme.muted, fontSize: 13),
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
                            style: TextStyle(color: StoreTheme.muted),
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

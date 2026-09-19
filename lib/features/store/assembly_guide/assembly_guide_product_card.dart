import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../../core/security/firebase_security_messages.dart';
import '../../auth/auth_guard.dart';
import '../store_theme.dart';
import 'assembly_guide_screen.dart';
import 'assembly_guide_service.dart';
import 'edit_assembly_guide_screen.dart';

/// بطاقة على صفحة المنتج: فتح / إدارة الدليل التفاعلي.
class AssemblyGuideProductCard extends StatefulWidget {
  final String productId;
  final String productName;
  final String? createdBy;
  final bool hintHasGuide;

  const AssemblyGuideProductCard({
    super.key,
    required this.productId,
    required this.productName,
    this.createdBy,
    this.hintHasGuide = false,
  });

  @override
  State<AssemblyGuideProductCard> createState() =>
      _AssemblyGuideProductCardState();
}

class _AssemblyGuideProductCardState extends State<AssemblyGuideProductCard> {
  bool _loading = true;
  bool _hasGuide = false;
  bool _opening = false;
  bool _trying = false;

  bool get _isOwner {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null &&
        widget.createdBy != null &&
        widget.createdBy == uid;
  }

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    try {
      final guide = await AssemblyGuideService.instance
          .loadForProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _hasGuide = guide != null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasGuide = widget.hintHasGuide;
        _loading = false;
      });
    }
  }

  Future<void> _openGuide() async {
    setState(() => _opening = true);
    try {
      final guide = await AssemblyGuideService.instance
          .loadForProduct(widget.productId);
      if (!mounted) return;
      if (guide == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'لا يوجد دليل تفاعلي لهذا المنتج بعد',
              'No interactive product guide yet',
            )),
          ),
        );
        return;
      }
      final allowed = await AssemblyGuideService.instance.canAccess(
        productId: widget.productId,
        guide: guide,
      );
      if (!mounted) return;
      if (!allowed) {
        final loggedIn = await ensureLoggedIn(context);
        if (!loggedIn || !mounted) return;
        final again = await AssemblyGuideService.instance.canAccess(
          productId: widget.productId,
          guide: guide,
        );
        if (!mounted) return;
        if (!again) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t(
                'الدليل يُفتح بعد شراء المنتج وتأكيد الدفع (محجوز).',
                'Guide unlocks after purchase and payment held confirmation.',
              )),
            ),
          );
          return;
        }
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssemblyGuideScreen(
            productId: widget.productId,
            productName: widget.productName,
            guide: guide,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FirebaseSecurityMessages.fromException(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _tryOnThisProduct() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;
    setState(() => _trying = true);
    try {
      final guide = await AssemblyGuideService.instance.ensurePlayableGuide(
        productId: widget.productId,
        productName: widget.productName,
      );
      if (!mounted) return;
      setState(() => _hasGuide = true);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssemblyGuideScreen(
            productId: widget.productId,
            productName: widget.productName,
            guide: guide,
          ),
        ),
      );
      await _probe();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FirebaseSecurityMessages.fromException(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _trying = false);
    }
  }

  Future<void> _editGuide() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditAssemblyGuideScreen(
          productId: widget.productId,
          productName: widget.productName,
        ),
      ),
    );
    if (saved == true) await _probe();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !widget.hintHasGuide && !_isOwner) {
      return const SizedBox.shrink();
    }
    if (!_hasGuide && !_isOwner && !widget.hintHasGuide) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB2EBF2)),
          ),
          child: Text(
            context.t(
              'دليل تفاعلي: استخدام أو تشغيل أو تعامل مع المنتج خطوة بخطوة '
              '(صوت + صورة/فيديو + فحص بالكاميرا).',
              'Interactive product guide: how to use, operate, or handle this item '
              '(voice + image/video + camera check).',
            ),
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        if (!_isOwner && (_hasGuide || widget.hintHasGuide))
          FilledButton.icon(
            onPressed: _opening ? null : _openGuide,
            style: FilledButton.styleFrom(
              backgroundColor: StoreTheme.accent,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _opening
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.view_in_ar_outlined),
            label: Text(
              context.t(
                'ابدأ الدليل التفاعلي',
                'Start interactive product guide',
              ),
            ),
          ),
        if (_isOwner) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _trying ? null : _tryOnThisProduct,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D7377),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _trying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(
              context.t(
                _hasGuide
                    ? 'جرّب الدليل على هذا المنتج'
                    : 'أنشئ دليلاً وجرّبه الآن',
                _hasGuide
                    ? 'Try the guide on this product'
                    : 'Create a guide and try it now',
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _editGuide,
            icon: const Icon(Icons.edit_note_outlined),
            label: Text(
              context.t(
                _hasGuide ? 'تعديل الدليل التفاعلي' : 'إضافة دليل تفاعلي',
                _hasGuide
                    ? 'Edit interactive product guide'
                    : 'Add interactive product guide',
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

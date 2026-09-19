import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import 'package:image_picker/image_picker.dart';

import '../../core/locale/app_translate.dart';

import '../../core/locale/l10n_lookup.dart';

import '../../core/locale/locale_extensions.dart';

import '../../core/storage/storage_service.dart';

import '../auth/provider_publish_gate.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../analytics/kpi_analytics_service.dart';
import 'store_badges.dart';
import 'store_categories.dart';
import 'store_theme.dart';



class AddProductScreen extends StatefulWidget {
  final String categoryTitle;
  /// Links the product to a directory supplier page (Managed Verified flow).
  final String? supplierId;
  final String? storeNameHint;
  final String? contactHint;

  const AddProductScreen({
    super.key,
    required this.categoryTitle,
    this.supplierId,
    this.storeNameHint,
    this.contactHint,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}



class _AddProductScreenState extends State<AddProductScreen> {

  final _formKey = GlobalKey<FormState>();



  final _nameController = TextEditingController();

  final _priceController = TextEditingController();

  final _descriptionController = TextEditingController();

  final _storeNameController = TextEditingController();

  final _contactController = TextEditingController();

  final _skuController = TextEditingController();

  final _brandController = TextEditingController();

  final _unitController = TextEditingController();

  final _gradeController = TextEditingController();

  final _originController = TextEditingController();

  final _cityController = TextEditingController();

  bool _isSaving = false;

  bool _inStock = true;

  bool _fastShipping = false;

  final Set<String> _selectedBadges = {};

  XFile? _imageFile;



  String get _categoryDisplayTitle {

    final category = storeCategoryByTitle(widget.categoryTitle);

    return category != null

        ? L10nLookup.storeCategoryTitle(category.id)

        : widget.categoryTitle;

  }



  @override

  void dispose() {

    _nameController.dispose();

    _priceController.dispose();

    _descriptionController.dispose();

    _storeNameController.dispose();

    _contactController.dispose();

    _skuController.dispose();

    _brandController.dispose();

    _unitController.dispose();

    _gradeController.dispose();

    _originController.dispose();

    _cityController.dispose();

    super.dispose();

  }

  @override
  void initState() {
    super.initState();
    final storeHint = (widget.storeNameHint ?? '').trim();
    if (storeHint.isNotEmpty) {
      _storeNameController.text = storeHint;
    }
    final contactHint = (widget.contactHint ?? '').trim();
    if (contactHint.isNotEmpty) {
      _contactController.text = contactHint;
    }
  }

  String? _validateRequired(String? value) {

    final v = (value ?? '').trim();

    if (v.isEmpty) return appTr('هذا الحقل مطلوب', 'This field is required');

    return null;

  }



  String? _validatePrice(String? value) {

    final v = (value ?? '').trim();

    if (v.isEmpty) return appTr('السعر مطلوب', 'Price is required');

    final parsed = num.tryParse(v.replaceAll(',', '.'));

    if (parsed == null) return appTr('أدخل رقم صحيح', 'Enter a valid number');

    if (parsed < 0) {

      return appTr('السعر لا يمكن أن يكون سالباً', 'Price cannot be negative');

    }

    return null;

  }



  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'يجب تسجيل الدخول لإضافة منتج',
              'You must sign in to add a product',
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await UserAccountService.instance.ensureAccountExists(user);
    var account = await UserAccountService.instance.loadCurrentAccount();
    if (!UserRole.canSellProducts(account?.role)) {
      if (!mounted) return;
      final enable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('تفعيل حساب تاجر؟', 'Enable merchant account?')),
          content: Text(
            ctx.t(
              'حسابك الحالي ليس بدور تاجر/مورد. لتتمكن من حفظ المنتجات، فعّل دور التاجر لهذا الحساب.',
              'Your account is not a merchant/supplier. Enable the merchant role to save products.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('تفعيل وحفظ', 'Enable & save')),
            ),
          ],
        ),
      );
      if (enable != true) return;
      try {
        await UserAccountService.instance.enableMerchantSelling();
        account = await UserAccountService.instance.loadCurrentAccount();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'تعذر تفعيل دور التاجر: $e',
                'Could not enable merchant role: $e',
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!UserRole.canSellProducts(account?.role)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'ما زال الحساب بدون صلاحية بيع. سجّل حساباً بدور تاجر أو تواصل مع الإدارة.',
                'Account still cannot sell. Register as a merchant or contact admin.',
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!ProviderPublishGate.canSubmitContent(account)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                ProviderPublishGate.blockMessageAr(account),
                ProviderPublishGate.blockMessageEn(account),
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final price =
          num.parse(_priceController.text.trim().replaceAll(',', '.'));

      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await StorageService.instance.uploadImage(
          file: _imageFile!,
          folder: 'products',
        );
      }

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'price': price,
        'category': widget.categoryTitle,
        'description': _descriptionController.text.trim(),
        'storeName': _storeNameController.text.trim(),
        'contact': _contactController.text.trim(),
        'imageUrl': ?imageUrl,
        if (imageUrl != null) 'imageUrls': [imageUrl],
        'sku': _skuController.text.trim(),
        'brand': _brandController.text.trim(),
        'unit': _unitController.text.trim(),
        'grade': _gradeController.text.trim(),
        'originCountry': _originController.text.trim(),
        'city': _cityController.text.trim(),
        'inStock': _inStock,
        'fastShipping': _fastShipping,
        'badges': _selectedBadges.toList(),
        'createdBy': user.uid,
        'approvalStatus':
            ProviderPublishGate.contentApprovalStatus(account),
        'createdAt': FieldValue.serverTimestamp(),
        if ((widget.supplierId ?? '').trim().isNotEmpty) ...{
          'supplierId': widget.supplierId!.trim(),
          'isPartner': true,
          'isVerifiedSeller': true,
          'directoryStatus': 'managed_verified',
          'isDirectoryListing': false,
        },
      };

      await FirebaseFirestore.instance.collection('product').add(payload);
      // ignore: unawaited_futures
      KpiAnalyticsService.instance.logPartnerActivity(action: 'add_product');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم حفظ المنتج وظهوره في المتجر',
              'Product saved and listed in the store',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final denied = e.code == 'permission-denied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            denied
                ? context.t(
                    'رفض الحفظ: صلاحيات غير كافية. تأكد أن دورك تاجر وأن قواعد Firestore محدّثة.',
                    'Save denied: insufficient permissions. Ensure your role is merchant and Firestore rules are deployed.',
                  )
                : '${context.t('فشل الحفظ: ', 'Save failed: ')}${e.message ?? e.code}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('فشل الحفظ: ', 'Save failed: ')}$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }



  @override

  Widget build(BuildContext context) {

    return Theme(

      data: StoreTheme.overlay(context),

      child: Scaffold(

      backgroundColor: StoreTheme.bg,

      appBar: AcadeGateAppBar(

        title: Text(context.t('إضافة منتج', 'Add product')),

        backgroundColor: StoreTheme.appBar,

        foregroundColor: StoreTheme.appBarForeground,

      ),

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(16),

          child: Form(

            key: _formKey,

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                Container(

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(

                    color: StoreTheme.surface,

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(color: StoreTheme.border),

                  ),

                  child: Row(

                    children: [

                      const Icon(Icons.category_outlined, color: StoreTheme.ink),

                      const SizedBox(width: 10),

                      Expanded(

                        child: Text(

                          context.t('القسم: ', 'Category: ') +

                              _categoryDisplayTitle,

                          style: const TextStyle(fontWeight: FontWeight.w600),

                        ),

                      ),

                    ],

                  ),

                ),

                const SizedBox(height: 16),

                TextFormField(

                  controller: _nameController,

                  validator: _validateRequired,

                  textInputAction: TextInputAction.next,

                  decoration: InputDecoration(

                    labelText: context.t('اسم المنتج', 'Product name'),

                    border: const OutlineInputBorder(),

                  ),

                ),

                const SizedBox(height: 12),

                TextFormField(

                  controller: _priceController,

                  validator: _validatePrice,

                  keyboardType: TextInputType.number,

                  textInputAction: TextInputAction.next,

                  decoration: InputDecoration(

                    labelText: context.t('السعر', 'Price'),

                    hintText: context.t('مثال: 150 أو 150.5', 'e.g. 150 or 150.5'),

                    border: const OutlineInputBorder(),

                  ),

                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _skuController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.t('SKU (اختياري)', 'SKU (optional)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.t('العلامة / الماركة', 'Brand'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.t('الوحدة', 'Unit'),
                          hintText: '500ml / 1kg',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _gradeController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.t('النقاء / الدرجة', 'Purity / grade'),
                          hintText: 'ACS / AR',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _originController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.t('بلد المنشأ', 'Country of origin'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.t('المدينة', 'City'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('متوفر حالياً', 'In stock now')),
                  value: _inStock,
                  onChanged: (v) => setState(() => _inStock = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('شحن سريع', 'Fast shipping')),
                  value: _fastShipping,
                  onChanged: (v) => setState(() => _fastShipping = v),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('شارات تخصصية', 'Specialty badges'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 6,
                  children: StoreBadge.all.map((b) {
                    final selected = _selectedBadges.contains(b.id);
                    return FilterChip(
                      selected: selected,
                      label: Text(b.label(), style: const TextStyle(fontSize: 11)),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedBadges.add(b.id);
                          } else {
                            _selectedBadges.remove(b.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                OutlinedButton.icon(

                  onPressed: () async {

                    final file = await StorageService.instance.pickImage();

                    if (file != null) setState(() => _imageFile = file);

                  },

                  icon: const Icon(Icons.add_photo_alternate_outlined),

                  label: Text(

                    _imageFile == null

                        ? context.t('إضافة صورة المنتج', 'Add product image')

                        : context.t('تم اختيار الصورة', 'Image selected'),

                  ),

                ),

                const SizedBox(height: 12),

                TextFormField(

                  controller: _descriptionController,

                  maxLines: 4,

                  textInputAction: TextInputAction.newline,

                  decoration: InputDecoration(

                    labelText: context.t('الوصف (اختياري)', 'Description (optional)'),

                    border: const OutlineInputBorder(),

                  ),

                ),

                const SizedBox(height: 12),

                TextFormField(

                  controller: _storeNameController,

                  textInputAction: TextInputAction.next,

                  decoration: InputDecoration(

                    labelText: context.t(

                      'اسم المورد/المتجر (اختياري)',

                      'Supplier/store name (optional)',

                    ),

                    border: const OutlineInputBorder(),

                  ),

                ),

                const SizedBox(height: 12),

                TextFormField(

                  controller: _contactController,

                  textInputAction: TextInputAction.done,

                  decoration: InputDecoration(

                    labelText: context.t(

                      'رقم/وسيلة تواصل (اختياري)',

                      'Phone/contact (optional)',

                    ),

                    border: const OutlineInputBorder(),

                  ),

                ),

                const SizedBox(height: 20),

                SizedBox(

                  height: 52,

                  child: FilledButton.icon(

                    onPressed: _isSaving ? null : _save,

                    style: FilledButton.styleFrom(

                      backgroundColor: StoreTheme.accent,

                    ),

                    icon: _isSaving

                        ? const SizedBox(

                            height: 18,

                            width: 18,

                            child: CircularProgressIndicator(

                              strokeWidth: 2,

                              color: Colors.white,

                            ),

                          )

                        : const Icon(Icons.save_outlined),

                    label: Text(

                      _isSaving

                          ? context.t('جارٍ الحفظ...', 'Saving...')

                          : context.t('حفظ المنتج', 'Save product'),

                    ),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    ),

    );

  }

}



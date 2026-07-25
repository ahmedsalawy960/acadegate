import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import 'package:image_picker/image_picker.dart';

import '../../core/locale/app_translate.dart';

import '../../core/locale/l10n_lookup.dart';

import '../../core/locale/locale_extensions.dart';

import '../../core/storage/storage_service.dart';

import '../moderation/approval_status.dart';

import 'store_categories.dart';



class AddProductScreen extends StatefulWidget {

  final String categoryTitle;



  const AddProductScreen({super.key, required this.categoryTitle});



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



  bool _isSaving = false;

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

    super.dispose();

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



    setState(() {

      _isSaving = true;

    });



    try {

      final price = num.parse(_priceController.text.trim().replaceAll(',', '.'));



      String? imageUrl;

      if (_imageFile != null) {

        imageUrl = await StorageService.instance.uploadImage(

          file: _imageFile!,

          folder: 'products',

        );

      }



      await FirebaseFirestore.instance.collection('product').add({

        'name': _nameController.text.trim(),

        'price': price,

        'category': widget.categoryTitle,

        'description': _descriptionController.text.trim(),

        'storeName': _storeNameController.text.trim(),

        'contact': _contactController.text.trim(),

        'imageUrl': ?imageUrl,

        'createdBy': user.uid,

        'approvalStatus': ApprovalStatus.pending,

        'createdAt': FieldValue.serverTimestamp(),

      });



      if (!mounted) return;

      Navigator.pop(context, true);

    } on FirebaseException catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(

            '${context.t('فشل الحفظ: ', 'Save failed: ')}${e.message ?? e.code}',

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

    return Scaffold(

      appBar: AcadeGateAppBar(

        title: Text(context.t('إضافة منتج', 'Add product')),

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

                    color: Colors.blueGrey.withValues(alpha: 0.06),

                    borderRadius: BorderRadius.circular(12),

                  ),

                  child: Row(

                    children: [

                      Icon(Icons.category_outlined, color: Colors.blueGrey[700]),

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

                  child: ElevatedButton.icon(

                    onPressed: _isSaving ? null : _save,

                    icon: _isSaving

                        ? const SizedBox(

                            height: 18,

                            width: 18,

                            child: CircularProgressIndicator(strokeWidth: 2),

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

    );

  }

}



import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import '../analysis_labs/request_sample_analysis_screen.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../lab_import/lab_claim_service.dart';
import '../lab_import/nbsle_contact_enrichment_service.dart';
import '../moderation/content_delete_service.dart';
import '../moderation/delete_content_button.dart';
import '../profile/academic_profile_service.dart';
import '../store/product_list_screen.dart';
import '../store/store_categories.dart';
import 'book_equipment_screen.dart';
import 'lab_contacts_panel.dart';
import 'smart_labs_service.dart';

class SmartLabDetailScreen extends StatefulWidget {
  final AcademicLab lab;

  const SmartLabDetailScreen({super.key, required this.lab});

  @override
  State<SmartLabDetailScreen> createState() => _SmartLabDetailScreenState();
}

class _SmartLabDetailScreenState extends State<SmartLabDetailScreen> {
  final _commentController = TextEditingController();
  int _selectedRating = 5;
  bool _isSubmittingRating = false;
  bool _isClaiming = false;
  bool _enrichingContacts = false;
  late AcademicLab _lab;
  late List<LabEquipment> _equipment;
  late List<SampleAnalysisService> _services;
  late String _ownerId;

  AcademicLab get lab => _lab;

  AcademicLab get _effectiveLab => AcademicLab(
        id: lab.id,
        name: lab.name,
        location: lab.location,
        equipment: lab.equipment,
        tags: lab.tags,
        city: lab.city,
        university: lab.university,
        ratingAvg: lab.ratingAvg,
        ratingsCount: lab.ratingsCount,
        defaultWaitDays: lab.defaultWaitDays,
        equipmentList: _equipment,
        ownerId: _ownerId,
        approvalStatus: lab.approvalStatus,
        labType: lab.labType,
        category: lab.category,
        facultyId: lab.facultyId,
        facultyNameAr: lab.facultyNameAr,
        description: lab.description,
        acceptsExternalSamples: lab.acceptsExternalSamples,
        contactEmail: lab.contactEmail,
        contactPhone: lab.contactPhone,
        contactName: lab.contactName,
        contacts: lab.contacts,
        sampleServices: _services,
        importSource: lab.importSource,
        sourceUrl: lab.sourceUrl,
        nbsleLabId: lab.nbsleLabId,
        equipmentCountHint: lab.equipmentCountHint,
      );

  @override
  void initState() {
    super.initState();
    _lab = widget.lab;
    _equipment = List.of(widget.lab.devices);
    _services = List.of(widget.lab.sampleServices);
    _ownerId = widget.lab.ownerId;
    _enrichContacts();
  }

  Future<void> _enrichContacts() async {
    if (!_lab.isNbsleImport) return;
    setState(() => _enrichingContacts = true);
    final enriched =
        await NbsleContactEnrichmentService.instance.enrichIfNeeded(_lab);
    if (!mounted) return;
    setState(() {
      _lab = enriched;
      _enrichingContacts = false;
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _removeEquipment(LabEquipment equipment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('حذف الجهاز؟', 'Delete device?')),
        content: Text(equipment.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SmartLabsService.instance.removeEquipment(
        lab: lab,
        equipmentId: equipment.id.isNotEmpty ? equipment.id : equipment.name,
      );
      if (!mounted) return;
      setState(() {
        _equipment.removeWhere(
          (e) => e.id == equipment.id || e.name == equipment.name,
        );
      });
      _showMessage(context.t('تم حذف الجهاز', 'Device deleted'));
    } catch (e) {
      if (!mounted) return;
      _showMessage('$e', isError: true);
    }
  }

  Future<void> _removeService(SampleAnalysisService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('حذف خدمة التحليل؟', 'Delete analysis service?')),
        content: Text(service.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SmartLabsService.instance.removeSampleService(
        lab: lab,
        serviceId: service.id.isNotEmpty ? service.id : service.name,
      );
      if (!mounted) return;
      setState(() {
        _services.removeWhere(
          (s) => s.id == service.id || s.name == service.name,
        );
      });
      _showMessage(context.t('تم حذف الخدمة', 'Service deleted'));
    } catch (e) {
      if (!mounted) return;
      _showMessage('$e', isError: true);
    }
  }

  Future<void> _submitRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(
        context.t(
          'يجب تسجيل الدخول لتقييم المختبر',
          'You must sign in to rate the lab',
        ),
        isError: true,
      );
      return;
    }

    setState(() => _isSubmittingRating = true);

    try {
      final profile = await AcademicProfileService.instance.loadProfile();
      await SmartLabsService.instance.submitRating(
        lab: widget.lab,
        rating: _selectedRating,
        comment: _commentController.text,
        userName: profile?.fullName ??
            user.email ??
            appTr('طالب', 'Student'),
      );
      if (!mounted) return;
      _showMessage(context.t('تم حفظ تقييمك', 'Your rating was saved'));
      _commentController.clear();
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''),
          isError: true);
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _claimLab() async {
    setState(() => _isClaiming = true);
    try {
      await LabClaimService.instance.claimLab(_effectiveLab);
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      setState(() => _ownerId = uid);
      _showMessage(
        context.t(
          'تم ربط المختبر بحسابك — الطلبات الجديدة ستصلك',
          'Lab linked to your account — new requests will reach you',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('$e', isError: true);
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  Future<void> _openSourceUrl() async {
    final raw = lab.sourceUrl.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _showMessage(
        context.t('تعذر فتح الرابط', 'Could not open link'),
        isError: true,
      );
    }
  }

  Widget _buildContactsCard() {
    if (_enrichingContacts) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.t(
                    'جاري جلب كل جهات التواصل من NBSLE…',
                    'Loading all NBSLE contacts…',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (lab.hasLabContact || lab.contacts.isNotEmpty) {
      return LabContactsPanel(lab: lab);
    }

    if (lab.sourceUrl.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          context.t(
            'لا توجد بيانات تواصل مخزّنة بعد — افتح صفحة NBSLE أو أعد المزامنة من لوحة المدير.',
            'No stored contacts yet — open the NBSLE page or re-sync from admin.',
          ),
        ),
      ),
    );
  }

  void _openStore(String categoryTitle) {
    final category = storeCategoryByTitle(categoryTitle);
    if (category == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductListScreen(categoryTitle: category.title),
      ),
    );
  }

  void _openBooking(LabEquipment equipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookEquipmentScreen(
          lab: _effectiveLab,
          equipment: equipment,
        ),
      ),
    );
  }

  String _storeCategoryLabel(String categoryTitle) {
    final category = storeCategoryByTitle(categoryTitle);
    return category != null
        ? L10nLookup.storeCategoryTitle(category.id)
        : categoryTitle;
  }

  @override
  Widget build(BuildContext context) {
    final lab = _lab;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('تفاصيل المختبر', 'Lab details')),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: deleteAppBarActions(
          collection: 'labs',
          documentId: lab.id,
          ownerId: _ownerId,
          itemLabel: lab.name,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            lab.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.purple[900],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 16),
              const SizedBox(width: 4),
              Expanded(child: Text(lab.location)),
            ],
          ),
          if (lab.university.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                lab.university,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          if (lab.hasFacultyLink)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Chip(
                avatar: Icon(Icons.school, size: 16, color: Colors.purple[800]),
                label: Text(
                  context.t(
                    '${lab.displayFacultyName} — مرتبط',
                    '${lab.displayFacultyName} — linked',
                  ),
                ),
                backgroundColor: Colors.purple[50],
              ),
            ),
          if (lab.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(lab.description),
          ],
          if (_ownerId.trim().isEmpty && lab.isFromFirebase) ...[
            const SizedBox(height: 12),
            Material(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                        'مختبر غير مربوط بمالك على AcadeGate بعد',
                        'This lab is not yet claimed on AcadeGate',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(
                        'الحجز وطلب التحليل يصلان لمديري المنصة حتى يطالب مدير المعمل المختبر.',
                        'Bookings and sample requests go to platform admins until a lab manager claims this lab.',
                      ),
                      style: TextStyle(height: 1.35, color: Colors.orange[900]),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder(
                      stream:
                          UserAccountService.instance.watchCurrentAccount(),
                      builder: (context, snap) {
                        final role = snap.data?.role ?? '';
                        final canClaim = role == UserRole.labManager ||
                            role == UserRole.admin;
                        if (!canClaim) return const SizedBox.shrink();
                        return FilledButton.icon(
                          onPressed: _isClaiming ? null : _claimLab,
                          icon: _isClaiming
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.handshake_outlined),
                          label: Text(
                            context.t(
                              'مطالبة هذا المختبر',
                              'Claim this lab',
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (lab.sourceUrl.isNotEmpty ||
              lab.hasLabContact ||
              _enrichingContacts) ...[
            const SizedBox(height: 12),
            _buildContactsCard(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (lab.sourceUrl.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _openSourceUrl,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      context.t('فتح صفحة NBSLE', 'Open NBSLE page'),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(lab.labTypeLabel)),
              if (lab.acceptsExternalSamples)
                Chip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text(
                    context.t(
                      'يقبل عينات خارجية',
                      'Accepts external samples',
                    ),
                  ),
                ),
              if (lab.ratingAvg > 0)
                Chip(
                  avatar: const Icon(Icons.star, color: Colors.amber, size: 18),
                  label: Text(
                    '${lab.ratingAvg.toStringAsFixed(1)} (${lab.ratingsCount})',
                  ),
                ),
              Chip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(
                  context.t(
                    'انتظار من ${lab.minWaitDays} يوم',
                    'Wait from ${lab.minWaitDays} days',
                  ),
                ),
              ),
              if (!lab.isFromFirebase)
                Chip(
                  avatar: const Icon(Icons.info_outline, size: 18),
                  label: Text(
                    context.t(
                      'بيانات تجريبية — الحجز يتطلب Firebase',
                      'Demo data — booking requires Firebase',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_services.isNotEmpty || lab.acceptsExternalSamples) ...[
            Text(
              context.t(
                'خدمات تحليل العينات',
                'Sample analysis services',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            ..._services.map(_buildSampleServiceCard),
            if (_services.isEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openSampleAnalysisRequestScreen(context, lab: _effectiveLab),
                  icon: const Icon(Icons.biotech),
                  label: Text(
                    context.t('طلب تحليل عينة', 'Request sample analysis'),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
          Text(
            context.t('الأجهزة المتاحة', 'Available equipment'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          ..._equipment.map(_buildEquipmentCard),
          const SizedBox(height: 24),
          Text(
            context.t('تقييمات الطلاب', 'Student ratings'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          if (lab.isFromFirebase)
            StreamBuilder<List<LabRating>>(
              stream: SmartLabsService.instance.ratingsStream(lab.id!),
              builder: (context, snapshot) {
                final ratings = snapshot.data ?? [];
                if (ratings.isEmpty) {
                  return Text(
                    context.t(
                      'لا توجد تقييمات بعد — كن أول من يقيّم',
                      'No ratings yet — be the first to rate',
                    ),
                    style: TextStyle(color: Colors.grey[600]),
                  );
                }

                final avg = ratings
                        .map((item) => item.rating)
                        .fold<int>(0, (sum, value) => sum + value) /
                    ratings.length;

                return Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          context.t(
                            '${avg.toStringAsFixed(1)} من 5',
                            '${avg.toStringAsFixed(1)} out of 5',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.t(
                            '(${ratings.length} تقييم)',
                            '(${ratings.length} ratings)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...ratings.take(5).map(_buildRatingTile),
                  ],
                );
              },
            )
          else
            ..._fallbackRatings(),
          const SizedBox(height: 16),
          _buildRatingForm(),
          ManageContentActions(
            collection: 'labs',
            documentId: lab.id,
            ownerId: lab.ownerId,
            itemLabel: lab.name,
          ),
        ],
      ),
    );
  }

  List<Widget> _fallbackRatings() {
    if (widget.lab.ratingsCount == 0) {
      return [
        Text(
          context.t(
            'التقييمات الحية متاحة بعد ربط المختبر بـ Firebase',
            'Live ratings are available after linking the lab to Firebase',
          ),
          style: TextStyle(color: Colors.grey[600]),
        ),
      ];
    }

    return [
      Row(
        children: [
          const Icon(Icons.star, color: Colors.amber),
          const SizedBox(width: 6),
          Text(
            context.t(
              '${widget.lab.ratingAvg.toStringAsFixed(1)} من 5 (${widget.lab.ratingsCount} تقييم)',
              '${widget.lab.ratingAvg.toStringAsFixed(1)} out of 5 (${widget.lab.ratingsCount} ratings)',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(context.t('طالب ماجستير', 'Master\'s student')),
        subtitle: Text(
          context.t(
            'أجهزة حديثة وفريق متعاون',
            'Modern equipment and a helpful team',
          ),
        ),
        trailing: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 16),
            Text('5'),
          ],
        ),
      ),
    ];
  }

  Widget _buildSampleServiceCard(SampleAnalysisService service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.purple[50],
      child: ListTile(
        title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          [
            if (service.description.isNotEmpty) service.description,
            context.t(
              'مدة ${service.turnaroundDays} يوم',
              '${service.turnaroundDays} days turnaround',
            ),
            if (service.priceFrom > 0)
              context.t(
                'من ${service.priceFrom} ج.م',
                'From ${service.priceFrom} EGP',
              ),
            if (service.sampleTypes.isNotEmpty)
              context.t(
                'عينات: ${service.sampleTypes.join('، ')}',
                'Samples: ${service.sampleTypes.join(', ')}',
              ),
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<bool>(
              future: ContentDeleteService.instance.canDelete(ownerId: lab.ownerId),
              builder: (context, snap) {
                if (snap.data != true) return const SizedBox.shrink();
                return IconButton(
                  tooltip: context.t('حذف الخدمة', 'Delete service'),
                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                  onPressed: () => _removeService(service),
                );
              },
            ),
            FilledButton(
              onPressed: () => openSampleAnalysisRequestScreen(
                context,
                lab: _effectiveLab,
                preselectedService: service,
              ),
              style: FilledButton.styleFrom(backgroundColor: Colors.purple[700]),
              child: Text(context.t('طلب', 'Request')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentCard(LabEquipment equipment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    equipment.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                FutureBuilder<bool>(
                  future: ContentDeleteService.instance.canDelete(ownerId: lab.ownerId),
                  builder: (context, snap) {
                    if (snap.data != true) return const SizedBox.shrink();
                    return IconButton(
                      tooltip: context.t('حذف الجهاز', 'Delete device'),
                      icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                      onPressed: () => _removeEquipment(equipment),
                    );
                  },
                ),
                if (equipment.code.isNotEmpty)
                  Chip(
                    label: Text(equipment.code),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _meta(
                  Icons.payments_outlined,
                  '${equipment.costPerSession} ${appTr('ج.م', 'EGP')}',
                ),
                _meta(
                  Icons.timer_outlined,
                  context.t(
                    '${equipment.durationMinutes} دقيقة',
                    '${equipment.durationMinutes} min',
                  ),
                ),
                _meta(
                  Icons.schedule,
                  context.t(
                    'انتظار ${equipment.waitDays} يوم',
                    'Wait ${equipment.waitDays} days',
                  ),
                ),
              ],
            ),
            if (equipment.storeCategoryTitle.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openStore(equipment.storeCategoryTitle),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.storefront_outlined,
                          color: Colors.green[800], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.t(
                            'يحتاج مواد من ${_storeCategoryLabel(equipment.storeCategoryTitle)}',
                            'Needs supplies from ${_storeCategoryLabel(equipment.storeCategoryTitle)}',
                          ),
                          style: TextStyle(
                            color: Colors.green[900],
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: Colors.green[800]),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openBooking(equipment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.event_available),
                label: Text(context.t('حجز فوري', 'Instant booking')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
      ],
    );
  }

  Widget _buildRatingTile(LabRating rating) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(
          rating.userName.isNotEmpty
              ? rating.userName[0]
              : appTr('ط', 'S'),
        ),
      ),
      title: Text(rating.userName),
      subtitle: rating.comment.isNotEmpty ? Text(rating.comment) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 16),
          Text('${rating.rating}'),
        ],
      ),
    );
  }

  Widget _buildRatingForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('قيّم هذا المختبر', 'Rate this lab'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _selectedRating = value),
                  icon: Icon(
                    value <= _selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.t('تعليقك (اختياري)', 'Your comment (optional)'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingRating ? null : _submitRating,
                child: Text(
                  _isSubmittingRating
                      ? context.t('جارٍ الحفظ...', 'Saving...')
                      : context.t('إرسال التقييم', 'Submit rating'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

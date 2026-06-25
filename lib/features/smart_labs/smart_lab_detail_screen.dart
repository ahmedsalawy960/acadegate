import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../academic/academic_models.dart';
import '../analysis_labs/request_sample_analysis_screen.dart';
import '../moderation/delete_content_button.dart';
import '../profile/academic_profile_service.dart';
import '../store/product_list_screen.dart';
import '../store/store_categories.dart';
import 'book_equipment_screen.dart';
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('يجب تسجيل الدخول لتقييم المختبر', isError: true);
      return;
    }

    setState(() => _isSubmittingRating = true);

    try {
      final profile = await AcademicProfileService.instance.loadProfile();
      await SmartLabsService.instance.submitRating(
        lab: widget.lab,
        rating: _selectedRating,
        comment: _commentController.text,
        userName: profile?.fullName ?? user.email ?? 'طالب',
      );
      if (!mounted) return;
      _showMessage('تم حفظ تقييمك');
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
          lab: widget.lab,
          equipment: equipment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المختبر'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: deleteAppBarActions(
          collection: 'labs',
          documentId: lab.id,
          ownerId: lab.ownerId,
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
                label: Text('${lab.displayFacultyName} — مرتبط'),
                backgroundColor: Colors.purple[50],
              ),
            ),
          if (lab.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(lab.description),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(lab.labTypeLabel)),
              if (lab.acceptsExternalSamples)
                const Chip(
                  avatar: Icon(Icons.check, size: 16),
                  label: Text('يقبل عينات خارجية'),
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
                label: Text('انتظار من ${lab.minWaitDays} يوم'),
              ),
              if (!lab.isFromFirebase)
                const Chip(
                  avatar: Icon(Icons.info_outline, size: 18),
                  label: Text('بيانات تجريبية — الحجز يتطلب Firebase'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (lab.sampleServices.isNotEmpty || lab.acceptsExternalSamples) ...[
            const Text(
              'خدمات تحليل العينات',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            ...lab.sampleServices.map(_buildSampleServiceCard),
            if (lab.sampleServices.isEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openSampleAnalysisRequestScreen(context, lab: lab),
                  icon: const Icon(Icons.biotech),
                  label: const Text('طلب تحليل عينة'),
                ),
              ),
            const SizedBox(height: 24),
          ],
          const Text(
            'الأجهزة المتاحة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          ...lab.devices.map(_buildEquipmentCard),
          const SizedBox(height: 24),
          const Text(
            'تقييمات الطلاب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          if (lab.isFromFirebase)
            StreamBuilder<List<LabRating>>(
              stream: SmartLabsService.instance.ratingsStream(lab.id!),
              builder: (context, snapshot) {
                final ratings = snapshot.data ?? [];
                if (ratings.isEmpty) {
                  return Text(
                    'لا توجد تقييمات بعد — كن أول من يقيّم',
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
                          '${avg.toStringAsFixed(1)} من 5',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text('(${ratings.length} تقييم)'),
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
          'التقييمات الحية متاحة بعد ربط المختبر بـ Firebase',
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
            '${widget.lab.ratingAvg.toStringAsFixed(1)} من 5 (${widget.lab.ratingsCount} تقييم)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text('طالب ماجستير'),
        subtitle: Text('أجهزة حديثة وفريق متعاون'),
        trailing: Row(
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
            'مدة ${service.turnaroundDays} يوم',
            if (service.priceFrom > 0) 'من ${service.priceFrom} ج.م',
            if (service.sampleTypes.isNotEmpty)
              'عينات: ${service.sampleTypes.join('، ')}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: FilledButton(
          onPressed: () => openSampleAnalysisRequestScreen(
            context,
            lab: widget.lab,
            preselectedService: service,
          ),
          style: FilledButton.styleFrom(backgroundColor: Colors.purple[700]),
          child: const Text('طلب'),
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
                _meta(Icons.payments_outlined, '${equipment.costPerSession} ج.م'),
                _meta(Icons.timer_outlined, '${equipment.durationMinutes} دقيقة'),
                _meta(Icons.schedule, 'انتظار ${equipment.waitDays} يوم'),
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
                          'يحتاج مواد من ${equipment.storeCategoryTitle}',
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
                label: const Text('حجز فوري'),
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
        child: Text(rating.userName.isNotEmpty ? rating.userName[0] : 'ط'),
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
            const Text(
              'قيّم هذا المختبر',
              style: TextStyle(fontWeight: FontWeight.bold),
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
              decoration: const InputDecoration(
                labelText: 'تعليقك (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingRating ? null : _submitRating,
                child: Text(
                  _isSubmittingRating ? 'جارٍ الحفظ...' : 'إرسال التقييم',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

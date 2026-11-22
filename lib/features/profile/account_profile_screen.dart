import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../../core/storage/storage_service.dart';
import '../../core/widgets/safe_network_avatar.dart';
import '../billing/subscription_screen.dart';
import '../store/store_more_screen.dart';
import '../auth/complete_personal_info_screen.dart';
import '../auth/personal_info.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import 'academic_profile_screen.dart';
import 'merchant_business_section.dart';
import 'provider_org_section.dart';

/// ملف الحساب الشخصي — صورة، بريد، اسم، وإدارة الملف الأكاديمي.
class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final _nameController = TextEditingController();
  bool _savingName = false;
  bool _uploadingPhoto = false;
  String? _lastSyncedName;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final uploadFailedMsg =
        context.t('تعذر رفع الصورة', 'Could not upload photo');
    final updatedMsg =
        context.t('تم تحديث صورة الملف', 'Profile photo updated');
    try {
      final file = await StorageService.instance.pickImage();
      if (file == null) return;
      if (!mounted) return;
      setState(() => _uploadingPhoto = true);
      final url = await StorageService.instance.uploadImage(
        file: file,
        folder: 'avatars',
      );
      if (url == null || url.isEmpty) {
        throw Exception(uploadFailedMsg);
      }
      await UserAccountService.instance.updatePhotoUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updatedMsg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('إزالة الصورة', 'Remove photo')),
        content: Text(
          context.t(
            'هل تريد إزالة صورة ملفك الشخصي؟',
            'Remove your profile photo?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('إزالة', 'Remove')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      setState(() => _uploadingPhoto = true);
      await UserAccountService.instance.updatePhotoUrl(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تمت إزالة الصورة', 'Photo removed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingName = true);
    try {
      await UserAccountService.instance.updateDisplayName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تم حفظ الاسم', 'Name saved')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  void _syncNameController(UserAccount? account) {
    if (_savingName) return;
    final authName = FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    final next = (account?.displayName.trim().isNotEmpty == true)
        ? account!.displayName.trim()
        : authName;
    if (_lastSyncedName == next) return;
    _lastSyncedName = next;
    _nameController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('حسابي', 'My account')),
        ),
        body: Center(
          child: Text(
            context.t('سجّل الدخول لإدارة حسابك', 'Sign in to manage your account'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('حسابي', 'My account')),
      ),
      body: StreamBuilder<UserAccount?>(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, snapshot) {
          final account = snapshot.data;
          _syncNameController(account);

          final photoUrl = (account?.photoUrl?.trim().isNotEmpty == true)
              ? account!.photoUrl!.trim()
              : (authUser.photoURL?.trim() ?? '');
          final email = (account?.email.trim().isNotEmpty == true)
              ? account!.email.trim()
              : (authUser.email ?? '');
          final role = account?.role ?? UserRole.student;
          final name = _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : (email.split('@').first);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SafeNetworkAvatar(
                      imageUrl: photoUrl,
                      radius: 56,
                      backgroundColor:
                          const Color(0xFF1A237E).withValues(alpha: 0.12),
                      fallback: Text(
                        name.isNotEmpty
                            ? name.characters.first.toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF4F7FB),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Material(
                        color: const Color(0xFF1A237E),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _uploadingPhoto
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (photoUrl.isNotEmpty)
                Center(
                  child: TextButton(
                    onPressed: _uploadingPhoto ? null : _removePhoto,
                    child: Text(context.t('إزالة الصورة', 'Remove photo')),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                context.t(
                  'صورة الحساب تظهر في أعلى التطبيق بدل أيقونة الشخص.',
                  'Your photo appears in the app bar instead of the person icon.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AcadeGateColors.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('بيانات الحساب', 'Account details'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AcadeGateColors.text,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: context.t('الاسم الظاهر', 'Display name'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _saveName(),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton.icon(
                          onPressed: _savingName ? null : _saveName,
                          icon: _savingName
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(context.t('حفظ الاسم', 'Save name')),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined),
                        title: Text(context.t('البريد الإلكتروني', 'Email')),
                        subtitle: Text(email.isEmpty ? '—' : email),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.work_outline),
                        title: Text(context.t('الدور', 'Role')),
                        subtitle: Text(UserRole.label(role)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AcadeGateColors.line),
                ),
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: Text(context.t('الاشتراك', 'Subscription')),
                  subtitle: Text(
                    account?.isAdmin == true
                        ? 'Admin'
                        : SubscriptionTier.label(
                            account?.effectiveTier ?? SubscriptionTier.free,
                          ),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AcadeGateColors.line),
                ),
                child: ListTile(
                  leading: const Icon(Icons.grid_view_outlined),
                  title: Text(context.t('المزيد في المتجر', 'Store more')),
                  subtitle: Text(
                    context.t(
                      'الطلبات، المفضلة، الخصومات، والمقارنة',
                      'Orders, favorites, offers, and compare',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StoreMoreScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PersonalInfoCard(info: account?.personalInfo ?? const PersonalInfo()),
              const SizedBox(height: 16),
              if (UserRole.showsMerchantBusiness(role)) ...[
                MerchantBusinessSection(
                  account: account ??
                      UserAccount(
                        uid: authUser.uid,
                        email: email,
                        displayName: name,
                        role: role,
                      ),
                ),
                const SizedBox(height: 16),
              ],
              if (UserRole.showsProviderOrg(role) &&
                  role != UserRole.admin) ...[
                ProviderOrgSection(
                  account: account ??
                      UserAccount(
                        uid: authUser.uid,
                        email: email,
                        displayName: name,
                        role: role,
                      ),
                ),
                const SizedBox(height: 16),
              ],
              if (UserRole.showsAcademicProfile(role))
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.school_outlined,
                          color: Color(0xFFF4F7FB),
                        ),
                        title: Text(
                          context.t('الملف الأكاديمي', 'Academic profile'),
                        ),
                        subtitle: Text(
                          context.t(
                            'الجامعة، التخصص، الاهتمام البحثي، المهارات',
                            'University, specialization, research interest, skills',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AcademicProfileScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.info});

  final PersonalInfo info;

  @override
  Widget build(BuildContext context) {
    String orDash(String v) => v.trim().isEmpty ? '—' : v;
    final birth = info.birthDate;
    final age = info.age;

    Widget row(IconData icon, String title, String value) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(value),
        );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AcadeGateColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('البيانات الشخصية', 'Personal details'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AcadeGateColors.text,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompletePersonalInfoScreen(
                        initial: info,
                        isEdit: true,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(context.t('تعديل', 'Edit')),
                ),
              ],
            ),
            Text(
              context.t(
                'خاصة بك ولا تظهر لباقي المستخدمين.',
                'Private — not shown to other users.',
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFFB7C3D6)),
            ),
            const SizedBox(height: 8),
            row(
              Icons.phone_outlined,
              context.t('رقم الموبايل', 'Mobile number'),
              orDash(PersonalInfo.localPhone(info.phone)),
            ),
            row(
              Icons.wc_outlined,
              context.t('النوع', 'Gender'),
              Gender.all.contains(info.gender)
                  ? context.t(
                      Gender.labelAr(info.gender),
                      Gender.labelEn(info.gender),
                    )
                  : '—',
            ),
            row(
              Icons.cake_outlined,
              context.t('تاريخ الميلاد', 'Date of birth'),
              birth == null
                  ? '—'
                  : '${birth.day}/${birth.month}/${birth.year}'
                      '${age == null ? '' : context.t('  ($age سنة)', '  (age $age)')}',
            ),
            row(
              Icons.location_on_outlined,
              context.t('المحافظة', 'Governorate'),
              orDash(info.governorate),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/directory/claim_profile_sheet.dart';
import '../../core/directory/directory_trust_status.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../auth/login_screen.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../moderation/delete_content_button.dart';
import '../store/catalog_disclaimer.dart';
import '../supervision/contact_supervisor.dart';
import '../supervisor_metrics/supervisor_publication_panel.dart';
import 'academic_models.dart';

class SupervisorProfileScreen extends StatefulWidget {
  final AcademicSupervisor supervisor;

  const SupervisorProfileScreen({super.key, required this.supervisor});

  @override
  State<SupervisorProfileScreen> createState() =>
      _SupervisorProfileScreenState();
}

class _SupervisorProfileScreenState extends State<SupervisorProfileScreen> {
  late AcademicSupervisor _supervisor;

  @override
  void initState() {
    super.initState();
    _supervisor = widget.supervisor;
  }

  Future<void> _openClaimProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final id = _supervisor.id;
    if (id == null || id.isEmpty) return;
    await showClaimProfileSheet(
      context,
      targetType: 'supervisor',
      targetId: id,
      targetName: _supervisor.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final supervisor = _supervisor;
    final bio = supervisor.bio.isEmpty
        ? L10nLookup.professorBioDefault(supervisor.speciality)
        : supervisor.bio;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(L10nLookup.supervisorProfile),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: deleteAppBarActions(
          collection: 'supervisors',
          documentId: supervisor.id,
          ownerId: supervisor.ownerId,
          itemLabel: supervisor.name,
          isDemo: supervisor.isDemo,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: const Color(0xFF1A237E),
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: supervisor.photoUrl.isNotEmpty
                        ? NetworkImage(supervisor.photoUrl)
                        : null,
                    child: supervisor.photoUrl.isEmpty
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    supervisor.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    supervisor.university,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10nLookup.specialityLabel(supervisor.speciality),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  if (supervisor.hasPublicationIds) ...[
                    const SizedBox(height: 10),
                    SupervisorMetricsChipRow(supervisor: supervisor),
                  ],
                  const Divider(height: 30),
                  SupervisorPublicationPanel(supervisor: supervisor),
                  const SizedBox(height: 20),
                  Text(
                    L10nLookup.supervisorBioSection,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                  ),
                  DirectoryTrustChip(
                    status: DirectoryTrustStatus.resolve(
                      directoryStatus: supervisor.directoryStatus,
                      ownerId: supervisor.ownerId,
                    ),
                    lastManagedLabel: supervisor.lastManagedIso,
                  ),
                  if ((supervisor.id ?? '').isNotEmpty)
                    CatalogReportLink(
                      targetType: 'supervisor',
                      supplierId: supervisor.id,
                      storeName: supervisor.name,
                      emphasizeFakeSupervisor: true,
                    ),
                  if (supervisor.isClaimable) ...[
                    const SizedBox(height: 24),
                    Material(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.t(
                                'هل هذا ملفك؟',
                                'Is this your profile?',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.teal.shade900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.t(
                                'أرسل إثبات التمثيل عبر «مطالبة هذا الملف». بعد المراجعة يصبح «موثّق ومُدار» وتصلك طلبات الإشراف.',
                                'Submit representation proof via “Claim this profile”. After review it becomes Managed Verified and supervision requests reach you.',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.teal.shade900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            StreamBuilder(
                              stream: UserAccountService.instance
                                  .watchCurrentAccount(),
                              builder: (context, snap) {
                                final role = snap.data?.role ?? '';
                                final signedIn =
                                    FirebaseAuth.instance.currentUser != null;
                                final canClaim = !signedIn ||
                                    role == UserRole.supervisor ||
                                    role == UserRole.student ||
                                    role == UserRole.admin;
                                if (!canClaim) {
                                  return Text(
                                    context.t(
                                      'للمطالبة سجّل بدور مشرف (أو طالب ثم اربط بعد الاعتماد).',
                                      'To claim, register as supervisor (or student — promoted after approval).',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade800,
                                    ),
                                  );
                                }
                                return FilledButton.icon(
                                  onPressed: _openClaimProfile,
                                  icon: const Icon(Icons.badge_outlined),
                                  label: Text(
                                    context.t(
                                      'مطالبة هذا الملف',
                                      'Claim this profile',
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              contactSupervisor(context, supervisor),
                          icon: const Icon(Icons.email),
                          label: Text(L10nLookup.messageSupervisor),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              requestSupervision(context, supervisor),
                          icon: const Icon(Icons.check_circle),
                          label: Text(L10nLookup.requestSupervisionLabel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ManageContentActions(
                    collection: 'supervisors',
                    documentId: supervisor.id,
                    ownerId: supervisor.ownerId,
                    itemLabel: supervisor.name,
                    isDemo: supervisor.isDemo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

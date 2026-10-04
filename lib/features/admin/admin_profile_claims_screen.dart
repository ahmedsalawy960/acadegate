import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/directory/directory_trust_status.dart';
import '../../core/directory/profile_claim_service.dart';
import '../../core/locale/locale_extensions.dart';
import 'admin_access_gate.dart';

/// Admin inbox: approve/reject Claim Profile requests → Managed Verified.
class AdminProfileClaimsScreen extends StatelessWidget {
  const AdminProfileClaimsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminAccessGate(
      child: Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(
            context.t('مطالبات الملفات', 'Profile claims'),
          ),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ProfileClaimService.instance.watchPending(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Center(
                child: Text(context.t('لا مطالبات', 'No claims')),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final doc = docs[i];
                final d = doc.data();
                final status = d['status']?.toString() ?? '';
                final evidence =
                    (d['evidence'] as Map?)?.cast<String, dynamic>() ?? {};
                final pending = status == 'pending_review';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d['targetType']} · ${d['targetName'] ?? d['targetId']}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d['claimantName']} (${d['claimantRole']}) · $status',
                          style: TextStyle(color: const Color(0xFFB7C3D6)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            evidence['legalName'],
                            evidence['jobTitle'],
                            evidence['officialEmail'],
                            evidence['commercialRegisterNo'],
                          ].where((e) => (e?.toString() ?? '').isNotEmpty).join(' · '),
                          style: const TextStyle(height: 1.35),
                        ),
                        if ((evidence['notes']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(evidence['notes'].toString()),
                        ],
                        if ((evidence['proofUrl']?.toString() ?? '').isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              final u = Uri.tryParse(
                                evidence['proofUrl'].toString(),
                              );
                              if (u != null) {
                                launchUrl(u, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.attach_file),
                            label: Text(context.t('فتح الإثبات', 'Open proof')),
                          ),
                        if (pending)
                          Row(
                            children: [
                              FilledButton(
                                onPressed: () async {
                                  try {
                                    await ProfileClaimService.instance
                                        .approveClaim(doc.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.t(
                                            'تمت الموافقة — Managed Verified',
                                            'Approved — Managed Verified',
                                          ),
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                },
                                child: Text(
                                  context.t(
                                    'اعتماد → موثّق ومُدار',
                                    'Approve → Managed Verified',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () async {
                                  try {
                                    await ProfileClaimService.instance
                                        .rejectClaim(doc.id);
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                },
                                child: Text(context.t('رفض', 'Reject')),
                              ),
                            ],
                          )
                        else if (status == 'approved')
                          DirectoryTrustChip(
                            status: DirectoryTrustStatus.managedVerified,
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

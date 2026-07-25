import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:flutter/material.dart';

import '../../core/locale/l10n_lookup.dart';
import '../moderation/delete_content_button.dart';
import '../supervision/contact_supervisor.dart';
import '../supervisor_metrics/supervisor_publication_panel.dart';
import 'academic_models.dart';

class SupervisorProfileScreen extends StatelessWidget {
  final AcademicSupervisor supervisor;

  const SupervisorProfileScreen({super.key, required this.supervisor});

  @override
  Widget build(BuildContext context) {
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

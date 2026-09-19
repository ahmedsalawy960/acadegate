import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../academic/supervisor_profile_screen.dart';
import '../smart_labs/book_equipment_screen.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import '../supervision/contact_supervisor.dart';
import 'catalog_hit.dart';

class CatalogHitActions {
  CatalogHitActions._();

  static Future<void> open(BuildContext context, CatalogHit hit) async {
    if (hit.kind == CatalogHitKind.lab) {
      await openLab(context, hit);
      return;
    }
    await openSupervisor(context, hit);
  }

  static Future<void> openLab(BuildContext context, CatalogHit hit) async {
    final lab = await _lab(context, hit.id);
    if (lab == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SmartLabDetailScreen(lab: lab)),
    );
  }

  static Future<void> book(BuildContext context, CatalogHit hit) async {
    final lab = await _lab(context, hit.id);
    if (lab == null || !context.mounted) return;
    LabEquipment? equipment;
    if (hit.matchedEquipmentId.isNotEmpty) {
      for (final item in lab.devices) {
        if (item.id == hit.matchedEquipmentId ||
            item.name == hit.matchedEquipmentName) {
          equipment = item;
          break;
        }
      }
    }
    equipment ??= lab.devices.isEmpty ? null : lab.devices.first;
    if (equipment == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SmartLabDetailScreen(lab: lab)),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookEquipmentScreen(lab: lab, equipment: equipment!),
      ),
    );
  }

  static Future<void> openSupervisor(
    BuildContext context,
    CatalogHit hit,
  ) async {
    final supervisor = await _supervisor(context, hit.id);
    if (supervisor == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupervisorProfileScreen(supervisor: supervisor),
      ),
    );
  }

  static Future<void> contact(BuildContext context, CatalogHit hit) async {
    final supervisor = await _supervisor(context, hit.id);
    if (supervisor == null || !context.mounted) return;
    await contactSupervisor(context, supervisor);
  }

  static Future<AcademicLab?> _lab(BuildContext context, String id) async {
    final lab = await AcademicContentService.instance.fetchLabById(id);
    if (lab == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تعذر فتح المختبر. ربما حُذف أو لم يُنشر بعد.',
              'Could not open the lab. It may have been removed.',
            ),
          ),
        ),
      );
    }
    return lab;
  }

  static Future<AcademicSupervisor?> _supervisor(
    BuildContext context,
    String id,
  ) async {
    final supervisor =
        await AcademicContentService.instance.fetchSupervisorById(id);
    if (supervisor == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تعذر فتح ملف المشرف.',
              'Could not open the supervisor profile.',
            ),
          ),
        ),
      );
    }
    return supervisor;
  }
}

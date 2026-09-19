import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../academic/academic_models.dart';
import 'lab_operations.dart';

class LabTrainingService {
  LabTrainingService._();

  static final LabTrainingService instance = LabTrainingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _mine(String uid) =>
      _db.collection('users').doc(uid).collection('device_trainings');

  Future<bool> hasCompleted({
    required String labId,
    required String equipmentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final snap = await _mine(user.uid)
        .doc(LabOperations.trainingDocId(labId: labId, equipmentId: equipmentId))
        .get();
    return snap.data()?['status']?.toString() == 'completed';
  }

  Stream<bool> watchCompleted({
    required String labId,
    required String equipmentId,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);
    return _mine(user.uid)
        .doc(LabOperations.trainingDocId(labId: labId, equipmentId: equipmentId))
        .snapshots()
        .map((snap) => snap.data()?['status']?.toString() == 'completed');
  }

  Future<void> recordSelfAttested({
    required AcademicLab lab,
    required LabEquipment equipment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
        appTr(
          'سجّل الدخول لتسجيل التدريب',
          'Sign in to record training',
        ),
      );
    }
    if (!lab.isFromFirebase) {
      throw Exception(
        appTr(
          'التدريب يُسجَّل للمختبرات المسجّلة فقط',
          'Training is recorded for registered labs only',
        ),
      );
    }
    await _mine(user.uid)
        .doc(
          LabOperations.trainingDocId(
            labId: lab.id!,
            equipmentId: equipment.id,
          ),
        )
        .set({
      'labId': lab.id,
      'labName': lab.name,
      'equipmentId': equipment.id,
      'equipmentName': equipment.name,
      'nbsleLab': lab.isNbsleImport,
      'status': 'completed',
      'mode': 'self_attested',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}

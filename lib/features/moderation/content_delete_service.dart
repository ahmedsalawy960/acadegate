import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/l10n_lookup.dart';
import '../auth/user_account_service.dart';

class ContentDeleteService {
  ContentDeleteService._();

  static final ContentDeleteService instance = ContentDeleteService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> canDelete({String? ownerId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final account = await UserAccountService.instance.loadCurrentAccount();
    if (account?.isAdmin == true) return true;

    return ownerId != null && ownerId.isNotEmpty && ownerId == user.uid;
  }

  Future<bool> confirmAndDelete(
    BuildContext context, {
    required String collection,
    required String documentId,
    required String itemLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10nLookup.confirmDelete),
        content: Text(L10nLookup.deleteConfirmMessage(itemLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L10nLookup.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L10nLookup.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await _deleteByCollection(collection, documentId);
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10nLookup.deleteFailed(error)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _deleteByCollection(String collection, String documentId) async {
    switch (collection) {
      case 'labs':
        await deleteLabDocument(documentId);
        return;
      case 'research_ideas':
        await _deleteWithSubcollections(
          parentPath: 'research_ideas/$documentId',
          subcollections: const ['proposals', 'votes'],
        );
        return;
      case 'community_posts':
        await _deleteWithSubcollections(
          parentPath: 'community_posts/$documentId',
          subcollections: const ['replies', 'upvotes'],
        );
        return;
      case 'writing_services':
        await _deleteWithSubcollections(
          parentPath: 'writing_services/$documentId',
          subcollections: const ['writing_orders'],
        );
        return;
      default:
        await _db.collection(collection).doc(documentId).delete();
    }
  }

  Future<void> deleteLabDocument(String documentId) async {
    await _deleteWithSubcollections(
      parentPath: 'labs/$documentId',
      subcollections: const ['bookings', 'ratings'],
    );
  }

  Future<void> _deleteWithSubcollections({
    required String parentPath,
    required List<String> subcollections,
  }) async {
    final segments = parentPath.split('/');
    final parentRef = _db.collection(segments[0]).doc(segments[1]);

    for (final sub in subcollections) {
      final snapshot = await parentRef.collection(sub).get();
      if (snapshot.docs.isEmpty) continue;

      var batch = _db.batch();
      var count = 0;
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 400) {
          await batch.commit();
          batch = _db.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();
    }

    await parentRef.delete();
  }
}

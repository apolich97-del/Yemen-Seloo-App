import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// خدمة سجل التدقيق والمحذوفات — توثّق كل تعديل أو حذف يقوم به المدير والموظفون.
class AuditService extends GetxService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> logAction({
    required String action,
    required String collectionName,
    required String docId,
    required String summary,
    Map<String, dynamic> meta = const <String, dynamic>{},
  }) async {
    try {
      await _db.collection('audit_logs').add({
        'action': action,
        'collection': collectionName,
        'docId': docId,
        'summary': summary,
        'meta': meta,
        'byUid': _auth.currentUser?.uid ?? '',
        'byEmail': _auth.currentUser?.email ?? '',
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// أرشفة أي سجل (طلب / إيصال / منتج كتالوج / تنبيه) ثم حذفه بأمان.
  Future<void> archiveAndDelete({
    required String collectionName,
    required String docId,
    required Map<String, dynamic> snapshotData,
    String reason = '',
    String summary = '',
  }) async {
    await _db.collection('deleted_records').add({
      'collection': collectionName,
      'docId': docId,
      'summary': summary.isEmpty ? '$collectionName/$docId' : summary,
      'reason': reason.trim(),
      'snapshot': snapshotData,
      'deletedByUid': _auth.currentUser?.uid ?? '',
      'deletedByEmail': _auth.currentUser?.email ?? '',
      'deletedAt': FieldValue.serverTimestamp(),
    });
    await logAction(
      action: 'delete',
      collectionName: collectionName,
      docId: docId,
      summary: summary.isEmpty ? 'حذف $collectionName/$docId' : summary,
      meta: {'reason': reason.trim()},
    );
  }
}

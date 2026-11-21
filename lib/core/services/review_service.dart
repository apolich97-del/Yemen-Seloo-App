import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// تقييم العميل بعد استلام الطلب — يُنشر بعد مراجعة الإدارة فقط.
class ReviewService extends GetxService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> mine() => _db
      .collection('reviews')
      .where('userId', isEqualTo: _uid)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> pending() => _db
      .collection('reviews')
      .where('status', isEqualTo: 'pending')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> approved() => _db
      .collection('reviews')
      .where('status', isEqualTo: 'approved')
      .limit(12)
      .snapshots();

  Future<void> submit({
    required String orderId,
    required String orderNo,
    required int rating,
    required List<String> tags,
    required String text,
    required String governorate,
    required String photoData,
    String customerName = '',
  }) async {
    await _db.collection('reviews').add({
      'userId': _uid,
      'orderId': orderId,
      'orderNo': orderNo,
      'customerName': customerName,
      'rating': rating,
      'tags': tags,
      'text': text,
      'governorate': governorate,
      'photoUrl': photoData,
      'status': 'pending',
      'reply': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> moderate(String id, String status, {String reply = ''}) =>
      _db.collection('reviews').doc(id).update({
        'status': status,
        'reply': reply,
        'moderatedAt': FieldValue.serverTimestamp(),
        'moderatedBy': FirebaseAuth.instance.currentUser?.email ?? '',
      });

  Future<void> deleteReview(String id) =>
      _db.collection('reviews').doc(id).delete();
}

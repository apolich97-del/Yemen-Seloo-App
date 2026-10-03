import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../../core/config/seloo_config.dart';
import '../data/seloo_cart_service.dart';
import '../domain/cart_item.dart';

/// حالة السلة المشتركة في التطبيق.
///
/// مصدر الحقيقة هو Firestore، وليس ذاكرة الواجهة.
class CartCounter extends GetxService {
  CartCounter({SelooCartService? service, FirebaseFirestore? firestore})
      : _service = service ?? SelooCartService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final SelooCartService _service;
  final FirebaseFirestore _firestore;

  final RxList<CartItem> items = <CartItem>[].obs;
  final Rx<CartQuote?> quote = Rx<CartQuote?>(null);
  final RxBool busy = false.obs;
  final RxnString lastError = RxnString();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<User?>? _authSubscription;

  Stream<int> get stream =>
      items.stream.map((List<CartItem> list) => list.length);
  int get count => items.length;
  double get subtotalLocal => items.fold<double>(
      0, (double sum, CartItem item) => sum + item.lineTotalLocal);

  @override
  void onInit() {
    super.onInit();
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _subscription?.cancel();
      items.clear();
      if (user != null) {
        _subscribe(user.uid);
      }
    });
  }

  void _subscribe(String uid) {
    _subscription = _firestore
        .collection(SelooConfig.usersCollection)
        .doc(uid)
        .collection(SelooConfig.cartCollection)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        items.assignAll(
          snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              CartItem.fromFirestore(doc.id, doc.data())),
        );
      },
      onError: (Object error, StackTrace stack) {
        lastError.value = 'تعذّر تحميل السلة: $error';
      },
    );
  }

  Future<void> refreshQuote() async {
    if (items.isEmpty) {
      quote.value = null;
      return;
    }
    busy.value = true;
    try {
      quote.value = await _service.quote();
      lastError.value = null;
    } catch (error) {
      lastError.value = 'تعذّر حساب الإجمالي: $error';
    } finally {
      busy.value = false;
    }
  }

  Future<String?> updateQuantity(CartItem item, int quantity) async {
    if (quantity < 1 || quantity > SelooConfig.maxQuantityPerLine) {
      return 'الكمية يجب أن تكون بين 1 و ${SelooConfig.maxQuantityPerLine}';
    }
    busy.value = true;
    try {
      final result = await _service.updateLine(item.lineId, quantity);
      if (result.isOk) await refreshQuote();
      return result.isOk ? null : result.message;
    } catch (error) {
      return 'تعذّر تحديث الكمية: $error';
    } finally {
      busy.value = false;
    }
  }

  Future<String?> remove(CartItem item) async {
    busy.value = true;
    try {
      final result = await _service.removeLine(item.lineId);
      if (result.isOk) await refreshQuote();
      return result.isOk ? null : result.message;
    } catch (error) {
      return 'تعذّر حذف المنتج: $error';
    } finally {
      busy.value = false;
    }
  }

  Future<String?> clear() async {
    busy.value = true;
    try {
      final result = await _service.clear();
      quote.value = null;
      return result.isOk ? null : result.message;
    } catch (error) {
      return 'تعذّر تفريغ السلة: $error';
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.onClose();
  }
}

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/cart/application/cart_counter.dart';
import '../config/payment_accounts.dart';
import '../models/currency.dart';
import '../models/order.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../models/cart.dart';
import '../services/order_service.dart';
import 'checkout_controller.dart';

/// بيانات الحوالة كما يدخلها العميل في نافذة «بيانات الحوالة».
class TransferDraft {
  final String senderName;
  final String refNo;
  final String note;
  final String proofUrl;

  const TransferDraft({
    required this.senderName,
    required this.refNo,
    this.note = '',
    this.proofUrl = '',
  });
}

class PaymentController extends GetxController {
  final _orders = Get.find<OrderService>();
  final _auth = Get.find<AuthService>();
  final _cart = Get.find<CartRepository>();
  final _cartCounter = Get.find<CartCounter>();

  late final CheckoutPayload payload;
  final accounts = <PaymentAccount>[].obs;
  final selected = Rxn<PaymentAccount>();
  final transfer = Rxn<TransferDraft>();
  final busy = false.obs;
  final uploading = false.obs;

  final amountCtrl = TextEditingController();
  final senderCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    payload = Get.arguments as CheckoutPayload;
    accounts.assignAll(accountsForCurrency(payload.currency));
    amountCtrl.text = payload.estimate.totalLocal.toStringAsFixed(payload.currency.decimals == 0 ? 0 : 2);
    if (accounts.length == 1) selected.value = accounts.first;
  }

  @override
  void onClose() {
    amountCtrl.dispose();
    senderCtrl.dispose();
    refCtrl.dispose();
    noteCtrl.dispose();
    super.onClose();
  }

  AppCurrency get currency => payload.currency;
  String get totalLabel => formatMoney(payload.estimate.totalLocal, currency);
  bool get canConfirm => transfer.value != null && !busy.value;

  void select(PaymentAccount a) => selected.value = a;

  Future<void> pickProof() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (x == null) return;
      uploading.value = true;
      final uid = _auth.uid ?? 'anon';
      final ref = FirebaseStorage.instance
          .ref('proofs/$uid/${DateTime.now().millisecondsSinceEpoch}_${x.name}');
      await ref.putFile(File(x.path));
      _proofUrl = await ref.getDownloadURL();
      Get.snackbar('تم', 'تم إرفاق صورة الحوالة');
    } catch (e) {
      Get.snackbar('تعذر الإرفاق', 'يمكنك إكمال الطلب بدون صورة، أو المحاولة لاحقاً');
    } finally {
      uploading.value = false;
    }
  }

  String _proofUrl = '';

  /// تُفتح عند الضغط على «إدخال بيانات الحوالة».
  void saveTransfer() {
    final sender = senderCtrl.text.trim();
    final refNo = refCtrl.text.trim();
    if (sender.length < 3) {
      Get.snackbar('بيانات ناقصة', 'أدخل اسم المرسل كما في الحوالة');
      return;
    }
    if (refNo.length < 4) {
      Get.snackbar('بيانات ناقصة', 'أدخل رقم عملية الحوالة');
      return;
    }
    transfer.value = TransferDraft(
      senderName: sender,
      refNo: refNo,
      note: noteCtrl.text.trim(),
      proofUrl: _proofUrl,
    );
    Get.back();
  }

  Future<void> confirmPayment() async {
    final t = transfer.value;
    final acc = selected.value;
    if (t == null || acc == null) return;
    busy.value = true;
    try {
      final orderNo = await _orders.submitOrder(
        lines: payload.lines,
        currency: currency,
        address: payload.address,
        couponCode: payload.estimate.couponCode,
        payment: {
          'accountId': acc.id,
          'accountTitleAr': acc.titleAr,
          'accountNumber': acc.primaryNumber,
          'amount': payload.estimate.totalLocal,
          'currency': currency.key,
          'senderName': t.senderName,
          'refNo': t.refNo,
          'note': t.note,
          'proofUrl': t.proofUrl,
        },
        // عمولة المندوب: بند داخلي لا يُضاف إلى إجمالي العميل.
        commission: <String, dynamic>{
          'perPieceSar': _cartCounter.commissionPerPiece.value,
          'approved': _cartCounter.commissionApproved.value,
        },
      );
      _cart.clear();
      Get.offAllNamed(AppRoutes.orders);
      Get.snackbar(
        'تم إرسال الطلب',
        'رقم الطلب $orderNo — سيُفعّل بعد تأكيد الحوالة من المحاسبة',
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar('تعذر إرسال الطلب', '$e');
    } finally {
      busy.value = false;
    }
  }

  void copyNumber(String value) {
    Clipboard.setData(ClipboardData(text: value));
    Get.snackbar('تم النسخ', value);
  }

  /// معاينة المبلغ المتوقّع (يُعاد حسابه على السيرفر).
  Map<String, dynamic> debugPayload() => {
        'currency': currency.key,
        'totalLocal': payload.estimate.totalLocal,
        'rate': payload.estimate.rate,
        'server_timestamp_placeholder': FieldValue.serverTimestamp(),
      };
}

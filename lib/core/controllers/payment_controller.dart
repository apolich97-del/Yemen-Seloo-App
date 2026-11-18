import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/cart/application/cart_counter.dart';
import '../config/payment_accounts.dart';
import '../models/currency.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../models/cart.dart';
import '../services/order_service.dart';
import 'checkout_controller.dart';

/// بيانات الحوالة كما يدخلها العميل في نافذة «بيانات الحوالة».
class TransferDraft {
  final double amount;
  final String senderName;
  final String refNo;
  final String note;
  final String proofUrl;

  const TransferDraft({
    required this.amount,
    required this.senderName,
    required this.refNo,
    this.note = '',
    required this.proofUrl,
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
    amountCtrl.text = payload.estimate.totalLocal
        .toStringAsFixed(payload.currency.decimals == 0 ? 0 : 2);
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
  bool get proofAttached => proofImage.value.isNotEmpty;

  /// صورة الحوالة كـ data URI لعرضها للمستخدم قبل الإرسال.
  String get proofDataUri => proofImage.value;

  bool get canConfirm =>
      transfer.value != null &&
      transfer.value!.proofUrl.isNotEmpty &&
      transfer.value!.amount + 0.01 >= payload.estimate.totalLocal &&
      !busy.value;

  void select(PaymentAccount a) => selected.value = a;

  final proofImage = ''.obs;
  final ocrDone = false.obs;
  final ocrAmountOk = false.obs;
  final ocrRefOk = false.obs;
  final ocrDateOk = false.obs;
  final ocrNameOk = false.obs;
  String _ocrRaw = '';
  TextRecognizer? _recognizer;

  /// تطبيع الأرقام العربية-الهندية إلى لاتينية ثم إزالة الفواصل.
  String _normDigits(String t) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in t.split('')) {
      final i = ar.indexOf(ch);
      final j = fa.indexOf(ch);
      if (i >= 0) {
        b.write(i);
      } else if (j >= 0) {
        b.write(j);
      } else {
        b.write(ch);
      }
    }
    return b.toString().replaceAll(RegExp(r'[\s,_\-\u200f\u200e]'), '');
  }

  /// قراءة الصورة ومقارنة المبلغ ورقم العملية والتاريخ ببيانات الحوالة.
  Future<void> _runOcr(String path) async {
    ocrDone.value = false;
    ocrAmountOk.value = false;
    ocrRefOk.value = false;
    ocrDateOk.value = false;
    try {
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
      final res = await _recognizer!
          .processImage(InputImage.fromFilePath(path));
      _ocrRaw = res.text;
      final text = _normDigits(_ocrRaw);

      final amount = amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '');
      final whole = amount.split('.').first;
      ocrAmountOk.value = whole.isNotEmpty && text.contains(whole);

      final ref = refCtrl.text.replaceAll(RegExp(r'\D'), '');
      ocrRefOk.value = ref.length >= 4 && text.contains(ref);

      // مطابقة اسم المودع: يكفي تطابق كلمتين من اسم المرسل.
      final name = _normDigits(senderCtrl.text.trim());
      final words = name.split(RegExp(r'\s+')).where((w) => w.length > 2);
      final hits = words.where(text.contains).length;
      ocrNameOk.value = words.isNotEmpty && hits >= (words.length > 1 ? 2 : 1);

      final now = DateTime.now();
      final dmy = ['${now.day}${now.month}', '${now.month}${now.day}',
        '${now.day}${now.month}${now.year}', '${now.year}${now.month}${now.day}'];
      ocrDateOk.value = dmy.any(text.contains);

      ocrDone.value = _ocrRaw.trim().isNotEmpty;
      debugPrint('OCR text: ${_ocrRaw.replaceAll(RegExp(r'\s+'), ' ')}');
    } catch (e) {
      debugPrint('OCR FAILED: $e');
      ocrDone.value = false;
    }
  }

  Future<void> pickProof() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 25,
        maxWidth: 720,
        maxHeight: 720,
      );
      if (x == null) return;
      uploading.value = true;
      final bytes = await x.readAsBytes();
      if (bytes.length > 300 * 1024) {
        Get.snackbar('الصورة كبيرة',
            'اختر صورة أصغر (أقل من 300 ك.ب) أو قصّها ثم أعد المحاولة');
        return;
      }
      final mime = (x.path.toLowerCase().endsWith('.png')) ? 'image/png' : 'image/jpeg';
      proofImage.value = 'data:$mime;base64,${base64Encode(bytes)}';
      await _runOcr(x.path);
      if (!ocrDone.value) {
        Get.snackbar('تم الإرفاق', 'تعذر قراءة نص الصورة — ستُراجع يدوياً',
            duration: const Duration(seconds: 4));
      } else if (ocrAmountOk.value && ocrRefOk.value) {
        Get.snackbar('تم', 'الصورة مطابقة للمبلغ ورقم العملية');
      } else {
        Get.snackbar('تحقق من الصورة',
            'لم تتطابق ${!ocrAmountOk.value ? 'المبلغ ' : ''}${!ocrRefOk.value ? 'رقم العملية' : ''}',
            duration: const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('PROOF ATTACH FAILED: $e');
      Get.snackbar('تعذر إرفاق الصورة', 'أعد المحاولة');
    } finally {
      uploading.value = false;
    }
  }


  /// تُفتح عند الضغط على «إدخال بيانات الحوالة».
  void saveTransfer() {
    final sender = senderCtrl.text.trim();
    final refNo = refCtrl.text.trim();
    if (sender.length < 3) {
      Get.snackbar('بيانات ناقصة', 'أدخل اسم المرسل كما في الحوالة');
      return;
    }
    // رقم العملية اختياري: بعض الحوالات تُعرف باسم المودع فقط.
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      Get.snackbar('المبلغ مطلوب', 'أدخل المبلغ الذي حوّلته فعلاً');
      return;
    }
    final required = payload.paymentPlan == 'half_deferred'
        ? roundMoney(payload.estimate.totalLocal * (payload.upfrontPercent / 100),
            payload.currency)
        : payload.estimate.totalLocal;
    if (amount + 0.01 < required) {
      Get.snackbar(
        'المبلغ أقل من المطلوب',
        'إجمالي الطلب ${formatMoney(required, currency)} — لا يُقبل مبلغ أقل منه',
        duration: const Duration(seconds: 4),
      );
      return;
    }
    if (proofImage.value.isEmpty) {
      Get.snackbar('صورة الحوالة مطلوبة', 'أرفق صورة الإيداع أو الحوالة قبل الإرسال');
      return;
    }
    // نتائج القراءة إرشادية: المحاسبة تراجع الصورة، فلا نمنع العميل
    // بسبب صورة غير واضحة أو حوالة مكتوبة بخط لا يقرأه المحرك.
    transfer.value = TransferDraft(
      amount: amount,
      senderName: sender,
      refNo: refNo,
      note: noteCtrl.text.trim(),
      proofUrl: proofImage.value,
    );
    Get.back();
  }

  Future<void> confirmPayment() async {
    final t = transfer.value;
    final acc = selected.value;
    if (t == null || acc == null) return;
    busy.value = true;
    try {
      final cc = _cartCounter;
      final orderNo = await _orders.submitOrder(
        lines: payload.lines,
        currency: currency,
        address: payload.address,
        couponCode: payload.estimate.couponCode,
        estimate: payload.estimate,
        paymentPlan: payload.paymentPlan,
        upfrontPercent: payload.upfrontPercent,
        payment: {
          'accountId': acc.id,
          'accountTitleAr': acc.titleAr,
          'accountNumber': acc.primaryNumber,
          'amount': t.amount,
          'requiredAmount': payload.estimate.totalLocal,
          'proofVerified': ocrDone.value && ocrAmountOk.value && ocrRefOk.value,
          'ocrChecks': <String, dynamic>{
            'read': ocrDone.value,
            'amount': ocrAmountOk.value,
            'ref': ocrRefOk.value,
            'date': ocrDateOk.value,
            'raw': _ocrRaw.length > 300 ? _ocrRaw.substring(0, 300) : _ocrRaw,
          },
          'currency': currency.key,
          'senderName': t.senderName,
          'refNo': t.refNo,
          'note': t.note,
          'proofUrl': t.proofUrl,
          // أي زيادة فوق قيمة الطلب والشحن تُسجَّل رصيداً للعميل.
          // الفائض فوق إجمالي الطلب فقط يُسجّل رصيداً؛ وما بين الدفعة
          // الأولى والإجمالي يُخصم من المتبقي.
          'creditLocal': t.amount > payload.estimate.totalLocal
              ? (t.amount - payload.estimate.totalLocal)
              : 0.0,
        },
        // عمولة المندوب: بند داخلي لا يُضاف إلى إجمالي العميل.
        commission: <String, dynamic>{
          'perPieceSar': cc
              .commissionPerPiece
              .value,
          'approved': cc
              .commissionApproved
              .value,
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
      final msg = '$e';
      final hint = msg.contains('permission')
          ? 'قواعد Firestore المحدّثة لم تُنشر بعد — انشرها من الكونسول ثم أعد المحاولة.'
          : msg.contains('maximum') || msg.contains('longer than')
              ? 'صورة الحوالة كبيرة على الحفظ — التقط صورة أوضح وأصغر.'
              : msg;
      Get.snackbar('تعذر إرسال الطلب', hint,
          duration: const Duration(seconds: 6));
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

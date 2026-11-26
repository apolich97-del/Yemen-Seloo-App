import 'dart:convert';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, FieldValue, Timestamp;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/cart.dart';
import '../../core/models/currency.dart';
import '../home/presentation/main_tab_controller.dart';
import '../../core/models/order.dart';
import '../../core/models/receipt.dart';
import '../../core/services/cart_share.dart';
import '../../core/services/receipt_service.dart';
import '../cart/presentation/cart_share_card.dart';
import '../../core/widgets/brand_header.dart';
import '../guide/interactive_guide.dart';
import 'refunds_ui.dart';
import '../../core/widgets/order_stage_bar.dart';
import '../receipts/presentation/my_receipts_screen.dart';
import '../support/presentation/support_screen.dart';
import '../../core/services/order_documents.dart';
import '../../core/services/order_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

/// تفاصيل الطلب: الخط الزمني + المنتجات + إثبات التسليم + تسريع الشحن.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = Get.arguments as String? ?? '';
    final svc = Get.find<OrderService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        actions: const [ThemeToggleButton(), SizedBox(width: 6)],
      ),
      body: StreamBuilder<Order?>(
        stream: svc.watchOrder(id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final o = snap.data;
          if (o == null) {
            return const Center(child: Text('الطلب غير موجود'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BrandHeader(
                title: 'طلب ${o.orderNo}',
                subtitle: o.address.receiverName.isEmpty
                    ? 'يمن سيلو · متابعة الطلب'
                    : '${o.address.receiverName} · ${o.address.city}',
                badge: o.status.labelAr,
              ),
              const SizedBox(height: 12),
              _header(o),
              if (o.hasPendingPriceSync) ...[
                const SizedBox(height: 12),
                _priceSyncCard(o, svc),
              ],
              const SizedBox(height: 12),
              _timeline(o),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Get.to(() => SupportScreen(order: o)),
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('اسأل الدعم عن الطلب'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Get.to(() => const MyReceiptsScreen()),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('إيصالات السداد الخاصة بي'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final count = await Get.find<CartRepository>().reorderOrderItems(o.items);
                      Get.snackbar('أُعيدت للسلة ✓', 'تمت إضافة $count منتجاً إلى سلة التسوق');
                      if (Get.isRegistered<MainTabController>()) {
                        Get.find<MainTabController>().goToCart();
                        Get.offAllNamed('/main');
                      }
                    } catch (e) {
                      Get.snackbar('تعذر إعادة الطلب', '$e');
                    }
                  },
                  icon: const Icon(Icons.replay_outlined, size: 18),
                  label: const Text('إعادة الطلب للسلة'),
                ),
              ),
              const SizedBox(height: 12),
              CartShareCard(url: CartShare.fromOrderItems(o)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  title: 'مراحل الطلب',
                  child: OrderStageBar(status: o.status, whatsappSent: o.hasWhatsAppSent, stageHint: o.stageHintAr),
                ),
              ),
              _receiptsCard(o),
              _balanceCard(o),
              if (o.hasRemaining) const SizedBox(height: 12),
              _items(o),
              const SizedBox(height: 12),
              _payment(o),
              if (o.proofImageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _proof(o),
              ],
              const SizedBox(height: 12),
              _totals(o),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareWhatsApp(o),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('مشاركة واتساب'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sharePdf(o),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('ملخص PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final f = await OrderDocuments.buildShippingWaybillPdf(o);
                          await Share.shareXFiles([XFile(f.path)],
                              text: 'بوليصة شحن ${o.orderNo} — يمن سيلو');
                        } catch (e) {
                          Get.snackbar('تعذر إنشاء البوليصة', '$e');
                        }
                      },
                      icon: const Icon(Icons.local_shipping_outlined, size: 17),
                      label: const Text('بوليصة الشحن PDF', style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final f = await OrderDocuments.buildDeliveryWaybillPdf(o);
                          await Share.shareXFiles([XFile(f.path)],
                              text: 'بوليصة إثبات التسليم ${o.orderNo} — يمن سيلو');
                        } catch (e) {
                          Get.snackbar('تعذر إنشاء البوليصة', '$e');
                        }
                      },
                      icon: const Icon(Icons.verified_outlined, size: 17),
                      label: const Text('بوليصة التسليم PDF', style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
                ],
              ),
              if (!o.status.isTerminal) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: o.expediteRequestedAt != null
                      ? null
                      : () async {
                          try {
                            await svc.requestExpedite(id);
                            Get.snackbar('تم', 'أُرسل تنبيه تسريع الشحن للموظف');
                          } catch (e) {
                            Get.snackbar('تعذر الإرسال', '$e');
                          }
                        },
                  icon: const Icon(Icons.bolt),
                  label: Text(o.expediteRequestedAt != null
                      ? 'طلب التسريع مُرسل'
                      : 'طلب تسريع الشحن'),
                ),
              ],
              ShippingDetailsCard(order: o),
              const SizedBox(height: 12),
              RefundsSection(order: o),
              const SizedBox(height: 12),
              _CancelCard(order: o),
              if (Get.isRegistered<AuthService>() &&
                  Get.find<AuthService>().canEditOrders) ...[
                const SizedBox(height: 12),
                _managerActions(o),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  /// أدوات المدير الرئيسي: تصحيح البيانات أو حذف الطلب.
  Widget _managerActions(Order o) => SectionCard(
        title: 'صلاحيات التعديل والحذف',
        child: Column(
          children: [
            Text(
              'مخصّصة للمدير الرئيسي والمحاسب لتصحيح أخطاء الموظفين: تعديل الحالة '
              'والمبالغ والتتبع والملاحظات، أو حذف الطلب وإيصالاته.',
              style: TextStyle(fontSize: 10.5, height: 1.6, color: T.muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _managerEdit(o),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('تعديل بيانات الطلب',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _managerDelete(o),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('حذف',
                      style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _managerEdit(Order o) async {
    var status = o.status;
    final tracking = TextEditingController(text: o.trackingNo);
    final courier = TextEditingController(text: o.courierName);
    final paid =
        TextEditingController(text: o.paidTotalLocal.toStringAsFixed(2));
    final note = TextEditingController();

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('تعديل بيانات الطلب',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<OrderStatus>(
                value: status,
                isExpanded: true,
                items: OrderStatus.values
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.labelAr,
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (v) => status = v ?? status,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tracking,
                decoration: const InputDecoration(
                    labelText: 'رقم التتبع', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: courier,
                decoration: const InputDecoration(
                    labelText: 'المندوب', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: paid,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'تصحيح المدفوع', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                    labelText: 'سبب التصحيح (يُسجَّل)', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final newPaid = double.tryParse(paid.text.trim());
      final ref = FirebaseFirestore.instance.collection('orders').doc(o.id);
      await ref.update({
        'status': status.key,
        'trackingNo': tracking.text.trim(),
        'courierName': courier.text.trim(),
        if (newPaid != null) 'paidTotalLocal': newPaid,
        if (newPaid != null)
          'remainingLocal': (o.totalLocal - newPaid).clamp(0, 1e12),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await ref.collection('events').add({
        'status': status.key,
        'at': Timestamp.now(),
        'byName': 'المدير الرئيسي',
        'note': note.text.trim().isEmpty
            ? 'تصحيح بيانات الطلب'
            : note.text.trim(),
      });
      Get.snackbar('تم التعديل', 'حُدّثت بيانات الطلب ${o.orderNo}');
    } catch (e) {
      Get.snackbar('تعذر التعديل', '$e');
    }
  }

  Future<void> _managerDelete(Order o) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('حذف الطلب؟'),
        content: Text(
            'سيُحذف الطلب ${o.orderNo} وإيصالاته نهائياً. لا يمكن التراجع.',
            style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = FirebaseFirestore.instance;
      final receipts = await db
          .collection('orders')
          .doc(o.id)
          .collection('receipts')
          .get();
      for (final r in receipts.docs) {
        await r.reference.delete();
      }
      await db.collection('orders').doc(o.id).delete();
      Get.snackbar('تم الحذف', 'أُزيل الطلب ${o.orderNo}');
      Get.back();
    } catch (e) {
      Get.snackbar('تعذر الحذف', '$e');
    }
  }

  Widget _deferredBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent),
        ),
        child: const Text('آجل 50%',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7A5E00))),
      );


  Widget _priceSyncCard(Order o, OrderService svc) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.warning.withOpacity(.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.warning.withOpacity(.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.price_change_outlined, size: 18, color: T.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'تحديث أسعار / توفر القطع من الإدارة',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: T.text),
                  ),
                ),
              ],
            ),
            if (o.priceSyncNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(o.priceSyncNote,
                  style: TextStyle(fontSize: 11.5, height: 1.5, color: T.text)),
            ],
            const SizedBox(height: 8),
            Text(
              'الإجمالي المقترح بعد التحديث: ${formatMoney(o.proposedTotalLocal, o.currency)} '
              '(${o.proposedTotalSar.toStringAsFixed(2)} ر.س)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: T.primary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await svc.respondToPriceSync(o.id, accepted: true);
                        Get.snackbar('تمت الموافقة ✓', 'أُبلغت الإدارة بموافقتك لتحديث الطلب');
                      } catch (e) {
                        Get.snackbar('تعذر الإرسال', '$e');
                      }
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('أوافق على التعديل', style: TextStyle(fontSize: 11.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await svc.respondToPriceSync(o.id, accepted: false);
                        Get.snackbar('تم الرفض', 'تم إشعار الإدارة برفض التعديل للمراجعة');
                      } catch (e) {
                        Get.snackbar('تعذر الإرسال', '$e');
                      }
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('أرفض / راجعني', style: TextStyle(fontSize: 11.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _header(Order o) {
    final c = Color(o.status.colorValue);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(o.orderNo,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                if (o.isDeferred) ...[
                  const SizedBox(width: 6),
                  _deferredBadge(),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(o.status.labelAr,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تاريخ الطلب: ${o.createdAt.day}/${o.createdAt.month}/${o.createdAt.year}',
              style: TextStyle(fontSize: 12, color: T.muted),
            ),
            if (o.trackingNo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('رقم التتبع: ${o.trackingNo}${o.courierName.isEmpty ? '' : ' · ${o.courierName}'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 6),
            Text(o.address.fullAr,
                style: TextStyle(fontSize: 12, height: 1.6, color: T.muted)),
          ],
        ),
      ),
    );
  }

  Widget _timeline(Order o) {
    return SectionCard(
      title: 'حالة الطلب',
      child: Column(
        children: List.generate(kTimelineStages.length, (i) {
          final stage = kTimelineStages[i];
          final done = o.stageReached(stage);
          final event = o.timeline.where((e) => stage.reachedBy.contains(e.status)).toList();
          final at = event.isEmpty ? null : event.last.at;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primary : T.card,
                      border: Border.all(
                        color: done ? AppColors.primary : const Color(0xFFDCE3E0),
                        width: 2,
                      ),
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                  if (i != kTimelineStages.length - 1)
                    Container(
                      width: 2,
                      height: 34,
                      color: done ? AppColors.primary.withOpacity(.35) : const Color(0xFFEDF1EF),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.labelAr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                        color: done ? T.text : T.muted,
                      ),
                    ),
                    if (at != null)
                      Text(
                        '${at.day}/${at.month} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: T.muted),
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _items(Order o) => SectionCard(
        title: 'المنتجات (${o.totalPieces})',
        child: Column(
          children: o.items.map((it) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      it.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: const Color(0xFFEDF1EF),
                        child: Icon(Icons.image_outlined, size: 18, color: T.muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        if (it.size.isNotEmpty || it.color.isNotEmpty)
                          Text(
                            [if (it.size.isNotEmpty) 'مقاس ${it.size}',
                             if (it.color.isNotEmpty) 'لون ${it.color}'].join(' · '),
                            style: TextStyle(fontSize: 11, color: T.muted),
                          ),
                      ],
                    ),
                  ),
                  if (it.isNonRefundable)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: T.warning.withOpacity(.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: T.warning.withOpacity(.5)),
                      ),
                      child: Text(
                        'غير قابل للاسترداد',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: T.warning),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('× ${it.qty}', style: const TextStyle(fontSize: 12)),
                      Text(
                        formatMoney(it.lineTotalSar * o.exchangeRate, o.currency),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );

  /// بطاقة الرصيد: إجمالي الطلب / المدفوع المؤكد / المتبقي.
  Widget _balanceCard(Order o) {
    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 10.5, color: T.muted)),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: color ?? T.text)),
            ],
          ),
        );
    return SectionCard(
      title: o.isDeferred ? 'رصيد الطلب — آجل 50%' : 'رصيد الطلب',
      child: Column(
        children: [
          Row(
            children: [
              cell('إجمالي الطلب', formatMoney(o.totalLocal, o.currency)),
              cell('المؤكد دفعه', formatMoney(o.paidTotalLocal, o.currency),
                  color: AppColors.success),
              cell('المتبقي عليك', formatMoney(o.remainingLocal, o.currency),
                  color: AppColors.danger),
            ],
          ),
          if (o.isDeferred && o.currency != AppCurrency.sar) ...[
            const SizedBox(height: 8),
            Text(
              'الطلب الآجل مثبّت بسعر الصرف يوم الطلب (1 ر.س = ${o.exchangeRate.toStringAsFixed(0)})',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: T.muted),
            ),
          ],
          if (!o.hasRemaining) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'تم سداد كامل قيمة هذا الطلب — يمكنك تنزيل إيصالاتك من زر '
                    '«إيصالات السداد الخاصة بي».',
                    style: TextStyle(fontSize: 10.5, height: 1.5, color: T.muted),
                  ),
                ),
              ],
            ),
          ],
          if (o.hasRemaining && o.status != OrderStatus.unpaid) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (Get.isRegistered<InteractiveGuideController>()) {
                    Get.find<InteractiveGuideController>().showIfFirst(
                      'action_receipt',
                      title: 'رفع إيصال سداد',
                      body: 'ارفع صورة الحوالة وسيُخصم المبلغ من المتبقي بعد اعتماد المحاسبة.',
                      steps: <String>[
                        'أدخل المبلغ المحوّل واسم المرسل.',
                        'أرفق صورة إشعار الحوالة.',
                        'انتظر الاعتماد ليظهر الإيصال برقمه.',
                      ],
                    );
                  }
                  Get.bottomSheet(
                          _UploadReceiptSheet(order: o),
                  isScrollControlled: true,
                  backgroundColor: T.card,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20))),
                        );
                },
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('رفع إيصال سداد'),
              ),
            ),
          ],
          if (o.hasRemaining && o.status == OrderStatus.outForDelivery) ...[
            const SizedBox(height: 8),
            Text(
                '⚠️ طلب آجل — تحصيل متبقٍ عند التسليم: '
                '${formatMoney(o.remainingLocal, o.currency)}',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger)),
          ],
        ],
      ),
    );
  }

  /// إيصالات السداد الخاصة بالعميل مع حالتها.
  Widget _receiptsCard(Order o) => StreamBuilder<List<Receipt>>(
        stream: Get.find<ReceiptService>().forOrder(o.id),
        builder: (context, snap) {
          final list = snap.data ?? const <Receipt>[];
          if (list.isEmpty) return const SizedBox.shrink();
          Widget statusChip(Receipt r) {
            final color = r.isApproved
                ? AppColors.success
                : r.isRejected
                    ? AppColors.danger
                    : const Color(0xFFB26A00);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(r.statusAr,
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SectionCard(
              title: 'إيصالات السداد (${list.length})',
              child: Column(
                children: list.map((r) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.receiptNo,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                              if (r.note.isNotEmpty)
                                Text(r.note,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: T.muted)),
                            ],
                          ),
                        ),
                        Text(formatMoney(r.amountLocal, o.currency),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 6),
                        statusChip(r),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      );

  Widget _payment(Order o) {
    final p = o.payment;
    if (p.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'بيانات الحوالة',
      child: Column(
        children: [
          MoneyRow(label: 'اسم المرسل', value: p.senderName),
          if (p.refNo.isNotEmpty)
            MoneyRow(label: 'رقم العملية', value: p.refNo),
          MoneyRow(label: 'الحساب المستلم', value: p.accountNumber),
          MoneyRow(
            label: 'حالة التأكيد',
            value: p.confirmedAt == null ? 'بانتظار مراجعة المحاسبة' : 'مؤكدة',
            free: p.confirmedAt != null,
          ),
          _ProofSection(order: o, direct: p.proofUrl),
        ],
      ),
    );
  }

  /// الصورة قد تكون مخزّنة داخل Firestore (data:) أو رابطاً خارجياً.
  Widget _proofImage(String src) {
    if (src.startsWith('data:')) {
      try {
        final b64 = src.substring(src.indexOf(',') + 1);
        return Image.memory(base64Decode(b64),
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(
                height: 60,
                child: Center(child: Text('تعذر عرض صورة الحوالة'))));
      } catch (_) {
        return const SizedBox(
            height: 60, child: Center(child: Text('تعذر عرض صورة الحوالة')));
      }
    }
    return Image.network(src,
        height: 220,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
            height: 60,
            child: Center(child: Text('تعذر تحميل صورة الحوالة'))));
  }

  /// مشاركة ملخص الطلب على واتساب بقالب يمن سيلو.
  Future<void> _shareWhatsApp(Order o) async {
    final text = OrderDocuments.whatsappText(o);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Share.share(text);
    }
  }

  /// فاتورة PDF عربية بهوية يمن سيلو.
  Future<void> _sharePdf(Order o) async {
    try {
      final f = await OrderDocuments.buildPdf(o);
      await Share.shareXFiles([XFile(f.path)], text: 'فاتورة الطلب ${o.orderNo} — يمن سيلو');
    } catch (e) {
      Get.snackbar('تعذر إنشاء PDF', '$e');
    }
  }

  Widget _proof(Order o) => SectionCard(
        title: 'إثبات التسليم',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            o.proofImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 80,
              child: Center(child: Text('تعذر تحميل صورة الإثبات')),
            ),
          ),
        ),
      );

  Widget _totals(Order o) {
    return SectionCard(
      title: 'الملخص المالي',
      child: Column(
        children: [
          MoneyRow(
            label: 'المنتجات',
            value: formatMoney(o.subtotalSar * o.exchangeRate, o.currency),
          ),
          MoneyRow(
            label: 'الشحن',
            value: o.shippingFeeSar == 0
                ? 'مجاني'
                : formatMoney(o.shippingFeeSar * o.exchangeRate, o.currency),
            free: o.shippingFeeSar == 0,
          ),
          MoneyRow(
            label: 'التوصيل',
            value: formatMoney(o.deliveryFeeSar * o.exchangeRate, o.currency),
          ),
          if (o.discountSar > 0)
            MoneyRow(
              label: 'الخصم (${o.couponCode})',
              value: '- ${formatMoney(o.discountSar * o.exchangeRate, o.currency)}',
              free: true,
            ),
          const Divider(height: 20),
          MoneyRow(
            label: 'الإجمالي',
            value: formatMoney(o.totalLocal, o.currency),
            bold: true,
          ),
        ],
      ),
    );
  }
}


/// نافذة رفع إيصال سداد من العميل (يُحفظ بحالة pending للمراجعة).
class _UploadReceiptSheet extends StatefulWidget {
  const _UploadReceiptSheet({required this.order});

  final Order order;

  @override
  State<_UploadReceiptSheet> createState() => _UploadReceiptSheetState();
}

class _UploadReceiptSheetState extends State<_UploadReceiptSheet> {
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _sender = TextEditingController();
  final _note = TextEditingController();
  String _proof = '';
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _sender.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 25,
        maxWidth: 720,
        maxHeight: 720);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > 300 * 1024) {
      Get.snackbar('الصورة كبيرة', 'اختر صورة أصغر من 300 ك.ب');
      return;
    }
    final mime = x.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    setState(() => _proof = 'data:$mime;base64,${base64Encode(bytes)}');
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
    if (amount <= 0) {
      Get.snackbar('المبلغ مطلوب', 'أدخل المبلغ الذي حوّلته');
      return;
    }
    if (_proof.isEmpty) {
      Get.snackbar('الصورة مطلوبة', 'أرفق صورة إشعار الحوالة');
      return;
    }
    setState(() => _busy = true);
    try {
      final no = await Get.find<ReceiptService>().create(
        order: widget.order,
        amountLocal: amount,
        refNo: _ref.text.trim(),
        senderName: _sender.text.trim().isEmpty
            ? widget.order.address.receiverName
            : _sender.text.trim(),
        note: _note.text.trim(),
        proofUrl: _proof,
        source: 'customer',
      );
      Get.back();
      Get.snackbar('تم الإرسال',
          'أُرسل الإيصال $no للمحاسبة وسيُخصم من المتبقي بعد الاعتماد',
          duration: const Duration(seconds: 5));
    } catch (e) {
      Get.snackbar('تعذر الإرسال', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('رفع إيصال سداد',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(
                    onPressed: Get.back, icon: const Icon(Icons.close, size: 18)),
              ],
            ),
            Text('المتبقي عليك: ${formatMoney(o.remainingLocal, o.currency)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger)),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المحوّل'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sender,
              decoration:
                  const InputDecoration(labelText: 'اسم المرسل (اختياري)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ref,
              decoration: const InputDecoration(
                  labelText: 'رقم العملية (اختياري)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(_proof.isEmpty
                  ? 'إرفاق صورة الإشعار'
                  : 'تم إرفاق صورة الإشعار ✓'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'جارٍ الإرسال…' : 'إرسال للمحاسبة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// يعرض صورة الحوالة: من بيانات الطلب أو من آخر إيصال مرفوع.
class _ProofSection extends StatelessWidget {
  const _ProofSection({required this.order, required this.direct});

  final Order order;
  final String direct;

  Widget _image(String src) {
    try {
      if (src.startsWith('data:')) {
        return Image.memory(base64Decode(src.substring(src.indexOf(',') + 1)),
            height: 230,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(
                height: 60,
                child: Center(child: Text('تعذر عرض صورة الحوالة'))));
      }
      return Image.network(src,
          height: 230,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(
              height: 60,
              child: Center(child: Text('تعذر تحميل صورة الحوالة'))));
    } catch (_) {
      return const SizedBox(
          height: 60, child: Center(child: Text('تعذر عرض صورة الحوالة')));
    }
  }

  Widget _label(String text, Color color) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(text,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (direct.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('صورة الحوالة المرفقة', AppColors.success),
          const SizedBox(height: 6),
          ClipRRect(
              borderRadius: BorderRadius.circular(12), child: _image(direct)),
        ],
      );
    }
    return StreamBuilder<List<Receipt>>(
      stream: Get.find<ReceiptService>().forOrder(order.id),
      builder: (context, snap) {
        final list = snap.data ?? const <Receipt>[];
        final withProof = list.where((r) => r.proofUrl.isNotEmpty).toList();
        if (withProof.isEmpty) {
          return _label(
              snap.hasError
                  ? 'تعذر تحميل الإيصالات'
                  : 'لا توجد صورة حوالة مرفقة مع هذا الطلب',
              AppColors.danger);
        }
        final r = withProof.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('صورة الحوالة المرفقة (${r.receiptNo})', AppColors.success),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _image(r.proofUrl)),
          ],
        );
      },
    );
  }
}

/// إلغاء الطلب خلال 24 ساعة للعميل، مع عدّاد للأسباب الجاهزة.
class _CancelCard extends StatefulWidget {
  const _CancelCard({required this.order});
  final Order order;

  @override
  State<_CancelCard> createState() => _CancelCardState();
}

class _CancelCardState extends State<_CancelCard> {
  Timer? _ticker;

  static const List<String> _reasons = <String>[
    'تغيير المقاس/اللون',
    'تغيير الرأي',
    'خطأ في العنوان',
    'تأخر التحقق',
  ];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _allowedStatus =>
      widget.order.status == OrderStatus.unpaid ||
      widget.order.status == OrderStatus.verifying ||
      widget.order.status == OrderStatus.processing;

  Duration get _left {
    final deadline =
        widget.order.createdAt.add(const Duration(hours: 24));
    final diff = deadline.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    if (!_allowedStatus || _left == Duration.zero) {
      return const SizedBox.shrink();
    }
    final h = _left.inHours;
    final m = _left.inMinutes % 60;
    return SectionCard(
      title: 'إلغاء الطلب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: T.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.softBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 15, color: T.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'يمكنك الإلغاء مجاناً خلال $h ساعة و$m دقيقة',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: T.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الإلغاء متاح ما دام الطلب غير مشحون وخلال 24 ساعة من إنشائه.',
            style: TextStyle(fontSize: 10.5, height: 1.6, color: T.muted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withOpacity(.5)),
              ),
              onPressed: () => _askCancel(o),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('إلغاء الطلب',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _askCancel(Order o) async {
    String? reason;
    final other = TextEditingController();
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('سبب إلغاء الطلب',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: StatefulBuilder(
          builder: (context, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._reasons.map((r) => RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: r,
                      groupValue: reason,
                      title: Text(r,
                          style: TextStyle(fontSize: 12, color: T.text)),
                      onChanged: (v) => setLocal(() => reason = v),
                    )),
                const SizedBox(height: 6),
                TextField(
                  controller: other,
                  decoration: const InputDecoration(
                      labelText: 'سبب آخر (اختياري)', isDense: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () => Get.back(result: true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final finalReason = (other.text.trim().isNotEmpty
            ? other.text.trim()
            : (reason ?? 'بدون سبب محدد'))
        .toString();
    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('orders').doc(o.id);
      await ref.update({
        'status': OrderStatus.cancelled.key,
        'cancelReason': finalReason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await ref.collection('events').add({
        'status': OrderStatus.cancelled.key,
        'at': Timestamp.now(),
        'byName': 'العميل',
        'note': 'إلغاء خلال 24 ساعة — $finalReason',
      });

      // تنبيه المحاسبة إذا كان هناك مبلغ مدفوع.
      if (o.paidTotalLocal > 0.5) {
        await db.collection('staff_alerts').add({
          'type': 'cancel_with_payment',
          'target': 'accounting',
          'orderId': o.id,
          'orderNo': o.orderNo,
          'amountLocal': o.paidTotalLocal,
          'currency': o.currency.name,
          'reason': finalReason,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      Get.snackbar('تم الإلغاء',
          o.paidTotalLocal > 0.5
              ? 'أُلغي الطلب، وأُبلغت المحاسبة لمراجعة المبلغ المدفوع'
              : 'أُلغي الطلب بنجاح');
      Get.offAllNamed('/main');
    } catch (e) {
      Get.snackbar('تعذر الإلغاء', '$e');
    }
  }
}


/// تفاصيل التوصيل + صندوق اتفاق نقل المحافظات للموظف.
class ShippingDetailsCard extends StatefulWidget {
  const ShippingDetailsCard({super.key, required this.order});
  final Order order;

  @override
  State<ShippingDetailsCard> createState() => _ShippingDetailsCardState();
}

class _ShippingDetailsCardState extends State<ShippingDetailsCard> {
  final _fee = TextEditingController();
  String _collect = 'office';
  bool _saving = false;

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = double.tryParse(_fee.text.trim()) ?? 0;
    if (v <= 0) {
      Get.snackbar('المبلغ مطلوب', 'أدخل سعر النقل المتفق عليه');
      return;
    }
    setState(() => _saving = true);
    try {
      await Get.find<OrderService>().setTransportFee(
        orderId: widget.order.id,
        feeLocal: v,
        collect: _collect,
      );
      Get.snackbar('تم', 'تم حفظ اتفاق النقل');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final isStaff =
        Get.isRegistered<AuthService>() && Get.find<AuthService>().isStaff;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.local_shipping_outlined, size: 17, color: T.primary),
            const SizedBox(width: 6),
            Text('التوصيل',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: T.text)),
          ]),
          const SizedBox(height: 6),
          Text(o.shippingModeAr,
              style: TextStyle(fontSize: 11.5, color: T.text)),
          if (o.shippingMode == 'governorate') ...[
            const SizedBox(height: 4),
            Text(
                'المحافظة: ${o.shippingGovernorate.isEmpty ? '—' : o.shippingGovernorate}'
                ' · المكتب: ${o.shippingOffice.isEmpty ? 'يمن سيلو يختار أنسب مكتب' : o.shippingOffice}',
                style: TextStyle(fontSize: 11, color: T.muted)),
            if (o.receiverName.isNotEmpty)
              Text('المستلم: ${o.receiverName} — ${o.receiverPhone}',
                  style: TextStyle(fontSize: 11, color: T.muted)),
            const SizedBox(height: 4),
            Text(
                o.transportFeeLocal > 0
                    ? 'أجور النقل: ${o.transportFeeLocal.toStringAsFixed(0)} — ${o.transportFeeCollect == 'office' ? 'تُدفع لمكتب النقل' : 'أُضيفت للمتبقي'}'
                    : 'أجور النقل تُحدَّد بالاتفاق مع يمن سيلو ومكتب الشحن',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: o.transportFeeLocal > 0 ? T.success : T.warning)),
          ],
          if (o.shippingMode == 'driver') ...[
            const SizedBox(height: 4),
            Text('السائق: ${o.driverName} — ${o.driverPhone}',
                style: TextStyle(fontSize: 11, color: T.text)),
            Text('نقطة الالتقاء: ${o.driverMeetPoint}',
                style: TextStyle(fontSize: 11, color: T.muted)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${o.driverPhone}')),
                  icon: const Icon(Icons.call, size: 15),
                  label: const Text('اتصال', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(
                      'https://wa.me/${o.driverPhone.replaceAll(RegExp(r'[^0-9]'), '')}')),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: T.whatsapp),
                  icon: const Icon(Icons.chat, size: 15),
                  label: const Text('واتساب', style: TextStyle(fontSize: 11)),
                ),
              ),
            ]),
          ],
          if (isStaff && o.shippingMode == 'governorate') ...[
            const SizedBox(height: 10),
            Divider(color: T.border, height: 1),
            const SizedBox(height: 8),
            Text('اتفاق نقل المحافظات',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: T.primary)),
            const SizedBox(height: 6),
            TextField(
              controller: _fee,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'سعر النقل المتفق عليه',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            RadioListTile<String>(
              value: 'office',
              groupValue: _collect,
              onChanged: (v) => setState(() => _collect = v ?? 'office'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('تُدفع عند الاستلام مباشرة لمكتب النقل',
                  style: TextStyle(fontSize: 11, color: T.text)),
            ),
            RadioListTile<String>(
              value: 'invoice',
              groupValue: _collect,
              onChanged: (v) => setState(() => _collect = v ?? 'office'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('تُضاف لمتبقي الفاتورة',
                  style: TextStyle(fontSize: 11, color: T.text)),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ اتفاق النقل'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

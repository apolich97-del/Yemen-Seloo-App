import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/currency.dart';
import '../../core/models/order.dart';
import '../../core/services/order_documents.dart';
import '../../core/services/order_service.dart';
import '../../core/theme/app_theme.dart';
import 'role_guard.dart';

/// الشحن: الطلبات الجاهزة للشحن + بوليصة شحن المحافظات + بوليصة إثبات التسليم.
class ShippingTab extends StatelessWidget {
  const ShippingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = Get.find<OrderService>();
    return RoleGuard(
      allow: ['shipping', 'courier'],
      child: StreamBuilder<List<Order>>(
        stream: allOrdersStream(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!
              .where((o) =>
                  o.status == OrderStatus.processing ||
                  o.status == OrderStatus.shipped ||
                  o.status == OrderStatus.outForDelivery ||
                  o.status == OrderStatus.delivered)
              .toList();
          if (list.isEmpty) {
            return Center(
              child: Text('لا توجد شحنات نشطة',
                  style: TextStyle(fontSize: 13, color: T.muted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final o = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(o.orderNo,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: T.text)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Color(o.status.colorValue).withOpacity(.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(o.status.labelAr,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(o.status.colorValue))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${o.address.city} · ${o.address.receiverName} · ${o.totalPieces} قطعة\n'
                        '${o.courierName.isEmpty ? 'بلا مندوب' : o.courierName}'
                        '${o.trackingNo.isEmpty ? '' : ' · تتبع ${o.trackingNo}'}'
                        ' · ${formatMoney(o.totalLocal, o.currency)}\n'
                        'المرحلة: ${o.milestone.emoji} ${o.milestone.labelAr}'
                        '${o.trackingUrl.isNotEmpty ? " · رابط تتبع مرفق ✓" : ""}'
                        '${o.deliverySigned ? " · موقّع إلكترونياً ✍️" : ""}',
                        style: TextStyle(fontSize: 11.5, height: 1.5, color: T.muted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!o.status.isTerminal)
                            FilledButton.icon(
                              onPressed: () => _editMilestone(orders, o),
                              icon: const Icon(Icons.alt_route, size: 15),
                              label: const Text('مراحل الشحن والتتبع', style: TextStyle(fontSize: 11)),
                            ),
                          if (!o.status.isTerminal)
                            OutlinedButton.icon(
                              onPressed: () => _advance(orders, o),
                              icon: const Icon(Icons.update, size: 15),
                              label: const Text('تحديث الحالة', style: TextStyle(fontSize: 11)),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _editShippingWaybill(o),
                            icon: const Icon(Icons.edit_document, size: 15),
                            label: const Text('تعديل بوليصة الشحن', style: TextStyle(fontSize: 11)),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final f = await OrderDocuments.buildShippingWaybillPdf(o);
                                await Share.shareXFiles([XFile(f.path)],
                                    text: 'بوليصة شحن المحافظات ${o.orderNo} — يمن سيلو');
                              } catch (e) {
                                Get.snackbar('تعذر الإصدار', '$e');
                              }
                            },
                            icon: const Icon(Icons.local_shipping_outlined, size: 15),
                            label: const Text('بوليصة الشحن PDF', style: TextStyle(fontSize: 11)),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final f = await OrderDocuments.buildDeliveryWaybillPdf(o);
                                await Share.shareXFiles([XFile(f.path)],
                                    text: 'بوليصة إثبات التسليم ${o.orderNo} — يمن سيلو');
                              } catch (e) {
                                Get.snackbar('تعذر الإصدار', '$e');
                              }
                            },
                            icon: const Icon(Icons.verified_outlined, size: 15),
                            label: const Text('بوليصة التسليم PDF', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editShippingWaybill(Order o) async {
    final sw = o.shippingWaybill;
    final sender = TextEditingController(text: '${sw['senderName'] ?? 'يمن سيلو'}');
    final phone = TextEditingController(text: '${sw['companyPhone'] ?? '770518757'}');
    final gov = TextEditingController(
        text: '${sw['governorate'] ?? (o.shippingGovernorate.isNotEmpty ? o.shippingGovernorate : o.address.city)}');
    final office = TextEditingController(
        text: '${sw['officeName'] ?? (o.shippingOffice.isNotEmpty ? o.shippingOffice : '')}');
    final receiver = TextEditingController(
        text: '${sw['receiverName'] ?? (o.receiverName.isNotEmpty ? o.receiverName : o.address.receiverName)}');
    final rPhone = TextEditingController(
        text: '${sw['receiverPhone'] ?? (o.receiverPhone.isNotEmpty ? o.receiverPhone : o.address.phone)}');
    final notes = TextEditingController(text: '${sw['notes'] ?? ''}');
    var voucherUrl = '${sw['voucherUrl'] ?? ''}';

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('بيانات بوليصة الشحن للمحافظات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 440,
          child: StatefulBuilder(
            builder: (ctx, setLocal) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: sender, decoration: const InputDecoration(labelText: 'اسم المرسل', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'هاتف الشركة', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: gov, decoration: const InputDecoration(labelText: 'المحافظة الوجهة', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: office, decoration: const InputDecoration(labelText: 'مكتب النقل', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: receiver, decoration: const InputDecoration(labelText: 'اسم المستلم', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: rPhone, decoration: const InputDecoration(labelText: 'هاتف المستلم', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات (دون أي بيانات بنكية)', isDense: true)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final x = await ImagePicker().pickImage(
                          source: ImageSource.gallery, imageQuality: 30, maxWidth: 800, maxHeight: 800);
                      if (x == null) return;
                      final bytes = await x.readAsBytes();
                      if (bytes.length > 350 * 1024) {
                        Get.snackbar('الصورة كبيرة', 'اختر صورة أصغر من 350 ك.ب');
                        return;
                      }
                      final mime = x.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
                      setLocal(() => voucherUrl = 'data:$mime;base64,${base64Encode(bytes)}');
                    },
                    icon: const Icon(Icons.photo_camera_outlined, size: 17),
                    label: Text(voucherUrl.isEmpty ? 'إرفاق صورة سند مكتب النقل' : 'تغيير صورة السند ✓'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('حفظ البوليصة')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('orders').doc(o.id).set({
        'shippingWaybill': {
          'senderName': sender.text.trim(),
          'companyPhone': phone.text.trim(),
          'governorate': gov.text.trim(),
          'officeName': office.text.trim(),
          'receiverName': receiver.text.trim(),
          'receiverPhone': rPhone.text.trim(),
          'notes': notes.text.trim(),
          'voucherUrl': voucherUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
      Get.snackbar('تم الحفظ', 'تم تحديث بوليصة الشحن للطلب ${o.orderNo}');
    } catch (e) {
      Get.snackbar('تعذر الحفظ', '$e');
    }
  }

  Future<void> _editMilestone(OrderService orders, Order o) async {
    var selected = o.milestone;
    final note = TextEditingController(text: o.shippingStageNote);
    final trackingNo = TextEditingController(text: o.trackingNo);
    final trackingUrl = TextEditingController(text: o.trackingUrl);
    final courierName = TextEditingController(text: o.courierName);
    var trackingImageUrl = o.trackingImageUrl;
    var uploading = false;

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('تتبع ومراحل شحنة ${o.orderNo}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 440,
          child: StatefulBuilder(
            builder: (ctx, setLocal) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<ShippingMilestone>(
                    value: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'مرحلة الشحن الحالية', isDense: true),
                    items: ShippingMilestone.values
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text('${m.emoji} ${m.labelAr}',
                                  style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (v) => setLocal(() => selected = v ?? selected),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: trackingNo,
                    decoration: const InputDecoration(labelText: 'رقم التتبع', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: trackingUrl,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                        labelText: 'رابط تتبع الطلب (URL)', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: courierName,
                    decoration: const InputDecoration(labelText: 'شركة الشحن / المندوب', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'ملاحظة للعميل (تُرسل كإشعار)', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            final x = await ImagePicker().pickImage(
                                source: ImageSource.gallery, imageQuality: 45, maxWidth: 1080, maxHeight: 1080);
                            if (x == null) return;
                            setLocal(() => uploading = true);
                            try {
                              final bytes = await x.readAsBytes();
                              final ext = x.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
                              String url = '';
                              try {
                                final ref = FirebaseStorage.instance
                                    .ref('tracking/${o.id}/trk_${DateTime.now().millisecondsSinceEpoch}.$ext');
                                await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
                                url = await ref.getDownloadURL();
                              } catch (_) {
                                if (bytes.length <= 450 * 1024) {
                                  url = 'data:image/${ext == 'png' ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
                                }
                              }
                              if (url.isNotEmpty) {
                                setLocal(() => trackingImageUrl = url);
                              } else {
                                Get.snackbar('الصورة كبيرة', 'اختر صورة أصغر لحفظها في التتبع');
                              }
                            } catch (e) {
                              Get.snackbar('تعذر معالجة الصورة', '$e');
                            } finally {
                              setLocal(() => uploading = false);
                            }
                          },
                    icon: uploading
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_a_photo_outlined, size: 17),
                    label: Text(trackingImageUrl.isEmpty
                        ? 'إرفاق صورة التتبع من شركة الشحن'
                        : 'تم إرفاق صورة التتبع ✓ (تغيير)'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('حفظ وإرسال إشعار')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await orders.updateShippingMilestone(
        order: o,
        milestone: selected,
        note: note.text.trim(),
        trackingNo: trackingNo.text.trim(),
        trackingUrl: trackingUrl.text.trim(),
        trackingImageUrl: trackingImageUrl,
        courierName: courierName.text.trim(),
      );
      Get.snackbar('تم التحديث ✓', 'تم تحديث مرحلة الشحن وإرسال إشعار للعميل');
    } catch (e) {
      Get.snackbar('تعذر التحديث', '$e');
    }
  }

  Future<void> _advance(OrderService orders, Order o) async {
    final next = o.status.nextStatuses.where((s) => s != OrderStatus.cancelled).toList();
    if (next.isEmpty) return;
    final to = await showDialog<OrderStatus>(
      context: Get.context!,
      builder: (context) => SimpleDialog(
        title: const Text('الإجراء', style: TextStyle(fontSize: 15)),
        children: next
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, s),
                  child: Text(s.labelAr),
                ))
            .toList(),
      ),
    );
    if (to == null) return;
    final tracking = TextEditingController(text: o.trackingNo);
    final courier = TextEditingController(text: o.courierName);
    final proof = TextEditingController(text: o.proofImageUrl);
    final courierPhone = TextEditingController();
    final collected = TextEditingController();
    final ok = await showDialog<bool>(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: Text(to.labelAr, style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (to == OrderStatus.shipped) ...[
              TextField(
                  controller: tracking,
                  decoration: const InputDecoration(labelText: 'رقم التتبع')),
              const SizedBox(height: 8),
              TextField(
                  controller: courier,
                  decoration: const InputDecoration(labelText: 'شركة الشحن')),
            ],
            if (to == OrderStatus.outForDelivery) ...[
              TextField(
                  controller: courier,
                  decoration: const InputDecoration(labelText: 'اسم المندوب')),
              const SizedBox(height: 8),
              TextField(
                  controller: courierPhone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration:
                      const InputDecoration(labelText: 'رقم جوال المندوب')),
              const SizedBox(height: 8),
              TextField(
                  controller: collected,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'مبلغ التحصيل (بالعملة المحلية)')),
            ],
            if (to == OrderStatus.delivered)
              TextField(
                  controller: proof,
                  decoration: const InputDecoration(labelText: 'رابط صورة الإثبات')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تنفيذ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await orders.advanceStatus(
        orderId: o.id,
        to: to,
        trackingNo: tracking.text.trim(),
        courierName: courier.text.trim(),
        proofUrl: proof.text.trim(),
        courierPhone: courierPhone.text.trim(),
        collectedLocal: double.tryParse(collected.text.trim()),
      );
      Get.snackbar('تم', 'تم تحديث الحالة إلى ${to.labelAr}');
    } catch (e) {
      Get.snackbar('تعذر التحديث', '$e');
    }
  }
}

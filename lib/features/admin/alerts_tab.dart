import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/audit_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import 'role_guard.dart';

/// تنبيهات ما قبل الدفع للعملاء — يدخلها المدير وموظف الدعم والشحن.
class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _severity = 'warning';
  bool _requiresAck = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      Get.snackbar('بيانات ناقصة', 'أدخل عنوان التنبيه ونص الرسالة');
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = Get.find<AuthService>();
      final ns = Get.find<NotificationService>();
      await ns.createCheckoutAlert(
        title: _title.text.trim(),
        message: _message.text.trim(),
        severity: _severity,
        requiresAck: _requiresAck,
        role: auth.roleLabelAr,
        authorName: auth.user.value?.displayName ?? auth.roleLabelAr,
      );
      if (Get.isRegistered<AuditService>()) {
        await Get.find<AuditService>().logAction(
          action: 'create_alert',
          collectionName: 'checkout_alerts',
          docId: 'new',
          summary: 'نشر تنبيه دفع: ${_title.text.trim()}',
        );
      }
      _title.clear();
      _message.clear();
      setState(() => _requiresAck = false);
      Get.snackbar('تم النشر ✓', 'سيظهر التنبيه فوراً في صفحة تأكيد الطلب والدفع');
    } catch (e) {
      Get.snackbar('تعذر النشر', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ns = Get.find<NotificationService>();
    final isManager = Get.find<AuthService>().isManager;
    return RoleGuard(
      allow: ['manager', 'support', 'shipping'],
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          SectionCard(
            title: 'إضافة تنبيه يظهر للعملاء أثناء تأكيد الطلب',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'مناسب لتنبيهات ظروف الشحن، تغير أسعار الصرف، أو مواعيد الإجازات.',
                  style: TextStyle(fontSize: 11.5, color: T.muted),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'عنوان التنبيه',
                    hintText: 'مثلاً: تحديث مواعيد الشحن أو سعر الصرف',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _message,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل التنبيه للعميل',
                    hintText: 'اكتب الرسالة التي ستظهر أعلى صفحة الدفع وتأكيد الطلب...',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('معلومة'),
                      selected: _severity == 'info',
                      onSelected: (_) => setState(() => _severity = 'info'),
                    ),
                    ChoiceChip(
                      label: const Text('تنبيه مهم'),
                      selected: _severity == 'warning',
                      onSelected: (_) => setState(() => _severity = 'warning'),
                    ),
                    ChoiceChip(
                      label: const Text('عاجل'),
                      selected: _severity == 'urgent',
                      onSelected: (_) => setState(() => _severity = 'urgent'),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _requiresAck,
                  onChanged: (v) => setState(() => _requiresAck = v),
                  title: Text('إلزام العميل بوضع علامة الموافقة قبل متابعة الدفع',
                      style: TextStyle(fontSize: 12, color: T.text)),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: Text(_busy ? 'جارٍ النشر...' : 'نشر التنبيه الآن'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'التنبيهات المنشورة',
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('checkout_alerts')
                  .orderBy('createdAt', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Text('لا توجد تنبيهات منشورة',
                      style: TextStyle(fontSize: 12, color: T.muted));
                }
                return Column(
                  children: docs.map((d) {
                    final a = CheckoutAlert.fromDoc(d.id, d.data());
                    final c = a.severity == 'urgent'
                        ? T.danger
                        : (a.severity == 'info' ? T.info : T.warning);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: a.active ? c.withOpacity(.09) : T.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: a.active ? c.withOpacity(.45) : T.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(a.title,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: T.text)),
                              ),
                              Switch(
                                value: a.active,
                                onChanged: (v) =>
                                    ns.toggleCheckoutAlert(a.id, v),
                              ),
                              if (isManager)
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 18, color: T.danger),
                                  onPressed: () async {
                                    if (Get.isRegistered<AuditService>()) {
                                      await Get.find<AuditService>()
                                          .archiveAndDelete(
                                        collectionName: 'checkout_alerts',
                                        docId: a.id,
                                        snapshotData: d.data(),
                                        summary: 'حذف تنبيه: ${a.title}',
                                      );
                                    }
                                    await ns.deleteCheckoutAlert(a.id);
                                  },
                                ),
                            ],
                          ),
                          Text(a.message,
                              style: TextStyle(fontSize: 11.5, color: T.muted)),
                          const SizedBox(height: 4),
                          Text(
                            'بواسطة: ${a.createdByName} (${a.createdByRole})${a.requiresAck ? " · يتطلب موافقة العميل" : ""}',
                            style: TextStyle(fontSize: 10, color: T.muted),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

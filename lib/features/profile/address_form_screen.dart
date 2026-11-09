import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/order.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

/// إضافة/تعديل عنوان — يُرجع [Address] عبر Get.back(result:).
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _line = TextEditingController();
  final _phone = TextEditingController();
  final _receiver = TextEditingController();
  String _label = 'المنزل';
  bool _default = true;
  bool _busy = false;
  late final Address? _existing;

  @override
  void initState() {
    super.initState();
    _existing = Get.arguments is Address ? Get.arguments as Address : null;
    final a = _existing;
    if (a != null) {
      _city.text = a.city;
      _district.text = a.district;
      _line.text = a.line;
      _phone.text = a.phone;
      _receiver.text = a.receiverName;
      _label = a.label;
    } else {
      final u = Get.find<AuthService>().user.value;
      _phone.text = u?.phone ?? '';
      _receiver.text = u?.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _city.dispose();
    _district.dispose();
    _line.dispose();
    _phone.dispose();
    _receiver.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_city.text.trim().isEmpty || _district.text.trim().isEmpty || _line.text.trim().isEmpty) {
      Get.snackbar('بيانات ناقصة', 'أكمل المدينة والمديرية والعنوان التفصيلي');
      return;
    }
    if (_receiver.text.trim().length < 3 || _phone.text.trim().length < 8) {
      Get.snackbar('بيانات ناقصة', 'أدخل اسم المستلم ورقم هاتف صحيح');
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = Get.find<AuthService>();
      final uid = auth.uid;
      final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('addresses');
      final doc = _existing == null ? col.doc() : col.doc(_existing!.id);
      final data = {
        'label': _label,
        'city': _city.text.trim(),
        'district': _district.text.trim(),
        'line': _line.text.trim(),
        'phone': _phone.text.trim(),
        'receiverName': _receiver.text.trim(),
        'isDefault': _default,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await doc.set(data, SetOptions(merge: true));
      Get.back(result: Address.fromMap({'id': doc.id, ...data}));
      Get.snackbar('تم', 'تم حفظ العنوان');
    } catch (e) {
      Get.snackbar('تعذر الحفظ', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? 'إضافة عنوان' : 'تعديل العنوان')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'تفاصيل العنوان',
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: ['المنزل', 'العمل', 'أخرى']
                      .map((l) => ChoiceChip(
                            label: Text(l),
                            selected: _label == l,
                            onSelected: (_) => setState(() => _label = l),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'المدينة', hintText: 'صنعاء'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _district,
                  decoration: const InputDecoration(labelText: 'المديرية / الحي'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _line,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'العنوان التفصيلي',
                    hintText: 'أقرب علامة مميزة، رقم المبنى، الطابق',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _receiver,
                  decoration: const InputDecoration(labelText: 'اسم المستلم'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'هاتف المستلم (واتساب)'),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _default,
                  onChanged: (v) => setState(() => _default = v),
                  title: const Text('اجعله العنوان الافتراضي',
                      style: TextStyle(fontSize: 13)),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('حفظ العنوان'),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/order.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';

class ProfileController extends GetxController {
  final _auth = Get.find<AuthService>();
  final _db = FirebaseFirestore.instance;

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();

  final addresses = <Address>[].obs;
  final busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    ever(_auth.user, _fill);
    _fill(_auth.user.value);
    loadAddresses();
  }

  void _fill(AppUser? u) {
    if (u == null) return;
    firstName.text = u.firstName;
    lastName.text = u.lastName;
    phone.text = u.phone ?? '';
  }

  @override
  void onClose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    super.onClose();
  }

  Future<void> loadAddresses() async {
    final uid = _auth.uid;
    if (uid == null) return;
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .orderBy('createdAt', descending: true)
        .get();
    addresses.assignAll(
      snap.docs.map((d) => Address.fromMap({'id': d.id, ...d.data()})).toList(),
    );
  }

  Future<void> savePersonal() async {
    busy.value = true;
    try {
      await _auth.saveProfile(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        phone: phone.text.trim(),
      );
      Get.snackbar('تم الحفظ', 'تم تحديث بياناتك الشخصية');
    } catch (e) {
      Get.snackbar('تعذر الحفظ', '$e');
    } finally {
      busy.value = false;
    }
  }

  Future<void> addAddress() async {
    final a = await Get.toNamed<Address>(AppRoutes.addressForm);
    if (a != null) await loadAddresses();
  }

  Future<void> deleteAddress(String id) async {
    final uid = _auth.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('addresses').doc(id).delete();
    await loadAddresses();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    Get.offAllNamed(AppRoutes.login);
  }
}

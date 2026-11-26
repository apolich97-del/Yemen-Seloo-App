import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // order | shipping | replacement | receipt | alert | support
  final String orderId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'order',
    this.orderId = '',
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(String id, Map<String, dynamic> m) {
    DateTime dt = DateTime.now();
    final ts = m['createdAt'];
    try {
      if (ts != null) dt = (ts as dynamic).toDate() as DateTime;
    } catch (_) {}
    return AppNotification(
      id: id,
      title: (m['title'] ?? '').toString(),
      body: (m['body'] ?? '').toString(),
      type: (m['type'] ?? 'order').toString(),
      orderId: (m['orderId'] ?? '').toString(),
      read: (m['read'] as bool?) ?? false,
      createdAt: dt,
    );
  }
}

class CheckoutAlert {
  final String id;
  final String title;
  final String message;
  final String severity; // info | warning | urgent
  final bool active;
  final bool requiresAck;
  final String createdByRole;
  final String createdByName;
  final DateTime createdAt;

  const CheckoutAlert({
    required this.id,
    required this.title,
    required this.message,
    this.severity = 'warning',
    this.active = true,
    this.requiresAck = false,
    this.createdByRole = '',
    this.createdByName = '',
    required this.createdAt,
  });

  factory CheckoutAlert.fromDoc(String id, Map<String, dynamic> m) {
    DateTime dt = DateTime.now();
    try {
      if (m['createdAt'] != null) {
        dt = (m['createdAt'] as dynamic).toDate() as DateTime;
      }
    } catch (_) {}
    return CheckoutAlert(
      id: id,
      title: (m['title'] ?? '').toString(),
      message: (m['message'] ?? '').toString(),
      severity: (m['severity'] ?? 'warning').toString(),
      active: (m['active'] as bool?) ?? true,
      requiresAck: (m['requiresAck'] as bool?) ?? false,
      createdByRole: (m['createdByRole'] ?? '').toString(),
      createdByName: (m['createdByName'] ?? '').toString(),
      createdAt: dt,
    );
  }
}

class NotificationService extends GetxService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final RxList<AppNotification> items = <AppNotification>[].obs;
  final RxList<CheckoutAlert> checkoutAlerts = <CheckoutAlert>[].obs;

  int get unreadCount => items.where((e) => !e.read).length;

  StreamSubscription? _authSub;
  StreamSubscription? _notifSub;
  StreamSubscription? _alertsSub;

  @override
  void onInit() {
    super.onInit();
    _watchCheckoutAlerts();
    _authSub = _auth.authStateChanges().listen((u) {
      _notifSub?.cancel();
      if (u == null) {
        items.clear();
      } else {
        _watchUserNotifications(u.uid);
      }
    });
  }

  void _watchCheckoutAlerts() {
    _alertsSub?.cancel();
    _alertsSub = _db
        .collection('checkout_alerts')
        .where('active', isEqualTo: true)
        .limit(10)
        .snapshots()
        .listen((snap) {
      final list = snap.docs
          .map((d) => CheckoutAlert.fromDoc(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      checkoutAlerts.assignAll(list);
    }, onError: (_) {});
  }

  void _watchUserNotifications(String uid) {
    _notifSub = _db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      items.assignAll(
        snap.docs.map((d) => AppNotification.fromDoc(d.id, d.data())).toList(),
      );
    }, onError: (_) {});
  }

  Future<void> markRead(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .doc(id)
          .update({'read': true});
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final unread = items.where((e) => !e.read).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final n in unread) {
      batch.update(
        _db.collection('notifications').doc(uid).collection('items').doc(n.id),
        {'read': true},
      );
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  Future<void> pushUserNotification({
    required String targetUid,
    required String title,
    required String body,
    String type = 'order',
    String orderId = '',
  }) async {
    if (targetUid.trim().isEmpty) return;
    try {
      await _db
          .collection('notifications')
          .doc(targetUid)
          .collection('items')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'orderId': orderId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> createCheckoutAlert({
    required String title,
    required String message,
    required String severity,
    required bool requiresAck,
    required String role,
    required String authorName,
  }) async {
    await _db.collection('checkout_alerts').add({
      'title': title.trim(),
      'message': message.trim(),
      'severity': severity,
      'requiresAck': requiresAck,
      'active': true,
      'createdByRole': role,
      'createdByName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleCheckoutAlert(String id, bool active) async {
    await _db.collection('checkout_alerts').doc(id).update({'active': active});
  }

  Future<void> deleteCheckoutAlert(String id) async {
    await _db.collection('checkout_alerts').doc(id).delete();
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _notifSub?.cancel();
    _alertsSub?.cancel();
    super.onClose();
  }
}

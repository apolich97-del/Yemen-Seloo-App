import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:get/get.dart';

import '../../../core/models/currency.dart';
import '../../../core/models/order.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cart_share.dart';
import 'support_guide.dart';
import 'support_models.dart';

/// خدمة الدعم: دليل قابل للبحث + مساعد ذكي بسياق حقيقي + دردشة حية.
class SupportService extends GetxService {
  final _db = FirebaseFirestore.instance;

  // ═══════════════ الدليل الإرشادي ═══════════════

  /// يدمج الدليل الافتراضي مع ما اعتُمد من تحليل الأسئلة.
  Stream<List<GuideEntry>> guide() => _db
      .collection('support_guide')
      .where('approved', isEqualTo: true)
      .snapshots()
      .map((snap) {
        final remote = snap.docs
            .map((d) => GuideEntry.fromMap(d.id, d.data()))
            .toList();
        return <GuideEntry>[...kDefaultGuide, ...remote];
      });

  /// بحث فوري: يرتّب النتائج بعدد الكلمات المطابقة.
  static List<GuideEntry> search(List<GuideEntry> all, String query) {
    final q = _norm(query);
    if (q.isEmpty) return all;
    final words = q.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    final scored = <MapEntry<GuideEntry, int>>[];
    for (final e in all) {
      var score = 0;
      final hay = _norm('${e.question} ${e.answer} ${e.tags.join(' ')}');
      for (final w in words) {
        if (hay.contains(w)) score += 2;
      }
      if (_norm(e.question).contains(q)) score += 3;
      if (score > 0) scored.add(MapEntry(e, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// أسئلة مقترحة: الأكثر بحثاً عند العملاء ثم من الدليل.
  Future<List<String>> suggestions() async {
    try {
      final snap = await _db
          .collection('support_query_logs')
          .orderBy('at', descending: true)
          .limit(300)
          .get();
      final counts = <String, int>{};
      for (final d in snap.docs) {
        final t = (d.data()['text'] ?? '').toString().trim();
        if (t.length < 4) continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }
      final top = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final list = top.map((e) => e.key).take(6).toList();
      if (list.length < 6) {
        list.addAll(kDefaultGuide.take(6 - list.length).map((e) => e.question));
      }
      return list;
    } catch (_) {
      return kDefaultGuide.take(6).map((e) => e.question).toList();
    }
  }

  /// يسجّل عبارة بحث أو سؤالاً للتحليل لاحقاً.
  Future<void> logQuery(String text, {String kind = 'search', String? orderNo}) async {
    final t = text.trim();
    if (t.length < 3) return;
    try {
      await _db.collection('support_query_logs').add({
        'text': t,
        'kind': kind,
        'userId': Get.find<AuthService>().uid ?? '',
        'orderNo': orderNo ?? '',
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ═══════════════ المحادثات ═══════════════

  Stream<List<SupportThread>> myThreads() {
    final uid = Get.find<AuthService>().uid ?? '';
    return _db
        .collection('support_threads')
        .where('userId', isEqualTo: uid)
        .limit(20)
        .snapshots()
        .map((s) => s.docs
            .map((d) => SupportThread.fromDoc(d.id, d.data()))
            .toList()
          ..sort((a, b) => (b.lastAt ?? DateTime(2000))
              .compareTo(a.lastAt ?? DateTime(2000))));
  }

  Stream<List<SupportThread>> allThreads() => _db
      .collection('support_threads')
      .limit(100)
      .snapshots()
      .map((s) => s.docs
          .map((d) => SupportThread.fromDoc(d.id, d.data()))
          .toList()
        ..sort((a, b) => (b.lastAt ?? DateTime(2000))
            .compareTo(a.lastAt ?? DateTime(2000))));

  Stream<List<SupportMessage>> messages(String threadId) => _db
      .collection('support_threads')
      .doc(threadId)
      .collection('messages')
      .orderBy('at')
      .limit(200)
      .snapshots()
      .map((s) => s.docs
          .map((d) => SupportMessage.fromDoc(d.id, d.data()))
          .toList());

  /// ينشئ محادثة جديدة أو يعيد المفتوحة للعميل.
  Future<String> openThread({Order? order}) async {
    final auth = Get.find<AuthService>();
    final uid = auth.uid ?? '';
    // استعلام بحقل واحد فقط حتى لا يحتاج فهرساً مركّباً؛
    // استبعاد المحادثات المغلقة يتم داخل التطبيق.
    final existing = await _db
        .collection('support_threads')
        .where('userId', isEqualTo: uid)
        .limit(10)
        .get();
    for (final d in existing.docs) {
      final m = d.data();
      if ((m['mode'] ?? 'bot') == 'closed') continue;
      if (order == null || m['orderId'] == order.id) return d.id;
    }
    final ref = _db.collection('support_threads').doc();
    await ref.set({
      'userId': uid,
      'customerName': (auth.user.value?.displayName.isNotEmpty ?? false) ? auth.user.value!.displayName : (auth.user.value?.phone ?? ''),
      'customerPhone': auth.user.value?.phone ?? '',
      'orderId': order?.id ?? '',
      'orderNo': order?.orderNo ?? '',
      'mode': 'bot',
      'summary': '',
      'lastMessage': '',
      'unreadForAgent': 0,
      'unreadForCustomer': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> sendCustomerMessage(String threadId, String text,
      {String imageUrl = '', Order? order, bool forceBot = false}) async {
    final t = text.trim();
    if (t.isEmpty && imageUrl.isEmpty) return;
    final auth = Get.find<AuthService>();
    final thread = _db.collection('support_threads').doc(threadId);

    await thread.collection('messages').add({
      'from': 'customer',
      'text': t,
      'imageUrl': imageUrl,
      'byName': (auth.user.value?.displayName.isNotEmpty ?? false) ? auth.user.value!.displayName : (auth.user.value?.phone ?? ''),
      'at': FieldValue.serverTimestamp(),
    });
    await thread.set({
      'lastMessage': t.isEmpty ? '📷 صورة' : t,
      'lastAt': FieldValue.serverTimestamp(),
      'unreadForAgent': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await logQuery(t, kind: 'chat', orderNo: order?.orderNo);

    final nq = _norm(t);
    final autoQuery = forceBot ||
        _has(nq, ['حالة', 'وين', 'اين', 'أين', 'وصل', 'تتبع', 'شحن', 'شحنت', 'طلبي',
                  'متبقي', 'باقي', 'رصيد', 'آجل', 'اجل', 'صرف', 'سعر', 'ايصال', 'إيصال', 'دفع']);
    if (autoQuery) {
      await thread.set({'mode': 'bot'}, SetOptions(merge: true));
    }
    final snap = await thread.get();
    final mode = autoQuery ? 'bot' : ((snap.data()?['mode'] ?? 'bot') as String);
    if (mode == 'bot' && t.isNotEmpty) {
      AssistantReply reply;
      try {
        reply = await assistantReply(t, order: order);
      } catch (_) {
        reply = const AssistantReply(
          'أهلاً بك! اختر رقم طلبك من زر «إرسال الطلب» أو اكتب رقم الطلب (مثل YS26...) لأعرض لك حالته وتتبّعه فوراً.',
          escalate: false,
        );
      }
      await thread.collection('messages').add({
        'from': 'bot',
        'text': reply.text,
        'at': FieldValue.serverTimestamp(),
      });
      await thread.set({
        'lastMessage': reply.text,
        'lastAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (reply.escalate && !forceBot) {
        await escalate(threadId, order: order, reason: t);
      }
    }
  }

  // ═══════════════ المساعد الذكي ═══════════════

  /// يجيب من سياق العميل الحقيقي + الدليل، دون اختراع بيانات.
  Future<AssistantReply> assistantReply(String question,
      {Order? order}) async {
    final q = _norm(question);

    // 0) إن لم يُمرَّر طلب، اجلب طلبات العميل دون orderBy (تجنّب خطأ الفهرس المركّب)
    if (order == null && Get.isRegistered<AuthService>()) {
      final auth = Get.find<AuthService>();
      final uid = auth.uid;
      final List<Order> candidateOrders = <Order>[];
      if (uid != null && uid.isNotEmpty) {
        try {
          final snap = await _db
              .collection('orders')
              .where('userId', isEqualTo: uid)
              .limit(30)
              .get();
          for (final d in snap.docs) {
            candidateOrders.add(Order.fromDoc(d.id, d.data()));
          }
        } catch (_) {}
      }
      if (candidateOrders.isEmpty) {
        final rawPhone = (auth.user.value?.phone ?? '').trim();
        final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
        final local9 = digits.length >= 9 ? digits.substring(digits.length - 9) : digits;
        final variants = <String>{
          if (rawPhone.isNotEmpty) rawPhone,
          if (digits.isNotEmpty) digits,
          if (local9.isNotEmpty) local9,
          if (local9.isNotEmpty) '0$local9',
          if (local9.isNotEmpty) '967$local9',
          if (local9.isNotEmpty) '+967$local9',
        };
        for (final ph in variants) {
          if (candidateOrders.isNotEmpty) break;
          try {
            final snap = await _db
                .collection('orders')
                .where('address.phone', isEqualTo: ph)
                .limit(15)
                .get();
            for (final d in snap.docs) {
              candidateOrders.add(Order.fromDoc(d.id, d.data()));
            }
          } catch (_) {}
        }
      }
      if (candidateOrders.isNotEmpty) {
        candidateOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        // إن ذكر العميل رقم طلب معين مثل YS26... نطابقه أولاً
        final noMatch = RegExp(r'YS[A-Z0-9\-/]{4,}', caseSensitive: false)
            .firstMatch(question);
        if (noMatch != null) {
          final targetNo = noMatch.group(0)!.toUpperCase();
          order = candidateOrders.firstWhere(
            (e) => e.orderNo.toUpperCase().contains(targetNo),
            orElse: () => candidateOrders.first,
          );
        } else {
          order = candidateOrders.first;
        }
      }
    }

    // 1) أسئلة تخص طلباً بعينه
    if (order != null) {
      final cur = order.currency;
      if (_has(q, ['حالة', 'وين', 'أين', 'وصل', 'تتبع', 'شحن', 'شحنت', 'طلبي'])) {
        final b = StringBuffer()
          ..writeln('📦 طلبك ${order.orderNo}')
          ..writeln('• الحالة الحالية: «${order.status.labelAr}»')
          ..writeln('• المدة المتوقعة: ${order.expectedDeliveryAr}');
        if (order.trackingNo.isNotEmpty) {
          b.writeln('• رقم التتبع: ${order.trackingNo}');
        }
        if (order.courierName.isNotEmpty) {
          b.writeln('• المندوب / شركة النقل: ${order.courierName}');
        }
        b.writeln(
            '• الإجمالي: ${formatMoney(order.totalLocal, cur)} · المتبقي: ${formatMoney(order.remainingLocal, cur)}');
        return AssistantReply(b.toString().trim(), escalate: false);
      }
      if (_has(q, ['متبقي', 'باقي', 'رصيد', 'آجل', 'نصف', 'قسط'])) {
        final b = StringBuffer()
          ..writeln('إجمالي طلبك ${formatMoney(order.totalLocal, cur)} '
              '(${order.totalSar.toStringAsFixed(2)} ر.س).')
          ..writeln('المؤكد دفعه: ${formatMoney(order.paidTotalLocal, cur)}.')
          ..writeln('المتبقي: ${formatMoney(order.remainingLocal, cur)}.');
        if (order.isDeferred) {
          b.writeln('نظام السداد: آجل 50% — الدفعة الأولى '
              '${formatMoney(order.upfrontDueLocal, cur)}.');
        } else {
          b.writeln('نظام السداد: دفعة كاملة.');
        }
        return AssistantReply(b.toString(), escalate: false);
      }
      if (_has(q, ['صرف', 'سعر', 'عملة', 'ريال', 'دولار'])) {
        return AssistantReply(
          'سعر الصرف المثبّت على طلبك: 1 ر.س = '
          '${order.exchangeRate.toStringAsFixed(2)} '
          '${order.currency.name.toUpperCase()}، '
          'وإجمالي طلبك ${formatMoney(order.totalLocal, cur)}.',
          escalate: false,
        );
      }
      if (_has(q, ['سلة', 'منتجات', 'قطع', 'اصناف', 'أصناف', 'رابط'])) {
        final link = CartShare.fromOrderItems(order);
        return AssistantReply(
          'طلبك ${order.orderNo} يحتوي ${order.items.length} قطعة.\n'
          '${link.isEmpty ? '' : 'رابط السلة كاملة:\n$link'}',
          escalate: false,
        );
      }
    }

    if (order == null &&
        _has(q, ['أين طلبي', 'اين طلبي', 'تتبع شحنتي', 'وين طلبي', 'شحنتي', 'حالة طلبي'])) {
      return const AssistantReply(
        'لم أجد طلبات مسجلة على هذا الحساب حالياً. '
        'تأكد من تسجيل الدخول بالحساب الذي أنشأت منه الطلب، أو اضغط «طلبي» لاختيار طلبك أو تحويل المحادثة لموظف الدعم.',
        escalate: false,
      );
    }

    // 2) شكاوى تُحوّل لموظف بشري
    if (_has(q, ['تالف', 'مكسور', 'مختلف', 'خطأ', 'استرجاع', 'تعويض', 'موظف', 'بشري', 'إنسان'])) {
      return AssistantReply(
        'أتفهّم ذلك، وسأحوّلك الآن إلى موظف خدمة عملاء بشري مع ملخص لمشكلتك. '
        'أرفق صورة المنتج إن أمكن لتسريع المعالجة.',
        escalate: true,
      );
    }

    // 3) الدليل الإرشادي
    final all = <GuideEntry>[];
    try {
      all.addAll(kDefaultGuide);
      final snap = await _db
          .collection('support_guide')
          .where('approved', isEqualTo: true)
          .limit(50)
          .get();
      all.addAll(snap.docs.map((d) => GuideEntry.fromMap(d.id, d.data())));
    } catch (_) {}

    final hits = search(all, question);
    if (hits.isNotEmpty) {
      final e = hits.first;
      final b = StringBuffer(e.answer);
      if (e.steps.isNotEmpty) {
        b.writeln('\n\nالخطوات:');
        for (var i = 0; i < e.steps.length; i++) {
          b.writeln('${i + 1}) ${e.steps[i]}');
        }
      }
      return AssistantReply(b.toString(), escalate: false);
    }

    return const AssistantReply(
      'لم أجد إجابة دقيقة في الدليل. اكتب سؤالك بصيغة أخرى، '
      'أو اضغط «تحويل لموظف خدمة العملاء» وسأحوّلك مع ملخص واضح.',
      escalate: false,
    );
  }

  /// يحوّل المحادثة لموظف ويولّد ملخصاً ذكياً للمشكلة.
  Future<void> escalate(String threadId,
      {Order? order, String reason = ''}) async {
    final thread = _db.collection('support_threads').doc(threadId);
    final summary = await buildSummary(threadId, order: order, reason: reason);
    await thread.set({
      'mode': 'waiting_agent',
      'summary': summary,
      'unreadForAgent': FieldValue.increment(1),
      'lastAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await thread.collection('messages').add({
      'from': 'system',
      'text': 'تم تحويل المحادثة إلى موظف خدمة عملاء. سيرد عليك في أقرب وقت.',
      'at': FieldValue.serverTimestamp(),
    });

    // تنبيه فوري لدور الدعم وللمدير الرئيسي.
    for (final target in ['support', 'manager']) {
      await _db.collection('staff_alerts').add({
        'type': 'human_requested',
        'target': target,
        'threadId': threadId,
        'orderId': order?.id ?? '',
        'orderNo': order?.orderNo ?? '',
        'customerName': order?.address.receiverName ?? '',
        'summary': summary,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }

  /// ملخص ذكي (قالبي) من آخر الرسائل وبيانات الطلب.
  Future<String> buildSummary(String threadId,
      {Order? order, String reason = ''}) async {
    final b = StringBuffer();
    try {
      final snap = await _db
          .collection('support_threads')
          .doc(threadId)
          .collection('messages')
          .orderBy('at', descending: true)
          .limit(5)
          .get();
      final lines = snap.docs
          .map((d) => (d.data()['text'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toList()
          .reversed
          .toList();
      b.writeln('المشكلة: ${reason.isEmpty ? (lines.isNotEmpty ? lines.last : 'استفسار') : reason}');
      if (lines.isNotEmpty) {
        b.writeln('آخر ما كتبه العميل:');
        for (final l in lines) {
          b.writeln('• $l');
        }
      }
    } catch (_) {}
    if (order != null) {
      b.writeln('الطلب: ${order.orderNo} — ${order.status.labelAr}');
      b.writeln(
          'المتبقي: ${formatMoney(order.remainingLocal, order.currency)} من '
          '${formatMoney(order.totalLocal, order.currency)}');
      if (order.trackingNo.isNotEmpty) b.writeln('التتبع: ${order.trackingNo}');
    }
    return b.toString().trim();
  }

  Future<void> agentReply(String threadId, String text,
      {String imageUrl = '', String byName = ''}) async {
    final thread = _db.collection('support_threads').doc(threadId);
    await thread.collection('messages').add({
      'from': 'agent',
      'text': text.trim(),
      'imageUrl': imageUrl,
      'byName': byName,
      'at': FieldValue.serverTimestamp(),
    });
    await thread.set({
      'mode': 'live',
      'lastMessage': text.trim().isEmpty ? '📷 صورة' : text.trim(),
      'lastAt': FieldValue.serverTimestamp(),
      'unreadForAgent': 0,
      'unreadForCustomer': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> closeThread(String threadId) => _db
      .collection('support_threads')
      .doc(threadId)
      .set({'mode': 'closed'}, SetOptions(merge: true));

  Future<void> returnToBot(String threadId) => _db
      .collection('support_threads')
      .doc(threadId)
      .set({'mode': 'bot'}, SetOptions(merge: true));

  Future<void> markReadForAgent(String threadId) => _db
      .collection('support_threads')
      .doc(threadId)
      .set({'unreadForAgent': 0}, SetOptions(merge: true));

  Future<void> markReadForCustomer(String threadId) => _db
      .collection('support_threads')
      .doc(threadId)
      .set({'unreadForCustomer': 0}, SetOptions(merge: true));

  // ═══════════════ تحليل الأسئلة المتكررة ═══════════════

  /// يستخرج المجموعات المتكررة من السجلات (تجميع محلي بلا خدمات خارجية).
  Future<List<FaqSuggestion>> analyseFaqs() async {
    final texts = <String>[];
    try {
      final logs = await _db
          .collection('support_query_logs')
          .orderBy('at', descending: true)
          .limit(500)
          .get();
      texts.addAll(logs.docs
          .map((d) => (d.data()['text'] ?? '').toString())
          .where((t) => t.trim().length > 3));
    } catch (_) {}

    final groups = <String, List<String>>{};
    for (final t in texts) {
      final words = _norm(t).split(RegExp(r'\s+'))
          .where((w) => w.length > 2)
          .toList();
      if (words.isEmpty) continue;
      // بصمة المجموعة: أول كلمتين معنويتين بعد الترتيب
      final key = (words.toList()..sort()).take(2).join('_');
      groups.putIfAbsent(key, () => []).add(t);
    }

    final out = <FaqSuggestion>[];
    for (final e in groups.entries) {
      if (e.value.length < 2) continue;
      final sample = e.value.first;
      final hits = search(kDefaultGuide, sample);
      out.add(FaqSuggestion(
        key: e.key,
        question: sample,
        answer: hits.isNotEmpty ? hits.first.answer : 'سيُحرَّر الجواب عند الاعتماد.',
        steps: hits.isNotEmpty ? hits.first.steps : const <String>[],
        stage: hits.isNotEmpty ? hits.first.stage : 'أسئلة متكررة',
        count: e.value.length,
        examples: e.value.take(3).toList(),
      ));
    }
    out.sort((a, b) => b.count.compareTo(a.count));
    return out.take(12).toList();
  }

  /// يعتمد مقترحاً فينشره في دليل العملاء.
  Future<void> publishSuggestion(FaqSuggestion s) => _db
      .collection('support_guide')
      .doc('ai_${DateTime.now().millisecondsSinceEpoch}')
      .set(<String, dynamic>{
        'stage': s.stage,
        'question': s.question,
        'answer': s.answer,
        'steps': s.steps,
        'tags': s.question.split(RegExp(r'\s+')).take(6).toList(),
        'fromAi': true,
        'approved': true,
        'hits': s.count,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// يتجاهل مقترحاً (يسجّل التجاهل حتى لا يتكرر ظهوره).
  Future<void> ignoreSuggestion(String key) async {
    try {
      await _db.collection('support_faq_ignored').doc(key).set({
        'ignoredAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

class AssistantReply {
  const AssistantReply(this.text, {required this.escalate});
  final String text;
  final bool escalate;
}

class FaqSuggestion {
  const FaqSuggestion({
    required this.key,
    required this.question,
    required this.answer,
    required this.steps,
    required this.stage,
    required this.count,
    required this.examples,
  });

  final String key;
  final String question;
  final String answer;
  final List<String> steps;
  final String stage;
  final int count;
  final List<String> examples;
}

// ═══════════════ أدوات نصية ═══════════════

String _norm(String s) {
  var t = s.toLowerCase();
  t = t.replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '');
  t = t.replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه');
  t = t.replaceAll(RegExp(r'[^\w\u0600-\u06FF\s]'), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _has(String haystack, List<String> needles) =>
    needles.any((n) => haystack.contains(_norm(n)));

/// ترميز/فك ترميز مساعد لرسائل النظام (يُستخدم في الاختبارات).
String encodePayload(Object data) =>
    base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');

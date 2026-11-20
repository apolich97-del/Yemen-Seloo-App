import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/currency.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_theme.dart';
import '../data/support_guide.dart';
import '../data/support_models.dart';
import '../data/support_service.dart';

/// شاشة «خدمة العملاء والدعم»: دليل إرشادي + مساعد ذكي ودردشة حية.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.order});

  /// إن فُتحت من تفاصيل طلب، تُربط المحادثة بالطلب.
  final Order? order;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _svc = Get.find<SupportService>();
  final _search = TextEditingController();
  String _query = '';
  List<String> _suggestions = const <String>[];
  String? _threadId;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _svc.suggestions().then((v) {
      if (mounted) setState(() => _suggestions = v);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.order == null
        ? 'خدمة العملاء والدعم'
        : 'الدعم عن الطلب ${widget.order!.orderNo}';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.accent,
            tabs: [
              Tab(text: 'الدليل الإرشادي', icon: Icon(Icons.menu_book, size: 18)),
              Tab(text: 'المساعد والدردشة', icon: Icon(Icons.chat_bubble_outline, size: 18)),
            ],
          ),
        ),
        body: TabBarView(
          children: [_guideTab(), _chatTab()],
        ),
      ),
    );
  }

  // ══════════════ قسم أ: الدليل ══════════════

  Widget _guideTab() => StreamBuilder<List<GuideEntry>>(
        stream: _svc.guide(),
        builder: (context, snap) {
          final all = snap.data ?? kDefaultGuide;
          final results = SupportService.search(all, _query);
          final stages = <String, List<GuideEntry>>{};
          for (final e in (_query.isEmpty ? all : results)) {
            stages.putIfAbsent(e.stage, () => []).add(e);
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'ابحث: الدفع، الإيصال، الطلب الآجل، التوصيل…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
                onSubmitted: (v) => _svc.logQuery(v),
              ),
              if (_query.isEmpty && _suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('الأكثر بحثاً',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: T.primary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _suggestions
                      .map((s) => ActionChip(
                            backgroundColor: T.card,
                            side: BorderSide(color: T.border),
                            label: Text(s,
                                style: TextStyle(
                                    fontSize: 10.5, color: T.text)),
                            onPressed: () {
                              _search.text = s;
                              setState(() => _query = s);
                              _svc.logQuery(s);
                            },
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              if (results.isEmpty && _query.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: T.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('لا توجد إجابة جاهزة لسؤالك',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                          'اسأل المساعد الذكي وسيجيبك من بيانات طلبك، أو حوّلك لموظف.',
                          style: TextStyle(
                              fontSize: 11.5, color: T.muted)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _openChat(prefill: _query),
                        child: const Text('اسأل المساعد الذكي'),
                      ),
                    ],
                  ),
                ),
              ...stages.entries.map((entry) => _stageBlock(entry.key, entry.value)),
            ],
          );
        },
      );

  Widget _stageBlock(String stage, List<GuideEntry> items) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(stage,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: T.primary)),
            ),
            const SizedBox(height: 6),
            ...items.map((e) => _entryTile(e)),
          ],
        ),
      );

  Widget _entryTile(GuideEntry e) => Obx(() => Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.border),
        ),
        child: Theme(
          data: Theme.of(Get.context!).copyWith(
            dividerColor: Colors.transparent,
            splashColor: T.primary.withOpacity(.08),
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            backgroundColor: T.card,
            collapsedBackgroundColor: T.card,
            iconColor: T.primary,
            collapsedIconColor: T.muted,
            textColor: T.text,
            collapsedTextColor: T.text,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(e.question,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: T.text)),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(e.answer,
                    style: TextStyle(
                        fontSize: 12, height: 1.6, color: T.text)),
              ),
              if (e.steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...List.generate(
                  e.steps.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: AppColors.accent.withOpacity(.25),
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: T.text)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e.steps[i],
                              style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.5,
                                  color: T.text)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ));

  // ══════════════ قسم ب: المساعد والدردشة ══════════════

  Widget _chatTab() {
    if (_threadId == null) {
      return _startPanel();
    }
    return _ChatView(threadId: _threadId!, order: widget.order);
  }

  Widget _startPanel() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent, size: 64, color: AppColors.primary),
            const SizedBox(height: 10),
            const Text('مساعد يمن سيلو الذكي',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'يجيبك من بيانات طلبك الفعلية: الحالة، المدفوع، المتبقي، التتبع، '
              'ثم يحوّلك لموظف خدمة عملاء عند الحاجة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: T.muted, height: 1.6),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _opening ? null : () => _openChat(),
              icon: const Icon(Icons.chat, size: 18),
              label: Text(_opening ? 'جارٍ الفتح…' : 'ابدأ المحادثة'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _openChat(prefill: 'أريد التحدث مع موظف خدمة العملاء'),
              child: const Text('تحويل لموظف خدمة العملاء'),
            ),
          ],
        ),
      );

  Future<void> _openChat({String prefill = ''}) async {
    setState(() => _opening = true);
    try {
      final id = await _svc.openThread(order: widget.order);
      if (!mounted) return;
      setState(() {
        _threadId = id;
        _opening = false;
      });
      if (prefill.isNotEmpty) {
        await _svc.sendCustomerMessage(id, prefill, order: widget.order);
      }
    } catch (e) {
      if (mounted) setState(() => _opening = false);
      Get.snackbar('تعذر فتح المحادثة', '$e');
    }
  }
}

/// واجهة الدردشة الفعلية.
class _ChatView extends StatefulWidget {
  const _ChatView({required this.threadId, this.order});

  final String threadId;
  final Order? order;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _svc = Get.find<SupportService>();
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send({String image = ''}) async {
    final t = _text.text.trim();
    if (t.isEmpty && image.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _svc.sendCustomerMessage(widget.threadId, t,
          imageUrl: image, order: widget.order);
      _text.clear();
    } catch (e) {
      Get.snackbar('تعذر الإرسال', '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _typingBubble() => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: T.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: T.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('•••',
                  style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                      color: T.muted)),
              const SizedBox(width: 6),
              Text('المساعد يكتب',
                  style: TextStyle(fontSize: 9.5, color: T.muted)),
            ],
          ),
        ),
      );

  Widget _composerBar() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _pickOrder,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: T.primary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: T.primary.withOpacity(.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 14, color: T.primary),
                      const SizedBox(width: 5),
                      Text('إرسال الطلب',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: T.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ...<String>[
                'تتبع شحنتي',
                'المتبقي الآجل',
                'طلب إرجاع',
                'تعديل العنوان',
              ].map((t) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        _text.text = t;
                        _send();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: T.soft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: T.softBorder),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 10.5, color: T.text)),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      );

  Future<void> _pickOrder() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final picked = await showModalBottomSheet<Order>(
      context: context,
      backgroundColor: T.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, size: 17, color: T.primary),
                const SizedBox(width: 6),
                Text('طلبي',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: T.text)),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('userId', isEqualTo: uid)
                    .orderBy('createdAt', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('لا توجد طلبات',
                          style: TextStyle(fontSize: 12, color: T.muted)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final o = Order.fromDoc(
                          docs[i].id, docs[i].data());
                      return ListTile(
                        dense: true,
                        title: Text(o.orderNo,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: T.text)),
                        subtitle: Text(
                            '${o.status.labelAr} · ${formatMoney(o.totalSar, AppCurrency.sar)}',
                            style: TextStyle(fontSize: 10.5, color: T.muted)),
                        trailing: Icon(Icons.send, size: 16, color: T.primary),
                        onTap: () => Navigator.pop(context, o),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    _text.text =
        'أرغب في الاستفسار عن طلبي ${picked.orderNo} — الحالة: ${picked.status.labelAr}';
    await _send();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 40, maxWidth: 900);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final mime = x.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    await _send(image: 'data:$mime;base64,${base64Encode(bytes)}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<SupportMessage>>(
            stream: _svc.messages(widget.threadId),
            builder: (context, snap) {
              final list = snap.data ?? const <SupportMessage>[];
              final header = _AssistantHeader(
                onAsk: (String q) {
                  _text.text = q;
                  _send();
                },
                onOrder: _pickOrder,
              );
              if (list.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    header,
                    if (_sending) _typingBubble(),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length + 1 + (_sending ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == 0) return header;
                  if (i > list.length) return _typingBubble();
                  return _bubble(list[i - 1]);
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              color: T.card,
              border: Border(top: BorderSide(color: T.border)),
            ),
            child: Column(
              children: [
                _composerBar(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: _pickImage,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            hintText: 'اكتب رسالتك…'),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: AppColors.primary),
                      onPressed: _sending ? null : () => _send(),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    await _svc.escalate(widget.threadId, order: widget.order);
                    Get.snackbar('تم التحويل',
                        'سيتواصل معك موظف خدمة عملاء قريباً');
                  },
                  icon: const Icon(Icons.headset_mic_outlined, size: 16),
                  label: const Text('تحويل لموظف خدمة العملاء'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(SupportMessage m) {
    final mine = m.isCustomer;
    final isBot = m.from == 'bot';
    final color = mine
        ? AppColors.primary
        : isBot
            ? T.card
            : m.from == 'system'
                ? AppColors.accent.withOpacity(.15)
                : T.card;
    final textColor = mine ? Colors.white : T.text;
    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * .78),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                  isBot
                      ? 'المساعد الذكي'
                      : m.from == 'system'
                          ? 'النظام'
                          : (m.byName.isEmpty ? 'خدمة العملاء' : m.byName),
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: T.muted)),
            const SizedBox(height: 3),
            if (m.imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                      base64Decode(
                          m.imageUrl.substring(m.imageUrl.indexOf(',') + 1)),
                      height: 140,
                      fit: BoxFit.cover),
                ),
              ),
            Text(m.text,
                style: TextStyle(fontSize: 12, height: 1.6, color: textColor)),
            if (isBot) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickReplies
                    .map((q) => ActionChip(
                          backgroundColor: T.card,
                          side: BorderSide(color: T.border),
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 2),
                          label: Text(q,
                              style: TextStyle(
                                  fontSize: 10.5, color: T.primary)),
                          onPressed: () => _quick(q),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const List<String> _quickReplies = <String>[
    'تتبع طلبي',
    'كم المتبقي في الآجل',
    'خطوات الدفع',
    'إلغاء الطلب',
    'التحدث مع موظف بشري',
  ];

  Future<void> _quick(String q) async {
    if (q == 'التحدث مع موظف بشري') {
      await _svc.escalate(widget.threadId, order: widget.order);
      Get.snackbar('تم التحويل', 'سيتواصل معك موظف خدمة عملاء قريباً');
      return;
    }
    _text.text = q;
    await _send();
  }
}


/// رأس المساعد الذكي: إجراءات سريعة + بطاقة «أسئلة ساخنة» بتبويبات.
class _AssistantHeader extends StatefulWidget {
  const _AssistantHeader({required this.onAsk, required this.onOrder});
  final void Function(String question) onAsk;
  final VoidCallback onOrder;

  @override
  State<_AssistantHeader> createState() => _AssistantHeaderState();
}

class _AssistantHeaderState extends State<_AssistantHeader> {
  static const List<_QuickAction> _actions = <_QuickAction>[
    _QuickAction('إرجاع واسترداد', Icons.assignment_return_outlined),
    _QuickAction('تتبع الشحنة', Icons.local_shipping_outlined),
    _QuickAction('تسريع الشحن', Icons.bolt_outlined),
    _QuickAction('إرسال الطلب', Icons.send_outlined),
    _QuickAction('تعديل العنوان', Icons.location_on_outlined),
  ];

  static const Map<String, List<String>> _hot = <String, List<String>>{
    'أسئلة ساخنة': <String>[
      'كيف أعرف أن طلبي وصل إلى مستودع شي إن؟',
      'متى يتم شحن طلبي إلى اليمن؟',
      'ما هي مدة التوصيل المتوقعة؟',
      'كيف أتواصل مع موظف بشري؟',
    ],
    'التتبع والتوصيل': <String>[
      'أين أجد رقم تتبع الشحنة؟',
      'شحنتي متأخرة، ماذا أفعل؟',
      'هل يمكن تغيير عنوان التوصيل بعد الشحن؟',
      'من هو المندوب المسؤول عن طلبي؟',
    ],
    'الإرجاع والاسترداد': <String>[
      'كيف أطلب إرجاع منتج؟',
      'متى تُرد مبالغ الاسترداد؟',
      'هل يمكن استرداد المبلغ على المحفظة؟',
      'ماذا لو وصل المنتج تالفاً؟',
    ],
    'قيد التجهيز': <String>[
      'كم يستغرق تجهيز الطلب؟',
      'هل يمكن تعديل الطلب قبل التجهيز؟',
      'لماذا طلبي قيد التجهيز منذ أيام؟',
      'هل أستطيع إضافة منتج لطلبي؟',
    ],
    'الدفع والآجل': <String>[
      'ما هو نظام الدفع الآجل 50%؟',
      'كيف أرفع إيصال الحوالة؟',
      'ما المبلغ المتبقي عليّ؟',
      'أي محافظ وبنوك تقبلونها؟',
    ],
  };

  int _tab = 0;
  int _seed = 0;

  List<String> get _questions {
    final base = _hot[_hot.keys.elementAt(_tab)] ?? const <String>[];
    if (_seed == 0) return base;
    final copy = List<String>.from(base);
    copy.removeAt(_seed % copy.length);
    copy.add(base[_seed % base.length]);
    return copy;
  }

  void _onAction(String label) {
    if (label == 'إرسال الطلب') {
      widget.onOrder();
      return;
    }
    widget.onAsk(label == 'إرجاع واسترداد'
        ? 'أرغب في طلب إرجاع واسترداد مبلغ منتج من طلبي.'
        : label == 'تتبع الشحنة'
            ? 'أريد تتبع شحنتي ومعرفة موقعها الحالي.'
            : label == 'تسريع الشحن'
                ? 'أريد تسريع شحن طلبي، ما الخيارات المتاحة؟'
                : 'أريد تعديل عنوان التوصيل في طلبي.');
  }

  void _more() {
    Get.dialog(
      AlertDialog(
        backgroundColor: T.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('الأسئلة الموصى بها',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: T.text)),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _hot.entries.expand((e) {
                return <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: T.primary)),
                  ),
                  ...e.value.map((q) => InkWell(
                        onTap: () {
                          Get.back();
                          widget.onAsk(q);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('• $q',
                              style: TextStyle(
                                  fontSize: 11.5, color: T.text)),
                        ),
                      )),
                ];
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: Text('إغلاق', style: TextStyle(color: T.primary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // بطاقات الإجراءات السريعة
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a = _actions[i];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _onAction(a.label),
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: T.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: T.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(a.icon, size: 18, color: T.primary),
                      const SizedBox(height: 5),
                      Text(a.label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 9.5,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: T.text)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // بطاقة الأسئلة الساخنة
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: T.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: T.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department_outlined,
                      size: 16, color: T.primary),
                  const SizedBox(width: 6),
                  Text('أسئلة ساخنة',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: T.text)),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _seed++),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 13, color: T.muted),
                          const SizedBox(width: 3),
                          Text('تحديث',
                              style: TextStyle(
                                  fontSize: 9.5, color: T.muted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _more,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      child: Text('أكثر',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: T.primary)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _hot.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final active = i == _tab;
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() {
                        _tab = i;
                        _seed = 0;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? T.primary.withOpacity(.13)
                              : T.soft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active ? T.primary : T.softBorder),
                        ),
                        child: Text(_hot.keys.elementAt(i),
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: active
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: active ? T.primary : T.muted)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              ...List<Widget>.generate(_questions.length, (i) {
                final q = _questions[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => widget.onAsk(q),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 17,
                          height: 17,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: T.soft,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: T.softBorder),
                          ),
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: T.primary)),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(q,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: T.text)),
                        ),
                        Icon(Icons.chevron_left,
                            size: 14, color: T.muted),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  const _QuickAction(this.label, this.icon);
}

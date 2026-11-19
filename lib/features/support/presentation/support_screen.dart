import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

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
                            label: Text(s,
                                style: const TextStyle(fontSize: 10.5)),
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
              if (list.isEmpty) {
                return Center(
                    child: Text('اكتب سؤالك وسيجيبك المساعد الذكي',
                        style: TextStyle(fontSize: 12, color: T.muted)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) => _bubble(list[i]),
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
            ? T.bg
            : m.from == 'system'
                ? AppColors.accent.withOpacity(.15)
                : Colors.white;
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
          ],
        ),
      ),
    );
  }
}

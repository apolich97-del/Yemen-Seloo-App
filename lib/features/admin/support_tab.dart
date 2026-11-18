import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../support/data/support_models.dart';
import '../support/data/support_service.dart';

/// تبويب «دعم العملاء وتحليل الأسئلة» في لوحة الإدارة.
class AdminSupportTab extends StatefulWidget {
  const AdminSupportTab({super.key});

  @override
  State<AdminSupportTab> createState() => _AdminSupportTabState();
}

class _AdminSupportTabState extends State<AdminSupportTab> {
  final _svc = Get.find<SupportService>();
  List<FaqSuggestion> _faqs = const <FaqSuggestion>[];
  bool _loadingFaqs = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppColors.primaryDark,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'محادثات العملاء'),
              Tab(text: 'تحليل الأسئلة المتكررة'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_threadsList(), _faqAnalysis()],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════ المحادثات ═══════════

  Widget _threadsList() => StreamBuilder<List<SupportThread>>(
        stream: _svc.allThreads(),
        builder: (context, snap) {
          final list = snap.data ?? const <SupportThread>[];
          if (list.isEmpty) {
            return const Center(
                child: Text('لا توجد محادثات بعد',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) => _threadRow(list[i]),
          );
        },
      );

  Widget _threadRow(SupportThread t) {
    final color = t.mode == 'waiting_agent'
        ? AppColors.danger
        : t.mode == 'live'
            ? AppColors.success
            : AppColors.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openThread(t),
        title: Row(
          children: [
            Text(t.orderNo.isEmpty ? 'استفسار عام' : t.orderNo,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(t.modeAr,
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w900, color: color)),
            ),
            if (t.unreadForAgent > 0) ...[
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 8,
                backgroundColor: AppColors.danger,
                child: Text('${t.unreadForAgent}',
                    style:
                        const TextStyle(fontSize: 8, color: Colors.white)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5, height: 1.5, color: AppColors.muted)),
              ),
            if (t.lastMessage.isNotEmpty)
              Text('آخر رسالة: ${t.lastMessage}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.primaryDark)),
          ],
        ),
        trailing: const Icon(Icons.chevron_left, size: 18),
      ),
    );
  }

  Future<void> _openThread(SupportThread t) async {
    await _svc.markReadForAgent(t.id);
    if (!mounted) return;
    Get.to(() => _AgentChatScreen(thread: t));
  }

  // ═══════════ تحليل الأسئلة ═══════════

  Widget _faqAnalysis() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'يقرأ النظام سجل أسئلة الدردشة وعبارات البحث، ويجمع المتكرر منها، '
              'ثم تقترح صياغة سؤال وجواب وخطوات. اعتمد ما تريد نشره في دليل العملاء.',
              style: TextStyle(fontSize: 11, height: 1.6, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _loadingFaqs ? null : _runAnalysis,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(_loadingFaqs
                ? 'جارٍ التحليل…'
                : 'تحليل الأسئلة المتكررة'),
          ),
          const SizedBox(height: 10),
          ..._faqs.map(_faqCard),
        ],
      );

  Future<void> _runAnalysis() async {
    setState(() => _loadingFaqs = true);
    try {
      final list = await _svc.analyseFaqs();
      if (mounted) setState(() => _faqs = list);
      if (list.isEmpty) {
        Get.snackbar('لا توجد بيانات كافية',
            'تحتاج أسئلة مكررة مرتين على الأقل في السجل');
      }
    } finally {
      if (mounted) setState(() => _loadingFaqs = false);
    }
  }

  Widget _faqCard(FaqSuggestion s) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.question,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${s.count}×',
                        style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('المرحلة: ${s.stage}',
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.muted)),
              const SizedBox(height: 4),
              Text(s.answer,
                  style: const TextStyle(fontSize: 11, height: 1.5)),
              if (s.examples.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('من كلام العملاء: ${s.examples.join(' · ')}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.muted)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _svc.publishSuggestion(s);
                        setState(() => _faqs = _faqs
                            .where((e) => e.key != s.key)
                            .toList());
                        Get.snackbar('نُشر', 'أُضيف السؤال إلى دليل العملاء');
                      },
                      child: const Text('اعتماد ونشر'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _svc.ignoreSuggestion(s.key);
                        setState(() => _faqs = _faqs
                            .where((e) => e.key != s.key)
                            .toList());
                      },
                      child: const Text('تجاهل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

/// محادثة الموظف مع العميل.
class _AgentChatScreen extends StatefulWidget {
  const _AgentChatScreen({required this.thread});

  final SupportThread thread;

  @override
  State<_AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<_AgentChatScreen> {
  final _svc = Get.find<SupportService>();
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.thread.orderNo.isEmpty
            ? 'محادثة عميل'
            : 'محادثة الطلب ${widget.thread.orderNo}'),
        actions: [
          IconButton(
            tooltip: 'إعادة للمساعد الذكي',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () async {
              await _svc.returnToBot(widget.thread.id);
              Get.snackbar('تم', 'عادت المحادثة للمساعد الذكي');
            },
          ),
          IconButton(
            tooltip: 'إغلاق التذكرة',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () async {
              await _svc.closeThread(widget.thread.id);
              Get.back();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.thread.summary.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.all(10),
              child: Text(widget.thread.summary,
                  style: const TextStyle(fontSize: 10.5, height: 1.5)),
            ),
          Expanded(
            child: StreamBuilder<List<SupportMessage>>(
              stream: _svc.messages(widget.thread.id),
              builder: (context, snap) {
                final list = snap.data ?? const <SupportMessage>[];
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final mine = m.isAgent;
                    return Align(
                      alignment:
                          mine ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * .78),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFE9E4F5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                mine
                                    ? 'أنت'
                                    : m.isCustomer
                                        ? 'العميل'
                                        : 'المساعد الذكي',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: mine
                                        ? Colors.white70
                                        : AppColors.muted)),
                            const SizedBox(height: 3),
                            if (m.imageUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                      base64Decode(m.imageUrl.substring(
                                          m.imageUrl.indexOf(',') + 1)),
                                      height: 130,
                                      fit: BoxFit.cover),
                                ),
                              ),
                            Text(m.text,
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                    color: mine ? Colors.white : AppColors.ink)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration:
                          const InputDecoration(hintText: 'ردّك على العميل…'),
                      onSubmitted: (_) => _reply(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _reply,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reply() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    final name = Get.find<AuthService>().user.value?.displayName ?? 'خدمة العملاء';
    await _svc.agentReply(widget.thread.id, t,
        byName: name.isEmpty ? 'خدمة العملاء' : name);
    _text.clear();
  }
}

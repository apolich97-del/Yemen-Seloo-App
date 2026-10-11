import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _purple = Color(0xFF7C3AED);

class SupportTab extends StatelessWidget {
  const SupportTab({super.key});

  Future<void> _openWhatsApp(String phone) async {
    final Uri url = Uri.parse('https://wa.me/$phone');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const SizedBox(height: 20),
          const Icon(Icons.support_agent, size: 80, color: _purple),
          const SizedBox(height: 16),
          const Text(
            'فريق يمن سيلو في خدمتك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'تواصل معنا عبر واتساب أو الهاتف',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 30),
          _ContactCard(
            title: 'الرقم الأساسي',
            phone: '770518757',
            onCall: () => _call('770518757'),
            onWhats: () => _openWhatsApp('967770518757'),
          ),
          const SizedBox(height: 12),
          _ContactCard(
            title: 'الرقم البديل',
            phone: '737383637',
            onCall: () => _call('737383637'),
            onWhats: () => _openWhatsApp('967737383637'),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: const Column(
              children: <Widget>[
                Icon(Icons.schedule, color: _purple, size: 24),
                SizedBox(height: 8),
                Text(
                  'أوقات العمل',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _purple),
                ),
                SizedBox(height: 4),
                Text(
                  'السبت - الخميس: 9 صباحاً - 9 مساءً',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.title,
    required this.phone,
    required this.onCall,
    required this.onWhats,
  });

  final String title;
  final String phone;
  final VoidCallback onCall;
  final VoidCallback onWhats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _purple),
          ),
          const SizedBox(height: 6),
          Text(phone,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onWhats,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('واتساب'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _purple,
                    side: const BorderSide(color: _purple),
                  ),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('اتصال'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

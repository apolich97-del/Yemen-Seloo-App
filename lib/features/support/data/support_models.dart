import 'package:cloud_firestore/cloud_firestore.dart';

/// محادثة دعم العميل.
class SupportThread {
  const SupportThread({
    required this.id,
    required this.userId,
    this.customerName = '',
    this.customerPhone = '',
    this.orderNo = '',
    this.orderId = '',
    this.mode = 'bot',
    this.summary = '',
    this.lastMessage = '',
    this.unreadForAgent = 0,
    this.unreadForCustomer = 0,
    this.createdAt,
    this.lastAt,
  });

  final String id;
  final String userId;
  final String customerName;
  final String customerPhone;
  final String orderNo;
  final String orderId;

  /// bot | waiting_agent | live | closed
  final String mode;
  final String summary;
  final String lastMessage;
  final int unreadForAgent;
  final int unreadForCustomer;
  final DateTime? createdAt;
  final DateTime? lastAt;

  String get modeAr {
    switch (mode) {
      case 'waiting_agent':
        return 'بانتظار موظف';
      case 'live':
        return 'محادثة حية';
      case 'closed':
        return 'مغلقة';
      default:
        return 'المساعد الذكي';
    }
  }

  factory SupportThread.fromDoc(String id, Map<String, dynamic> m) =>
      SupportThread(
        id: id,
        userId: (m['userId'] ?? '') as String,
        customerName: (m['customerName'] ?? '') as String,
        customerPhone: (m['customerPhone'] ?? '') as String,
        orderNo: (m['orderNo'] ?? '') as String,
        orderId: (m['orderId'] ?? '') as String,
        mode: (m['mode'] ?? 'bot') as String,
        summary: (m['summary'] ?? '') as String,
        lastMessage: (m['lastMessage'] ?? '') as String,
        unreadForAgent: (m['unreadForAgent'] as num?)?.toInt() ?? 0,
        unreadForCustomer: (m['unreadForCustomer'] as num?)?.toInt() ?? 0,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        lastAt: (m['lastAt'] as Timestamp?)?.toDate(),
      );
}

/// رسالة داخل المحادثة.
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.from,
    required this.text,
    this.imageUrl = '',
    this.byName = '',
    this.at,
  });

  final String id;

  /// customer | bot | agent | system
  final String from;
  final String text;
  final String imageUrl;
  final String byName;
  final DateTime? at;

  bool get isCustomer => from == 'customer';
  bool get isAgent => from == 'agent';

  factory SupportMessage.fromDoc(String id, Map<String, dynamic> m) =>
      SupportMessage(
        id: id,
        from: (m['from'] ?? 'customer') as String,
        text: (m['text'] ?? '') as String,
        imageUrl: (m['imageUrl'] ?? '') as String,
        byName: (m['byName'] ?? '') as String,
        at: (m['at'] as Timestamp?)?.toDate(),
      );
}

/// سجل سؤال/بحث لتحليل الأسئلة المتكررة.
class QueryLog {
  const QueryLog({
    required this.text,
    this.kind = 'search',
    this.userId = '',
    this.orderNo = '',
    this.at,
  });

  final String text;
  final String kind;
  final String userId;
  final String orderNo;
  final DateTime? at;
}

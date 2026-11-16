import 'package:cloud_firestore/cloud_firestore.dart';

/// إيصال سداد مرتبط بطلب — نظام «إيصال» المزدوج.
class Receipt {
  final String id;
  final String receiptNo;
  final String orderId;
  final String orderNo;

  /// 'pending' | 'approved' | 'rejected'
  final String status;

  /// 'customer' | 'admin'
  final String source;

  final double amountLocal;
  final double amountSar;
  final String refNo;
  final String senderName;
  final String note;
  final String proofUrl;
  final double remainingAfterLocal;
  final String reviewedBy;
  final String rejectReason;
  final Map<String, dynamic> verification;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const Receipt({
    required this.id,
    required this.receiptNo,
    required this.orderId,
    required this.orderNo,
    this.status = 'pending',
    this.source = 'customer',
    this.amountLocal = 0,
    this.amountSar = 0,
    this.refNo = '',
    this.senderName = '',
    this.note = '',
    this.proofUrl = '',
    this.remainingAfterLocal = 0,
    this.reviewedBy = '',
    this.rejectReason = '',
    this.verification = const {},
    this.createdAt,
    this.reviewedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusAr => switch (status) {
        'approved' => 'معتمد ومقيّد',
        'rejected' => 'مرفوض',
        _ => 'قيد المراجعة',
      };

  factory Receipt.fromDoc(String id, Map<String, dynamic> m) => Receipt(
        id: id,
        receiptNo: (m['receiptNo'] ?? '') as String,
        orderId: (m['orderId'] ?? '') as String,
        orderNo: (m['orderNo'] ?? '') as String,
        status: (m['status'] ?? 'pending') as String,
        source: (m['source'] ?? 'customer') as String,
        amountLocal: (m['amountLocal'] as num?)?.toDouble() ?? 0,
        amountSar: (m['amountSar'] as num?)?.toDouble() ?? 0,
        refNo: (m['refNo'] ?? '') as String,
        senderName: (m['senderName'] ?? '') as String,
        note: (m['note'] ?? '') as String,
        proofUrl: (m['proofUrl'] ?? '') as String,
        remainingAfterLocal:
            (m['remainingAfterLocal'] as num?)?.toDouble() ?? 0,
        reviewedBy: (m['reviewedBy'] ?? '') as String,
        rejectReason: (m['rejectReason'] ?? '') as String,
        verification: (m['verification'] as Map<String, dynamic>?) ?? const {},
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        reviewedAt: (m['reviewedAt'] as Timestamp?)?.toDate(),
      );
}

/// سجل استرداد أموال داخل مستند الطلب (orders/{id}.refunds[]).
class RefundRecord {
  RefundRecord({
    required this.id,
    required this.refundRefNo,
    required this.reason,
    this.reasonNote = '',
    required this.items,
    required this.amountSar,
    required this.amountLocal,
    required this.currency,
    required this.exchangeRate,
    required this.settlementMethod,
    this.bankOrWalletName = '',
    this.payoutAccountNumber = '',
    this.payoutAccountHolder = '',
    this.status = 'pending_account',
    this.transferRefNo = '',
    this.transferProofUrl = '',
    this.createdBy = '',
    this.completedBy = '',
    this.deductedFromRemainingLocal = 0,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String refundRefNo;

  /// out_of_stock | shipping_unavailable | damaged | other
  final String reason;
  final String reasonNote;

  /// عناصر مستردة: goodsId, title, imageUrl, color, size, qty, unitPriceSar, lineLocal
  final List<Map<String, dynamic>> items;

  final double amountSar;
  final double amountLocal;
  final String currency;
  final double exchangeRate;

  /// bank_transfer | deduct_remaining
  final String settlementMethod;

  final String bankOrWalletName;
  final String payoutAccountNumber;
  final String payoutAccountHolder;

  /// pending_account | ready_to_transfer | completed | cancelled
  final String status;

  final String transferRefNo;
  final String transferProofUrl;
  final String createdBy;
  final String completedBy;
  final double deductedFromRemainingLocal;
  final DateTime? createdAt;
  final DateTime? completedAt;

  String get reasonAr => switch (reason) {
        'out_of_stock' => 'نفاد الكمية',
        'shipping_unavailable' => 'تعذر الشحن',
        'damaged' => 'منتج تالف',
        _ => 'سبب آخر',
      };

  String get statusAr => switch (status) {
        'pending_account' => 'بانتظار بيانات الحساب',
        'ready_to_transfer' => 'جاهز للتحويل',
        'completed' => 'مكتمل',
        _ => 'ملغي',
      };

  String get methodAr => settlementMethod == 'deduct_remaining'
      ? 'خصم من المتبقي (آجل 50%)'
      : 'تحويل لحساب العميل';

  bool get awaitingAccount => status == 'pending_account';
  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'refundRefNo': refundRefNo,
        'reason': reason,
        'reasonNote': reasonNote,
        'items': items,
        'amountSar': amountSar,
        'amountLocal': amountLocal,
        'currency': currency,
        'exchangeRate': exchangeRate,
        'settlementMethod': settlementMethod,
        'bankOrWalletName': bankOrWalletName,
        'payoutAccountNumber': payoutAccountNumber,
        'payoutAccountHolder': payoutAccountHolder,
        'status': status,
        'transferRefNo': transferRefNo,
        'transferProofUrl': transferProofUrl,
        'createdBy': createdBy,
        'completedBy': completedBy,
        'deductedFromRemainingLocal': deductedFromRemainingLocal,
        'createdAt': createdAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory RefundRecord.fromMap(Map<String, dynamic> m) => RefundRecord(
        id: '${m['id'] ?? ''}',
        refundRefNo: '${m['refundRefNo'] ?? ''}',
        reason: '${m['reason'] ?? 'other'}',
        reasonNote: '${m['reasonNote'] ?? ''}',
        items: ((m['items'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        amountSar: ((m['amountSar'] as num?) ?? 0).toDouble(),
        amountLocal: ((m['amountLocal'] as num?) ?? 0).toDouble(),
        currency: '${m['currency'] ?? 'SAR'}',
        exchangeRate: ((m['exchangeRate'] as num?) ?? 1).toDouble(),
        settlementMethod: '${m['settlementMethod'] ?? 'bank_transfer'}',
        bankOrWalletName: '${m['bankOrWalletName'] ?? ''}',
        payoutAccountNumber: '${m['payoutAccountNumber'] ?? ''}',
        payoutAccountHolder: '${m['payoutAccountHolder'] ?? ''}',
        status: '${m['status'] ?? 'pending_account'}',
        transferRefNo: '${m['transferRefNo'] ?? ''}',
        transferProofUrl: '${m['transferProofUrl'] ?? ''}',
        createdBy: '${m['createdBy'] ?? ''}',
        completedBy: '${m['completedBy'] ?? ''}',
        deductedFromRemainingLocal:
            ((m['deductedFromRemainingLocal'] as num?) ?? 0).toDouble(),
        createdAt: DateTime.tryParse('${m['createdAt'] ?? ''}'),
        completedAt: DateTime.tryParse('${m['completedAt'] ?? ''}'),
      );

  RefundRecord copyWith({
    String? bankOrWalletName,
    String? payoutAccountNumber,
    String? payoutAccountHolder,
    String? status,
    String? transferRefNo,
    String? transferProofUrl,
    String? completedBy,
    DateTime? completedAt,
  }) =>
      RefundRecord(
        id: id,
        refundRefNo: refundRefNo,
        reason: reason,
        reasonNote: reasonNote,
        items: items,
        amountSar: amountSar,
        amountLocal: amountLocal,
        currency: currency,
        exchangeRate: exchangeRate,
        settlementMethod: settlementMethod,
        bankOrWalletName: bankOrWalletName ?? this.bankOrWalletName,
        payoutAccountNumber: payoutAccountNumber ?? this.payoutAccountNumber,
        payoutAccountHolder: payoutAccountHolder ?? this.payoutAccountHolder,
        status: status ?? this.status,
        transferRefNo: transferRefNo ?? this.transferRefNo,
        transferProofUrl: transferProofUrl ?? this.transferProofUrl,
        createdBy: createdBy,
        completedBy: completedBy ?? this.completedBy,
        deductedFromRemainingLocal: deductedFromRemainingLocal,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );

  /// البنوك والمحافظ اليمنية المقترحة.
  static const List<String> wallets = <String>[
    'الكريمي',
    'جوالي',
    'كاش',
    'ون كاش',
    'فلوسك',
    'موني',
    'بنك التضامن',
  ];
}

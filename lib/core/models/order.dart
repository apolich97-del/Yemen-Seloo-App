import 'currency.dart';

/// حالات الطلب — نفس مفاتيح Firestore التي يستخدمها السيرفر واللوحة.
/// الشريط الزمني في واجهة العميل يعرض: السداد → الرفع → التجهيز → الشحن → التوصيل → التسليم.
enum OrderStatus { unpaid, verifying, processing, shipped, outForDelivery, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get key => switch (this) {
        OrderStatus.unpaid => 'unpaid',
        OrderStatus.verifying => 'verifying',
        OrderStatus.processing => 'processing',
        OrderStatus.shipped => 'shipped',
        OrderStatus.outForDelivery => 'outForDelivery',
        OrderStatus.delivered => 'delivered',
        OrderStatus.cancelled => 'cancelled',
      };

  String get labelAr => switch (this) {
        OrderStatus.unpaid => 'غير مدفوع',
        OrderStatus.verifying => 'قيد التحقق',
        OrderStatus.processing => 'قيد التجهيز',
        OrderStatus.shipped => 'تم الشحن',
        OrderStatus.outForDelivery => 'جاري التوصيل',
        OrderStatus.delivered => 'تم التسليم',
        OrderStatus.cancelled => 'ملغي',
      };

  bool get isTerminal => this == OrderStatus.delivered || this == OrderStatus.cancelled;

  /// الانتقالات المسموحة — منسوخة في functions/index.js ويُفرض هناك.
  List<OrderStatus> get nextStatuses => switch (this) {
        OrderStatus.unpaid => const [OrderStatus.verifying, OrderStatus.cancelled],
        OrderStatus.verifying => const [
            OrderStatus.processing,
            OrderStatus.unpaid,
            OrderStatus.cancelled
          ],
        OrderStatus.processing => const [OrderStatus.shipped, OrderStatus.cancelled],
        OrderStatus.shipped => const [OrderStatus.outForDelivery, OrderStatus.cancelled],
        OrderStatus.outForDelivery => const [OrderStatus.delivered, OrderStatus.shipped],
        _ => const [],
      };

  /// الرمز/اللون المستخدم في الشرائح والخط الزمني.
  int get colorValue => switch (this) {
        OrderStatus.unpaid => 0xFFB3261E,
        OrderStatus.verifying => 0xFFB26A00,
        OrderStatus.processing => 0xFF1A56DB,
        OrderStatus.shipped => 0xFF6B21A8,
        OrderStatus.outForDelivery => 0xFF0E7490,
        OrderStatus.delivered => 0xFF15803D,
        OrderStatus.cancelled => 0xFF6B7280,
      };

  static OrderStatus fromKey(String? key) {
    for (final s in OrderStatus.values) {
      if (s.key == key) return s;
    }
    return OrderStatus.unpaid;
  }
}

/// تبويبات شاشة «طلباتي» كما في المتطلبات (الكل + 5 حالات).
const List<OrderStatus?> kOrderTabs = [
  null,
  OrderStatus.unpaid,
  OrderStatus.verifying,
  OrderStatus.processing,
  OrderStatus.shipped,
  OrderStatus.delivered,
];

/// مراحل الخط الزمني المعروضة للعميل داخل تفاصيل الطلب.
class TimelineStage {
  final String labelAr;
  final List<OrderStatus> reachedBy;
  const TimelineStage(this.labelAr, this.reachedBy);
}

const List<TimelineStage> kTimelineStages = [
  TimelineStage('رفع الطلب', [OrderStatus.unpaid]),
  TimelineStage('السداد', [OrderStatus.verifying, OrderStatus.processing]),
  TimelineStage('التجهيز', [OrderStatus.processing]),
  TimelineStage('الشحن', [OrderStatus.shipped]),
  TimelineStage('التوصيل', [OrderStatus.outForDelivery]),
  TimelineStage('التسليم', [OrderStatus.delivered]),
];

class Address {
  final String id;
  final String label;
  final String city;
  final String district;
  final String line;
  final String phone;
  final String receiverName;
  final double? lat;
  final double? lng;

  const Address({
    required this.id,
    required this.city,
    required this.district,
    required this.line,
    required this.phone,
    required this.receiverName,
    this.label = 'المنزل',
    this.lat,
    this.lng,
  });

  String get shortAr => '$city — $district';
  String get fullAr => '$city، $district، $line';

  factory Address.fromMap(Map<String, dynamic> m) => Address(
        id: (m['id'] ?? '') as String,
        label: (m['label'] ?? 'المنزل') as String,
        city: (m['city'] ?? '') as String,
        district: (m['district'] ?? '') as String,
        line: (m['line'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        receiverName: (m['receiverName'] ?? '') as String,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'city': city,
        'district': district,
        'line': line,
        'phone': phone,
        'receiverName': receiverName,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

class OrderItem {
  /// معرّف شي إن الرقمي — بدونه لا يستطيع السيرفر تسعير السطر.
  final String goodsId;
  final String sku;
  final String title;
  final String imageUrl;
  final String size;
  final String color;
  final int qty;

  /// سعر الوحدة بالريال السعودي (عملة التسعير الأساسية).
  final double unitPriceSar;
  final String productUrl;

  const OrderItem({
    required this.sku,
    this.goodsId = '',
    required this.title,
    required this.imageUrl,
    required this.qty,
    required this.unitPriceSar,
    this.size = '',
    this.color = '',
    this.productUrl = '',
  });

  double get lineTotalSar => unitPriceSar * qty;

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        goodsId: (m['goodsId'] ?? '') as String,
        sku: (m['sku'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        imageUrl: (m['imageUrl'] ?? '') as String,
        size: (m['size'] ?? '') as String,
        color: (m['color'] ?? '') as String,
        qty: (m['qty'] as num?)?.toInt() ?? 1,
        unitPriceSar: (m['unitPriceSar'] as num?)?.toDouble() ?? 0,
        productUrl: (m['productUrl'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        'goodsId': goodsId,
        'sku': sku,
        'title': title,
        'imageUrl': imageUrl,
        'size': size,
        'color': color,
        'qty': qty,
        'unitPriceSar': unitPriceSar,
        'productUrl': productUrl,
      };
}

class TimelineEvent {
  final OrderStatus status;
  final DateTime at;
  final String byName;
  final String note;

  const TimelineEvent({
    required this.status,
    required this.at,
    this.byName = 'النظام',
    this.note = '',
  });

  factory TimelineEvent.fromMap(Map<String, dynamic> m) => TimelineEvent(
        status: OrderStatusX.fromKey(m['status'] as String?),
        at: _ts(m['at']) ?? DateTime.now(),
        byName: (m['byName'] ?? 'النظام') as String,
        note: (m['note'] ?? '') as String,
      );
}

class PaymentInfo {
  final String accountId;

  /// اسم المحفظة وقت الدفع — شلن وجيب يتشاركان رقماً واحداً،
  /// فالاسم هو ما يفرّق بينهما عند المراجعة.
  final String accountTitleAr;
  final String accountNumber;
  final double amount;
  final String senderName;
  final String refNo;
  final String note;
  final String proofUrl;
  final DateTime? submittedAt;
  final DateTime? confirmedAt;
  final String confirmedByName;

  const PaymentInfo({
    this.accountId = '',
    this.accountTitleAr = '',
    this.accountNumber = '',
    this.amount = 0,
    this.senderName = '',
    this.refNo = '',
    this.note = '',
    this.proofUrl = '',
    this.submittedAt,
    this.confirmedAt,
    this.confirmedByName = '',
  });

  bool get isEmpty => refNo.isEmpty && senderName.isEmpty && amount == 0;

  factory PaymentInfo.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const PaymentInfo();
    return PaymentInfo(
      accountId: (m['accountId'] ?? '') as String,
      accountTitleAr: (m['accountTitleAr'] ?? '') as String,
      accountNumber: (m['accountNumber'] ?? '') as String,
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      senderName: (m['senderName'] ?? '') as String,
      refNo: (m['refNo'] ?? '') as String,
      note: (m['note'] ?? '') as String,
      proofUrl: (m['proofUrl'] ?? '') as String,
      submittedAt: _ts(m['submittedAt']),
      confirmedAt: _ts(m['confirmedAt']),
      confirmedByName: (m['confirmedByName'] ?? '') as String,
    );
  }
}

class Order {
  final String id;
  final String orderNo;
  final String userId;
  final AppCurrency currency;
  final double exchangeRate;
  final List<OrderItem> items;
  final double subtotalSar;
  final double shippingFeeSar;
  final double deliveryFeeSar;

  /// عمولة المندوب — بند داخلي، ليست جزءاً من [totalSar].
  final double commissionSar;
  final double commissionLocal;
  final double commissionPerPieceSar;

  /// هل وافق المندوب على مشاركة عمولته مع الشركة؟
  final bool commissionApproved;
  final double discountSar;
  final double totalSar;

  /// الإجمالي بعملة العميل — محسوب على السيرفر وقت الطلب ومُجمّد.
  final double totalLocal;
  final String couponCode;
  final Address address;
  final OrderStatus status;
  final List<TimelineEvent> timeline;
  final PaymentInfo payment;
  final String trackingNo;
  final String courierName;
  final String proofImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expediteRequestedAt;

  // ═══ فكرة يمن: نسخة واحدة معتمدة + سجل تعديلات داخلي ═══
  /// رقم النسخة الحالية. يزيد مع كل تعديل قبل الاعتماد النهائي.
  final int revision;

  /// وقت اعتماد العميل لآخر نسخة. `null` يعني الطلب ما زال «قيد التعديل».
  final DateTime? approvedAt;

  /// يُغلق بعد أن يبدأ فريق يمن سيلو التنفيذ، فلا يُعدَّل الطلب بعدها.
  final bool editingLocked;

  final String approvedByName;

  const Order({
    required this.id,
    required this.orderNo,
    required this.userId,
    required this.currency,
    required this.exchangeRate,
    required this.items,
    required this.subtotalSar,
    required this.shippingFeeSar,
    required this.deliveryFeeSar,
    this.commissionSar = 0,
    this.commissionLocal = 0,
    this.commissionPerPieceSar = 0,
    this.commissionApproved = false,
    required this.discountSar,
    required this.totalSar,
    required this.totalLocal,
    required this.address,
    required this.status,
    required this.timeline,
    required this.createdAt,
    required this.updatedAt,
    this.couponCode = '',
    this.payment = const PaymentInfo(),
    this.trackingNo = '',
    this.courierName = '',
    this.proofImageUrl = '',
    this.expediteRequestedAt,
    this.revision = 1,
    this.approvedAt,
    this.editingLocked = false,
    this.approvedByName = '',
    this.deliveryMinDays = 15,
    this.deliveryMaxDays = 20,
    this.serviceFeeSar = 0,
  });

  final int deliveryMinDays;
  final int deliveryMaxDays;
  final double serviceFeeSar;

  int get totalPieces => items.fold(0, (s, i) => s + i.qty);
  List<String> get thumbnails => items.map((i) => i.imageUrl).where((e) => e.isNotEmpty).toList();

  /// مدة التوصيل المتوقعة — 15 إلى 20 يوماً افتراضياً،
  /// وتُقرأ من الطلب نفسه إذا خزّنها السيرفر (قابلة للتعديل من اللوحة).
  String get expectedDeliveryAr {
    final int minDays = deliveryMinDays > 0 ? deliveryMinDays : 15;
    final int maxDays = deliveryMaxDays >= minDays ? deliveryMaxDays : minDays;
    final from = createdAt.add(Duration(days: minDays));
    final to = createdAt.add(Duration(days: maxDays));
    String d(DateTime x) => '${x.day}/${x.month}';
    return 'من $minDays إلى $maxDays يوماً (${d(from)} – ${d(to)})';
  }

  bool stageReached(TimelineStage stage) {
    if (status == OrderStatus.cancelled) {
      return timeline.any((e) => stage.reachedBy.contains(e.status));
    }
    final idx = kTimelineStages.indexOf(stage);
    final currentIdx = status == OrderStatus.unpaid ? 0 : _statusStageIndex();
    return currentIdx >= idx;
  }

  int _statusStageIndex() => switch (status) {
        OrderStatus.unpaid => 0,
        OrderStatus.verifying => 1,
        OrderStatus.processing => 2,
        OrderStatus.shipped => 3,
        OrderStatus.outForDelivery => 4,
        OrderStatus.delivered => 5,
        OrderStatus.cancelled => 0,
      };

  /// 🟡 قيد التعديل · 🟢 تم اعتماد الطلب · 🔒 تم إغلاق التعديل
  String get editStateAr {
    if (editingLocked) return 'تم إغلاق التعديل';
    if (approvedAt == null) return 'قيد التعديل';
    return 'تم اعتماد الطلب';
  }

  /// لا يُعدَّل إلا قبل الإغلاق وقبل أن يتقدّم التنفيذ.
  bool get isEditable =>
      !editingLocked &&
      (status == OrderStatus.unpaid || status == OrderStatus.verifying);

  /// عميل عدّل بعد اعتماد سابق ولم يعتمد آخر تعديل بعد.
  bool get needsApproval => isEditable && approvedAt == null;

  factory Order.fromDoc(String id, Map<String, dynamic> m) {
    final items = ((m['items'] as List?) ?? const [])
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final tl = ((m['timeline'] as List?) ?? const [])
        .map((e) => TimelineEvent.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Order(
      id: id,
      orderNo: (m['orderNo'] ?? id) as String,
      userId: (m['userId'] ?? '') as String,
      currency: AppCurrencyX.fromKey(m['currency'] as String?),
      exchangeRate: (m['exchangeRate'] as num?)?.toDouble() ?? 1,
      items: items,
      deliveryMinDays: (m['deliveryMinDays'] as num?)?.toInt() ?? 15,
      deliveryMaxDays: (m['deliveryMaxDays'] as num?)?.toInt() ?? 20,
      subtotalSar: (m['subtotalSar'] as num?)?.toDouble() ?? 0,
      shippingFeeSar: (m['shippingFeeSar'] as num?)?.toDouble() ?? 0,
      serviceFeeSar: (m['serviceFeeSar'] as num?)?.toDouble() ?? 0,
      deliveryFeeSar: (m['deliveryFeeSar'] as num?)?.toDouble() ?? 0,
      commissionSar: ((m['commission'] as Map?)?['totalSar'] as num?)?.toDouble() ?? 0,
      commissionLocal: ((m['commission'] as Map?)?['totalLocal'] as num?)?.toDouble() ?? 0,
      commissionPerPieceSar:
          ((m['commission'] as Map?)?['perPieceSar'] as num?)?.toDouble() ?? 0,
      commissionApproved: ((m['commission'] as Map?)?['approved'] as bool?) ?? false,
      discountSar: (m['discountSar'] as num?)?.toDouble() ?? 0,
      totalSar: (m['totalSar'] as num?)?.toDouble() ?? 0,
      totalLocal: (m['totalLocal'] as num?)?.toDouble() ?? 0,
      couponCode: (m['couponCode'] ?? '') as String,
      address: Address.fromMap(Map<String, dynamic>.from((m['address'] as Map?) ?? {})),
      status: OrderStatusX.fromKey(m['status'] as String?),
      timeline: tl,
      payment: PaymentInfo.fromMap(m['payment'] == null ? null : Map<String, dynamic>.from(m['payment'] as Map)),
      trackingNo: (m['trackingNo'] ?? '') as String,
      courierName: (m['courierName'] ?? '') as String,
      proofImageUrl: (m['proofImageUrl'] ?? '') as String,
      createdAt: _ts(m['createdAt']) ?? DateTime.now(),
      updatedAt: _ts(m['updatedAt']) ?? DateTime.now(),
      expediteRequestedAt: _ts(m['expediteRequestedAt']),
      revision: (m['revision'] as num?)?.toInt() ?? 1,
      approvedAt: _ts(m['approvedAt']),
      editingLocked: (m['editingLocked'] as bool?) ?? false,
      approvedByName: (m['approvedByName'] ?? '') as String,
    );
  }
}

DateTime? _ts(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    return (v as dynamic).toDate() as DateTime; // Timestamp
  } catch (_) {
    return null;
  }
}

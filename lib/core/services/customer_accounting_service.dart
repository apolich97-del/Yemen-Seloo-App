import '../models/order.dart';
import '../models/receipt.dart';
import '../models/refund.dart';

/// تطبيع رقم الهاتف للمطابقة (آخر 9 أرقام) لربط حسابات العملاء والطلبات بدقة.
String normalizePhoneLast9(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 9) return digits;
  return digits.substring(digits.length - 9);
}

bool isSamePhone(String? a, String? b) {
  final na = normalizePhoneLast9(a);
  final nb = normalizePhoneLast9(b);
  return na.length >= 7 && nb.length >= 7 && na == nb;
}

bool doesOrderBelongToCustomer(
  Order order, {
  String? uid,
  String? phone,
}) {
  if (uid != null && uid.isNotEmpty && order.userId == uid) return true;
  if (phone != null && phone.isNotEmpty) {
    if (isSamePhone(order.address.phone, phone) ||
        isSamePhone(order.receiverPhone, phone)) {
      return true;
    }
  }
  return false;
}

/// فئة العميل والحد الائتماني الآجل.
enum CustomerTier { normal, vip, blockedDeferred }

extension CustomerTierX on CustomerTier {
  String get key => switch (this) {
        CustomerTier.normal => 'normal',
        CustomerTier.vip => 'vip',
        CustomerTier.blockedDeferred => 'blocked_deferred',
      };

  String get labelAr => switch (this) {
        CustomerTier.normal => 'عادي',
        CustomerTier.vip => 'VIP مميز',
        CustomerTier.blockedDeferred => 'موقوف عن الآجل',
      };

  double get defaultCreditLimitSar => switch (this) {
        CustomerTier.normal => 1500.0,
        CustomerTier.vip => 5000.0,
        CustomerTier.blockedDeferred => 0.0,
      };

  static CustomerTier fromKey(String? raw) => switch (raw) {
        'vip' => CustomerTier.vip,
        'blocked_deferred' => CustomerTier.blockedDeferred,
        _ => CustomerTier.normal,
      };
}

enum AccountingEntryType {
  orderDebit,
  receiptCredit,
  orderCancelCredit,
  refundCreditNote,
  refundPayoutDebit,
}

class AccountingLedgerEntry {
  final int seq;
  final DateTime date;
  final AccountingEntryType entryType;
  final String entryTypeLabel;
  final String docNo;
  final String orderNo;
  final String description;
  final double debitSar;
  final double creditSar;
  final double runningBalanceSar;
  final String proofUrl;

  const AccountingLedgerEntry({
    required this.seq,
    required this.date,
    required this.entryType,
    required this.entryTypeLabel,
    required this.docNo,
    required this.orderNo,
    required this.description,
    required this.debitSar,
    required this.creditSar,
    required this.runningBalanceSar,
    this.proofUrl = '',
  });
}

class StatementTransferPhoto {
  final String id;
  final String title;
  final String subtitle;
  final String refNo;
  final double amountSar;
  final String statusAr;
  final String url;
  final DateTime date;
  final bool isRefund;

  const StatementTransferPhoto({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.refNo,
    required this.amountSar,
    required this.statusAr,
    required this.url,
    required this.date,
    this.isRefund = false,
  });
}

class StatementRefundItem {
  final String id;
  final String orderId;
  final String orderNo;
  final String refundRefNo;
  final String reasonAr;
  final String methodAr;
  final String settlementMethod;
  final String status;
  final String statusAr;
  final double amountSar;
  final double amountLocal;
  final String currencyKey;
  final String transferRefNo;
  final String transferProofUrl;
  final DateTime date;

  const StatementRefundItem({
    required this.id,
    required this.orderId,
    required this.orderNo,
    required this.refundRefNo,
    required this.reasonAr,
    required this.methodAr,
    required this.settlementMethod,
    required this.status,
    required this.statusAr,
    required this.amountSar,
    required this.amountLocal,
    required this.currencyKey,
    required this.transferRefNo,
    required this.transferProofUrl,
    required this.date,
  });
}

class AccountingStatementReport {
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double openingBalanceSar;
  final double periodDebitSar;
  final double periodCreditSar;
  final double closingBalanceSar;
  final double totalOrdersSar;
  final double totalPaidSar;
  final double totalRefundedSar;
  final double remainingDebtSar;
  final int deferredOrdersCount;
  final List<AccountingLedgerEntry> entries;
  final List<StatementRefundItem> refunds;
  final List<StatementTransferPhoto> transferPhotos;
  final List<Order> includedOrders;

  const AccountingStatementReport({
    this.periodStart,
    this.periodEnd,
    required this.openingBalanceSar,
    required this.periodDebitSar,
    required this.periodCreditSar,
    required this.closingBalanceSar,
    required this.totalOrdersSar,
    required this.totalPaidSar,
    required this.totalRefundedSar,
    required this.remainingDebtSar,
    required this.deferredOrdersCount,
    required this.entries,
    required this.refunds,
    required this.transferPhotos,
    required this.includedOrders,
  });
}

class _RawLedger {
  final DateTime date;
  final AccountingEntryType entryType;
  final String entryTypeLabel;
  final String docNo;
  final String orderNo;
  final String description;
  final double debitSar;
  final double creditSar;
  final String proofUrl;

  const _RawLedger({
    required this.date,
    required this.entryType,
    required this.entryTypeLabel,
    required this.docNo,
    required this.orderNo,
    required this.description,
    required this.debitSar,
    required this.creditSar,
    this.proofUrl = '',
  });
}

/// محرك توليد كشف الحساب المحاسبي (قيد مزدوج + استردادات + أرشيف صور الحوالات + تصفية المدة).
class AccountingStatementEngine {
  static AccountingStatementReport build({
    required List<Order> orders,
    required List<Receipt> receipts,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final DateTime? startBound = fromDate == null
        ? null
        : DateTime(fromDate.year, fromDate.month, fromDate.day, 0, 0, 0);
    final DateTime? endBound = toDate == null
        ? null
        : DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999);

    bool inWindow(DateTime d) {
      if (startBound != null && d.isBefore(startBound)) return false;
      if (endBound != null && d.isAfter(endBound)) return false;
      return true;
    }

    final Map<String, Order> orderById = {
      for (final o in orders) o.id: o,
    };
    final Map<String, List<Receipt>> receiptsByOrder = {};
    for (final r in receipts) {
      receiptsByOrder.putIfAbsent(r.orderId, () => []).add(r);
    }

    final List<_RawLedger> rawEntries = [];
    final List<StatementTransferPhoto> transferPhotos = [];
    final List<StatementRefundItem> refundItems = [];
    final Set<String> seenPhotoKeys = {};

    double _toSar(double local, Order o) {
      if (o.exchangeRate <= 0) return local;
      return local / o.exchangeRate;
    }

    for (final o in orders) {
      // 1) قيد فاتورة الطلب (مدين)
      rawEntries.add(_RawLedger(
        date: o.createdAt,
        entryType: AccountingEntryType.orderDebit,
        entryTypeLabel: 'فاتورة مبيعات',
        docNo: o.orderNo,
        orderNo: o.orderNo,
        description:
            'طلب ${o.orderNo} (${o.isDeferred ? 'آجل 50%' : 'دفع كامل'}) · ${o.totalPieces} قطعة',
        debitSar: o.totalSar,
        creditSar: 0,
      ));

      // 2) قيد إلغاء الطلب (عكس دائن)
      if (o.status == OrderStatus.cancelled) {
        rawEntries.add(_RawLedger(
          date: o.updatedAt,
          entryType: AccountingEntryType.orderCancelCredit,
          entryTypeLabel: 'إلغاء فاتورة',
          docNo: 'CN-${o.orderNo}',
          orderNo: o.orderNo,
          description: 'إلغاء وعكس قيمة الطلب ${o.orderNo}',
          debitSar: 0,
          creditSar: o.totalSar,
        ));
      }

      // 3) إيصالات السداد المرتبطة بالطلب
      final orderReceipts = receiptsByOrder[o.id] ?? const <Receipt>[];
      int approvedCount = 0;

      for (final r in orderReceipts) {
        final rDate = r.reviewedAt ?? r.createdAt ?? o.createdAt;
        final amtSar =
            r.amountSar > 0 ? r.amountSar : _toSar(r.amountLocal, o);

        if (r.isApproved && amtSar > 0) {
          approvedCount++;
          rawEntries.add(_RawLedger(
            date: rDate,
            entryType: AccountingEntryType.receiptCredit,
            entryTypeLabel: 'سند قبض',
            docNo: r.receiptNo.isNotEmpty ? r.receiptNo : r.id,
            orderNo: o.orderNo,
            description:
                'سداد معتمد${r.refNo.isEmpty ? '' : ' (مرجع: ${r.refNo})'}${r.senderName.isEmpty ? '' : ' — ${r.senderName}'}',
            debitSar: 0,
            creditSar: amtSar,
            proofUrl: r.proofUrl,
          ));
        }

        if (r.proofUrl.isNotEmpty && inWindow(rDate)) {
          final key = '${r.refNo}|${r.proofUrl.hashCode}';
          if (seenPhotoKeys.add(key)) {
            transferPhotos.add(StatementTransferPhoto(
              id: r.id,
              title: r.receiptNo.isNotEmpty ? 'إيصال ${r.receiptNo}' : 'حوالة طلب ${o.orderNo}',
              subtitle: r.senderName.isEmpty ? o.orderNo : '${o.orderNo} · ${r.senderName}',
              refNo: r.refNo,
              amountSar: amtSar,
              statusAr: r.statusAr,
              url: r.proofUrl,
              date: rDate,
            ));
          }
        }
      }

      // 4) الدفعة الأولى على مستند الطلب (في حال عدم وجود إيصال معتمد مسجّل أو لإضافة صورة الحوالة الأولى)
      final p = o.payment;
      final paidSar = o.paidTotalSar;
      if (approvedCount == 0 && paidSar > 0 && o.status != OrderStatus.unpaid && o.status != OrderStatus.cancelled) {
        final pDate = p.submittedAt ?? o.createdAt;
        if (o.status != OrderStatus.verifying) {
          rawEntries.add(_RawLedger(
            date: pDate,
            entryType: AccountingEntryType.receiptCredit,
            entryTypeLabel: 'سند قبض',
            docNo: p.refNo.isNotEmpty ? 'PAY-${p.refNo}' : 'PAY-${o.orderNo}',
            orderNo: o.orderNo,
            description:
                'دفعة طلب ${o.orderNo}${p.accountTitleAr.isEmpty ? '' : ' عبر ${p.accountTitleAr}'}${p.refNo.isEmpty ? '' : ' (${p.refNo})'}',
            debitSar: 0,
            creditSar: paidSar,
            proofUrl: p.proofUrl,
          ));
        }
      }
      if (p.proofUrl.isNotEmpty) {
        final pDate = p.submittedAt ?? o.createdAt;
        if (inWindow(pDate)) {
          final key = '${p.refNo}|${p.proofUrl.hashCode}';
          if (seenPhotoKeys.add(key)) {
            final amtSar = p.amount > 0 ? _toSar(p.amount, o) : paidSar;
            transferPhotos.add(StatementTransferPhoto(
              id: 'pay-${o.id}',
              title: 'حوالة طلب ${o.orderNo}',
              subtitle: p.senderName.isEmpty
                  ? p.accountTitleAr
                  : '${p.accountTitleAr} · ${p.senderName}',
              refNo: p.refNo,
              amountSar: amtSar,
              statusAr: o.status == OrderStatus.verifying ? 'قيد التحقق' : 'مرفقة',
              url: p.proofUrl,
              date: pDate,
            ));
          }
        }
      }

      // 5) عمليات الاسترداد (مكتملة تدخل في القيد المحاسبي + كل الحالات في جدول الاستردادات)
      for (final RefundRecord ref in o.refunds) {
        final refDate = ref.completedAt ?? ref.createdAt ?? o.updatedAt;
        if (inWindow(refDate)) {
          refundItems.add(StatementRefundItem(
            id: ref.id,
            orderId: o.id,
            orderNo: o.orderNo,
            refundRefNo: ref.refundRefNo,
            reasonAr: ref.reasonAr,
            methodAr: ref.methodAr,
            settlementMethod: ref.settlementMethod,
            status: ref.status,
            statusAr: ref.statusAr,
            amountSar: ref.amountSar,
            amountLocal: ref.amountLocal,
            currencyKey: ref.currency,
            transferRefNo: ref.transferRefNo,
            transferProofUrl: ref.transferProofUrl,
            date: refDate,
          ));

          if (ref.transferProofUrl.isNotEmpty) {
            final key = 'ref|${ref.transferRefNo}|${ref.transferProofUrl.hashCode}';
            if (seenPhotoKeys.add(key)) {
              transferPhotos.add(StatementTransferPhoto(
                id: 'ref-${ref.id}',
                title: 'إثبات استرداد ${ref.refundRefNo}',
                subtitle: '${o.orderNo} · ${ref.bankOrWalletName}',
                refNo: ref.transferRefNo,
                amountSar: ref.amountSar,
                statusAr: ref.statusAr,
                url: ref.transferProofUrl,
                date: refDate,
                isRefund: true,
              ));
            }
          }
        }

        if (ref.isCompleted && ref.amountSar > 0) {
          rawEntries.add(_RawLedger(
            date: refDate,
            entryType: AccountingEntryType.refundCreditNote,
            entryTypeLabel: 'إشعار دائن استرداد',
            docNo: ref.refundRefNo.isNotEmpty ? ref.refundRefNo : 'RF-${o.orderNo}',
            orderNo: o.orderNo,
            description:
                'إشعار استرداد (${ref.reasonAr}) — ${ref.methodAr}',
            debitSar: 0,
            creditSar: ref.amountSar,
            proofUrl: ref.transferProofUrl,
          ));

          if (ref.settlementMethod == 'bank_transfer') {
            rawEntries.add(_RawLedger(
              date: refDate.add(const Duration(seconds: 1)),
              entryType: AccountingEntryType.refundPayoutDebit,
              entryTypeLabel: 'صرف استرداد بنكي',
              docNo: ref.transferRefNo.isNotEmpty
                  ? ref.transferRefNo
                  : 'OUT-${ref.refundRefNo}',
              orderNo: o.orderNo,
              description:
                  'تحويل مبلغ مسترد لحساب العميل${ref.bankOrWalletName.isEmpty ? '' : ' (${ref.bankOrWalletName})'}',
              debitSar: ref.amountSar,
              creditSar: 0,
              proofUrl: ref.transferProofUrl,
            ));
          }
        }
      }
    }

    // إيصالات عامة لو وجدت بدون طلب مطابق في القائمة
    for (final r in receipts) {
      if (orderById.containsKey(r.orderId)) continue;
      final rDate = r.reviewedAt ?? r.createdAt ?? DateTime.now();
      if (r.isApproved && r.amountSar > 0) {
        rawEntries.add(_RawLedger(
          date: rDate,
          entryType: AccountingEntryType.receiptCredit,
          entryTypeLabel: 'سند قبض',
          docNo: r.receiptNo.isNotEmpty ? r.receiptNo : r.id,
          orderNo: r.orderNo,
          description: 'سداد معتمد — طلب ${r.orderNo}',
          debitSar: 0,
          creditSar: r.amountSar,
          proofUrl: r.proofUrl,
        ));
      }
      if (r.proofUrl.isNotEmpty && inWindow(rDate)) {
        final key = '${r.refNo}|${r.proofUrl.hashCode}';
        if (seenPhotoKeys.add(key)) {
          transferPhotos.add(StatementTransferPhoto(
            id: r.id,
            title: r.receiptNo.isNotEmpty ? 'إيصال ${r.receiptNo}' : 'حوالة ${r.orderNo}',
            subtitle: r.senderName,
            refNo: r.refNo,
            amountSar: r.amountSar,
            statusAr: r.statusAr,
            url: r.proofUrl,
            date: rDate,
          ));
        }
      }
    }

    rawEntries.sort((a, b) => a.date.compareTo(b.date));

    double openingBalanceSar = 0;
    double periodDebitSar = 0;
    double periodCreditSar = 0;
    final List<AccountingLedgerEntry> periodEntries = [];
    int seq = 0;

    for (final e in rawEntries) {
      if (startBound != null && e.date.isBefore(startBound)) {
        openingBalanceSar += (e.debitSar - e.creditSar);
        continue;
      }
      if (endBound != null && e.date.isAfter(endBound)) {
        continue;
      }
      seq++;
      periodDebitSar += e.debitSar;
      periodCreditSar += e.creditSar;
      final double running =
          (periodEntries.isEmpty ? openingBalanceSar : periodEntries.last.runningBalanceSar) +
              e.debitSar -
              e.creditSar;

      periodEntries.add(AccountingLedgerEntry(
        seq: seq,
        date: e.date,
        entryType: e.entryType,
        entryTypeLabel: e.entryTypeLabel,
        docNo: e.docNo,
        orderNo: e.orderNo,
        description: e.description,
        debitSar: e.debitSar,
        creditSar: e.creditSar,
        runningBalanceSar: running,
        proofUrl: e.proofUrl,
      ));
    }

    final double closingBalanceSar = periodEntries.isEmpty
        ? openingBalanceSar
        : periodEntries.last.runningBalanceSar;

    final includedOrders = orders.where((o) => inWindow(o.createdAt)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final double totalOrdersSar = includedOrders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold<double>(0, (s, o) => s + o.totalSar);
    final double totalPaidSar = includedOrders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold<double>(0, (s, o) => s + o.paidTotalSar);
    final double totalRefundedSar = refundItems
        .where((r) => r.status == 'completed')
        .fold<double>(0, (s, r) => s + r.amountSar);
    final int deferredCount = includedOrders
        .where((o) => o.isDeferred && o.hasRemaining && o.status != OrderStatus.cancelled)
        .length;

    transferPhotos.sort((a, b) => b.date.compareTo(a.date));
    refundItems.sort((a, b) => b.date.compareTo(a.date));

    return AccountingStatementReport(
      periodStart: startBound,
      periodEnd: endBound,
      openingBalanceSar: openingBalanceSar,
      periodDebitSar: periodDebitSar,
      periodCreditSar: periodCreditSar,
      closingBalanceSar: closingBalanceSar,
      totalOrdersSar: totalOrdersSar,
      totalPaidSar: totalPaidSar,
      totalRefundedSar: totalRefundedSar,
      remainingDebtSar: closingBalanceSar > 0 ? closingBalanceSar : 0,
      deferredOrdersCount: deferredCount,
      entries: periodEntries,
      refunds: refundItems,
      transferPhotos: transferPhotos,
      includedOrders: includedOrders,
    );
  }
}

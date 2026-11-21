import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/currency.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/wallet_service.dart';
import '../../core/theme/app_theme.dart';

/// «محفظتي»: الرصيد والحركات وطلب السحب النقدي.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.put(WalletService(), permanent: false);
    final rate = Get.isRegistered<SettingsService>()
        ? Get.find<SettingsService>().settings.value.rateSouth
        : 0.0;
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(title: const Text('محفظتي')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: svc.watch(),
        builder: (context, snap) {
          final data = snap.data;
          final balance =
              ((data?['balanceSar'] as num?) ?? 0).toDouble();
          final moves = svc.movementsOf(data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [T.primary, T.primary.withOpacity(.75)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رصيد المحفظة',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('${balance.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                        rate > 0
                            ? '≈ ${formatMoney(balance * rate, AppCurrency.south)}'
                            : 'يُعادل بعملة حسابك عند السحب',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _withdrawSheet(context, svc, balance),
                      icon: const Icon(Icons.account_balance_outlined, size: 17),
                      label: const Text('طلب سحب نقدي',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('سجل الحركات',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900, color: T.text)),
              const SizedBox(height: 8),
              if (moves.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('لا توجد حركات بعد',
                        style: TextStyle(fontSize: 12, color: T.muted)),
                  ),
                )
              else
                ...moves.map((m) {
                  final credit = m.type == 'credit';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: T.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: T.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            credit
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                            size: 18,
                            color: credit ? T.success : T.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.note,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: T.text)),
                              if (m.at != null)
                                Text(
                                    '${m.at!.day}/${m.at!.month}/${m.at!.year}',
                                    style: TextStyle(
                                        fontSize: 10, color: T.muted)),
                            ],
                          ),
                        ),
                        Text(
                            '${credit ? '+' : '-'}${m.amountSar.toStringAsFixed(2)} ر.س',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: credit ? T.success : T.danger)),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  void _withdrawSheet(
      BuildContext context, WalletService svc, double balance) {
    final amount = TextEditingController();
    final accountName = TextEditingController();
    final accountNumber = TextEditingController();
    final holder = TextEditingController();
    var method = 'bank';
    Get.bottomSheet(
      StatefulBuilder(builder: (context, setLocal) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: T.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('طلب سحب نقدي',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: T.text)),
                const SizedBox(height: 4),
                Text('الرصيد المتاح: ${balance.toStringAsFixed(2)} ر.س',
                    style: TextStyle(fontSize: 11, color: T.muted)),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ بالريال السعودي'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('حوالة بنكية',
                          style: TextStyle(fontSize: 11)),
                      selected: method == 'bank',
                      onSelected: (_) => setLocal(() => method = 'bank'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('محفظة إلكترونية',
                          style: TextStyle(fontSize: 11)),
                      selected: method == 'wallet',
                      onSelected: (_) => setLocal(() => method = 'wallet'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: accountName,
                  decoration: InputDecoration(
                      labelText: method == 'bank'
                          ? 'اسم البنك'
                          : 'اسم المحفظة (جوالي، كاش…)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: accountNumber,
                  decoration: const InputDecoration(labelText: 'رقم الحساب / المحفظة'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: holder,
                  decoration: const InputDecoration(labelText: 'اسم المستلم'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final v = double.tryParse(amount.text.trim()) ?? 0;
                      if (v <= 0 || v > balance) {
                        Get.snackbar('تحقق', 'أدخل مبلغاً صحيحاً ضمن رصيدك');
                        return;
                      }
                      final rate = Get.isRegistered<SettingsService>()
                          ? Get.find<SettingsService>().settings.value.rateSouth
                          : 0.0;
                      await svc.requestWithdrawal(
                        amountSar: v,
                        amountLocal: v * rate,
                        method: method,
                        accountName: accountName.text.trim(),
                        accountNumber: accountNumber.text.trim(),
                        holderName: holder.text.trim(),
                      );
                      Get.back();
                      Get.snackbar('تم', 'أُرسل طلب السحب للمحاسبة');
                    },
                    child: const Text('إرسال الطلب'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      }),
      isScrollControlled: true,
    );
  }
}

import React, { useMemo, useState } from 'react';
import { MessageCircle, Printer } from 'lucide-react';
import { useSeloo } from '../context/SelooContext';
import { convertSarToCurrency, formatMoney } from '../services/pricingService';
import {
  printAccountStatementPdf,
  StatementPrintRow,
} from '../services/receiptPdfService';
import { AppCurrency } from '../types/seloo';

const CURRENCY_BUTTONS: { key: AppCurrency; label: string }[] = [
  { key: 'south', label: 'يمني جنوب' },
  { key: 'north', label: 'يمني شمال' },
  { key: 'sar', label: 'سعودي' },
  { key: 'usd', label: 'دولار' },
];

export const AccountStatementView: React.FC = () => {
  const { user, orders, wallet, settings, currency, notifyToast } = useSeloo();
  const [stmtCurrency, setStmtCurrency] = useState<AppCurrency>(currency);

  const statement = useMemo(() => {
    interface RawEvent {
      at: number;
      description: string;
      debitSar: number;
      creditSar: number;
    }
    const events: RawEvent[] = [];

    for (const ord of orders) {
      events.push({
        at: ord.createdAt,
        description: `طلب ${ord.orderNo} (${ord.items.length} قطعة)`,
        debitSar: ord.totalSar,
        creditSar: 0,
      });
      if (ord.paidTotalLocal > 0 && ord.exchangeRate > 0) {
        events.push({
          at: ord.payment?.confirmedAt || ord.updatedAt || ord.createdAt,
          description: `دفعة / حوالة معتمدة — ${ord.orderNo}`,
          debitSar: 0,
          creditSar: ord.paidTotalLocal / ord.exchangeRate,
        });
      }
      if (ord.refundedTotalSar > 0) {
        events.push({
          at: ord.updatedAt || ord.createdAt,
          description: `استرداد مالي — ${ord.orderNo}`,
          debitSar: 0,
          creditSar: ord.refundedTotalSar,
        });
      }
    }

    for (const mv of wallet.movements) {
      events.push({
        at: mv.at,
        description: `محفظة: ${mv.note}`,
        debitSar: mv.type === 'debit' ? mv.amountSar : 0,
        creditSar: mv.type === 'credit' ? mv.amountSar : 0,
      });
    }

    events.sort((a, b) => a.at - b.at);

    let runningSar = 0;
    let totalDebitSar = 0;
    let totalCreditSar = 0;

    const rows: StatementPrintRow[] = events.map((ev) => {
      totalDebitSar += ev.debitSar;
      totalCreditSar += ev.creditSar;
      runningSar += ev.debitSar - ev.creditSar;
      return {
        dateLabel: new Date(ev.at).toLocaleDateString('ar-YE'),
        description: ev.description,
        debitLocal: ev.debitSar > 0 ? convertSarToCurrency(ev.debitSar, stmtCurrency, settings) : 0,
        creditLocal: ev.creditSar > 0 ? convertSarToCurrency(ev.creditSar, stmtCurrency, settings) : 0,
        balanceLocal: convertSarToCurrency(Math.abs(runningSar), stmtCurrency, settings) * (runningSar < 0 ? -1 : 1),
      };
    });

    const totalDebitLocal = convertSarToCurrency(totalDebitSar, stmtCurrency, settings);
    const totalCreditLocal = convertSarToCurrency(totalCreditSar, stmtCurrency, settings);
    const netSar = totalDebitSar - totalCreditSar;
    const netBalanceLocal =
      convertSarToCurrency(Math.abs(netSar), stmtCurrency, settings) * (netSar < 0 ? -1 : 1);

    return {
      rows: rows.slice().reverse(),
      totalDebitLocal,
      totalCreditLocal,
      netBalanceLocal,
      netSar,
    };
  }, [orders, wallet.movements, stmtCurrency, settings]);

  const handlePrint = () => {
    printAccountStatementPdf({
      customerName: user?.displayName || 'عميل يمن سيلو',
      customerEmail: user?.email || '',
      currency: stmtCurrency,
      totalDebitLocal: statement.totalDebitLocal,
      totalCreditLocal: statement.totalCreditLocal,
      netBalanceLocal: statement.netBalanceLocal,
      rows: statement.rows,
      companyNameAr: settings.companyNameAr,
    });
  };

  const handleWhatsAppShare = async () => {
    const label = CURRENCY_BUTTONS.find((c) => c.key === stmtCurrency)?.label || '';
    const msg = [
      `📊 *كشف حساب العميل — ${settings.companyNameAr || 'يمن سيلو'}*`,
      `الاسم: ${user?.displayName || 'عميل يمن سيلو'}`,
      `العملة المختارة: ${label}`,
      `───────────────`,
      `عليه (المطلوب): *${formatMoney(statement.totalDebitLocal, stmtCurrency)}*`,
      `له (المدفوع والمسترد): *${formatMoney(statement.totalCreditLocal, stmtCurrency)}*`,
      `الصافي: *${formatMoney(statement.netBalanceLocal, stmtCurrency)}*`,
    ].join('\n');
    try {
      await navigator.clipboard.writeText(msg);
      notifyToast('تم نسخ ملخص كشف الحساب وفتح واتساب', 'success');
    } catch {
      // ignore
    }
    const target = settings.supportWhatsApp || '967770518757';
    const a = document.createElement('a');
    a.href = `https://wa.me/${target}?text=${encodeURIComponent(msg)}`;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.click();
  };

  return (
    <div className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="font-extrabold text-base">كشف الحساب المبسط (عليه / له / الصافي)</h2>
          <p className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
            تحويل فوري لجميع الأرصدة والحركات بالعملة التي تختارها.
          </p>
        </div>

        {/* 4-Currency Toggle Buttons */}
        <div className="flex flex-wrap gap-1.5">
          {CURRENCY_BUTTONS.map((btn) => {
            const active = stmtCurrency === btn.key;
            return (
              <button
                key={btn.key}
                type="button"
                onClick={() => setStmtCurrency(btn.key)}
                className={`px-3 py-1.5 rounded-xl text-xs font-bold border transition-colors ${
                  active
                    ? 'bg-violet-600 text-white border-violet-600'
                    : 'border-black/10 dark:border-white/10 hover:border-violet-500/50'
                }`}
              >
                {btn.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* Simplified 3-Box Summary */}
      <div className="grid sm:grid-cols-3 gap-3">
        <div className="p-4 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/5 dark:border-white/5">
          <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">عليه (المطلوب)</div>
          <div className="font-mono-num font-extrabold text-lg text-rose-600 dark:text-rose-400 mt-1">
            {formatMoney(statement.totalDebitLocal, stmtCurrency)}
          </div>
        </div>
        <div className="p-4 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/5 dark:border-white/5">
          <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">له (المدفوع والمسترد)</div>
          <div className="font-mono-num font-extrabold text-lg text-emerald-600 dark:text-emerald-400 mt-1">
            {formatMoney(statement.totalCreditLocal, stmtCurrency)}
          </div>
        </div>
        <div className="p-4 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-violet-500/30">
          <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
            الصافي ({statement.netSar > 0 ? 'مستحق للدفع' : statement.netSar < 0 ? 'رصيد لك' : 'متوازن'})
          </div>
          <div className="font-mono-num font-extrabold text-lg text-violet-700 dark:text-violet-300 mt-1">
            {formatMoney(Math.abs(statement.netBalanceLocal), stmtCurrency)}
          </div>
        </div>
      </div>

      {/* Export Actions */}
      <div className="flex flex-wrap gap-2.5">
        <button
          type="button"
          onClick={handlePrint}
          className="px-4 py-2 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold flex items-center gap-1.5 hover:bg-black/5 dark:hover:bg-white/5"
        >
          <Printer className="w-4 h-4 text-violet-600 dark:text-violet-400" />
          <span>تصدير / طباعة PDF</span>
        </button>
        <button
          type="button"
          onClick={handleWhatsAppShare}
          className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold flex items-center gap-1.5"
        >
          <MessageCircle className="w-4 h-4" />
          <span>إرسال الكشف عبر واتساب</span>
        </button>
      </div>

      {/* Detailed Movements Table */}
      {statement.rows.length === 0 ? (
        <div className="py-10 text-center text-xs text-[#5F5870] dark:text-[#A9A1BA]">
          لا توجد حركات مالية مسجلة على حسابك حتى الآن.
        </div>
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-black/10 dark:border-white/10">
          <table className="w-full text-xs text-right">
            <thead className="bg-[#F3EFE9] dark:bg-[#1E1830] text-[#5F5870] dark:text-[#A9A1BA]">
              <tr>
                <th className="p-3 font-bold">التاريخ</th>
                <th className="p-3 font-bold">البيان</th>
                <th className="p-3 font-bold text-left">عليه (المطلوب)</th>
                <th className="p-3 font-bold text-left">له (المدفوع)</th>
                <th className="p-3 font-bold text-left">الصافي</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-black/10 dark:divide-white/10">
              {statement.rows.map((r, i) => (
                <tr key={i} className="hover:bg-black/[0.02] dark:hover:bg-white/[0.02]">
                  <td className="p-3 font-mono-num whitespace-nowrap">{r.dateLabel}</td>
                  <td className="p-3 font-semibold">{r.description}</td>
                  <td className="p-3 font-mono-num text-left text-rose-600 dark:text-rose-400">
                    {r.debitLocal > 0 ? formatMoney(r.debitLocal, stmtCurrency) : '—'}
                  </td>
                  <td className="p-3 font-mono-num text-left text-emerald-600 dark:text-emerald-400">
                    {r.creditLocal > 0 ? formatMoney(r.creditLocal, stmtCurrency) : '—'}
                  </td>
                  <td className="p-3 font-mono-num font-bold text-left">
                    {formatMoney(r.balanceLocal, stmtCurrency)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

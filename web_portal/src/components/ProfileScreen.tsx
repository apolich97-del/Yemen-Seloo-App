import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  AlertCircle,
  BarChart3,
  Calculator,
  Check,
  ExternalLink,
  Eye,
  Globe,
  Headphones,
  LogOut,
  MapPin,
  Moon,
  Percent,
  Plus,
  Printer,
  RefreshCw,
  Shield,
  Sun,
  Tag,
  Trash2,
  Truck,
  UserCheck,
  Users,
  Wallet,
  X,
  ZoomIn,
} from 'lucide-react';
import { compressImageToDataUrl } from '../config/firebase';
import {
  PAYMENT_ACCOUNTS,
  ROLE_LABELS_AR,
  ROLE_LABELS_EN,
  YEMEN_GOVERNORATES,
} from '../config/selooConfig';
import { useSeloo } from '../context/SelooContext';
import { BRAND_IMAGES, CATALOG_CATEGORIES } from '../data/seedData';
import {
  classifyBrandAndCategory,
  computeCurrencyMatrix,
  detectNonRefundable,
  formatMoney,
  parseSheinShareInput,
  sanitizeImageUrl,
} from '../services/pricingService';
import { SHIPPING_MILESTONES } from '../services/shipmentTrackingService';
import {
  AppCurrency,
  CatalogItem,
  Order,
  OrderStatus,
  ShippingMilestone,
  StaffRole,
} from '../types/seloo';
import { AccountStatementView } from './AccountStatementView';

export const ProfileScreen: React.FC = () => {
  const {
    user,
    signInGoogle,
    signOutUser,
    savedAccounts,
    removeSavedAccount,
    effectiveRole,
    isStaff,
    isManager,
    theme,
    toggleTheme,
    language,
    setLanguage,
    currency,
    setCurrencyModalOpen,
    savedAddresses,
    saveAddress,
    deleteAddress,
    settings,
    saveAppSettings,
    catalog,
    upsertCatalogItem,
    deleteCatalogItem,
    allOrdersForStaff,
    staffUpdateOrder,
    managerArchiveDeleteOrder,
    checkoutAlerts,
    saveCheckoutAlert,
    deleteCheckoutAlert,
    staffInvites,
    saveStaffInvite,
    removeStaffInvite,
    auditLogs,
    deletedRecords,
    supportMessages,
    sendSupportMessage,
    wallet,
    requestWalletWithdrawal,
    notifyToast,
  } = useSeloo();

  const [section, setSection] = useState<'account' | 'wallet' | 'support' | 'admin'>(
    isStaff ? 'admin' : 'account'
  );
  const [wdAmount, setWdAmount] = useState('');
  const [wdBank, setWdBank] = useState('بنك الكريمي');
  const [wdAcc, setWdAcc] = useState('');
  const [adminTab, setAdminTab] = useState<
    'rates' | 'orders' | 'reports' | 'catalog' | 'alerts' | 'staff' | 'audit'
  >('orders');

  const didAutoRouteStaff = useRef(false);
  useEffect(() => {
    if (isStaff && !didAutoRouteStaff.current) {
      didAutoRouteStaff.current = true;
      setSection('admin');
      if (effectiveRole === 'accounting') {
        setAdminTab('reports');
      } else if (effectiveRole === 'marketer') {
        setAdminTab('catalog');
      } else {
        setAdminTab('orders');
      }
    }
    if (!isStaff) {
      didAutoRouteStaff.current = false;
    }
  }, [isStaff, effectiveRole]);

  // Support chat
  const [chatText, setChatText] = useState('');

  // Address form
  const [addrName, setAddrName] = useState('');
  const [addrPhone, setAddrPhone] = useState('');
  const [addrCity, setAddrCity] = useState(YEMEN_GOVERNORATES[0].name);
  const [addrDistrict, setAddrDistrict] = useState('');
  const [addrLine, setAddrLine] = useState('');

  // Admin: Exchange rates form
  const [rateForm, setRateForm] = useState(settings);

  // Admin: Catalog add + Margin Calculator + Discount + Batch import
  const [catTitle, setCatTitle] = useState('');
  const [catUrl, setCatUrl] = useState('');
  const [catImgUrl, setCatImgUrl] = useState('');
  const [catPriceSar, setCatPriceSar] = useState('');
  const [catMarginSar, setCatMarginSar] = useState('15');
  const [catMarginPct, setCatMarginPct] = useState('');
  const [catCategory, setCatCategory] = useState(CATALOG_CATEGORIES[1]);
  const [catNonRef, setCatNonRef] = useState(false);
  const [batchLinks, setBatchLinks] = useState('');
  const [discountItemId, setDiscountItemId] = useState<string | null>(null);
  const [discountPctInput, setDiscountPctInput] = useState('15');

  // Admin: Expanded Staff Order Preview + Zoomable Proof + Order Editor
  const [previewOrder, setPreviewOrder] = useState<Order | null>(null);
  const [zoomProofUrl, setZoomProofUrl] = useState<string | null>(null);
  const [editingOrder, setEditingOrder] = useState<Order | null>(null);
  const [milestoneSel, setMilestoneSel] = useState<ShippingMilestone>(
    ShippingMilestone.preparing
  );
  const [trackNo, setTrackNo] = useState('');
  const [trackUrl, setTrackUrl] = useState('');
  const [trackImgUrl, setTrackImgUrl] = useState('');
  const [stageNote, setStageNote] = useState('');
  const [replacementItemTitle, setReplacementItemTitle] = useState('');
  const [replacementItemPrice, setReplacementItemPrice] = useState('');
  const [priceSyncTotalSar, setPriceSyncTotalSar] = useState('');
  const [priceSyncMsg, setPriceSyncMsg] = useState('');
  const [deleteReason, setDeleteReason] = useState('');

  // Admin: Financial Reports filters
  const [reportPeriod, setReportPeriod] = useState<
    'today' | '7d' | '30d' | 'all' | 'custom'
  >('today');
  const [reportAccountFilter, setReportAccountFilter] = useState<string>('all');
  const [reportFromDate, setReportFromDate] = useState(() =>
    new Date().toISOString().slice(0, 10)
  );
  const [reportToDate, setReportToDate] = useState(() =>
    new Date().toISOString().slice(0, 10)
  );

  // Admin: Checkout alert form
  const [alertTitle, setAlertTitle] = useState('');
  const [alertMsg, setAlertMsg] = useState('');
  const [alertSeverity, setAlertSeverity] = useState<'info' | 'warning' | 'urgent'>('warning');
  const [alertAck, setAlertAck] = useState(false);

  // Admin: Staff invite form
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteName, setInviteName] = useState('');
  const [inviteRoleVal, setInviteRoleVal] = useState<StaffRole>('support');

  const handleAddAddress = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!addrName.trim() || !addrPhone.trim() || !addrLine.trim()) {
      notifyToast('أدخل الاسم ورقم الهاتف وتفاصيل العنوان', 'error');
      return;
    }
    await saveAddress({
      id: `addr_${Date.now()}`,
      label: `${addrCity}${addrDistrict ? ` - ${addrDistrict}` : ''}`,
      receiverName: addrName.trim(),
      phone: addrPhone.trim(),
      city: addrCity,
      district: addrDistrict.trim(),
      line: addrLine.trim(),
    });
    setAddrName('');
    setAddrPhone('');
    setAddrDistrict('');
    setAddrLine('');
  };

  const handleSaveRates = async (e: React.FormEvent) => {
    e.preventDefault();
    await saveAppSettings(rateForm);
  };

  const handleAddCatalogSingle = async (e: React.FormEvent) => {
    e.preventDefault();
    const base = parseFloat(catPriceSar);
    const margin = parseFloat(catMarginSar) || 0;
    if (!catTitle.trim() || !Number.isFinite(base) || base <= 0) {
      notifyToast('أدخل اسم المنتج والسعر الأساسي بالريال السعودي', 'error');
      return;
    }
    const parsed = parseSheinShareInput(catUrl);
    const gid = parsed[0]?.goodsId || `CAT-${Date.now().toString().slice(-6)}`;
    const nr = detectNonRefundable(catTitle, catCategory);
    const classified = classifyBrandAndCategory(catTitle, catUrl, catCategory);
    await upsertCatalogItem({
      title: catTitle.trim(),
      goodsId: gid,
      sourceUrl: parsed[0]?.url || catUrl.trim(),
      imageUrl: sanitizeImageUrl(catImgUrl, BRAND_IMAGES.kaftan),
      brand: classified.brand,
      category: classified.category,
      colors: ['أساسي'],
      sizes: ['S', 'M', 'L', 'XL'],
      basePriceSar: base,
      marginSar: margin,
      region: 'south',
      badge: 'new',
      active: true,
      nonRefundable: catNonRef || nr.nonRefundable,
      nonRefundableReason: catNonRef ? 'وسم غير قابل للاسترداد' : nr.reason,
    });
    setCatTitle('');
    setCatUrl('');
    setCatImgUrl('');
    setCatPriceSar('');
    setCatMarginPct('');
  };

  const handleApplyQuickDiscount = async (item: CatalogItem) => {
    const pct = parseFloat(discountPctInput);
    if (!Number.isFinite(pct) || pct <= 0 || pct >= 90) {
      notifyToast('أدخل نسبة تخفيض صحيحة بين 1% و 89%', 'error');
      return;
    }
    const currentTotal = item.basePriceSar + item.marginSar;
    const originalTotal =
      item.originalPriceSar && item.originalPriceSar > currentTotal
        ? item.originalPriceSar
        : currentTotal;
    const targetTotal = Math.max(1, Number((currentTotal * (1 - pct / 100)).toFixed(2)));
    const newBaseSar = Math.max(1, Number((targetTotal - item.marginSar).toFixed(2)));
    const effectivePct = Math.max(
      1,
      Math.round(((originalTotal - (newBaseSar + item.marginSar)) / originalTotal) * 100)
    );
    await upsertCatalogItem(
      {
        title: item.title,
        goodsId: item.goodsId,
        sourceUrl: item.sourceUrl,
        imageUrl: item.imageUrl,
        brand: item.brand,
        promoHeadline: `خصم خاص -${effectivePct}%`,
        category: item.category,
        colors: item.colors,
        sizes: item.sizes,
        sizePrices: item.sizePrices,
        basePriceSar: newBaseSar,
        marginSar: item.marginSar,
        originalPriceSar: originalTotal,
        discountPercent: effectivePct,
        region: item.region,
        badge: 'offer',
        active: item.active,
        nonRefundable: item.nonRefundable,
        nonRefundableReason: item.nonRefundableReason,
      },
      item.id
    );
    setDiscountItemId(null);
  };

  // Financial Report computation per Bank Account + Period
  const financialReport = useMemo(() => {
    const now = new Date();
    const startOfToday = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate()
    ).getTime();

    let minAt = 0;
    let maxAt = Number.MAX_SAFE_INTEGER;
    if (reportPeriod === 'today') {
      minAt = startOfToday;
    } else if (reportPeriod === '7d') {
      minAt = now.getTime() - 7 * 86400_000;
    } else if (reportPeriod === '30d') {
      minAt = now.getTime() - 30 * 86400_000;
    } else if (reportPeriod === 'custom') {
      if (reportFromDate) {
        minAt = new Date(`${reportFromDate}T00:00:00`).getTime();
      }
      if (reportToDate) {
        maxAt = new Date(`${reportToDate}T23:59:59`).getTime();
      }
    }

    const accountMap = new Map<string, (typeof PAYMENT_ACCOUNTS)[number]>();
    PAYMENT_ACCOUNTS.forEach((a) => accountMap.set(a.id, a));

    interface ReportTransferRow {
      orderId: string;
      orderNo: string;
      customerName: string;
      accountId: string;
      accountTitleAr: string;
      accountNumber: string;
      currency: AppCurrency;
      amountLocal: number;
      amountSar: number;
      senderName: string;
      refNo: string;
      approved: boolean;
      at: number;
      proofUrl: string;
    }

    const rows: ReportTransferRow[] = [];
    for (const ord of allOrdersForStaff) {
      if (ord.status === OrderStatus.cancelled) continue;
      const amtLocal = Number(ord.payment?.amount || ord.paidTotalLocal || 0);
      if (amtLocal <= 0) continue;
      const at = Number(
        ord.payment?.submittedAt || ord.payment?.confirmedAt || ord.createdAt || 0
      );
      if (at < minAt || at > maxAt) continue;

      const accId = ord.payment?.accountId || 'unspecified';
      if (reportAccountFilter !== 'all' && accId !== reportAccountFilter) continue;

      const accMeta = accountMap.get(accId);
      const rate = ord.exchangeRate > 0 ? ord.exchangeRate : 1;
      const amountSar = amtLocal / rate;
      const approved = Boolean(
        ord.payment?.confirmedAt ||
          ord.approvedAt ||
          (ord.status !== OrderStatus.unpaid && ord.status !== OrderStatus.verifying)
      );

      rows.push({
        orderId: ord.id,
        orderNo: ord.orderNo,
        customerName: ord.receiverName || ord.customerName || 'عميل يمن سيلو',
        accountId: accId,
        accountTitleAr:
          accMeta?.titleAr || ord.payment?.accountTitleAr || 'حساب تحويل مباشر',
        accountNumber:
          ord.payment?.accountNumber || accMeta?.numbers[0] || '—',
        currency: ord.currency,
        amountLocal: amtLocal,
        amountSar,
        senderName: ord.payment?.senderName || ord.receiverName || '—',
        refNo: ord.payment?.refNo || '—',
        approved,
        at,
        proofUrl: ord.payment?.proofUrl || ord.proofImageUrl || '',
      });
    }

    rows.sort((a, b) => b.at - a.at);

    interface AccountAggregate {
      accountId: string;
      titleAr: string;
      accountNumber: string;
      count: number;
      approvedCount: number;
      totalSar: number;
      byCurrency: Record<AppCurrency, number>;
    }

    const grouped = new Map<string, AccountAggregate>();
    for (const r of rows) {
      const existing = grouped.get(r.accountId) || {
        accountId: r.accountId,
        titleAr: r.accountTitleAr,
        accountNumber: r.accountNumber,
        count: 0,
        approvedCount: 0,
        totalSar: 0,
        byCurrency: { south: 0, north: 0, sar: 0, usd: 0 },
      };
      existing.count += 1;
      if (r.approved) existing.approvedCount += 1;
      existing.totalSar += r.amountSar;
      existing.byCurrency[r.currency] =
        (existing.byCurrency[r.currency] || 0) + r.amountLocal;
      grouped.set(r.accountId, existing);
    }

    const accountSummaries = Array.from(grouped.values()).sort(
      (a, b) => b.totalSar - a.totalSar
    );
    const totalSar = rows.reduce((s, r) => s + r.amountSar, 0);
    const approvedCount = rows.filter((r) => r.approved).length;

    return {
      rows,
      accountSummaries,
      totalSar,
      approvedCount,
      pendingCount: rows.length - approvedCount,
    };
  }, [allOrdersForStaff, reportPeriod, reportAccountFilter, reportFromDate, reportToDate]);

  const handlePrintFinancialReport = () => {
    const periodLabel =
      reportPeriod === 'today'
        ? 'تقرير اليوم'
        : reportPeriod === '7d'
        ? 'آخر 7 أيام'
        : reportPeriod === '30d'
        ? 'آخر 30 يوماً'
        : reportPeriod === 'custom'
        ? `من ${reportFromDate} إلى ${reportToDate}`
        : 'جميع الفترات';

    const accRowsHtml = financialReport.accountSummaries
      .map(
        (ag) => `<tr>
          <td><strong>${ag.titleAr}</strong><br/><small>${ag.accountNumber}</small></td>
          <td>${ag.count} (معتمد: ${ag.approvedCount})</td>
          <td>${(Object.keys(ag.byCurrency) as AppCurrency[])
            .filter((cur) => ag.byCurrency[cur] > 0)
            .map((cur) => formatMoney(ag.byCurrency[cur], cur))
            .join(' + ')}</td>
          <td><strong>${ag.totalSar.toFixed(2)} SAR</strong></td>
        </tr>`
      )
      .join('');

    const detailRowsHtml = financialReport.rows
      .map(
        (r) => `<tr>
          <td>${new Date(r.at).toLocaleDateString('ar-YE')}</td>
          <td>${r.orderNo}</td>
          <td>${r.customerName}</td>
          <td>${r.accountTitleAr}</td>
          <td>${formatMoney(r.amountLocal, r.currency)}</td>
          <td>${r.amountSar.toFixed(2)} SAR</td>
          <td>${r.refNo}</td>
          <td>${r.approved ? 'معتمد' : 'قيد المراجعة'}</td>
        </tr>`
      )
      .join('');

    const html = `<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8"/>
      <title>التقرير المالي للحوالات — ${settings.companyNameAr || 'يمن سيلو'}</title>
      <style>
        body{font-family:Tahoma,Arial,sans-serif;padding:24px;color:#171321;background:#fff}
        h1{margin:0 0 6px;color:#5B21B6;font-size:20px}
        .meta{font-size:12px;color:#5F5870;margin-bottom:14px}
        .kpis{display:flex;gap:12px;margin-bottom:16px}
        .kpi{flex:1;border:1px solid #E5E0EE;border-radius:10px;padding:10px;background:#FAF8F5}
        table{width:100%;border-collapse:collapse;font-size:12px;margin-bottom:18px}
        th,td{border:1px solid #E5E0EE;padding:7px;text-align:right}
        th{background:#F3EFE9;font-weight:bold}
        @media print{body{padding:8px}}
      </style></head><body>
      <h1>التقرير المالي للحوالات البنكية — ${settings.companyNameAr || 'يمن سيلو'}</h1>
      <div class="meta">الفترة: ${periodLabel} · تاريخ الإصدار: ${new Date().toLocaleString('ar-YE')}</div>
      <div class="kpis">
        <div class="kpi">عدد الحوالات: <strong>${financialReport.rows.length}</strong></div>
        <div class="kpi">المعتمدة: <strong>${financialReport.approvedCount}</strong></div>
        <div class="kpi">قيد المراجعة: <strong>${financialReport.pendingCount}</strong></div>
        <div class="kpi">الإجمالي المعادل: <strong>${financialReport.totalSar.toFixed(2)} SAR</strong></div>
      </div>
      <h3>ملخص حسب الحساب البنكي / المحفظة</h3>
      <table><thead><tr><th>الحساب</th><th>العدد</th><th>المبالغ المحولة</th><th>المعادل SAR</th></tr></thead>
      <tbody>${accRowsHtml || '<tr><td colspan="4">لا توجد بيانات</td></tr>'}</tbody></table>
      <h3>تفاصيل الحوالات</h3>
      <table><thead><tr><th>التاريخ</th><th>الطلب</th><th>العميل</th><th>الحساب</th><th>المبلغ</th><th>SAR</th><th>المرجع</th><th>الحالة</th></tr></thead>
      <tbody>${detailRowsHtml || '<tr><td colspan="8">لا توجد حوالات مطابقة</td></tr>'}</tbody></table>
      </body></html>`;

    const iframe = document.createElement('iframe');
    iframe.style.position = 'fixed';
    iframe.style.width = '0';
    iframe.style.height = '0';
    iframe.style.border = '0';
    iframe.style.opacity = '0';
    document.body.appendChild(iframe);
    const doc = iframe.contentWindow?.document;
    if (!doc || !iframe.contentWindow) {
      iframe.remove();
      return;
    }
    doc.open();
    doc.write(html);
    doc.close();
    setTimeout(() => {
      iframe.contentWindow?.focus();
      iframe.contentWindow?.print();
      setTimeout(() => iframe.remove(), 1200);
    }, 350);
  };

  const handleBatchCatalogImport = async () => {
    const entries = parseSheinShareInput(batchLinks);
    if (entries.length === 0) {
      notifyToast('لم يتم العثور على روابط شي إن صالحة', 'error');
      return;
    }
    for (const ent of entries) {
      const nr = detectNonRefundable(ent.titleHint);
      await upsertCatalogItem({
        title: ent.titleHint,
        goodsId: ent.goodsId,
        sourceUrl: ent.url,
        imageUrl: BRAND_IMAGES.handbag,
        category: 'أزياء نسائية',
        colors: ['أساسي'],
        sizes: ['S', 'M', 'L', 'XL'],
        basePriceSar: ent.priceSarHint || 75,
        marginSar: 15,
        region: 'south',
        badge: 'new',
        active: true,
        nonRefundable: nr.nonRefundable,
        nonRefundableReason: nr.reason,
      });
    }
    setBatchLinks('');
    notifyToast(`تم استيراد ${entries.length} منتج للكتالوج دفعة واحدة`, 'success');
  };

  const openOrderEditor = (ord: Order) => {
    setEditingOrder(ord);
    setMilestoneSel(ord.shippingStage);
    setTrackNo(ord.trackingNo);
    setTrackUrl(ord.trackingUrl);
    setTrackImgUrl(ord.trackingImageUrl);
    setStageNote(ord.shippingStageNote);
    setPriceSyncTotalSar(String(ord.totalSar));
    setReplacementItemTitle(ord.items[0]?.title || '');
    setReplacementItemPrice(String(ord.items[0]?.unitPriceSar || 0));
  };

  const handleTrackImgUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const dataUrl = await compressImageToDataUrl(file, 900, 0.72);
    setTrackImgUrl(dataUrl);
  };

  return (
    <div className="space-y-8 pb-16">
      {/* Top Me Header & Role Badge */}
      <div className="p-6 sm:p-8 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
        {user ? (
          <div className="flex items-center gap-4">
            {user.photoURL ? (
              <img
                src={user.photoURL}
                alt={user.displayName}
                className="w-16 h-16 rounded-2xl object-cover border border-black/10"
              />
            ) : (
              <div className="w-16 h-16 rounded-2xl bg-violet-600 text-white flex items-center justify-center text-2xl font-extrabold">
                {user.displayName[0]}
              </div>
            )}
            <div>
              <h1 className="text-xl font-extrabold">{user.displayName}</h1>
              <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">{user.email}</div>
              <div className="mt-1.5 inline-flex items-center gap-1.5 text-xs font-bold text-violet-700 dark:text-violet-300">
                <Shield className="w-3.5 h-3.5" />
                <span>
                  {language === 'ar'
                    ? ROLE_LABELS_AR[effectiveRole]
                    : ROLE_LABELS_EN[effectiveRole]}
                </span>
              </div>
            </div>
          </div>
        ) : (
          <div className="space-y-1.5">
            <h1 className="text-xl font-extrabold">حسابي وإعداداتي (أنا)</h1>
            <p className="text-sm text-[#5F5870] dark:text-[#A9A1BA]">
              سجّل الدخول بحساب Google مباشرة بنقرة واحدة بدون نماذج مسبقة.
            </p>
          </div>
        )}

        <div className="flex flex-wrap items-center gap-2.5">
          {user ? (
            <>
              <button
                type="button"
                onClick={() => signInGoogle()}
                className="px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold flex items-center gap-1.5 hover:bg-black/5 dark:hover:bg-white/5"
              >
                <Users className="w-4 h-4" />
                <span>إضافة / تبديل حساب Google</span>
              </button>
              <button
                type="button"
                onClick={signOutUser}
                className="px-4 py-2.5 rounded-xl border border-rose-500/30 text-rose-600 dark:text-rose-400 text-xs font-bold flex items-center gap-1.5 hover:bg-rose-500/10"
              >
                <LogOut className="w-4 h-4" />
                <span>تسجيل الخروج</span>
              </button>
            </>
          ) : (
            <button
              type="button"
              onClick={() => signInGoogle()}
              className="px-6 py-3 rounded-xl bg-violet-600 hover:bg-violet-700 text-white text-sm font-bold"
            >
              تسجيل الدخول بحساب Google
            </button>
          )}
        </div>
      </div>

      {/* Point 8: Saved Accounts Switcher */}
      {savedAccounts.length > 0 && (
        <div className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3">
          <div className="text-xs font-bold text-[#5F5870] dark:text-[#A9A1BA] flex items-center gap-1.5">
            <UserCheck className="w-4 h-4 text-violet-600" />
            <span>الحسابات المسجلة على هذا الجهاز (تنقل فوري بدون إعادة إدخال البيانات)</span>
          </div>
          <div className="flex flex-wrap gap-3">
            {savedAccounts.map((acc) => {
              const current = user?.uid === acc.uid;
              return (
                <div
                  key={acc.uid}
                  className={`p-3 rounded-xl border flex items-center gap-3 ${
                    current
                      ? 'border-violet-600 bg-violet-600/8'
                      : 'border-black/10 dark:border-white/10'
                  }`}
                >
                  <button
                    type="button"
                    onClick={() => signInGoogle(acc.email)}
                    className="text-start flex items-center gap-2.5"
                  >
                    <div className="w-9 h-9 rounded-full bg-violet-600/15 text-violet-700 dark:text-violet-300 font-bold flex items-center justify-center text-sm">
                      {acc.displayName[0]}
                    </div>
                    <div>
                      <div className="text-xs font-bold">{acc.displayName}</div>
                      <div className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">
                        {acc.email} · {ROLE_LABELS_AR[acc.role]}
                      </div>
                    </div>
                  </button>
                  {!current && (
                    <button
                      type="button"
                      onClick={() => removeSavedAccount(acc.uid)}
                      className="p-1 text-[#5F5870] hover:text-rose-600"
                      aria-label="إزالة من القائمة"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Sub-navigation inside Me Tab */}
      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          onClick={() => setSection('account')}
          className={`px-4 py-2.5 rounded-xl text-xs font-bold border ${
            section === 'account'
              ? 'bg-violet-600 text-white border-violet-600'
              : 'bg-white dark:bg-[#151122] border-black/10 dark:border-white/10'
          }`}
        >
          التفضيلات والعناوين
        </button>
        <button
          type="button"
          onClick={() => setSection('wallet')}
          className={`px-4 py-2.5 rounded-xl text-xs font-bold border flex items-center gap-1.5 ${
            section === 'wallet'
              ? 'bg-violet-600 text-white border-violet-600'
              : 'bg-white dark:bg-[#151122] border-black/10 dark:border-white/10'
          }`}
        >
          <Wallet className="w-3.5 h-3.5" />
          <span>محفظتي وكشف الحساب</span>
        </button>
        <button
          type="button"
          onClick={() => setSection('support')}
          className={`px-4 py-2.5 rounded-xl text-xs font-bold border flex items-center gap-1.5 ${
            section === 'support'
              ? 'bg-violet-600 text-white border-violet-600'
              : 'bg-white dark:bg-[#151122] border-black/10 dark:border-white/10'
          }`}
        >
          <Headphones className="w-3.5 h-3.5" />
          <span>خدمة العملاء الذكية</span>
        </button>
        {isStaff && (
          <button
            type="button"
            onClick={() => setSection('admin')}
            className={`px-4 py-2.5 rounded-xl text-xs font-bold border flex items-center gap-1.5 ${
              section === 'admin'
                ? 'bg-amber-600 text-white border-amber-600'
                : 'bg-white dark:bg-[#151122] border-amber-500/40 text-amber-700 dark:text-amber-300'
            }`}
          >
            <Shield className="w-3.5 h-3.5" />
            <span>لوحة الإدارة والطاقم</span>
          </button>
        )}
      </div>

      {/* SECTION 1: Account Preferences & Addresses */}
      {section === 'account' && (
        <div className="grid lg:grid-cols-12 gap-6 items-start">
          <div className="lg:col-span-5 p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
            <h2 className="font-extrabold text-base">تخصيص الواجهة والإعدادات</h2>

            <button
              type="button"
              onClick={toggleTheme}
              className="w-full p-4 rounded-2xl border border-black/10 dark:border-white/10 flex items-center justify-between hover:border-violet-500/50"
            >
              <div className="flex items-center gap-3">
                {theme === 'dark' ? (
                  <Moon className="w-5 h-5 text-violet-400" />
                ) : (
                  <Sun className="w-5 h-5 text-amber-600" />
                )}
                <div className="text-start">
                  <div className="font-bold text-sm">المظهر (الثيم)</div>
                  <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                    {theme === 'dark' ? 'الوضع الليلي مفعّل' : 'الوضع النهاري مفعّل'}
                  </div>
                </div>
              </div>
              <span className="text-xs font-bold text-violet-700 dark:text-violet-300">
                تبديل
              </span>
            </button>

            <button
              type="button"
              onClick={() => setCurrencyModalOpen(true)}
              className="w-full p-4 rounded-2xl border border-black/10 dark:border-white/10 flex items-center justify-between hover:border-violet-500/50"
            >
              <div className="flex items-center gap-3">
                <RefreshCw className="w-5 h-5 text-violet-600 dark:text-violet-400" />
                <div className="text-start">
                  <div className="font-bold text-sm">العملة ومنطقة الصرف</div>
                  <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                    {currency === 'south'
                      ? 'ريال يمني — جنوب'
                      : currency === 'north'
                      ? 'ريال يمني — شمال'
                      : currency === 'usd'
                      ? 'الدولار الأمريكي (USD)'
                      : 'الريال السعودي (SAR)'}
                  </div>
                </div>
              </div>
              <span className="text-xs font-bold text-violet-700 dark:text-violet-300">
                تغيير
              </span>
            </button>

            <button
              type="button"
              onClick={() => setLanguage(language === 'ar' ? 'en' : 'ar')}
              className="w-full p-4 rounded-2xl border border-black/10 dark:border-white/10 flex items-center justify-between hover:border-violet-500/50"
            >
              <div className="flex items-center gap-3">
                <Globe className="w-5 h-5 text-violet-600 dark:text-violet-400" />
                <div className="text-start">
                  <div className="font-bold text-sm">لغة التطبيق</div>
                  <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                    {language === 'ar' ? 'العربية (RTL)' : 'English (LTR)'}
                  </div>
                </div>
              </div>
              <span className="text-xs font-bold text-violet-700 dark:text-violet-300">
                {language === 'ar' ? 'EN' : 'AR'}
              </span>
            </button>
          </div>

          <div className="lg:col-span-7 p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-5">
            <div className="flex items-center gap-2 font-extrabold text-base">
              <MapPin className="w-5 h-5 text-violet-600 dark:text-violet-400" />
              <span>العناوين المحفوظة ({savedAddresses.length})</span>
            </div>

            {savedAddresses.length > 0 && (
              <div className="space-y-2.5">
                {savedAddresses.map((a) => (
                  <div
                    key={a.id}
                    className="p-3.5 rounded-2xl bg-[#F3EFE9] dark:bg-[#1E1830] flex items-center justify-between gap-3 text-xs"
                  >
                    <div>
                      <div className="font-bold text-sm">
                        {a.receiverName} · <span className="font-mono-num">{a.phone}</span>
                      </div>
                      <div className="text-[#5F5870] dark:text-[#A9A1BA]">
                        {a.city}
                        {a.district ? ` - ${a.district}` : ''} — {a.line}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => deleteAddress(a.id)}
                      className="p-1.5 text-rose-600 hover:bg-rose-500/10 rounded-lg"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                ))}
              </div>
            )}

            <form onSubmit={handleAddAddress} className="space-y-3 pt-3 border-t border-black/10 dark:border-white/10">
              <div className="text-xs font-bold">إضافة عنوان جديد (المديرية اختيارية)</div>
              <div className="grid sm:grid-cols-2 gap-2.5">
                <input
                  type="text"
                  value={addrName}
                  onChange={(e) => setAddrName(e.target.value)}
                  placeholder="اسم المستلم *"
                  className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
                />
                <input
                  type="tel"
                  value={addrPhone}
                  onChange={(e) => setAddrPhone(e.target.value)}
                  placeholder="رقم الهاتف *"
                  className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
                />
                <select
                  value={addrCity}
                  onChange={(e) => setAddrCity(e.target.value)}
                  className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
                >
                  {YEMEN_GOVERNORATES.map((g) => (
                    <option key={g.name} value={g.name}>
                      {g.name}
                    </option>
                  ))}
                </select>
                <input
                  type="text"
                  value={addrDistrict}
                  onChange={(e) => setAddrDistrict(e.target.value)}
                  placeholder="المديرية / الحي (اختياري)"
                  className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
                />
              </div>
              <div className="flex gap-2">
                <input
                  type="text"
                  value={addrLine}
                  onChange={(e) => setAddrLine(e.target.value)}
                  placeholder="الشارع أو أقرب معلم *"
                  className="flex-1 px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
                />
                <button
                  type="submit"
                  className="px-5 py-2.5 rounded-xl bg-violet-600 text-white text-xs font-bold shrink-0"
                >
                  حفظ
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* SECTION: Wallet & Simplified 4-Currency Account Statement */}
      {section === 'wallet' && (
        <div className="space-y-6">
          <AccountStatementView />

          <div className="grid lg:grid-cols-12 gap-6 items-start">
            <div className="lg:col-span-5 p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
              <div className="text-xs font-semibold text-[#5F5870] dark:text-[#A9A1BA]">
                رصيد محفظة يمن سيلو المتاح
              </div>
              <div className="text-3xl font-extrabold font-mono-num text-violet-700 dark:text-violet-300">
                {wallet.balanceSar.toFixed(2)} SAR
              </div>
              <div className="text-xs font-mono-num text-[#5F5870] dark:text-[#A9A1BA]">
                شمال: {Math.round(wallet.balanceSar * settings.rateNorth).toLocaleString('en-US')} ر.ي · جنوب:{' '}
                {Math.round(wallet.balanceSar * settings.rateSouth).toLocaleString('en-US')} ر.ي
              </div>

              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  const amt = parseFloat(wdAmount);
                  await requestWalletWithdrawal(amt, wdBank, wdAcc);
                  setWdAmount('');
                  setWdAcc('');
                }}
                className="space-y-2.5 pt-3 border-t border-black/10 dark:border-white/10"
              >
                <div className="text-xs font-bold">طلب سحب رصيد نقدي</div>
                <input
                  type="number"
                  step="0.01"
                  value={wdAmount}
                  onChange={(e) => setWdAmount(e.target.value)}
                  placeholder="المبلغ بـ SAR"
                  className="w-full px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                />
                <input
                  type="text"
                  value={wdBank}
                  onChange={(e) => setWdBank(e.target.value)}
                  placeholder="البنك أو المحفظة (كريمي / جيب / قطيبي)"
                  className="w-full px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                />
                <input
                  type="text"
                  value={wdAcc}
                  onChange={(e) => setWdAcc(e.target.value)}
                  placeholder="رقم الحساب *"
                  className="w-full px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                />
                <button
                  type="submit"
                  className="w-full py-2.5 rounded-xl bg-violet-600 text-white text-xs font-bold"
                >
                  إرسال طلب سحب
                </button>
              </form>
            </div>

            <div className="lg:col-span-7 p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
              <h2 className="font-extrabold text-base">حركات المحفظة النقدية</h2>
              {wallet.movements.length === 0 ? (
                <div className="py-12 text-center text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                  لا توجد حركات مالية مسجلة في المحفظة حتى الآن.
                </div>
              ) : (
                <div className="space-y-2">
                  {wallet.movements.map((mv) => (
                    <div
                      key={mv.id}
                      className="p-3.5 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] flex items-center justify-between text-xs"
                    >
                      <div>
                        <div className="font-bold">{mv.note}</div>
                        <div className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">
                          {new Date(mv.at).toLocaleString('ar-YE')}
                        </div>
                      </div>
                      <span
                        className={`font-mono-num font-extrabold ${
                          mv.type === 'credit' ? 'text-emerald-600' : 'text-rose-600'
                        }`}
                      >
                        {mv.type === 'credit' ? '+' : '-'}
                        {mv.amountSar.toFixed(2)} SAR
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* SECTION 2: Smart Support Chat */}
      {section === 'support' && (
        <div className="max-w-3xl rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] p-6 space-y-5">
          <div className="flex items-center justify-between border-b border-black/10 dark:border-white/10 pb-3">
            <div>
              <h2 className="font-extrabold text-base">مركز خدمة العملاء والدعم المباشر</h2>
              <p className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                ردود سريعة للأسئلة الشائعة وتحويل مباشر لموظفي يمن سيلو.
              </p>
            </div>
            <span className="text-xs font-mono-num text-violet-700 dark:text-violet-300 font-bold">
              {settings.supportPhone}
            </span>
          </div>

          {/* Quick Smart FAQ shortcuts */}
          <div className="flex flex-wrap gap-2">
            {[
              'كم مدة الشحن إلى اليمن؟',
              'كيف يعمل الدفع الآجل 50%؟',
              'كيف أتابع مراحل شحنتي؟',
            ].map((q) => (
              <button
                key={q}
                type="button"
                onClick={() => sendSupportMessage(q)}
                className="px-3 py-1.5 rounded-xl bg-[#F3EFE9] dark:bg-[#1E1830] text-xs font-semibold hover:bg-violet-600 hover:text-white transition-colors"
              >
                {q}
              </button>
            ))}
          </div>

          <div className="h-64 overflow-y-auto space-y-2.5 p-3 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/5 dark:border-white/5">
            {supportMessages.length === 0 ? (
              <div className="text-xs text-center text-[#5F5870] dark:text-[#A9A1BA] py-16">
                اكتب استفسارك أو رقم طلبك ليصلك رد الفريق فوراً.
              </div>
            ) : (
              supportMessages.map((m) => (
                <div
                  key={m.id}
                  className={`max-w-[80%] p-3 rounded-2xl text-xs ${
                    m.isStaff
                      ? 'bg-[#F3EFE9] dark:bg-[#1E1830] mr-auto'
                      : 'bg-violet-600 text-white ml-auto'
                  }`}
                >
                  <div className="font-bold mb-0.5 opacity-80">{m.senderName}</div>
                  <div>{m.text}</div>
                </div>
              ))
            )}
          </div>

          <form
            onSubmit={async (e) => {
              e.preventDefault();
              if (!chatText.trim()) return;
              await sendSupportMessage(chatText);
              setChatText('');
            }}
            className="flex gap-2"
          >
            <input
              type="text"
              value={chatText}
              onChange={(e) => setChatText(e.target.value)}
              placeholder="اكتب رسالتك هنا..."
              className="flex-1 px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
            />
            <button
              type="submit"
              className="px-5 py-2.5 rounded-xl bg-violet-600 text-white text-xs font-bold"
            >
              إرسال
            </button>
          </form>
        </div>
      )}

      {/* SECTION 3: Role-Gated Staff & Manager Console */}
      {section === 'admin' && isStaff && (
        <div className="space-y-6">
          <div className="flex flex-wrap gap-2 border-b border-black/10 dark:border-white/10 pb-3">
            {[
              { k: 'orders' as const, label: 'الطلبات والشحن والتتبع' },
              { k: 'reports' as const, label: 'التقارير المالية' },
              { k: 'catalog' as const, label: 'استوديو الكتالوج والاستيراد' },
              { k: 'alerts' as const, label: 'تنبيهات صفحة الدفع' },
              ...(isManager
                ? [
                    { k: 'rates' as const, label: 'أسعار الصرف والإعدادات' },
                    { k: 'staff' as const, label: 'توزيع أدوار الطاقم' },
                    { k: 'audit' as const, label: 'سجل التدقيق والمحذوفات' },
                  ]
                : []),
            ].map((tab) => (
              <button
                key={tab.k}
                type="button"
                onClick={() => {
                  setRateForm(settings);
                  setAdminTab(tab.k);
                }}
                className={`px-3.5 py-2 rounded-xl text-xs font-bold border ${
                  adminTab === tab.k
                    ? 'bg-[#171321] dark:bg-violet-600 text-white border-transparent'
                    : 'bg-white dark:bg-[#151122] border-black/10 dark:border-white/10'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* ADMIN: Live Exchange Rates */}
          {adminTab === 'rates' && isManager && (
            <form
              onSubmit={handleSaveRates}
              className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-5"
            >
              <h3 className="font-extrabold text-base">
                تعديل أسعار الصرف المركزية (تنعكس لحظياً في الويب والتطبيق)
              </h3>
              <div className="grid sm:grid-cols-2 lg:grid-cols-5 gap-3">
                <div>
                  <label className="text-xs font-bold block mb-1">صرف السعودي — شمال</label>
                  <input
                    type="number"
                    step="0.1"
                    value={rateForm.rateNorth}
                    onChange={(e) =>
                      setRateForm({ ...rateForm, rateNorth: parseFloat(e.target.value) || 0 })
                    }
                    className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
                  />
                </div>
                <div>
                  <label className="text-xs font-bold block mb-1">صرف السعودي — جنوب</label>
                  <input
                    type="number"
                    step="0.1"
                    value={rateForm.rateSouth}
                    onChange={(e) =>
                      setRateForm({ ...rateForm, rateSouth: parseFloat(e.target.value) || 0 })
                    }
                    className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
                  />
                </div>
                <div>
                  <label className="text-xs font-bold block mb-1">صرف الدولار — شمال</label>
                  <input
                    type="number"
                    step="0.1"
                    value={rateForm.usdRateNorth}
                    onChange={(e) =>
                      setRateForm({ ...rateForm, usdRateNorth: parseFloat(e.target.value) || 0 })
                    }
                    className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
                  />
                </div>
                <div>
                  <label className="text-xs font-bold block mb-1">صرف الدولار — جنوب</label>
                  <input
                    type="number"
                    step="0.1"
                    value={rateForm.usdRateSouth}
                    onChange={(e) =>
                      setRateForm({ ...rateForm, usdRateSouth: parseFloat(e.target.value) || 0 })
                    }
                    className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
                  />
                </div>
                <div>
                  <label className="text-xs font-bold block mb-1">الريال السعودي مقابل الدولار</label>
                  <input
                    type="number"
                    step="0.01"
                    value={rateForm.sarPerUsd}
                    onChange={(e) =>
                      setRateForm({ ...rateForm, sarPerUsd: parseFloat(e.target.value) || 3.75 })
                    }
                    className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
                  />
                </div>
              </div>
              <button
                type="submit"
                className="px-6 py-3 rounded-xl bg-violet-600 text-white text-xs font-bold"
              >
                حفظ وتطبيق الأسعار لحظياً
              </button>
            </form>
          )}

          {/* ADMIN: Orders, Split Shipping Milestones, Price Sync, Replacement, Manager Archive-Delete */}
          {adminTab === 'orders' && (
            <div className="space-y-4">
              {editingOrder && (
                <div className="p-6 rounded-3xl border border-violet-500/40 bg-white dark:bg-[#151122] space-y-5">
                  <div className="flex items-center justify-between">
                    <h3 className="font-extrabold text-base">
                      إدارة الطلب <span className="font-mono-num text-violet-600">{editingOrder.orderNo}</span>
                    </h3>
                    <button
                      type="button"
                      onClick={() => setEditingOrder(null)}
                      className="text-xs font-bold text-[#5F5870] hover:underline"
                    >
                      إغلاق المحرر
                    </button>
                  </div>

                  {/* Quick Approval & Status */}
                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      onClick={() =>
                        staffUpdateOrder(
                          editingOrder.id,
                          {
                            status: OrderStatus.processing,
                            shippingStage: ShippingMilestone.preparing,
                            paidTotalLocal: editingOrder.upfrontDueLocal,
                            remainingLocal: Math.max(
                              0,
                              editingOrder.totalLocal - editingOrder.upfrontDueLocal
                            ),
                            approvedByName: user?.displayName || 'المحاسبة',
                            note: 'تم اعتماد الحوالة والبدء بشراء القطع',
                          },
                          'اعتماد حوالة'
                        )
                      }
                      className="px-3.5 py-2 rounded-xl bg-emerald-600 text-white text-xs font-bold flex items-center gap-1"
                    >
                      <Check className="w-3.5 h-3.5" />
                      <span>اعتماد الحوالة وبدء التجهيز</span>
                    </button>
                  </div>

                  {/* Split Shipping Milestones & Tracking */}
                  <div className="p-4 rounded-2xl bg-[#F3EFE9] dark:bg-[#1E1830] space-y-3">
                    <div className="text-xs font-bold flex items-center gap-1.5">
                      <Truck className="w-4 h-4 text-violet-600" />
                      <span>تحديث مرحلة الشحن المقسمة والتتبع (الصين ← الإمارات ← السعودية ← اليمن)</span>
                    </div>
                    <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-2.5">
                      <select
                        value={milestoneSel}
                        onChange={(e) => setMilestoneSel(e.target.value as ShippingMilestone)}
                        className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs"
                      >
                        {SHIPPING_MILESTONES.map((m) => (
                          <option key={m.key} value={m.key}>
                            {m.emoji} {m.labelAr}
                          </option>
                        ))}
                      </select>
                      <input
                        type="text"
                        value={trackNo}
                        onChange={(e) => setTrackNo(e.target.value)}
                        placeholder="رقم التتبع"
                        className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs font-mono-num"
                      />
                      <input
                        type="url"
                        value={trackUrl}
                        onChange={(e) => setTrackUrl(e.target.value)}
                        placeholder="رابط تتبع شركة الشحن"
                        className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs"
                      />
                      <input
                        type="text"
                        value={stageNote}
                        onChange={(e) => setStageNote(e.target.value)}
                        placeholder="ملاحظة للعميل..."
                        className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs"
                      />
                    </div>
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <label className="text-xs font-bold text-violet-700 dark:text-violet-300 cursor-pointer">
                        + إرفاق صورة التتبع {trackImgUrl ? '(تم الإرفاق ✓)' : ''}
                        <input
                          type="file"
                          accept="image/*"
                          onChange={handleTrackImgUpload}
                          className="hidden"
                        />
                      </label>
                      <button
                        type="button"
                        onClick={() => {
                          const meta =
                            SHIPPING_MILESTONES.find((m) => m.key === milestoneSel) ||
                            SHIPPING_MILESTONES[0];
                          staffUpdateOrder(
                            editingOrder.id,
                            {
                              status: meta.mappedStatus,
                              shippingStage: milestoneSel,
                              shippingStageNote: stageNote,
                              trackingNo: trackNo,
                              trackingUrl: trackUrl,
                              trackingImageUrl: trackImgUrl,
                              note: `${meta.emoji} ${meta.labelAr}${
                                stageNote ? ` — ${stageNote}` : ''
                              }`,
                            },
                            'تحديث مرحلة الشحن والتتبع'
                          );
                        }}
                        className="px-4 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold"
                      >
                        حفظ المرحلة وإشعار العميل
                      </button>
                    </div>
                  </div>

                  {/* Price Sync + Smart Replacement after 24h */}
                  <div className="grid md:grid-cols-2 gap-4">
                    <div className="p-4 rounded-2xl border border-black/10 dark:border-white/10 space-y-2.5">
                      <div className="text-xs font-bold">إرسال مقترح مزامنة سعر للعميل</div>
                      <input
                        type="number"
                        step="0.01"
                        value={priceSyncTotalSar}
                        onChange={(e) => setPriceSyncTotalSar(e.target.value)}
                        placeholder="الإجمالي المقترح SAR"
                        className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                      />
                      <input
                        type="text"
                        value={priceSyncMsg}
                        onChange={(e) => setPriceSyncMsg(e.target.value)}
                        placeholder="سبب التعديل..."
                        className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                      />
                      <button
                        type="button"
                        onClick={() => {
                          const pSar = parseFloat(priceSyncTotalSar) || editingOrder.totalSar;
                          const pLocal = Math.round(pSar * editingOrder.exchangeRate);
                          staffUpdateOrder(
                            editingOrder.id,
                            {
                              priceSyncStatus: 'pending_customer',
                              priceSyncNote: priceSyncMsg || 'تغير سعر القطعة في المصدر',
                              proposedTotalSar: pSar,
                              proposedTotalLocal: pLocal,
                              proposedItems: editingOrder.items,
                              note: `طلب موافقة العميل على تعديل السعر إلى ${pSar.toFixed(2)} SAR`,
                            },
                            'طلب مزامنة سعر'
                          );
                        }}
                        className="px-3.5 py-2 rounded-xl bg-amber-600 text-white text-xs font-bold"
                      >
                        إرسال طلب موافقة للعميل
                      </button>
                      {editingOrder.priceSyncStatus === 'accepted' && (
                        <button
                          type="button"
                          onClick={() => {
                            const diff =
                              editingOrder.proposedTotalLocal - editingOrder.totalLocal;
                            staffUpdateOrder(
                              editingOrder.id,
                              {
                                totalSar: editingOrder.proposedTotalSar,
                                totalLocal: editingOrder.proposedTotalLocal,
                                remainingLocal: Math.max(
                                  0,
                                  editingOrder.remainingLocal + diff
                                ),
                                priceSyncStatus: '',
                                note: 'تم تطبيق السعر الجديد المعتمد من العميل',
                              },
                              'تطبيق مزامنة السعر'
                            );
                          }}
                          className="w-full px-3.5 py-2 rounded-xl bg-emerald-600 text-white text-xs font-bold"
                        >
                          العميل وافق — تطبيق السعر الجديد الآن ✓
                        </button>
                      )}
                    </div>

                    <div className="p-4 rounded-2xl border border-black/10 dark:border-white/10 space-y-2.5">
                      <div className="text-xs font-bold">تنبيه نفاد قطعة بعد 24 ساعة (البديل الذكي)</div>
                      <input
                        type="text"
                        value={replacementItemTitle}
                        onChange={(e) => setReplacementItemTitle(e.target.value)}
                        placeholder="اسم القطعة النافدة"
                        className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                      />
                      <input
                        type="number"
                        step="0.01"
                        value={replacementItemPrice}
                        onChange={(e) => setReplacementItemPrice(e.target.value)}
                        placeholder="سعرها SAR"
                        className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                      />
                      <button
                        type="button"
                        onClick={() => {
                          const p = parseFloat(replacementItemPrice) || 0;
                          staffUpdateOrder(
                            editingOrder.id,
                            {
                              replacementStatus: 'pending_customer',
                              replacementAlert: `نفدت القطعة (${replacementItemTitle}) — يرجى إرسال رابط بديل بنفس القيمة أو بتسوية الفارق`,
                              replacementProposal: {
                                targetItemTitle: replacementItemTitle,
                                targetItemPriceSar: p,
                              },
                              note: `تنبيه نفاد قطعة (${replacementItemTitle}) لطلب بديل ذكي`,
                            },
                            'طلب بديل ذكي بعد 24 ساعة'
                          );
                        }}
                        className="px-3.5 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold"
                      >
                        تفعيل تنبيه البديل الذكي
                      </button>

                      {editingOrder.replacementStatus === 'pending_admin' &&
                        editingOrder.replacementProposal?.replacementTitle && (
                          <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/30 space-y-2 text-xs">
                            <div className="font-bold">
                              بديل العميل: {editingOrder.replacementProposal.replacementTitle} (
                              {editingOrder.replacementProposal.replacementPriceSar} SAR)
                            </div>
                            <div className="text-[#5F5870] dark:text-[#A9A1BA]">
                              {editingOrder.replacementProposal.settlementNote}
                            </div>
                            <button
                              type="button"
                              onClick={() => {
                                const prop = editingOrder.replacementProposal!;
                                const diffSar = prop.diffSar || 0;
                                const diffLocal = Math.round(
                                  diffSar * editingOrder.exchangeRate
                                );
                                const nextItems = [
                                  ...editingOrder.items,
                                  {
                                    goodsId: `REP-${Date.now().toString().slice(-5)}`,
                                    sku: 'REPLACEMENT',
                                    title: prop.replacementTitle || 'بديل معتمد',
                                    imageUrl: prop.replacementImageUrl || '',
                                    size: 'One Size',
                                    color: 'بديل',
                                    qty: 1,
                                    unitPriceSar: prop.replacementPriceSar || 0,
                                    productUrl: prop.replacementUrl || '',
                                    nonRefundable: false,
                                    nonRefundableReason: '',
                                    isReplacement: true,
                                    replacedFromTitle: prop.targetItemTitle,
                                    replacementNote: prop.settlementNote,
                                  },
                                ];
                                staffUpdateOrder(
                                  editingOrder.id,
                                  {
                                    replacementStatus: 'approved',
                                    items: nextItems,
                                    totalSar: Math.max(0, editingOrder.totalSar + diffSar),
                                    totalLocal: Math.max(0, editingOrder.totalLocal + diffLocal),
                                    remainingLocal: Math.max(
                                      0,
                                      editingOrder.remainingLocal + diffLocal
                                    ),
                                    note: `تم اعتماد البديل (${prop.replacementTitle}) — ${prop.settlementNote}`,
                                  },
                                  'اعتماد البديل الذكي'
                                );
                              }}
                              className="w-full py-2 rounded-xl bg-emerald-600 text-white font-bold"
                            >
                              اعتماد البديل وتسجيله في الطلب ✓
                            </button>
                          </div>
                        )}
                    </div>
                  </div>

                  {/* Point 15: Manager Archive & Delete */}
                  {isManager && (
                    <div className="p-4 rounded-2xl border border-rose-500/30 bg-rose-500/5 flex flex-wrap items-center gap-2.5">
                      <input
                        type="text"
                        value={deleteReason}
                        onChange={(e) => setDeleteReason(e.target.value)}
                        placeholder="سبب حذف وأرشفة الطلب (إلزامي للتدقيق)..."
                        className="flex-1 px-3 py-2 rounded-xl border border-rose-500/30 bg-white dark:bg-[#151122] text-xs"
                      />
                      <button
                        type="button"
                        onClick={async () => {
                          await managerArchiveDeleteOrder(editingOrder, deleteReason || 'حذف إداري');
                          setEditingOrder(null);
                          setDeleteReason('');
                        }}
                        className="px-4 py-2 rounded-xl bg-rose-600 text-white text-xs font-bold"
                      >
                        حذف ونقل لسجل المحذوفات
                      </button>
                    </div>
                  )}
                </div>
              )}

              <div className="space-y-2.5">
                {allOrdersForStaff.length === 0 ? (
                  <div className="p-8 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] text-center text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                    لا توجد طلبات مسجلة حتى الآن أو جاري المزامنة مع السحابة.
                  </div>
                ) : (
                  allOrdersForStaff.map((ord) => {
                    const proofSrc = ord.payment?.proofUrl || ord.proofImageUrl;
                    return (
                      <div
                        key={ord.id}
                        className="p-4 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] flex flex-wrap items-center justify-between gap-3"
                      >
                        <div className="space-y-0.5">
                          <div className="font-mono-num font-extrabold text-sm text-violet-700 dark:text-violet-300">
                            {ord.orderNo} · {ord.receiverName || ord.customerName}
                          </div>
                          <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                            {ord.shippingGovernorate} · {ord.items.length} قطعة ·{' '}
                            {formatMoney(ord.totalLocal, ord.currency)} · {ord.shippingStage}
                            {proofSrc ? ' · حوالة مرفقة ✓' : ''}
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center gap-2">
                          <button
                            type="button"
                            onClick={() => setPreviewOrder(ord)}
                            className="px-3.5 py-2 rounded-xl border border-violet-500/40 text-violet-700 dark:text-violet-300 text-xs font-bold flex items-center gap-1.5 hover:bg-violet-500/10"
                          >
                            <Eye className="w-3.5 h-3.5" />
                            <span>معاينة موسّعة</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => openOrderEditor(ord)}
                            className="px-4 py-2 rounded-xl bg-[#F3EFE9] dark:bg-[#1E1830] text-xs font-bold hover:bg-violet-600 hover:text-white transition-colors"
                          >
                            إدارة وتحديث
                          </button>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          )}

          {/* ADMIN: Financial Reports ("التقارير المالية") */}
          {adminTab === 'reports' && (
            <div className="space-y-5">
              <div className="p-5 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div className="flex items-center gap-2">
                    <BarChart3 className="w-5 h-5 text-violet-600 dark:text-violet-400" />
                    <div>
                      <h3 className="font-extrabold text-base">
                        التقارير المالية — جرد الحوالات البنكية
                      </h3>
                      <p className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                        تقرير يومي وبالفترة لكل حساب تحويلي مع الإجمالي والمعادل بالريال السعودي.
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={handlePrintFinancialReport}
                    className="px-4 py-2 rounded-xl bg-[#171321] dark:bg-violet-600 text-white text-xs font-bold flex items-center gap-1.5"
                  >
                    <Printer className="w-3.5 h-3.5" />
                    <span>تصدير وطباعة التقرير PDF</span>
                  </button>
                </div>

                {/* Period & Bank Account Filters */}
                <div className="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-black/10 dark:border-white/10">
                  <div className="flex flex-wrap gap-1.5">
                    {(
                      [
                        { k: 'today', l: 'اليوم' },
                        { k: '7d', l: 'آخر 7 أيام' },
                        { k: '30d', l: 'آخر 30 يوماً' },
                        { k: 'all', l: 'الكل' },
                        { k: 'custom', l: 'فترة مخصصة' },
                      ] as const
                    ).map((p) => (
                      <button
                        key={p.k}
                        type="button"
                        onClick={() => setReportPeriod(p.k)}
                        className={`px-3 py-1.5 rounded-xl text-xs font-bold border ${
                          reportPeriod === p.k
                            ? 'bg-violet-600 text-white border-violet-600'
                            : 'border-black/15 dark:border-white/15'
                        }`}
                      >
                        {p.l}
                      </button>
                    ))}
                  </div>

                  <select
                    value={reportAccountFilter}
                    onChange={(e) => setReportAccountFilter(e.target.value)}
                    className="px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs font-bold"
                  >
                    <option value="all">جميع الحسابات البنكية والمحافظ</option>
                    {PAYMENT_ACCOUNTS.map((acc) => (
                      <option key={acc.id} value={acc.id}>
                        {acc.titleAr} ({acc.numbers[0]})
                      </option>
                    ))}
                  </select>
                </div>

                {reportPeriod === 'custom' && (
                  <div className="grid sm:grid-cols-2 gap-3 pt-1">
                    <div>
                      <label className="text-[11px] font-bold block mb-1">من تاريخ</label>
                      <input
                        type="date"
                        value={reportFromDate}
                        onChange={(e) => setReportFromDate(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-bold block mb-1">إلى تاريخ</label>
                      <input
                        type="date"
                        value={reportToDate}
                        onChange={(e) => setReportToDate(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                      />
                    </div>
                  </div>
                )}

                {/* Summary KPI Strip */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  <div className="p-3.5 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/5 dark:border-white/5">
                    <div className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">إجمالي الحوالات</div>
                    <div className="font-mono-num font-extrabold text-lg mt-0.5">
                      {financialReport.rows.length}
                    </div>
                  </div>
                  <div className="p-3.5 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/5 dark:border-white/5">
                    <div className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">معتمدة</div>
                    <div className="font-mono-num font-extrabold text-lg text-emerald-600 dark:text-emerald-400 mt-0.5">
                      {financialReport.approvedCount}
                    </div>
                  </div>
                  <div className="p-3.5 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/5 dark:border-white/5">
                    <div className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">قيد المراجعة</div>
                    <div className="font-mono-num font-extrabold text-lg text-amber-600 dark:text-amber-400 mt-0.5">
                      {financialReport.pendingCount}
                    </div>
                  </div>
                  <div className="p-3.5 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-violet-500/30">
                    <div className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">المعادل الإجمالي</div>
                    <div className="font-mono-num font-extrabold text-lg text-violet-700 dark:text-violet-300 mt-0.5">
                      {financialReport.totalSar.toFixed(2)} SAR
                    </div>
                  </div>
                </div>
              </div>

              {/* Per-Account Breakdown Cards */}
              {financialReport.accountSummaries.length > 0 && (
                <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  {financialReport.accountSummaries.map((ag) => (
                    <button
                      key={ag.accountId}
                      type="button"
                      onClick={() =>
                        setReportAccountFilter(
                          reportAccountFilter === ag.accountId ? 'all' : ag.accountId
                        )
                      }
                      className={`text-start p-4 rounded-2xl border transition-colors ${
                        reportAccountFilter === ag.accountId
                          ? 'border-violet-600 bg-violet-600/8'
                          : 'border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] hover:border-violet-500/40'
                      }`}
                    >
                      <div className="font-extrabold text-xs">{ag.titleAr}</div>
                      <div className="font-mono-num text-[11px] text-[#5F5870] dark:text-[#A9A1BA] mt-0.5">
                        رقم الحساب: {ag.accountNumber} · {ag.count} حوالة
                      </div>
                      <div className="mt-2 font-mono-num font-extrabold text-sm text-violet-700 dark:text-violet-300">
                        {ag.totalSar.toFixed(2)} SAR
                      </div>
                      <div className="text-[11px] font-mono-num text-[#5F5870] dark:text-[#A9A1BA] mt-1">
                        {(Object.keys(ag.byCurrency) as AppCurrency[])
                          .filter((cur) => ag.byCurrency[cur] > 0)
                          .map((cur) => formatMoney(ag.byCurrency[cur], cur))
                          .join(' · ')}
                      </div>
                    </button>
                  ))}
                </div>
              )}

              {/* Detailed Transfers Table */}
              <div className="p-5 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122]">
                {financialReport.rows.length === 0 ? (
                  <div className="py-10 text-center text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                    لا توجد حوالات مسجلة ضمن الفترة والحساب المحددين.
                  </div>
                ) : (
                  <div className="overflow-x-auto rounded-2xl border border-black/10 dark:border-white/10">
                    <table className="w-full text-xs text-right">
                      <thead className="bg-[#F3EFE9] dark:bg-[#1E1830] text-[#5F5870] dark:text-[#A9A1BA]">
                        <tr>
                          <th className="p-3 font-bold">التاريخ</th>
                          <th className="p-3 font-bold">الطلب والعميل</th>
                          <th className="p-3 font-bold">الحساب</th>
                          <th className="p-3 font-bold">المبلغ</th>
                          <th className="p-3 font-bold">SAR</th>
                          <th className="p-3 font-bold">الحالة والإثبات</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-black/10 dark:divide-white/10">
                        {financialReport.rows.map((r) => (
                          <tr key={r.orderId}>
                            <td className="p-3 font-mono-num whitespace-nowrap">
                              {new Date(r.at).toLocaleDateString('ar-YE')}
                            </td>
                            <td className="p-3">
                              <div className="font-mono-num font-bold">{r.orderNo}</div>
                              <div className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">
                                {r.customerName}
                              </div>
                            </td>
                            <td className="p-3">
                              <div className="font-semibold">{r.accountTitleAr}</div>
                              <div className="text-[11px] font-mono-num text-[#5F5870] dark:text-[#A9A1BA]">
                                مرجع: {r.refNo}
                              </div>
                            </td>
                            <td className="p-3 font-mono-num font-bold">
                              {formatMoney(r.amountLocal, r.currency)}
                            </td>
                            <td className="p-3 font-mono-num font-bold text-violet-700 dark:text-violet-300">
                              {r.amountSar.toFixed(2)}
                            </td>
                            <td className="p-3">
                              <div className="flex items-center gap-2">
                                <span
                                  className={`font-bold ${
                                    r.approved
                                      ? 'text-emerald-600 dark:text-emerald-400'
                                      : 'text-amber-600 dark:text-amber-400'
                                  }`}
                                >
                                  {r.approved ? 'معتمد' : 'قيد المراجعة'}
                                </span>
                                {r.proofUrl && (
                                  <button
                                    type="button"
                                    onClick={() =>
                                      setZoomProofUrl(
                                        sanitizeImageUrl(r.proofUrl, BRAND_IMAGES.kaftan)
                                      )
                                    }
                                    className="text-violet-700 dark:text-violet-300 font-bold hover:underline"
                                  >
                                    الصورة
                                  </button>
                                )}
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* ADMIN: Catalog Studio + Profit Calculator + Discount + Batch Import */}
          {adminTab === 'catalog' && (
            <div className="space-y-6">
              <div className="grid md:grid-cols-2 gap-6">
                <form
                  onSubmit={handleAddCatalogSingle}
                  className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3"
                >
                  <div className="font-extrabold text-sm flex items-center gap-1.5">
                    <Calculator className="w-4 h-4 text-violet-600 dark:text-violet-400" />
                    <span>إضافة قطعة وحاسبة هامش الربح</span>
                  </div>
                  <input
                    type="text"
                    value={catTitle}
                    onChange={(e) => setCatTitle(e.target.value)}
                    placeholder="اسم القطعة *"
                    className="w-full px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                  />
                  <div className="grid sm:grid-cols-2 gap-2">
                    <input
                      type="text"
                      value={catUrl}
                      onChange={(e) => setCatUrl(e.target.value)}
                      placeholder="رابط SHEIN أو نص المشاركة"
                      className="px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                    />
                    <input
                      type="url"
                      value={catImgUrl}
                      onChange={(e) => setCatImgUrl(e.target.value)}
                      placeholder="رابط صورة المنتج (اختياري)"
                      className="px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                    />
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                    <input
                      type="number"
                      step="0.01"
                      value={catPriceSar}
                      onChange={(e) => {
                        const v = e.target.value;
                        setCatPriceSar(v);
                        const base = parseFloat(v);
                        const pct = parseFloat(catMarginPct);
                        if (Number.isFinite(base) && base > 0 && Number.isFinite(pct) && pct >= 0) {
                          setCatMarginSar(((base * pct) / 100).toFixed(2));
                        }
                      }}
                      placeholder="التكلفة SAR"
                      className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                    />
                    <input
                      type="number"
                      step="0.01"
                      value={catMarginSar}
                      onChange={(e) => {
                        const m = e.target.value;
                        setCatMarginSar(m);
                        const base = parseFloat(catPriceSar);
                        const mv = parseFloat(m);
                        if (Number.isFinite(base) && base > 0 && Number.isFinite(mv)) {
                          setCatMarginPct(((mv / base) * 100).toFixed(1));
                        }
                      }}
                      placeholder="الهامش SAR"
                      className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                    />
                    <input
                      type="number"
                      step="0.5"
                      value={catMarginPct}
                      onChange={(e) => {
                        const pctVal = e.target.value;
                        setCatMarginPct(pctVal);
                        const base = parseFloat(catPriceSar);
                        const pct = parseFloat(pctVal);
                        if (Number.isFinite(base) && base > 0 && Number.isFinite(pct)) {
                          setCatMarginSar(((base * pct) / 100).toFixed(2));
                        }
                      }}
                      placeholder="نسبة الربح %"
                      className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                    />
                    <select
                      value={catCategory}
                      onChange={(e) => setCatCategory(e.target.value)}
                      className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs"
                    >
                      {CATALOG_CATEGORIES.filter((c) => c !== 'الكل').map((c) => (
                        <option key={c} value={c}>
                          {c}
                        </option>
                      ))}
                    </select>
                  </div>

                  {/* Live Selling Price Matrix Preview */}
                  {(parseFloat(catPriceSar) || 0) > 0 && (
                    <div className="p-3 rounded-xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/5 dark:border-white/5 text-[11px] font-mono-num space-y-1">
                      {(() => {
                        const finalSar =
                          (parseFloat(catPriceSar) || 0) + (parseFloat(catMarginSar) || 0);
                        const mx = computeCurrencyMatrix(finalSar, settings);
                        return (
                          <>
                            <div className="font-bold text-violet-700 dark:text-violet-300">
                              سعر البيع النهائي: {mx.sar.toFixed(2)} SAR (${mx.usd.toFixed(2)})
                            </div>
                            <div className="text-[#5F5870] dark:text-[#A9A1BA]">
                              جنوب: {mx.southFromSar.toLocaleString('en-US')} ر.ي · شمال:{' '}
                              {mx.northFromSar.toLocaleString('en-US')} ر.ي
                            </div>
                          </>
                        );
                      })()}
                    </div>
                  )}

                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="checkbox"
                      checked={catNonRef}
                      onChange={(e) => setCatNonRef(e.target.checked)}
                    />
                    <span>وسم غير قابل للاسترداد</span>
                  </label>
                  <button
                    type="submit"
                    className="px-5 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold flex items-center gap-1.5"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>نشر في الكتالوج</span>
                  </button>
                </form>

                <div className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3">
                  <div className="font-extrabold text-sm">استيراد جماعي لعدة روابط دفعة واحدة</div>
                  <textarea
                    rows={6}
                    value={batchLinks}
                    onChange={(e) => setBatchLinks(e.target.value)}
                    placeholder="الصق عدة روابط SHEIN أو نصوص مشاركة (رابط في كل سطر)..."
                    className="w-full p-3 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                  />
                  <button
                    type="button"
                    onClick={handleBatchCatalogImport}
                    className="px-5 py-2 rounded-xl bg-[#171321] dark:bg-violet-600 text-white text-xs font-bold"
                  >
                    تحليل ونشر الكل للكتالوج
                  </button>
                </div>
              </div>

              <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
                {catalog.map((c) => {
                  const totalSar = c.basePriceSar + c.marginSar;
                  const editingDisc = discountItemId === c.id;
                  return (
                    <div
                      key={c.id}
                      className="p-3.5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-2.5"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-2.5 min-w-0">
                          <img
                            src={sanitizeImageUrl(c.imageUrl, BRAND_IMAGES.kaftan)}
                            alt={c.title}
                            className="w-10 h-10 rounded-xl object-cover shrink-0 bg-[#F3EFE9]"
                          />
                          <div className="min-w-0">
                            <div className="font-bold text-xs truncate">{c.title}</div>
                            <div className="font-mono-num text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">
                              {totalSar.toFixed(2)} SAR · #{c.goodsId}
                              {c.discountPercent ? ` (-${c.discountPercent}%)` : ''}
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center gap-1 shrink-0">
                          <button
                            type="button"
                            onClick={() =>
                              setDiscountItemId(editingDisc ? null : c.id)
                            }
                            title="تطبيق تخفيض وإشعار المتابعين"
                            className="p-1.5 text-amber-600 hover:bg-amber-500/10 rounded-lg"
                          >
                            <Percent className="w-4 h-4" />
                          </button>
                          {isManager && (
                            <button
                              type="button"
                              onClick={() => deleteCatalogItem(c, 'حذف من لوحة الكتالوج')}
                              className="p-1.5 text-rose-600 hover:bg-rose-500/10 rounded-lg"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </div>

                      {editingDisc && (
                        <div className="pt-2 border-t border-black/10 dark:border-white/10 flex items-center gap-2">
                          <input
                            type="number"
                            min={1}
                            max={89}
                            value={discountPctInput}
                            onChange={(e) => setDiscountPctInput(e.target.value)}
                            placeholder="%"
                            className="w-16 px-2 py-1 rounded-lg border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num text-center"
                          />
                          <button
                            type="button"
                            onClick={() => handleApplyQuickDiscount(c)}
                            className="flex-1 py-1.5 rounded-lg bg-amber-600 text-white text-[11px] font-bold flex items-center justify-center gap-1"
                          >
                            <Tag className="w-3 h-3" />
                            <span>اعتماد خصم وإرسال إشعار</span>
                          </button>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* ADMIN: Checkout Alerts */}
          {adminTab === 'alerts' && (
            <div className="space-y-4">
              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!alertTitle.trim() || !alertMsg.trim()) return;
                  await saveCheckoutAlert({
                    title: alertTitle.trim(),
                    message: alertMsg.trim(),
                    severity: alertSeverity,
                    requireAck: alertAck,
                    active: true,
                  });
                  setAlertTitle('');
                  setAlertMsg('');
                }}
                className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3"
              >
                <div className="font-extrabold text-sm flex items-center gap-1.5">
                  <AlertCircle className="w-4 h-4 text-amber-600" />
                  <span>إضافة تنبيه يظهر للعملاء في صفحة الدفع</span>
                </div>
                <div className="grid sm:grid-cols-3 gap-2.5">
                  <input
                    type="text"
                    value={alertTitle}
                    onChange={(e) => setAlertTitle(e.target.value)}
                    placeholder="عنوان التنبيه *"
                    className="sm:col-span-2 px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                  />
                  <select
                    value={alertSeverity}
                    onChange={(e) =>
                      setAlertSeverity(e.target.value as 'info' | 'warning' | 'urgent')
                    }
                    className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs"
                  >
                    <option value="info">معلومة عادية</option>
                    <option value="warning">تنبيه شحن / جمارك</option>
                    <option value="urgent">عاجل / تغيّر أسعار</option>
                  </select>
                </div>
                <textarea
                  rows={2}
                  value={alertMsg}
                  onChange={(e) => setAlertMsg(e.target.value)}
                  placeholder="نص الرسالة للعميل قبل الدفع..."
                  className="w-full p-3 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                />
                <div className="flex items-center justify-between">
                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="checkbox"
                      checked={alertAck}
                      onChange={(e) => setAlertAck(e.target.checked)}
                    />
                    <span>إلزام العميل بالتأكيد قبل رفع الطلب</span>
                  </label>
                  <button
                    type="submit"
                    className="px-5 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold"
                  >
                    نشر التنبيه الآن
                  </button>
                </div>
              </form>

              <div className="space-y-2.5">
                {checkoutAlerts.map((a) => (
                  <div
                    key={a.id}
                    className="p-4 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] flex items-center justify-between gap-3"
                  >
                    <div>
                      <div className="font-bold text-xs">
                        {a.title} ({a.severity})
                      </div>
                      <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">{a.message}</div>
                    </div>
                    <button
                      type="button"
                      onClick={() => deleteCheckoutAlert(a.id)}
                      className="p-1.5 text-rose-600 hover:bg-rose-500/10 rounded-lg"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* ADMIN: Staff Invites */}
          {adminTab === 'staff' && isManager && (
            <div className="space-y-4">
              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!inviteEmail.trim()) return;
                  await saveStaffInvite({
                    email: inviteEmail.trim().toLowerCase(),
                    name: inviteName.trim(),
                    role: inviteRoleVal,
                    active: true,
                  });
                  setInviteEmail('');
                  setInviteName('');
                }}
                className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] grid sm:grid-cols-4 gap-2.5"
              >
                <input
                  type="email"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  placeholder="البريد الإلكتروني للموظف *"
                  className="sm:col-span-2 px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                />
                <select
                  value={inviteRoleVal}
                  onChange={(e) => setInviteRoleVal(e.target.value as StaffRole)}
                  className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs"
                >
                  <option value="support">خدمة العملاء</option>
                  <option value="accounting">قسم المحاسبة</option>
                  <option value="shipping">إدارة الشحن</option>
                  <option value="marketer">مسوّق الكتالوج</option>
                  <option value="courier">مندوب توصيل</option>
                  <option value="manager">مدير</option>
                </select>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold"
                >
                  منح الصلاحية
                </button>
              </form>

              <div className="space-y-2">
                {staffInvites.map((inv) => (
                  <div
                    key={inv.email}
                    className="p-3.5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] flex items-center justify-between text-xs"
                  >
                    <div>
                      <span className="font-bold">{inv.email}</span> ·{' '}
                      <span className="text-violet-700 dark:text-violet-300 font-bold">
                        {ROLE_LABELS_AR[inv.role]}
                      </span>{' '}
                      · <span>{inv.active ? 'نشط' : 'مسحوب'}</span>
                    </div>
                    {inv.active && (
                      <button
                        type="button"
                        onClick={() => removeStaffInvite(inv.email)}
                        className="text-rose-600 font-bold hover:underline"
                      >
                        سحب الصلاحية
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* ADMIN: Audit & Deleted Records */}
          {adminTab === 'audit' && isManager && (
            <div className="grid md:grid-cols-2 gap-5">
              <div className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3">
                <div className="font-extrabold text-sm">سجل المحذوفات والأرشفة ({deletedRecords.length})</div>
                <div className="space-y-2 max-h-80 overflow-y-auto">
                  {deletedRecords.map((dr) => (
                    <div
                      key={dr.id}
                      className="p-3 rounded-xl bg-[#FAF8F5] dark:bg-[#0D0B14] text-xs space-y-0.5"
                    >
                      <div className="font-bold">{dr.label}</div>
                      <div className="text-[#5F5870] dark:text-[#A9A1BA]">
                        السبب: {dr.reason} · حُذف بواسطة: {dr.deletedByName}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3">
                <div className="font-extrabold text-sm">سجل تدقيق الموظفين ({auditLogs.length})</div>
                <div className="space-y-2 max-h-80 overflow-y-auto">
                  {auditLogs.map((al) => (
                    <div
                      key={al.id}
                      className="p-3 rounded-xl bg-[#FAF8F5] dark:bg-[#0D0B14] text-xs space-y-0.5"
                    >
                      <div className="font-bold">
                        {al.action} ({al.targetId})
                      </div>
                      <div className="text-[#5F5870] dark:text-[#A9A1BA]">
                        {al.actorName} ({ROLE_LABELS_AR[al.actorRole as StaffRole] || al.actorRole}) ·{' '}
                        {al.details}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Expanded Staff Order Preview Modal */}
      {previewOrder && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/65 p-4"
          onClick={() => setPreviewOrder(null)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-4xl max-h-[90vh] overflow-y-auto rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] p-6 space-y-5"
          >
            <div className="flex flex-wrap items-start justify-between gap-3 border-b border-black/10 dark:border-white/10 pb-4">
              <div>
                <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                  معاينة شاملة للطلب · {new Date(previewOrder.createdAt).toLocaleString('ar-YE')}
                </div>
                <h3 className="text-xl font-extrabold font-mono-num text-violet-700 dark:text-violet-300">
                  {previewOrder.orderNo} — {previewOrder.receiverName || previewOrder.customerName}
                </h3>
                <div className="text-xs font-semibold mt-1">
                  الحالة: {previewOrder.status} · مرحلة الشحن: {previewOrder.shippingStage} · الخطة:{' '}
                  {previewOrder.paymentPlan === 'half_deferred' ? 'آجل 50%' : 'دفع كامل'}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => {
                    const target = previewOrder;
                    setPreviewOrder(null);
                    openOrderEditor(target);
                  }}
                  className="px-4 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold"
                >
                  فتح محرر الإدارة والتتبع
                </button>
                <button
                  type="button"
                  onClick={() => setPreviewOrder(null)}
                  className="p-2 rounded-xl border border-black/15 dark:border-white/15"
                  aria-label="إغلاق"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            </div>

            <div className="grid md:grid-cols-2 gap-4">
              {/* Customer & Address Details */}
              <div className="p-4 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/10 dark:border-white/10 space-y-2 text-xs">
                <div className="font-extrabold text-sm">بيانات العميل والعنوان الكامل</div>
                <div>
                  المستلم: <strong>{previewOrder.receiverName || previewOrder.address?.receiverName}</strong>
                </div>
                <div>
                  الهاتف:{' '}
                  <span className="font-mono-num font-bold">
                    {previewOrder.receiverPhone || previewOrder.address?.phone || '—'}
                  </span>
                </div>
                <div>البريد الإلكتروني: {previewOrder.customerEmail || '—'}</div>
                <div>
                  المحافظة والحي: <strong>{previewOrder.shippingGovernorate || previewOrder.address?.city}</strong>
                  {previewOrder.address?.district ? ` — ${previewOrder.address.district}` : ''}
                </div>
                <div>التفاصيل: {previewOrder.address?.line || '—'}</div>
                <div>
                  طريقة التسليم:{' '}
                  {previewOrder.shippingMode === 'driver'
                    ? `سائق مباشر (${previewOrder.driverName || 'غير محدد'})`
                    : previewOrder.shippingMode === 'pickup'
                    ? 'استلام من مقر الشركة'
                    : `مكتب شحن (${previewOrder.shippingOfficeChoice || previewOrder.shippingOffice || 'الافتراضي'})`}
                </div>
                {previewOrder.trackingNo && (
                  <div className="font-mono-num">رقم التتبع: {previewOrder.trackingNo}</div>
                )}
              </div>

              {/* Payment Summary & Zoomable Transfer Proof */}
              <div className="p-4 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/10 dark:border-white/10 space-y-2 text-xs">
                <div className="font-extrabold text-sm">بيانات الحوالة وإثبات الدفع</div>
                <div className="font-mono-num font-bold text-violet-700 dark:text-violet-300">
                  الإجمالي: {formatMoney(previewOrder.totalLocal, previewOrder.currency)} ({previewOrder.totalSar.toFixed(2)} SAR)
                </div>
                <div>
                  المدفوع: {formatMoney(previewOrder.paidTotalLocal, previewOrder.currency)} · المتبقي:{' '}
                  {formatMoney(previewOrder.remainingLocal, previewOrder.currency)}
                </div>
                <div>الحساب: {previewOrder.payment?.accountTitleAr || 'لم يُحدد'} ({previewOrder.payment?.accountNumber || '—'})</div>
                <div>
                  المحول: {previewOrder.payment?.senderName || '—'} · المرجع:{' '}
                  <span className="font-mono-num">{previewOrder.payment?.refNo || '—'}</span>
                </div>

                {(previewOrder.payment?.proofUrl || previewOrder.proofImageUrl) ? (
                  <div className="pt-2 space-y-2">
                    <div className="rounded-2xl overflow-hidden border border-black/15 dark:border-white/15 bg-white">
                      <img
                        src={sanitizeImageUrl(
                          previewOrder.payment?.proofUrl || previewOrder.proofImageUrl,
                          BRAND_IMAGES.kaftan
                        )}
                        alt="صورة الحوالة"
                        onClick={() =>
                          setZoomProofUrl(
                            sanitizeImageUrl(
                              previewOrder.payment?.proofUrl || previewOrder.proofImageUrl,
                              BRAND_IMAGES.kaftan
                            )
                          )
                        }
                        className="w-full max-h-52 object-contain cursor-zoom-in"
                      />
                    </div>
                    <button
                      type="button"
                      onClick={() =>
                        setZoomProofUrl(
                          sanitizeImageUrl(
                            previewOrder.payment?.proofUrl || previewOrder.proofImageUrl,
                            BRAND_IMAGES.kaftan
                          )
                        )
                      }
                      className="px-3.5 py-1.5 rounded-xl border border-violet-500/40 text-violet-700 dark:text-violet-300 font-bold inline-flex items-center gap-1.5"
                    >
                      <ZoomIn className="w-3.5 h-3.5" />
                      <span>تكبير صورة الحوالة بدقة كاملة</span>
                    </button>
                  </div>
                ) : (
                  <div className="text-amber-700 dark:text-amber-300 pt-1">
                    لم تُرفق صورة حوالة لهذا الطلب بعد.
                  </div>
                )}
              </div>
            </div>

            {/* Full Itemized List with Clickable SHEIN Links */}
            <div className="space-y-3">
              <div className="font-extrabold text-sm">
                قائمة القطع المطلوبة ({previewOrder.items.length})
              </div>
              <div className="divide-y divide-black/10 dark:divide-white/10 rounded-2xl border border-black/10 dark:border-white/10 overflow-hidden">
                {previewOrder.items.map((it, idx) => (
                  <div
                    key={idx}
                    className="p-3.5 flex flex-wrap items-center justify-between gap-3 bg-white dark:bg-[#151122]"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <img
                        src={sanitizeImageUrl(it.imageUrl, BRAND_IMAGES.kaftan)}
                        alt={it.title}
                        onClick={() =>
                          setZoomProofUrl(sanitizeImageUrl(it.imageUrl, BRAND_IMAGES.kaftan))
                        }
                        className="w-16 h-16 rounded-xl object-cover bg-[#F3EFE9] shrink-0 cursor-zoom-in"
                      />
                      <div className="min-w-0 space-y-1">
                        <div className="font-bold text-xs sm:text-sm">{it.title}</div>
                        <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                          اللون: {it.color} · المقاس: {it.size} · الكمية: {it.qty} · الكود: #{it.goodsId}
                        </div>
                        {it.productUrl && /^https?:\/\//i.test(it.productUrl) && (
                          <a
                            href={it.productUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1 text-xs font-bold text-violet-700 dark:text-violet-300 hover:underline"
                          >
                            <ExternalLink className="w-3.5 h-3.5" />
                            <span>فتح رابط SHEIN للشراء</span>
                          </a>
                        )}
                      </div>
                    </div>
                    <div className="text-end font-mono-num">
                      <div className="font-extrabold text-sm">
                        {(it.unitPriceSar * it.qty).toFixed(2)} SAR
                      </div>
                      <div className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">
                        {it.unitPriceSar.toFixed(2)} × {it.qty}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* High-Resolution Image Zoom Lightbox */}
      {zoomProofUrl && (
        <div
          className="fixed inset-0 z-[60] flex items-center justify-center bg-black/85 p-4"
          onClick={() => setZoomProofUrl(null)}
        >
          <div className="relative max-w-3xl w-full flex flex-col items-center">
            <button
              type="button"
              onClick={() => setZoomProofUrl(null)}
              className="mb-3 px-4 py-1.5 rounded-xl bg-white/15 text-white text-xs font-bold flex items-center gap-1.5"
            >
              <X className="w-4 h-4" />
              <span>إغلاق المعاينة</span>
            </button>
            <img
              src={zoomProofUrl}
              alt="معاينة الصورة بدقة عالية"
              onClick={(e) => e.stopPropagation()}
              className="max-h-[82vh] max-w-full rounded-2xl object-contain bg-white"
            />
          </div>
        </div>
      )}
    </div>
  );
};

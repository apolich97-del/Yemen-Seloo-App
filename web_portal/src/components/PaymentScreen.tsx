import React, { useEffect, useState } from 'react';
import {
  ArrowRight,
  CheckCircle2,
  Copy,
  Download,
  Edit3,
  Image as ImageIcon,
  MapPin,
  MessageCircle,
  Upload,
  X,
  ZoomIn,
} from 'lucide-react';
import { compressImageToDataUrl } from '../config/firebase';
import { accountsForCurrency, YEMEN_GOVERNORATES } from '../config/selooConfig';
import { useSeloo } from '../context/SelooContext';
import { formatMoney } from '../services/pricingService';
import {
  buildWhatsAppOrderForm,
  downloadDataUrl,
  generateOrderSummaryCardPng,
} from '../services/receiptPdfService';
import { Order } from '../types/seloo';

interface PaymentScreenProps {
  order: Order;
  onBack: () => void;
  onComplete: () => void;
}

export const PaymentScreen: React.FC<PaymentScreenProps> = ({
  order,
  onBack,
  onComplete,
}) => {
  const {
    settings,
    submitOrderPayment,
    recordWhatsAppSubmission,
    updateOrderAddress,
    notifyToast,
  } = useSeloo();

  const accounts = accountsForCurrency(order.currency);
  const [selectedAccId, setSelectedAccId] = useState(
    order.payment?.accountId || accounts[0]?.id || ''
  );
  const selectedAcc =
    accounts.find((a) => a.id === selectedAccId) || accounts[0];

  const [senderName, setSenderName] = useState(
    order.payment?.senderName || order.receiverName || ''
  );
  const [amount, setAmount] = useState(
    String(order.payment?.amount || order.upfrontDueLocal || order.totalLocal)
  );
  const [refNo, setRefNo] = useState(order.payment?.refNo || '');
  const [note, setNote] = useState(order.payment?.note || '');
  const [proofUrl, setProofUrl] = useState(order.payment?.proofUrl || '');
  const [zoomProofOpen, setZoomProofOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submittedOk, setSubmittedOk] = useState(Boolean(order.payment?.proofUrl));
  const [summaryCardPng, setSummaryCardPng] = useState(order.orderSummaryImageUrl || '');

  // Inline Address Edit State on Payment Screen
  const [addrEditing, setAddrEditing] = useState(false);
  const [addrReceiver, setAddrReceiver] = useState(
    order.receiverName || order.address.receiverName || ''
  );
  const [addrPhone, setAddrPhone] = useState(
    order.receiverPhone || order.address.phone || ''
  );
  const [addrCity, setAddrCity] = useState(
    order.shippingGovernorate || order.address.city || YEMEN_GOVERNORATES[0].name
  );
  const [addrDistrict, setAddrDistrict] = useState(order.address.district || '');
  const [addrLine, setAddrLine] = useState(order.address.line || '');

  useEffect(() => {
    // Auto-generate HD PNG confirmation card with QR on mount
    if (!summaryCardPng) {
      const png = generateOrderSummaryCardPng(order, settings);
      setSummaryCardPng(png);
    }
  }, [order, settings, summaryCardPng]);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const dataUrl = await compressImageToDataUrl(file, 950, 0.72);
      setProofUrl(dataUrl);
      notifyToast('تم تجهيز صورة الحوالة — يمكنك معاينتها أو تكبيرها قبل الإرسال', 'success');
    } catch (err: unknown) {
      notifyToast(err instanceof Error ? err.message : 'تعذر تحميل الصورة', 'error');
    }
  };

  const handleCopy = async (txt: string, label: string) => {
    try {
      await navigator.clipboard.writeText(txt);
      notifyToast(`تم نسخ ${label}`, 'success');
    } catch {
      notifyToast('تعذر النسخ', 'error');
    }
  };

  const handleSubmitProof = async (e: React.FormEvent) => {
    e.preventDefault();
    const numAmount = parseFloat(amount);
    if (!selectedAcc) return;
    if (senderName.trim().length < 3) {
      notifyToast('يرجى كتابة اسم المرسل كما في الحوالة', 'error');
      return;
    }
    if (!Number.isFinite(numAmount) || numAmount < order.upfrontDueLocal * 0.99) {
      notifyToast(
        `يجب أن يساوي المبلغ المطلوب على الأقل ${formatMoney(
          order.upfrontDueLocal,
          order.currency
        )}`,
        'error'
      );
      return;
    }
    if (!proofUrl) {
      notifyToast('يرجى إرفاق صورة الحوالة أولاً', 'error');
      return;
    }

    setSubmitting(true);
    try {
      await submitOrderPayment(order.id, {
        accountId: selectedAcc.id,
        accountTitleAr: selectedAcc.titleAr,
        accountNumber: selectedAcc.numbers[0],
        amount: numAmount,
        senderName: senderName.trim(),
        refNo: refNo.trim(),
        note: note.trim(),
        proofUrl,
        creditLocal: 0,
        confirmedByName: '',
      });
      setSubmittedOk(true);
    } catch (err: unknown) {
      notifyToast(
        err instanceof Error ? err.message : 'تعذر حفظ بيانات الحوالة',
        'error'
      );
    } finally {
      setSubmitting(false);
    }
  };

  const handleWhatsAppSend = async (targetPhone: string) => {
    const formText = buildWhatsAppOrderForm(order, settings);
    const png = summaryCardPng || generateOrderSummaryCardPng(order, settings);
    setSummaryCardPng(png);

    // Copy text automatically + download HD card + record whatsappSentAt in Firestore
    try {
      await navigator.clipboard.writeText(formText);
    } catch {
      // ignore clipboard restriction
    }
    if (png) {
      downloadDataUrl(png, `Seloo-Order-${order.orderNo}.png`);
    }
    try {
      await recordWhatsAppSubmission(order.id, targetPhone, png.slice(0, 120000));
    } catch {
      // ignore non-critical logging
    }

    notifyToast(
      'تم نسخ الاستمارة وتحميل بطاقة الطلب HD — أرفق الصورة في واتساب واضغط إرسال',
      'success'
    );
    const url = `https://wa.me/${targetPhone}?text=${encodeURIComponent(formText)}`;
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.target = '_blank';
    anchor.rel = 'noopener noreferrer';
    anchor.click();
  };

  return (
    <div className="max-w-5xl mx-auto space-y-6 pb-16">
      <div className="flex items-center justify-between border-b border-black/10 dark:border-white/10 pb-4">
        <button
          type="button"
          onClick={onBack}
          className="flex items-center gap-2 text-sm font-bold text-[#5F5870] dark:text-[#A9A1BA] hover:text-violet-600"
        >
          <ArrowRight className="w-4 h-4" />
          <span>رجوع</span>
        </button>
        <div className="text-end">
          <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">رقم الطلب</div>
          <div className="font-mono-num font-extrabold text-lg text-violet-700 dark:text-violet-300">
            {order.orderNo}
          </div>
        </div>
      </div>

      {/* Inline Address Card + "تعديل العنوان" button */}
      <div className="p-4 sm:p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2 font-bold text-sm">
            <MapPin className="w-4 h-4 text-violet-600 dark:text-violet-400" />
            <span>عنوان الاستلام المسجّل</span>
          </div>
          <button
            type="button"
            onClick={() => setAddrEditing((v) => !v)}
            className="px-3 py-1.5 rounded-xl border border-violet-600/30 text-violet-700 dark:text-violet-300 text-xs font-bold flex items-center gap-1.5 hover:bg-violet-600/10"
          >
            <Edit3 className="w-3.5 h-3.5" />
            <span>{addrEditing ? 'إغلاق' : 'تعديل العنوان'}</span>
          </button>
        </div>

        {!addrEditing ? (
          <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA] flex flex-wrap gap-3">
            <span className="font-bold text-[#171321] dark:text-[#F6F3EC]">{addrReceiver}</span>
            <span className="font-mono-num">{addrPhone}</span>
            <span>
              {addrCity}
              {addrDistrict ? ` - ${addrDistrict}` : ''} — {addrLine}
            </span>
          </div>
        ) : (
          <div className="grid sm:grid-cols-2 lg:grid-cols-5 gap-2.5 pt-2 border-t border-black/10 dark:border-white/10">
            <input
              type="text"
              value={addrReceiver}
              onChange={(e) => setAddrReceiver(e.target.value)}
              placeholder="اسم المستلم"
              className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
            />
            <input
              type="tel"
              value={addrPhone}
              onChange={(e) => setAddrPhone(e.target.value)}
              placeholder="رقم الهاتف"
              className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
            />
            <select
              value={addrCity}
              onChange={(e) => setAddrCity(e.target.value)}
              className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs"
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
              placeholder="المديرية (اختياري)"
              className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
            />
            <div className="flex gap-2">
              <input
                type="text"
                value={addrLine}
                onChange={(e) => setAddrLine(e.target.value)}
                placeholder="العنوان التفصيلي"
                className="flex-1 min-w-0 px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
              />
              <button
                type="button"
                onClick={async () => {
                  const nextAddr = {
                    ...order.address,
                    receiverName: addrReceiver.trim() || order.receiverName,
                    phone: addrPhone.trim() || order.receiverPhone,
                    city: addrCity,
                    district: addrDistrict.trim(),
                    line: addrLine.trim() || order.address.line,
                  };
                  await updateOrderAddress(order.id, nextAddr);
                  const updatedOrder = {
                    ...order,
                    address: nextAddr,
                    receiverName: nextAddr.receiverName,
                    receiverPhone: nextAddr.phone,
                    shippingGovernorate: nextAddr.city,
                  };
                  setSummaryCardPng(generateOrderSummaryCardPng(updatedOrder, settings));
                  setAddrEditing(false);
                }}
                className="px-3.5 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold shrink-0"
              >
                حفظ
              </button>
            </div>
          </div>
        )}
      </div>

      <div className="grid lg:grid-cols-12 gap-6 items-start">
        {/* Left: Accounts & Proof Upload */}
        <form
          onSubmit={handleSubmitProof}
          className="lg:col-span-7 p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-5"
        >
          <div className="flex items-center justify-between">
            <h2 className="font-extrabold text-lg">1. التحويل وإرفاق صورة الحوالة</h2>
            <span className="font-mono-num font-extrabold text-sm text-violet-700 dark:text-violet-300">
              المطلوب: {formatMoney(order.upfrontDueLocal, order.currency)}
            </span>
          </div>

          <div className="space-y-2.5">
            {accounts.map((acc) => {
              const active = acc.id === selectedAcc?.id;
              return (
                <div
                  key={acc.id}
                  onClick={() => setSelectedAccId(acc.id)}
                  className={`p-4 rounded-2xl border cursor-pointer transition-all ${
                    active
                      ? 'border-violet-600 bg-violet-600/8'
                      : 'border-black/10 dark:border-white/10 hover:border-violet-500/40'
                  }`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <div>
                      <div className="font-bold text-sm">{acc.titleAr}</div>
                      <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                        {acc.noteAr}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleCopy(acc.numbers[0], acc.titleAr);
                      }}
                      className="px-3 py-1.5 rounded-xl bg-[#F3EFE9] dark:bg-[#1E1830] text-xs font-mono-num font-bold flex items-center gap-1.5 hover:bg-violet-600 hover:text-white transition-colors shrink-0"
                    >
                      <span>{acc.numbers[0]}</span>
                      <Copy className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="grid sm:grid-cols-2 gap-3 pt-2">
            <div>
              <label className="text-xs font-bold block mb-1">اسم المرسل في الحوالة *</label>
              <input
                type="text"
                value={senderName}
                onChange={(e) => setSenderName(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
              />
            </div>
            <div>
              <label className="text-xs font-bold block mb-1">المبلغ المحول *</label>
              <input
                type="number"
                step="0.01"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
              />
            </div>
          </div>

          <div className="grid sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-bold block mb-1">رقم المرجع / الإيصال (اختياري)</label>
              <input
                type="text"
                value={refNo}
                onChange={(e) => setRefNo(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
              />
            </div>
            <div>
              <label className="text-xs font-bold block mb-1">ملاحظة</label>
              <input
                type="text"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
              />
            </div>
          </div>

          {/* Point 12: Payment Proof Upload + Inline Preview + Zoom Modal */}
          <div className="space-y-2.5">
            <label className="text-xs font-bold block">صورة الحوالة *</label>
            <label className="flex flex-col items-center justify-center p-5 rounded-2xl border-2 border-dashed border-black/15 dark:border-white/15 hover:border-violet-500 cursor-pointer transition-colors bg-[#FAF8F5] dark:bg-[#0D0B14]">
              <Upload className="w-6 h-6 text-violet-600 dark:text-violet-400 mb-1.5" />
              <span className="text-xs font-bold">
                {proofUrl ? 'تغيير صورة الحوالة' : 'اختر صورة الحوالة من جهازك'}
              </span>
              <input
                type="file"
                accept="image/*"
                onChange={handleFileChange}
                className="hidden"
              />
            </label>

            {proofUrl && (
              <div className="p-3.5 rounded-2xl border border-black/10 dark:border-white/10 bg-[#F3EFE9] dark:bg-[#1E1830] space-y-3">
                <div className="flex items-center justify-between gap-4">
                  <div className="flex items-center gap-2 text-xs font-bold text-emerald-700 dark:text-emerald-300">
                    <ImageIcon className="w-4 h-4" />
                    <span>معاينة صورة الحوالة بدقة عالية</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <button
                      type="button"
                      onClick={() => setZoomProofOpen(true)}
                      className="text-xs font-bold text-violet-700 dark:text-violet-300 flex items-center gap-1 hover:underline"
                    >
                      <ZoomIn className="w-3.5 h-3.5" />
                      <span>تكبير الشاشة</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setProofUrl('')}
                      className="text-xs font-bold text-rose-600 hover:underline"
                    >
                      حذف
                    </button>
                  </div>
                </div>
                <div
                  onClick={() => setZoomProofOpen(true)}
                  className="cursor-zoom-in rounded-xl overflow-hidden border border-black/10 dark:border-white/10 bg-white max-h-64 flex items-center justify-center"
                >
                  <img
                    src={proofUrl}
                    alt="معاينة الحوالة"
                    className="w-full max-h-64 object-contain"
                  />
                </div>
              </div>
            )}
          </div>

          <button
            type="submit"
            disabled={submitting}
            className="w-full py-3.5 rounded-xl bg-violet-600 hover:bg-violet-700 text-white font-bold text-sm flex items-center justify-center gap-2 disabled:opacity-60"
          >
            <CheckCircle2 className="w-4 h-4" />
            <span>{submitting ? 'جاري الرفع...' : 'تأكيد ورفع بيانات الحوالة'}</span>
          </button>
        </form>

        {/* Right: Point 2 HD Order Summary Card (PNG + QR) + WhatsApp Confirmation */}
        <div className="lg:col-span-5 space-y-4">
          <div className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
            <h2 className="font-extrabold text-lg">2. إرسال الاستمارة لواتساب الإدارة</h2>
            <p className="text-xs text-[#5F5870] dark:text-[#A9A1BA] leading-relaxed">
              تُنشأ بطاقة استمارة طلب عالية الدقة تتضمن رمز QR وكامل بيانات الطلب بالعملات الأربع، مع نسخ النص الرسمي تلقائياً عند فتح واتساب.
            </p>

            {summaryCardPng && (
              <div className="rounded-2xl overflow-hidden border border-black/10 dark:border-white/10 bg-[#FAF8F5]">
                <img
                  src={summaryCardPng}
                  alt="بطاقة تأكيد الطلب"
                  className="w-full h-auto"
                />
              </div>
            )}

            <div className="grid grid-cols-2 gap-2.5">
              <button
                type="button"
                onClick={() => handleWhatsAppSend(settings.supportWhatsApp || '967770518757')}
                className="py-3 px-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold flex items-center justify-center gap-1.5"
              >
                <MessageCircle className="w-4 h-4" />
                <span>واتساب {settings.supportPhone || '770518757'}</span>
              </button>
              <button
                type="button"
                onClick={() => handleWhatsAppSend(settings.alternateWhatsApp || '967737383637')}
                className="py-3 px-3 rounded-xl bg-emerald-700 hover:bg-emerald-800 text-white text-xs font-bold flex items-center justify-center gap-1.5"
              >
                <MessageCircle className="w-4 h-4" />
                <span>واتساب 737383637</span>
              </button>
            </div>

            {summaryCardPng && (
              <button
                type="button"
                onClick={() =>
                  downloadDataUrl(summaryCardPng, `Seloo-Order-${order.orderNo}.png`)
                }
                className="w-full py-2.5 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold flex items-center justify-center gap-2 hover:bg-black/5 dark:hover:bg-white/5"
              >
                <Download className="w-4 h-4" />
                <span>حفظ بطاقة الاستمارة PNG على الجهاز</span>
              </button>
            )}

            {submittedOk && (
              <button
                type="button"
                onClick={onComplete}
                className="w-full py-3 rounded-xl bg-[#171321] dark:bg-violet-600 text-white text-sm font-bold"
              >
                الانتقال لمتابعة طلبي
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Proof Zoom Modal */}
      {zoomProofOpen && proofUrl && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
          onClick={() => setZoomProofOpen(false)}
        >
          <div className="relative max-w-2xl w-full" onClick={(e) => e.stopPropagation()}>
            <button
              type="button"
              onClick={() => setZoomProofOpen(false)}
              className="absolute -top-10 left-0 p-2 rounded-full bg-white/15 text-white hover:bg-white/25"
            >
              <X className="w-5 h-5" />
            </button>
            <img
              src={proofUrl}
              alt="تكبير الحوالة"
              className="w-full max-h-[82vh] object-contain rounded-2xl bg-white"
            />
          </div>
        </div>
      )}
    </div>
  );
};

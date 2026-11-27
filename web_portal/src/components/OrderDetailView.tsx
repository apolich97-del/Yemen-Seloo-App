import React, { useRef, useState } from 'react';
import {
  AlertTriangle,
  ArrowRight,
  CheckCircle2,
  ExternalLink,
  PenTool,
  Printer,
  Receipt,
  RefreshCw,
  RotateCcw,
  ShieldCheck,
  Upload,
  X,
  ZoomIn,
} from 'lucide-react';
import { compressImageToDataUrl } from '../config/firebase';
import { useSeloo } from '../context/SelooContext';
import { BRAND_IMAGES } from '../data/seedData';
import {
  computeCurrencyMatrix,
  formatMoney,
  orderLockedRemainingInfo,
  sanitizeImageUrl,
} from '../services/pricingService';
import { printOrderInvoiceOrWaybill } from '../services/receiptPdfService';
import {
  ORDER_STAGE_BAR,
  orderStatusLabelAr,
} from '../services/shipmentTrackingService';
import { Order, OrderStatus } from '../types/seloo';
import { ShipmentTrackingMap } from './ShipmentTrackingMap';

interface OrderDetailViewProps {
  order: Order;
  onBack: () => void;
  onOpenPayment: (order: Order) => void;
}

export const OrderDetailView: React.FC<OrderDetailViewProps> = ({
  order,
  onBack,
  onOpenPayment,
}) => {
  const {
    settings,
    respondPriceSync,
    submitReplacementProposal,
    submitElectronicSignature,
    submitRefundRequest,
    orderReceipts,
    submitOrderReceipt,
    notifyToast,
  } = useSeloo();

  const [zoomImg, setZoomImg] = useState<string | null>(null);
  const [rcAmount, setRcAmount] = useState(
    String(order.remainingLocal > 0 ? order.remainingLocal : order.upfrontDueLocal || '')
  );
  const [rcSender, setRcSender] = useState(order.receiverName || '');
  const [rcRef, setRcRef] = useState('');
  const [rcProof, setRcProof] = useState('');
  const [rcSubmitting, setRcSubmitting] = useState(false);

  // Smart Replacement after 24h ("البديل الذكي")
  const [repTitle, setRepTitle] = useState('');
  const [repUrl, setRepUrl] = useState('');
  const [repPriceSar, setRepPriceSar] = useState(
    String(order.replacementProposal?.targetItemPriceSar || '')
  );
  const [repSubmitting, setRepSubmitting] = useState(false);

  // Electronic Signature Pad + PIN
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [drawing, setDrawing] = useState(false);
  const [hasDrawn, setHasDrawn] = useState(false);
  const [pinInput, setPinInput] = useState('');
  const [sigSubmitting, setSigSubmitting] = useState(false);

  // Refund modal
  const [refundOpen, setRefundOpen] = useState(false);
  const [refundType, setRefundType] = useState<
    'damaged' | 'wrong_item' | 'missing' | 'other'
  >('damaged');
  const [refundReason, setRefundReason] = useState('');
  const [refundBank, setRefundBank] = useState('بنك الكريمي');
  const [refundAccountNo, setRefundAccountNo] = useState('');

  const locked = orderLockedRemainingInfo(order);
  const stageIdx = Math.max(
    0,
    ORDER_STAGE_BAR.findIndex((s) => s.status === order.status)
  );
  const matrix = computeCurrencyMatrix(order.totalSar, {
    ...settings,
    rateNorth: order.currency === 'north' ? order.exchangeRate : settings.rateNorth,
    rateSouth: order.currency === 'south' ? order.exchangeRate : settings.rateSouth,
    usdRateNorth: order.usdRateNorth || settings.usdRateNorth,
    usdRateSouth: order.usdRateSouth || settings.usdRateSouth,
    sarPerUsd: order.sarPerUsd || settings.sarPerUsd,
  });

  const hasNonRefundable = order.items.some((i) => i.nonRefundable);

  // Canvas drawing helpers
  const startDraw = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.strokeStyle = '#171321';
    ctx.lineWidth = 2.6;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(e.clientX - rect.left, e.clientY - rect.top);
    setDrawing(true);
    setHasDrawn(true);
  };

  const moveDraw = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!drawing) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.lineTo(e.clientX - rect.left, e.clientY - rect.top);
    ctx.stroke();
  };

  const endDraw = () => setDrawing(false);

  const clearSignature = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    setHasDrawn(false);
  };

  const handleSaveSignature = async () => {
    const canvas = canvasRef.current;
    if (!canvas || !hasDrawn) {
      notifyToast('يرجى رسم توقيعك داخل المربع أولاً', 'error');
      return;
    }
    setSigSubmitting(true);
    // Render crisp signature with white background for clean print/PDF
    const out = document.createElement('canvas');
    out.width = canvas.width;
    out.height = canvas.height;
    const octx = out.getContext('2d');
    if (octx) {
      octx.fillStyle = '#FFFFFF';
      octx.fillRect(0, 0, out.width, out.height);
      octx.drawImage(canvas, 0, 0);
    }
    const dataUrl = out.toDataURL('image/png');
    await submitElectronicSignature(order.id, dataUrl, pinInput);
    setSigSubmitting(false);
  };

  const handleReplacementSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const p = parseFloat(repPriceSar);
    if (!repTitle.trim() || !Number.isFinite(p) || p <= 0) {
      notifyToast('أدخل اسم القطعة البديلة وسعرها بالريال السعودي', 'error');
      return;
    }
    setRepSubmitting(true);
    await submitReplacementProposal(order.id, {
      title: repTitle.trim(),
      url: repUrl.trim(),
      priceSar: p,
    });
    setRepSubmitting(false);
    setRepTitle('');
    setRepUrl('');
  };

  const handleRefundSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!refundReason.trim() || !refundAccountNo.trim()) {
      notifyToast('أكمل سبب الاسترداد ورقم الحساب', 'error');
      return;
    }
    await submitRefundRequest(order.id, {
      amountSar: order.totalSar,
      reason: refundReason.trim(),
      reasonType: refundType,
      bankOrWallet: refundBank,
      accountNo: refundAccountNo.trim(),
    });
    setRefundOpen(false);
    setRefundReason('');
  };

  return (
    <div className="space-y-6 pb-16">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-black/10 dark:border-white/10 pb-4">
        <button
          type="button"
          onClick={onBack}
          className="flex items-center gap-2 text-sm font-bold text-[#5F5870] dark:text-[#A9A1BA] hover:text-violet-600"
        >
          <ArrowRight className="w-4 h-4" />
          <span>العودة لطلباتي</span>
        </button>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => printOrderInvoiceOrWaybill(order, settings, 'invoice')}
            className="px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold flex items-center gap-1.5 hover:bg-black/5 dark:hover:bg-white/5"
          >
            <Printer className="w-3.5 h-3.5" />
            <span>طباعة الفاتورة PDF</span>
          </button>
          <button
            type="button"
            onClick={() => printOrderInvoiceOrWaybill(order, settings, 'waybill')}
            className="px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold flex items-center gap-1.5 hover:bg-black/5 dark:hover:bg-white/5"
          >
            <Printer className="w-3.5 h-3.5" />
            <span>بوليصة التسليم</span>
          </button>
          {(order.status === OrderStatus.unpaid || !order.whatsappSentAt) && (
            <button
              type="button"
              onClick={() => onOpenPayment(order)}
              className="px-4 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold hover:bg-violet-700"
            >
              الدفع / إرسال الاستمارة
            </button>
          )}
        </div>
      </div>

      {/* Header & Stage Bar */}
      <div className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-5">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
              تاريخ الطلب: {new Date(order.createdAt).toLocaleString('ar-YE')}
            </div>
            <h1 className="text-2xl font-extrabold font-mono-num text-violet-700 dark:text-violet-300 mt-0.5">
              {order.orderNo}
            </h1>
            <div className="text-sm font-bold mt-1">{orderStatusLabelAr(order.status)}</div>
          </div>

          <div className="text-end space-y-1">
            <div className="font-mono-num font-extrabold text-xl">
              {formatMoney(order.totalLocal, order.currency)}
            </div>
            <div className="text-xs font-mono-num text-[#5F5870] dark:text-[#A9A1BA]">
              {matrix.sar.toFixed(2)} SAR · ${matrix.usd.toFixed(2)} · سعر الطلب: {locked.lockedRate}
            </div>
            {order.paymentPlan === 'half_deferred' && (
              <div className="text-xs font-bold text-amber-700 dark:text-amber-300">
                آجل 50% (سعر الصرف مثبّت بسعر يوم الطلب) · المتبقي:{' '}
                <span className="font-mono-num">
                  {formatMoney(locked.remainingLocal, order.currency)}
                </span>
              </div>
            )}
          </div>
        </div>

        {/* 6-Stage Order Progress Bar */}
        <div className="grid grid-cols-3 sm:grid-cols-6 gap-2 pt-2">
          {ORDER_STAGE_BAR.map((st, idx) => {
            const active = order.status !== OrderStatus.cancelled && idx <= stageIdx;
            return (
              <div key={st.status} className="space-y-1.5">
                <div
                  className={`h-2 rounded-full ${
                    active
                      ? 'bg-violet-600'
                      : 'bg-black/10 dark:bg-white/10'
                  }`}
                />
                <div
                  className={`text-[11px] text-center ${
                    active
                      ? 'font-bold text-violet-700 dark:text-violet-300'
                      : 'text-[#5F5870] dark:text-[#A9A1BA]'
                  }`}
                >
                  {st.labelAr}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Price / Stock Sync Proposal Banner */}
      {order.priceSyncStatus === 'pending_customer' && (
        <div className="p-5 rounded-2xl border border-amber-500/40 bg-amber-500/10 space-y-3">
          <div className="flex items-center gap-2 font-extrabold text-amber-900 dark:text-amber-200">
            <RefreshCw className="w-5 h-5" />
            <span>تنبيه مزامنة السعر والمخزون من الإدارة</span>
          </div>
          <p className="text-sm text-[#171321] dark:text-[#F6F3EC]">
            {order.priceSyncNote ||
              'طرأ تحديث على سعر أو توفر إحدى القطع في المصدر قبل الشراء.'}
          </p>
          <div className="text-xs font-mono-num font-bold">
            السعر السابق: {formatMoney(order.totalLocal, order.currency)} ← المقترح:{' '}
            {formatMoney(order.proposedTotalLocal, order.currency)}
          </div>
          <div className="flex flex-wrap gap-2.5 pt-1">
            <button
              type="button"
              onClick={() => respondPriceSync(order.id, true)}
              className="px-4 py-2 rounded-xl bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700"
            >
              موافق على السعر المحدّث
            </button>
            <button
              type="button"
              onClick={() => respondPriceSync(order.id, false)}
              className="px-4 py-2 rounded-xl border border-rose-600/40 text-rose-700 dark:text-rose-300 text-xs font-bold hover:bg-rose-500/10"
            >
              رفض ومراجعة الدعم
            </button>
          </div>
        </div>
      )}

      {/* Smart Replacement after 24h ("البديل الذكي") */}
      {order.replacementStatus === 'pending_customer' && (
        <form
          onSubmit={handleReplacementSubmit}
          className="p-6 rounded-3xl border border-violet-500/40 bg-violet-500/8 space-y-4"
        >
          <div className="flex items-start gap-2.5">
            <AlertTriangle className="w-5 h-5 text-violet-600 dark:text-violet-300 shrink-0 mt-0.5" />
            <div>
              <h3 className="font-extrabold text-base">
                تنبيه نفاد قطعة بعد 24 ساعة — خدمة البديل الذكي
              </h3>
              <p className="text-xs text-[#5F5870] dark:text-[#A9A1BA] mt-1">
                {order.replacementAlert ||
                  `نفدت القطعة (${
                    order.replacementProposal?.targetItemTitle || 'قطعة في طلبك'
                  }). أرسل رابط البديل بنفس القيمة أو بتسوية الفارق تلقائياً.`}
              </p>
            </div>
          </div>

          <div className="grid sm:grid-cols-3 gap-3">
            <input
              type="text"
              value={repTitle}
              onChange={(e) => setRepTitle(e.target.value)}
              placeholder="اسم / وصف القطعة البديلة *"
              className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
            />
            <input
              type="url"
              value={repUrl}
              onChange={(e) => setRepUrl(e.target.value)}
              placeholder="رابط SHEIN للبديل *"
              className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
            />
            <input
              type="number"
              step="0.01"
              value={repPriceSar}
              onChange={(e) => setRepPriceSar(e.target.value)}
              placeholder="سعر البديل بالريال السعودي *"
              className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm font-mono-num"
            />
          </div>

          <button
            type="submit"
            disabled={repSubmitting}
            className="px-5 py-2.5 rounded-xl bg-violet-600 text-white text-xs font-bold hover:bg-violet-700"
          >
            {repSubmitting ? 'جاري الإرسال...' : 'اعتماد وإرسال القطعة البديلة'}
          </button>
        </form>
      )}

      {order.replacementStatus === 'pending_admin' && order.replacementProposal && (
        <div className="p-4 rounded-2xl border border-emerald-500/30 bg-emerald-500/10 text-xs space-y-1">
          <div className="font-bold text-emerald-800 dark:text-emerald-200">
            تم إرسال البديل بانتظار اعتماد الإدارة: {order.replacementProposal.replacementTitle}
          </div>
          <div>التسوية المالية: {order.replacementProposal.settlementNote}</div>
        </div>
      )}

      {/* Interactive Split-Milestone Tracking Map + External Link & Image */}
      <div className="space-y-4">
        <ShipmentTrackingMap
          currentMilestone={order.shippingStage}
          destinationCity={order.shippingGovernorate || order.address.city}
        />

        {(order.trackingNo || order.trackingUrl || order.trackingImageUrl) && (
          <div className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] flex flex-wrap items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                معلومات التتبع الخارجي
              </div>
              <div className="font-mono-num font-bold text-sm">
                رقم التتبع: {order.trackingNo || '—'} · الناقل: {order.courierName || 'يمن سيلو الدولي'}
              </div>
              {order.shippingStageNote && (
                <div className="text-xs text-violet-700 dark:text-violet-300">
                  ملاحظة الشحن: {order.shippingStageNote}
                </div>
              )}
            </div>

            <div className="flex items-center gap-2.5">
              {order.trackingUrl && (
                <a
                  href={order.trackingUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="px-4 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold flex items-center gap-1.5 hover:bg-violet-700"
                >
                  <ExternalLink className="w-3.5 h-3.5" />
                  <span>فتح رابط شركة الشحن</span>
                </a>
              )}
              {order.trackingImageUrl && (
                <button
                  type="button"
                  onClick={() => setZoomImg(order.trackingImageUrl)}
                  className="px-4 py-2 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold flex items-center gap-1.5 hover:bg-black/5 dark:hover:bg-white/5"
                >
                  <ZoomIn className="w-3.5 h-3.5" />
                  <span>عرض صورة التتبع</span>
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Point 7: Electronic Delivery Signature & 4-Digit Verification PIN */}
      <div className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center gap-2 font-extrabold text-base">
            <PenTool className="w-5 h-5 text-violet-600 dark:text-violet-400" />
            <span>التوقيع الإلكتروني وكود تأكيد الاستلام</span>
          </div>
          {order.deliveryPin && (
            <div className="text-xs font-mono-num bg-[#F3EFE9] dark:bg-[#1E1830] px-3 py-1.5 rounded-xl font-bold">
              كود الاستلام الخاص بك: <span className="text-violet-700 dark:text-violet-300">{order.deliveryPin}</span>
            </div>
          )}
        </div>

        {order.deliverySigned && order.customerSignatureUrl ? (
          <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 flex flex-wrap items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="font-bold text-sm text-emerald-800 dark:text-emerald-200 flex items-center gap-1.5">
                <CheckCircle2 className="w-4 h-4" />
                <span>تم توثيق استلام الطلب إلكترونياً</span>
              </div>
              <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                الموقّع: {order.signedByName || order.receiverName} ·{' '}
                {order.signedAt ? new Date(order.signedAt).toLocaleString('ar-YE') : ''}
              </div>
            </div>
            <img
              src={sanitizeImageUrl(order.customerSignatureUrl, BRAND_IMAGES.kaftan)}
              alt="توقيع العميل"
              className="h-20 rounded-xl border border-black/10 bg-white p-1"
            />
          </div>
        ) : order.status === OrderStatus.shipped ||
          order.status === OrderStatus.outForDelivery ? (
          <div className="space-y-3">
            <div className="p-3.5 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/10 dark:border-white/10 text-xs space-y-1.5">
              <div className="font-extrabold text-violet-700 dark:text-violet-300">
                متى وكيف يُستخدم التوقيع الإلكتروني؟
              </div>
              <p className="text-[#5F5870] dark:text-[#A9A1BA] leading-relaxed">
                يُستخدم فقط لحظة استلام الشحنة يداً بيد من المندوب أو مكتب الشحن بعد فحص سلامة الطرد؛ ارسم توقيعك داخل الإطار، أدخل كود الاستلام المكوّن من 4 أرقام، ثم اضغط <strong className="text-[#171321] dark:text-[#F6F3EC]">«تأكيد التوقيع»</strong> لحفظ التوثيق في بوليصة التسليم (أو <strong className="text-[#171321] dark:text-[#F6F3EC]">«مسح»</strong> لإعادة الرسم).
              </p>
            </div>
            <div className="rounded-2xl border border-black/15 dark:border-white/15 bg-white overflow-hidden">
              <canvas
                ref={canvasRef}
                width={540}
                height={160}
                onPointerDown={startDraw}
                onPointerMove={moveDraw}
                onPointerUp={endDraw}
                onPointerLeave={endDraw}
                className="w-full h-40 touch-none cursor-crosshair"
              />
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  maxLength={4}
                  value={pinInput}
                  onChange={(e) => setPinInput(e.target.value)}
                  placeholder="كود التحقق (4 أرقام)"
                  className="w-40 px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num text-center"
                />
                <button
                  type="button"
                  onClick={clearSignature}
                  className="px-4 py-2 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold hover:bg-black/5 dark:hover:bg-white/5"
                >
                  مسح
                </button>
              </div>
              <button
                type="button"
                onClick={handleSaveSignature}
                disabled={sigSubmitting}
                className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold flex items-center gap-1.5"
              >
                <ShieldCheck className="w-4 h-4" />
                <span>{sigSubmitting ? 'جاري التوثيق...' : 'تأكيد التوقيع'}</span>
              </button>
            </div>
          </div>
        ) : (
          <div className="p-3.5 rounded-2xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/10 dark:border-white/10 text-xs text-[#5F5870] dark:text-[#A9A1BA] space-y-1">
            <div className="font-bold text-[#171321] dark:text-[#F6F3EC]">
              تُفعَّل لوحة التوقيع الإلكتروني عند الشحن أو الخروج للتوصيل
            </div>
            <div>
              عند تسليم الطلب مع المندوب أو مكتب الشحن، سيُطلب منك رسم التوقيع وإدخال كود الـ 4 أرقام عبر خياري «تأكيد التوقيع» و«مسح» لإثبات الاستلام في البوليصة وحماية حقك المالي.
            </div>
          </div>
        )}
      </div>

      {/* Eesal ("إيصال") — Installment / Remaining Balance Receipts */}
      <div className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2 font-extrabold text-base">
            <Receipt className="w-5 h-5 text-violet-600 dark:text-violet-400" />
            <span>نظام «إيصال» وسداد الدفعات</span>
          </div>
          <span className="font-mono-num text-xs font-bold text-violet-700 dark:text-violet-300">
            المتبقي: {formatMoney(locked.remainingLocal, order.currency)}
          </span>
        </div>

        {orderReceipts.length > 0 && (
          <div className="space-y-2">
            {orderReceipts.map((rc) => (
              <div
                key={rc.id}
                className="p-3 rounded-xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/5 dark:border-white/5 flex items-center justify-between gap-3 text-xs"
              >
                <div>
                  <div className="font-bold font-mono-num">
                    {rc.receiptNo} · {formatMoney(rc.amountLocal, order.currency)}
                  </div>
                  <div className="text-[#5F5870] dark:text-[#A9A1BA]">
                    {rc.senderName} ·{' '}
                    {rc.status === 'approved'
                      ? 'معتمد ومقيّد ✓'
                      : rc.status === 'rejected'
                      ? `مرفوض (${rc.rejectReason || 'راجع الدعم'})`
                      : 'قيد المراجعة المحاسبية'}
                  </div>
                </div>
                {rc.proofUrl && (
                  <button
                    type="button"
                    onClick={() => setZoomImg(rc.proofUrl)}
                    className="text-violet-700 dark:text-violet-300 font-bold"
                  >
                    عرض الإيصال
                  </button>
                )}
              </div>
            ))}
          </div>
        )}

        {locked.remainingLocal > 0 && (
          <form
            onSubmit={async (e) => {
              e.preventDefault();
              const amt = parseFloat(rcAmount);
              if (!Number.isFinite(amt) || amt <= 0 || !rcProof) {
                notifyToast('أدخل المبلغ وأرفق صورة الإيصال', 'error');
                return;
              }
              setRcSubmitting(true);
              await submitOrderReceipt(order, {
                amountLocal: amt,
                senderName: rcSender || order.receiverName,
                refNo: rcRef,
                note: 'سداد دفعة عبر إيصال',
                proofUrl: rcProof,
              });
              setRcSubmitting(false);
              setRcProof('');
              setRcRef('');
            }}
            className="grid sm:grid-cols-4 gap-2.5 pt-2 border-t border-black/10 dark:border-white/10"
          >
            <input
              type="number"
              step="0.01"
              value={rcAmount}
              onChange={(e) => setRcAmount(e.target.value)}
              placeholder="المبلغ المحول"
              className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
            />
            <input
              type="text"
              value={rcSender}
              onChange={(e) => setRcSender(e.target.value)}
              placeholder="اسم المحول"
              className="px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
            />
            <label className="px-3 py-2 rounded-xl border border-dashed border-violet-500/40 text-xs font-bold flex items-center justify-center gap-1.5 cursor-pointer">
              <Upload className="w-3.5 h-3.5 text-violet-600" />
              <span>{rcProof ? 'تم الإرفاق ✓' : 'صورة الإيصال *'}</span>
              <input
                type="file"
                accept="image/*"
                onChange={async (ev) => {
                  const f = ev.target.files?.[0];
                  if (f) setRcProof(await compressImageToDataUrl(f, 900, 0.72));
                }}
                className="hidden"
              />
            </label>
            <button
              type="submit"
              disabled={rcSubmitting}
              className="px-4 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold"
            >
              {rcSubmitting ? 'جاري الرفع...' : 'رفع إيصال سداد'}
            </button>
          </form>
        )}
      </div>

      {/* Items List + Refund Request */}
      <div className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="font-extrabold text-base">المنتجات ({order.items.length})</h2>
          <button
            type="button"
            onClick={() => setRefundOpen(true)}
            className="text-xs font-bold text-rose-600 dark:text-rose-400 hover:underline flex items-center gap-1"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>طلب استرداد / مراجعة قطعة</span>
          </button>
        </div>

        <div className="divide-y divide-black/10 dark:divide-white/10">
          {order.items.map((it, i) => (
            <div key={i} className="py-3.5 flex items-center justify-between gap-4">
              <div className="flex items-center gap-3 min-w-0">
                <img
                  src={sanitizeImageUrl(it.imageUrl, BRAND_IMAGES.kaftan)}
                  alt={it.title}
                  onClick={() =>
                    setZoomImg(sanitizeImageUrl(it.imageUrl, BRAND_IMAGES.kaftan))
                  }
                  className="w-14 h-14 rounded-xl object-cover bg-[#F3EFE9] shrink-0 cursor-zoom-in"
                />
                <div className="min-w-0">
                  <div className="font-semibold text-sm truncate">{it.title}</div>
                  <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                    {it.color} · {it.size} · الكمية: {it.qty}
                    {it.isReplacement ? ' · بديل معتمد' : ''}
                  </div>
                  {it.productUrl && /^https?:\/\//i.test(it.productUrl) && (
                    <a
                      href={it.productUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 text-[11px] font-bold text-violet-700 dark:text-violet-300 hover:underline mt-0.5"
                    >
                      <ExternalLink className="w-3 h-3" />
                      <span>رابط SHEIN للقطعة</span>
                    </a>
                  )}
                  {it.nonRefundable && (
                    <div className="text-[11px] text-amber-700 dark:text-amber-300 mt-0.5">
                      غير قابل للاسترداد ({it.nonRefundableReason})
                    </div>
                  )}
                </div>
              </div>
              <div className="font-mono-num font-bold text-sm shrink-0">
                {(it.unitPriceSar * it.qty).toFixed(2)} SAR
              </div>
            </div>
          ))}
        </div>

        {/* Timeline Log */}
        <div className="pt-4 border-t border-black/10 dark:border-white/10 space-y-2">
          <div className="text-xs font-bold text-[#5F5870] dark:text-[#A9A1BA]">
            سجل حركات الطلب
          </div>
          <div className="space-y-2">
            {order.timeline
              .slice()
              .reverse()
              .map((ev, i) => (
                <div key={i} className="text-xs flex items-start justify-between gap-2">
                  <div>
                    <span className="font-bold">{ev.note}</span>
                    {ev.byName && (
                      <span className="text-[#5F5870] dark:text-[#A9A1BA]"> — {ev.byName}</span>
                    )}
                  </div>
                  <span className="font-mono-num text-[11px] text-[#5F5870] dark:text-[#A9A1BA] shrink-0">
                    {new Date(ev.at).toLocaleDateString('ar-YE')}
                  </span>
                </div>
              ))}
          </div>
        </div>
      </div>

      {/* Refund Request Modal */}
      {refundOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-4"
          onClick={() => setRefundOpen(false)}
        >
          <form
            onSubmit={handleRefundSubmit}
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-md rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] p-6 space-y-4"
          >
            <div className="flex items-center justify-between">
              <h3 className="font-extrabold text-base">طلب استرداد مالي</h3>
              <button type="button" onClick={() => setRefundOpen(false)}>
                <X className="w-5 h-5" />
              </button>
            </div>
            {hasNonRefundable && (
              <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/30 text-xs text-amber-800 dark:text-amber-200">
                تنبيه: يتضمن هذا الطلب قطعاً غير قابلة للاسترداد، ويُقبل طلب الاسترجاع فقط في حالات التلف أو اختلاف القطعة.
              </div>
            )}
            <div>
              <label className="text-xs font-bold block mb-1">سبب الطلب</label>
              <select
                value={refundType}
                onChange={(e) =>
                  setRefundType(
                    e.target.value as 'damaged' | 'wrong_item' | 'missing' | 'other'
                  )
                }
                className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
              >
                <option value="damaged">وصول قطعة تالفة</option>
                <option value="wrong_item">استلام قطعة مختلفة</option>
                <option value="missing">نقص قطعة من الطلب</option>
                <option value="other" disabled={hasNonRefundable}>
                  رغبة شخصية / سبب آخر {hasNonRefundable ? '(غير متاح)' : ''}
                </option>
              </select>
            </div>
            <textarea
              rows={3}
              value={refundReason}
              onChange={(e) => setRefundReason(e.target.value)}
              placeholder="اشرح تفاصيل المشكلة..."
              className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
            />
            <div className="grid grid-cols-2 gap-2.5">
              <input
                type="text"
                value={refundBank}
                onChange={(e) => setRefundBank(e.target.value)}
                placeholder="البنك / المحفظة"
                className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
              />
              <input
                type="text"
                value={refundAccountNo}
                onChange={(e) => setRefundAccountNo(e.target.value)}
                placeholder="رقم الحساب للاسترداد"
                className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
              />
            </div>
            <button
              type="submit"
              className="w-full py-3 rounded-xl bg-violet-600 text-white text-sm font-bold"
            >
              إرسال طلب الاسترداد
            </button>
          </form>
        </div>
      )}

      {zoomImg && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
          onClick={() => setZoomImg(null)}
        >
          <img
            src={zoomImg}
            alt="صورة التتبع"
            className="max-w-2xl max-h-[85vh] rounded-2xl object-contain bg-white"
          />
        </div>
      )}
    </div>
  );
};

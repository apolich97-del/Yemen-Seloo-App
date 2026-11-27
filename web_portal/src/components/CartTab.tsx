import React, { useState } from 'react';
import { doc, getDoc } from 'firebase/firestore';
import {
  AlertTriangle,
  ArrowLeft,
  Calculator,
  Copy,
  Edit3,
  Minus,
  Plus,
  RefreshCw,
  ShoppingBag,
  Trash2,
} from 'lucide-react';
import { db } from '../config/firebase';
import { useSeloo } from '../context/SelooContext';
import { BRAND_IMAGES } from '../data/seedData';
import {
  colorToHex,
  computeCartTotals,
  computeCurrencyMatrix,
  convertSarToCurrency,
  formatMoney,
  sanitizeImageUrl,
} from '../services/pricingService';
import { CartItem } from '../types/seloo';
import { CheckoutScreen } from './CheckoutScreen';
import { PaymentScreen } from './PaymentScreen';

export const CartTab: React.FC = () => {
  const {
    cart,
    catalog,
    currency,
    settings,
    updateCartQty,
    removeFromCart,
    clearCart,
    updateCartItemPrice,
    updateCartItemVariant,
    setActiveTab,
    activeOrderForPayment,
    setActiveOrderForPayment,
    notifyToast,
  } = useSeloo();

  const [showCheckout, setShowCheckout] = useState(false);
  const [syncingPrices, setSyncingPrices] = useState(false);
  const [editingVariantId, setEditingVariantId] = useState<string | null>(null);
  const [commissionPercent, setCommissionPercent] = useState('5');

  if (activeOrderForPayment) {
    return (
      <PaymentScreen
        order={activeOrderForPayment}
        onBack={() => {
          setActiveOrderForPayment(null);
          setShowCheckout(false);
        }}
        onComplete={() => {
          setActiveOrderForPayment(null);
          setShowCheckout(false);
          setActiveTab('orders');
        }}
      />
    );
  }

  if (showCheckout && cart.length > 0) {
    return (
      <CheckoutScreen
        onBack={() => setShowCheckout(false)}
        onOrderCreated={(order) => {
          setActiveOrderForPayment(order);
        }}
      />
    );
  }

  const totals = computeCartTotals(cart, settings, currency);
  const commPctNum = Math.max(0, Math.min(50, parseFloat(commissionPercent) || 0));
  const commissionSar = (totals.subtotalSar * commPctNum) / 100;
  const commMatrix = computeCurrencyMatrix(commissionSar, settings);

  const handleSyncPrices = async () => {
    if (cart.length === 0) return;
    setSyncingPrices(true);
    let updatedCount = 0;

    for (const item of cart) {
      const catMatch = catalog.find((c) => c.goodsId === item.goodsId);
      if (catMatch) {
        const sizeBase =
          catMatch.sizePrices && typeof catMatch.sizePrices[item.size] === 'number'
            ? catMatch.sizePrices[item.size]
            : catMatch.basePriceSar;
        const latest = sizeBase + catMatch.marginSar;
        if (Math.abs(latest - item.unitPriceSar) > 0.05) {
          updateCartItemPrice(item.id, latest);
          updatedCount++;
        }
        continue;
      }
      try {
        const snap = await getDoc(doc(db, 'shein_cache', item.goodsId));
        if (snap.exists()) {
          const data = snap.data();
          const map = data.sizePrices as Record<string, number> | undefined;
          const latest =
            map && typeof map[item.size] === 'number'
              ? Number(map[item.size])
              : typeof data.priceSar === 'number'
              ? Number(data.priceSar)
              : item.unitPriceSar;
          if (Math.abs(latest - item.unitPriceSar) > 0.05) {
            updateCartItemPrice(item.id, latest);
            updatedCount++;
          }
        }
      } catch {
        // ignore offline check
      }
    }

    setSyncingPrices(false);
    notifyToast(
      updatedCount > 0
        ? `تم تحديث أسعار ${updatedCount} قطعة حسب آخر مزامنة والمقاسات`
        : 'جميع أسعار سلتك محدثة ومطابقة لآخر مزامنة ✓',
      'success'
    );
  };

  const handleSelectCartSize = (item: CartItem, nextSize: string) => {
    const catMatch = catalog.find((c) => c.goodsId === item.goodsId);
    const localSizePrice = item.sizePrices?.[nextSize];
    let nextPrice = item.unitPriceSar;
    if (typeof localSizePrice === 'number' && localSizePrice > 0) {
      nextPrice = localSizePrice;
    } else if (catMatch?.sizePrices && typeof catMatch.sizePrices[nextSize] === 'number') {
      nextPrice = catMatch.sizePrices[nextSize] + catMatch.marginSar;
    }
    updateCartItemVariant(item.id, { size: nextSize, unitPriceSar: nextPrice });
  };

  const handleCopyCartSummary = async () => {
    const lines = cart
      .map(
        (c, i) =>
          `${i + 1}. ${c.title} (${c.color}/${c.size}) × ${c.qty} — ${(
            c.unitPriceSar * c.qty
          ).toFixed(2)} ر.س`
      )
      .join('\n');
    const summary = `🛍️ ملخص سلة يمن سيلو\n${lines}\n────────────\nالإجمالي: ${totals.matrix.sar.toFixed(
      2
    )} ر.س | $${totals.matrix.usd.toFixed(2)}\nصرف شمال: ${totals.matrix.northFromSar.toLocaleString(
      'en-US'
    )} ر.ي | صرف جنوب: ${totals.matrix.southFromSar.toLocaleString('en-US')} ر.ي`;
    try {
      await navigator.clipboard.writeText(summary);
      notifyToast('تم نسخ ملخص السلة للحافظة', 'success');
    } catch {
      notifyToast('تعذر النسخ التلقائي', 'error');
    }
  };

  if (cart.length === 0) {
    return (
      <div className="max-w-xl mx-auto py-16 text-center space-y-5">
        <div className="w-16 h-16 rounded-2xl bg-[#F3EFE9] dark:bg-[#1E1830] mx-auto flex items-center justify-center">
          <ShoppingBag className="w-8 h-8 text-violet-600 dark:text-violet-400" />
        </div>
        <h1 className="text-2xl font-extrabold">سلة التسوق فارغة</h1>
        <p className="text-sm text-[#5F5870] dark:text-[#A9A1BA]">
          أضف قطعاً من كتالوج يمن سيلو أو الصق رابط قطعة / سلة SHEIN لاستيرادها فوراً.
        </p>
        <div className="flex flex-wrap justify-center gap-3 pt-2">
          <button
            type="button"
            onClick={() => setActiveTab('catalog')}
            className="px-6 py-3 rounded-xl bg-violet-600 text-white text-sm font-bold hover:bg-violet-700"
          >
            تصفح الكتالوج
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('shein')}
            className="px-6 py-3 rounded-xl border border-black/15 dark:border-white/15 text-sm font-bold hover:bg-black/5 dark:hover:bg-white/5"
          >
            استيراد من SHEIN
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-16">
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-black/10 dark:border-white/10 pb-5">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold">
            سلة التسوق ({totals.totalPieces} قطعة)
          </h1>
          <p className="text-xs text-[#5F5870] dark:text-[#A9A1BA] mt-1">
            يمكنك تعديل المقاس واللون لكل قطعة مباشرة مع مزامنة السعر الفورية.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={handleSyncPrices}
            disabled={syncingPrices}
            className="px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold flex items-center gap-1.5 hover:bg-black/5 dark:hover:bg-white/5"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${syncingPrices ? 'animate-spin' : ''}`} />
            <span>مزامنة الأسعار الآن</span>
          </button>
          <button
            type="button"
            onClick={handleCopyCartSummary}
            className="px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold flex items-center gap-1.5 hover:bg-black/5 dark:hover:bg-white/5"
          >
            <Copy className="w-3.5 h-3.5" />
            <span>نسخ الملخص</span>
          </button>
          <button
            type="button"
            onClick={clearCart}
            className="px-3.5 py-2 rounded-xl border border-rose-500/30 text-rose-600 dark:text-rose-400 text-xs font-bold hover:bg-rose-500/10"
          >
            إفراغ السلة
          </button>
        </div>
      </div>

      {/* Free Shipping Threshold Bar */}
      <div className="p-4 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-2">
        <div className="flex items-center justify-between text-xs font-semibold">
          <span>
            {totals.remainingForFreeShippingSar <= 0
              ? 'مبروك! حصلت على شحن دولي مجاني ✓'
              : `أضف ${totals.remainingForFreeShippingSar.toFixed(
                  2
                )} ر.س إضافية للحصول على شحن دولي مجاني`}
          </span>
          <span className="font-mono-num text-violet-700 dark:text-violet-300">
            {totals.progressToFreeShipping}%
          </span>
        </div>
        <div className="h-2 rounded-full bg-[#F3EFE9] dark:bg-[#1E1830] overflow-hidden">
          <div
            className="h-full bg-violet-600 transition-all duration-300"
            style={{ width: `${totals.progressToFreeShipping}%` }}
          />
        </div>
      </div>

      <div className="grid lg:grid-cols-12 gap-8 items-start">
        {/* Cart Items */}
        <div className="lg:col-span-7 space-y-4">
          {cart.map((item) => {
            const lineSar = item.unitPriceSar * item.qty;
            const lineLocal = convertSarToCurrency(lineSar, currency, settings);
            const catMatch = catalog.find((c) => c.goodsId === item.goodsId);
            const colorOptions =
              item.availableColors?.length
                ? item.availableColors
                : catMatch?.colors?.length
                ? catMatch.colors
                : ['أسود فاحم', 'أبيض', 'بيج', 'عنابي', 'كحلي'];
            const sizeOptions =
              item.availableSizes?.length
                ? item.availableSizes
                : catMatch?.sizes?.length
                ? catMatch.sizes
                : ['S', 'M', 'L', 'XL'];
            const isEditingVar = editingVariantId === item.id;

            return (
              <div
                key={item.id}
                className="p-4 sm:p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3"
              >
                <div className="flex gap-4">
                  <img
                    src={sanitizeImageUrl(item.imageUrl, BRAND_IMAGES.kaftan)}
                    alt={item.title}
                    onError={(e) => {
                      e.currentTarget.src = BRAND_IMAGES.kaftan;
                    }}
                    className="w-24 h-24 sm:w-28 sm:h-28 rounded-xl object-cover bg-[#F3EFE9] dark:bg-[#1E1830] shrink-0"
                  />
                  <div className="flex-1 min-w-0 flex flex-col justify-between gap-3">
                    <div>
                      <div className="flex items-start justify-between gap-2">
                        <h3 className="font-bold text-sm sm:text-base leading-snug line-clamp-2">
                          {item.title}
                        </h3>
                        <button
                          type="button"
                          onClick={() => removeFromCart(item.id)}
                          className="p-1.5 rounded-lg text-[#5F5870] hover:text-rose-600 hover:bg-rose-500/10 shrink-0"
                          aria-label="حذف"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>

                      {/* Visual Color Swatch Icon + Size + Edit trigger */}
                      <div className="flex flex-wrap items-center gap-2 text-xs text-[#5F5870] dark:text-[#A9A1BA] mt-1.5">
                        <span className="inline-flex items-center gap-1.5 font-semibold text-[#171321] dark:text-[#F6F3EC]">
                          <span
                            className="w-3.5 h-3.5 rounded-full border border-black/25 dark:border-white/25 inline-block shrink-0"
                            style={{ backgroundColor: colorToHex(item.color) }}
                          />
                          <span>{item.color}</span>
                        </span>
                        <span>·</span>
                        <span className="font-mono-num font-bold">{item.size}</span>
                        <span>·</span>
                        <span className="font-mono-num">#{item.goodsId}</span>
                        <button
                          type="button"
                          onClick={() => setEditingVariantId(isEditingVar ? null : item.id)}
                          className="text-violet-700 dark:text-violet-300 font-bold flex items-center gap-1 hover:underline mr-1"
                        >
                          <Edit3 className="w-3 h-3" />
                          <span>{isEditingVar ? 'إغلاق التعديل' : 'تعديل اللون/المقاس'}</span>
                        </button>
                      </div>

                      {item.nonRefundable && (
                        <div className="flex items-center gap-1.5 text-xs text-amber-700 dark:text-amber-300 mt-1.5">
                          <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
                          <span>
                            غير قابل للاسترداد ({item.nonRefundableReason || 'سياسة القطع الخاصة'})
                          </span>
                        </div>
                      )}
                      {item.previousPriceSar && item.previousPriceSar !== item.unitPriceSar && (
                        <div className="text-xs text-emerald-600 dark:text-emerald-400 mt-1 font-mono-num">
                          تمت المزامنة: {item.previousPriceSar.toFixed(2)} ←{' '}
                          {item.unitPriceSar.toFixed(2)} SAR
                        </div>
                      )}
                    </div>

                    <div className="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-black/10 dark:border-white/10">
                      <div className="flex items-center gap-2 border border-black/15 dark:border-white/15 rounded-xl px-1.5 py-1">
                        <button
                          type="button"
                          onClick={() => updateCartQty(item.id, -1)}
                          className="w-7 h-7 rounded-lg hover:bg-black/5 dark:hover:bg-white/10 flex items-center justify-center"
                        >
                          <Minus className="w-3.5 h-3.5" />
                        </button>
                        <span className="font-mono-num font-bold text-sm w-6 text-center">
                          {item.qty}
                        </span>
                        <button
                          type="button"
                          onClick={() => updateCartQty(item.id, 1)}
                          className="w-7 h-7 rounded-lg hover:bg-black/5 dark:hover:bg-white/10 flex items-center justify-center"
                        >
                          <Plus className="w-3.5 h-3.5" />
                        </button>
                      </div>

                      <div className="text-end">
                        <div className="font-mono-num font-extrabold text-base text-violet-700 dark:text-violet-300">
                          {formatMoney(lineLocal, currency)}
                        </div>
                        <div className="font-mono-num text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">
                          {lineSar.toFixed(2)} SAR
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Inline SHEIN-Style Color & Size Editor */}
                {isEditingVar && (
                  <div className="p-3.5 rounded-xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/10 dark:border-white/10 space-y-3">
                    <div>
                      <div className="text-[11px] font-bold mb-1.5">اختر اللون:</div>
                      <div className="flex flex-wrap gap-1.5">
                        {colorOptions.map((c) => (
                          <button
                            key={c}
                            type="button"
                            onClick={() => updateCartItemVariant(item.id, { color: c })}
                            className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold border flex items-center gap-1.5 ${
                              item.color === c
                                ? 'border-violet-600 bg-violet-600 text-white'
                                : 'border-black/10 dark:border-white/10 bg-white dark:bg-[#151122]'
                            }`}
                          >
                            <span
                              className="w-3 h-3 rounded-full border border-black/25 shrink-0"
                              style={{ backgroundColor: colorToHex(c) }}
                            />
                            <span>{c}</span>
                          </button>
                        ))}
                      </div>
                    </div>
                    <div>
                      <div className="text-[11px] font-bold mb-1.5">
                        اختر المقاس (يحدّث السعر تلقائياً عند اختلاف سعر المقاس):
                      </div>
                      <div className="flex flex-wrap gap-1.5">
                        {sizeOptions.map((sz) => {
                          const sp =
                            item.sizePrices?.[sz] ??
                            (catMatch?.sizePrices?.[sz]
                              ? catMatch.sizePrices[sz] + catMatch.marginSar
                              : undefined);
                          return (
                            <button
                              key={sz}
                              type="button"
                              onClick={() => handleSelectCartSize(item, sz)}
                              className={`px-2.5 py-1 rounded-lg text-[11px] font-mono-num font-bold border ${
                                item.size === sz
                                  ? 'border-violet-600 bg-violet-600 text-white'
                                  : 'border-black/10 dark:border-white/10 bg-white dark:bg-[#151122]'
                              }`}
                            >
                              {sz}
                              {typeof sp === 'number' ? ` (${sp.toFixed(0)} SAR)` : ''}
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Summary, Four-Currency Breakdown & Commission Calculator */}
        <div className="lg:col-span-5 space-y-4 lg:sticky lg:top-24">
          <div className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-5">
            <h2 className="text-lg font-extrabold">ملخص السلة والتسعير الفوري</h2>

            <div className="space-y-2.5 text-sm">
              <div className="flex justify-between">
                <span className="text-[#5F5870] dark:text-[#A9A1BA]">مجموع القطع</span>
                <span className="font-mono-num font-bold">{totals.subtotalSar.toFixed(2)} ر.س</span>
              </div>
              <div className="flex justify-between">
                <span className="text-[#5F5870] dark:text-[#A9A1BA]">رسوم الشحن الدولي</span>
                <span className="font-mono-num font-bold">
                  {totals.shippingFeeSar === 0
                    ? 'مجاني'
                    : `${totals.shippingFeeSar.toFixed(2)} ر.س`}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-[#5F5870] dark:text-[#A9A1BA]">رسوم الخدمة</span>
                <span className="font-mono-num font-bold">{totals.serviceFeeSar.toFixed(2)} ر.س</span>
              </div>
              <div className="pt-3 border-t border-black/10 dark:border-white/10 flex justify-between items-baseline">
                <span className="font-extrabold">الإجمالي بعملتك</span>
                <span className="font-mono-num font-extrabold text-xl text-violet-700 dark:text-violet-300">
                  {formatMoney(totals.totalLocal, currency)}
                </span>
              </div>
            </div>

            {/* 4-Currency Comparison Matrix */}
            <div className="p-4 rounded-2xl bg-[#F3EFE9] dark:bg-[#1E1830] space-y-3 text-xs">
              <div className="font-bold text-violet-800 dark:text-violet-300">
                تفصيل التسعير المقارن (سعودي / دولار × شمال / جنوب)
              </div>
              <div className="grid grid-cols-2 gap-2.5 font-mono-num">
                <div className="p-2.5 rounded-xl bg-white dark:bg-[#151122] border border-black/5 dark:border-white/5">
                  <div className="text-[#5F5870] dark:text-[#A9A1BA]">الأصل السعودي</div>
                  <div className="font-extrabold text-sm mt-0.5">{totals.matrix.sar.toFixed(2)} SAR</div>
                </div>
                <div className="p-2.5 rounded-xl bg-white dark:bg-[#151122] border border-black/5 dark:border-white/5">
                  <div className="text-[#5F5870] dark:text-[#A9A1BA]">المعادل بالدولار</div>
                  <div className="font-extrabold text-sm mt-0.5">${totals.matrix.usd.toFixed(2)} USD</div>
                </div>
              </div>

              <div className="space-y-1.5 pt-1 border-t border-black/10 dark:border-white/10 font-mono-num">
                <div className="flex justify-between">
                  <span className="text-[#5F5870] dark:text-[#A9A1BA]">
                    شمال (سعودي × {settings.rateNorth}):
                  </span>
                  <span className="font-bold">
                    {totals.matrix.northFromSar.toLocaleString('en-US')} ر.ي
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[#5F5870] dark:text-[#A9A1BA]">
                    شمال (دولار × {settings.usdRateNorth}):
                  </span>
                  <span className="font-bold">
                    {totals.matrix.northFromUsd.toLocaleString('en-US')} ر.ي
                  </span>
                </div>
                <div className="flex justify-between pt-1">
                  <span className="text-[#5F5870] dark:text-[#A9A1BA]">
                    جنوب (سعودي × {settings.rateSouth}):
                  </span>
                  <span className="font-bold">
                    {totals.matrix.southFromSar.toLocaleString('en-US')} ر.ي
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[#5F5870] dark:text-[#A9A1BA]">
                    جنوب (دولار × {settings.usdRateSouth}):
                  </span>
                  <span className="font-bold">
                    {totals.matrix.southFromUsd.toLocaleString('en-US')} ر.ي
                  </span>
                </div>
              </div>
            </div>

            {/* Multi-Currency Commission Calculator */}
            <div className="p-4 rounded-2xl border border-black/10 dark:border-white/10 bg-[#FAF8F5] dark:bg-[#0D0B14] space-y-2.5 text-xs">
              <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-1.5 font-bold text-violet-700 dark:text-violet-300">
                  <Calculator className="w-4 h-4" />
                  <span>حاسبة عمولة المندوب / الوسيط</span>
                </div>
                <div className="flex items-center gap-1">
                  <input
                    type="number"
                    min={0}
                    max={50}
                    step="0.5"
                    value={commissionPercent}
                    onChange={(e) => setCommissionPercent(e.target.value)}
                    className="w-16 px-2 py-1 rounded-lg border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] font-mono-num text-center font-bold"
                  />
                  <span>%</span>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-2 font-mono-num text-[11px]">
                <div className="flex justify-between p-2 rounded-lg bg-white dark:bg-[#151122]">
                  <span className="text-[#5F5870] dark:text-[#A9A1BA]">سعودي:</span>
                  <span className="font-bold">{commMatrix.sar.toFixed(2)} SAR</span>
                </div>
                <div className="flex justify-between p-2 rounded-lg bg-white dark:bg-[#151122]">
                  <span className="text-[#5F5870] dark:text-[#A9A1BA]">دولار:</span>
                  <span className="font-bold">${commMatrix.usd.toFixed(2)}</span>
                </div>
                <div className="flex justify-between p-2 rounded-lg bg-white dark:bg-[#151122]">
                  <span className="text-[#5F5870] dark:text-[#A9A1BA]">شمال:</span>
                  <span className="font-bold">{commMatrix.northFromSar.toLocaleString('en-US')} ر.ي</span>
                </div>
                <div className="flex justify-between p-2 rounded-lg bg-white dark:bg-[#151122]">
                  <span className="text-[#5F5870] dark:text-[#A9A1BA]">جنوب:</span>
                  <span className="font-bold">{commMatrix.southFromSar.toLocaleString('en-US')} ر.ي</span>
                </div>
              </div>
            </div>

            {totals.canDeferred && (
              <div className="text-xs text-amber-800 dark:text-amber-300 bg-amber-500/10 border border-amber-500/25 rounded-xl p-3">
                طلبك مؤهل لخطة <strong>50% آجل</strong>: تدفع{' '}
                <span className="font-mono-num font-bold">
                  {formatMoney(totals.upfrontLocal, currency)}
                </span>{' '}
                فقط عند التثبيت وتحتفظ بسعر صرف يوم الطلب للمتبقي.
              </div>
            )}

            <button
              type="button"
              onClick={() => setShowCheckout(true)}
              className="w-full py-3.5 rounded-xl bg-violet-600 hover:bg-violet-700 text-white font-bold text-sm flex items-center justify-center gap-2"
            >
              <span>المتابعة لتأكيد العنوان والدفع</span>
              <ArrowLeft className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

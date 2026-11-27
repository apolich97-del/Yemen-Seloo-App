import React, { useState } from 'react';
import {
  ArrowUpLeft,
  Clock,
  Link2,
  PackageSearch,
  ShieldCheck,
  Sparkles,
  Truck,
  X,
} from 'lucide-react';
import { useSeloo } from '../context/SelooContext';
import { BRAND_IMAGES } from '../data/seedData';
import {
  computeCartTotals,
  computeCurrencyMatrix,
  convertSarToCurrency,
  formatMoney,
} from '../services/pricingService';
import { SELOO_POLICIES } from '../config/selooConfig';
import { CatalogItem } from '../types/seloo';

export const HomeTab: React.FC = () => {
  const {
    catalog,
    cart,
    isCartAbandoned24h,
    cartAgeHours,
    dismissCartReminder,
    currency,
    settings,
    setActiveTab,
    setCurrencyModalOpen,
    addToCart,
    orders,
    setSelectedOrderId,
    language,
  } = useSeloo();

  const [lookupNo, setLookupNo] = useState('');
  const featured = catalog.slice(0, 6);
  const cartTotals = computeCartTotals(cart, settings, currency);

  const handleQuickOrderTrack = (e: React.FormEvent) => {
    e.preventDefault();
    const cleaned = lookupNo.trim().toUpperCase();
    if (!cleaned) {
      setActiveTab('orders');
      return;
    }
    const found = orders.find(
      (o) =>
        o.orderNo.toUpperCase() === cleaned ||
        o.receiverPhone.includes(cleaned)
    );
    if (found) {
      setSelectedOrderId(found.id);
    }
    setActiveTab('orders');
  };

  const quickAdd = (item: CatalogItem) => {
    const priceSar = item.basePriceSar + item.marginSar;
    addToCart({
      goodsId: item.goodsId,
      title: item.title,
      imageUrl: item.imageUrl,
      size: item.sizes[0] || 'One Size',
      color: item.colors[0] || 'أساسي',
      availableColors: item.colors,
      availableSizes: item.sizes,
      sizePrices: item.sizePrices,
      qty: 1,
      unitPriceSar: priceSar,
      productUrl: item.sourceUrl,
      source: 'catalog',
      nonRefundable: item.nonRefundable,
      nonRefundableReason: item.nonRefundableReason,
    });
  };

  return (
    <div className="space-y-12 pb-16">
      {/* 24-Hour Abandoned Cart Reminder */}
      {isCartAbandoned24h && cart.length > 0 && (
        <div className="p-4 sm:p-5 rounded-2xl border border-amber-500/40 bg-amber-500/10 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-start gap-3">
            <Clock className="w-5 h-5 text-amber-700 dark:text-amber-300 shrink-0 mt-0.5" />
            <div className="space-y-0.5">
              <div className="font-extrabold text-sm text-amber-900 dark:text-amber-200">
                تذكير: سلتك تنتظرك منذ {cartAgeHours} ساعة ({cartTotals.totalPieces} قطعة)
              </div>
              <p className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                القيمة الحالية:{' '}
                <strong className="font-mono-num">
                  {formatMoney(cartTotals.totalLocal, currency)}
                </strong>{' '}
                — ثبّت طلبك الآن قبل تغيّر الأسعار أو نفاد الكمية.
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setActiveTab('cart')}
              className="px-4 py-2 rounded-xl bg-amber-600 hover:bg-amber-700 text-white text-xs font-bold"
            >
              إتمام الطلب الآن
            </button>
            <button
              type="button"
              onClick={dismissCartReminder}
              className="p-1.5 rounded-lg text-[#5F5870] hover:bg-black/5 dark:hover:bg-white/10"
              aria-label="تجاهل التذكير"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* Section 1: Editorial Storefront Hero */}
      <section className="grid lg:grid-cols-12 gap-6 items-stretch">
        <div className="lg:col-span-6 flex flex-col justify-between rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] p-7 sm:p-10">
          <div className="space-y-5">
            <div className="text-xs font-semibold tracking-wider uppercase text-violet-700 dark:text-violet-300">
              {language === 'ar'
                ? 'وسيطك الموثوق للتسوق العالمي · الصين ← اليمن'
                : 'TRUSTED GLOBAL SHOPPING · CHINA TO YEMEN'}
            </div>
            <h1 className="text-3xl sm:text-4xl lg:text-[2.6rem] font-extrabold leading-[1.2] tracking-tight">
              {language === 'ar'
                ? 'تسوّق من SHEIN وكتالوج يمن سيلو بتسعير فوري وشفاف'
                : 'Shop SHEIN & Yemen Seloo Catalog with Live Currency Clarity'}
            </h1>
            <p className="text-base text-[#5F5870] dark:text-[#A9A1BA] leading-relaxed max-w-xl">
              {language === 'ar'
                ? 'استورد روابط وسلال شي إن بنقرة واحدة، ادفع بالريال اليمني (شمال/جنوب) أو السعودي أو الدولار، وتابع شحنتك من الصين عبر الإمارات والسعودية حتى باب منزلك.'
                : 'Import SHEIN links and carts in seconds, pay in YER North/South, SAR, or USD, and track every transit milestone to your governorate.'}
            </p>
          </div>

          <div className="pt-8 space-y-5">
            <div className="flex flex-wrap gap-3">
              <button
                type="button"
                onClick={() => setActiveTab('catalog')}
                className="px-6 py-3.5 rounded-xl bg-violet-600 hover:bg-violet-700 text-white font-bold text-sm transition-colors flex items-center gap-2"
              >
                <span>{language === 'ar' ? 'تصفح كتالوج يمن سيلو' : 'Browse Catalog'}</span>
                <ArrowUpLeft className="w-4 h-4" />
              </button>
              <button
                type="button"
                onClick={() => setActiveTab('shein')}
                className="px-6 py-3.5 rounded-xl border border-black/15 dark:border-white/15 hover:bg-black/5 dark:hover:bg-white/5 font-bold text-sm transition-colors flex items-center gap-2"
              >
                <Link2 className="w-4 h-4 text-violet-600 dark:text-violet-400" />
                <span>{language === 'ar' ? 'استيراد رابط / سلة SHEIN' : 'Import SHEIN Link'}</span>
              </button>
            </div>

            <div className="pt-4 border-t border-black/10 dark:border-white/10 grid grid-cols-3 gap-4 text-xs">
              <div>
                <div className="text-[#5F5870] dark:text-[#A9A1BA]">شحن مجاني من</div>
                <div className="font-bold font-mono-num text-sm mt-0.5">
                  {settings.freeShippingThresholdSar} SAR
                </div>
              </div>
              <div>
                <div className="text-[#5F5870] dark:text-[#A9A1BA]">خطة 50% آجل</div>
                <div className="font-bold font-mono-num text-sm mt-0.5">
                  +{settings.deferredThresholdSar} SAR
                </div>
              </div>
              <div>
                <div className="text-[#5F5870] dark:text-[#A9A1BA]">مدة الوصول</div>
                <div className="font-bold font-mono-num text-sm mt-0.5">
                  {settings.deliveryMinDays}–{settings.deliveryMaxDays} يوم
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="lg:col-span-6 relative rounded-3xl overflow-hidden border border-black/10 dark:border-white/10 min-h-[280px] lg:min-h-[420px]">
          <img
            src={BRAND_IMAGES.hero}
            alt="يمن سيلو للأزياء العالمية"
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/15 to-transparent" />
          <div className="absolute bottom-5 right-5 left-5 flex flex-wrap items-end justify-between gap-4 text-white">
            <div>
              <div className="text-xs uppercase tracking-wider text-amber-300 font-semibold">
                LIVE EXCHANGE MATRIX
              </div>
              <div className="text-lg font-bold mt-0.5">
                سعودي {settings.rateNorth} شمال · {settings.rateSouth} جنوب | دولار {settings.usdRateNorth} / {settings.usdRateSouth}
              </div>
            </div>
            <button
              type="button"
              onClick={() => setCurrencyModalOpen(true)}
              className="px-4 py-2 rounded-xl bg-white/15 backdrop-blur-md border border-white/25 text-xs font-bold hover:bg-white/25 transition-colors"
            >
              تغيير العملة
            </button>
          </div>
        </div>
      </section>

      {/* Section 2: Trust & Deferred Plan Highlights */}
      <section className="grid md:grid-cols-3 gap-5">
        <div className="p-6 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-2">
          <Truck className="w-6 h-6 text-violet-600 dark:text-violet-400" />
          <h3 className="font-bold text-base">تتبع مقسّم من الصين حتى بابك</h3>
          <p className="text-sm text-[#5F5870] dark:text-[#A9A1BA] leading-relaxed">
            خريطة مسار تفاعلية وإشعارات لكل محطة: الصين ← الإمارات ← الجمارك السعودية ← اليمن ← المندوب.
          </p>
        </div>
        <div className="p-6 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-2">
          <ShieldCheck className="w-6 h-6 text-amber-600 dark:text-amber-400" />
          <h3 className="font-bold text-base">تثبيت سعر يوم الطلب للآجل</h3>
          <p className="text-sm text-[#5F5870] dark:text-[#A9A1BA] leading-relaxed">
            {SELOO_POLICIES.deferredRule}
          </p>
        </div>
        <div className="p-6 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-2">
          <Sparkles className="w-6 h-6 text-violet-600 dark:text-violet-400" />
          <h3 className="font-bold text-base">نظام البديل الذكي والتوقيع الإلكتروني</h3>
          <p className="text-sm text-[#5F5870] dark:text-[#A9A1BA] leading-relaxed">
            في حال نفاد أي قطعة يتم تنبيهك لإرسال بديل بنفس القيمة أو بتسوية الفارق، مع توقيع استلام إلكتروني وكود تحقق.
          </p>
        </div>
      </section>

      {/* Section 3: Featured Catalog Grid */}
      <section className="space-y-6">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <div className="text-xs font-semibold uppercase tracking-wider text-violet-700 dark:text-violet-300">
              YEMEN SELOO CURATED
            </div>
            <h2 className="text-2xl font-extrabold mt-1">
              {language === 'ar' ? 'مختارات كتالوج يمن سيلو' : 'Featured Catalog'}
            </h2>
          </div>
          <button
            type="button"
            onClick={() => setActiveTab('catalog')}
            className="text-sm font-bold text-violet-700 dark:text-violet-300 hover:underline flex items-center gap-1"
          >
            <span>عرض الكتالوج الكامل ({catalog.length})</span>
            <ArrowUpLeft className="w-4 h-4" />
          </button>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {featured.map((item) => {
            const sar = item.basePriceSar + item.marginSar;
            const localPrice = convertSarToCurrency(sar, currency, settings);
            const matrix = computeCurrencyMatrix(sar, settings);
            return (
              <article
                key={item.id}
                className="group rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] overflow-hidden flex flex-col transition-transform duration-200 hover:-translate-y-0.5 hover:shadow-lg"
              >
                <div className="aspect-[4/3] bg-[#F3EFE9] dark:bg-[#1E1830] overflow-hidden relative">
                  <img
                    src={item.imageUrl}
                    alt={item.title}
                    className="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-300"
                  />
                  {item.badge && (
                    <span className="absolute top-3 right-3 px-2.5 py-1 rounded-md text-[11px] font-bold bg-black/75 text-white backdrop-blur-sm">
                      {item.badge === 'best'
                        ? 'الأكثر طلباً'
                        : item.badge === 'new'
                        ? 'وصل حديثاً'
                        : 'عرض خاص'}
                    </span>
                  )}
                </div>
                <div className="p-5 flex-1 flex flex-col justify-between gap-4">
                  <div className="space-y-1.5">
                    <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                      {item.category} · #{item.goodsId}
                    </div>
                    <h3 className="font-semibold text-base leading-snug line-clamp-2">
                      {item.title}
                    </h3>
                  </div>

                  <div className="space-y-3 pt-2 border-t border-black/10 dark:border-white/10">
                    <div className="flex items-baseline justify-between gap-2">
                      <span className="font-mono-num font-extrabold text-lg text-violet-700 dark:text-violet-300">
                        {formatMoney(localPrice, currency)}
                      </span>
                      <span className="font-mono-num text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                        {sar.toFixed(2)} SAR · ${matrix.usd.toFixed(2)}
                      </span>
                    </div>
                    <button
                      type="button"
                      onClick={() => quickAdd(item)}
                      className="w-full py-2.5 rounded-xl bg-violet-600 hover:bg-violet-700 text-white text-sm font-bold transition-colors"
                    >
                      أضف للسلة فوراً
                    </button>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      </section>

      {/* Section 4: Quick Order Tracking Bar */}
      <section className="rounded-3xl border border-black/10 dark:border-white/10 bg-[#F3EFE9] dark:bg-[#1E1830] p-6 sm:p-8 flex flex-col md:flex-row items-center justify-between gap-6">
        <div className="space-y-1.5">
          <div className="flex items-center gap-2 text-violet-700 dark:text-violet-300 font-bold text-sm">
            <PackageSearch className="w-4 h-4" />
            <span>تتبع شحنتك أو استبدال قطعة</span>
          </div>
          <h3 className="text-xl font-extrabold">أدخل رقم الطلب (مثال: YS1024) لعرض المسار</h3>
        </div>
        <form onSubmit={handleQuickOrderTrack} className="flex w-full md:w-auto gap-2.5">
          <input
            type="text"
            value={lookupNo}
            onChange={(e) => setLookupNo(e.target.value)}
            placeholder="رقم الطلب أو رقم الهاتف..."
            className="flex-1 md:w-64 px-4 py-3 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm focus:outline-none focus:ring-2 focus:ring-violet-500"
          />
          <button
            type="submit"
            className="px-5 py-3 rounded-xl bg-[#171321] dark:bg-violet-600 text-white text-sm font-bold hover:opacity-90 transition-opacity shrink-0"
          >
            متابعة الطلب
          </button>
        </form>
      </section>
    </div>
  );
};

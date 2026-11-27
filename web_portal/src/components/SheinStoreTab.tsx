import React, { useState } from 'react';
import { doc, getDoc, serverTimestamp, setDoc } from 'firebase/firestore';
import {
  AlertTriangle,
  Briefcase,
  CheckCircle2,
  ExternalLink,
  Link2,
  Plus,
  RefreshCw,
  ShoppingBag,
  Sparkles,
  Upload,
} from 'lucide-react';
import { db } from '../config/firebase';
import { useSeloo } from '../context/SelooContext';
import { BRAND_IMAGES, CATALOG_CATEGORIES } from '../data/seedData';
import {
  cacheSheinSizePrices,
  readCachedSheinSizePrices,
} from '../services/idbCacheService';
import {
  classifyBrandAndCategory,
  colorToHex,
  convertSarToCurrency,
  detectNonRefundable,
  formatMoney,
  ParsedSheinEntry,
  parseSheinShareInput,
  sanitizeImageUrl,
} from '../services/pricingService';

interface DraftImportItem {
  goodsId: string;
  url: string;
  title: string;
  priceSar: string;
  marginSar: string;
  promoHeadline: string;
  category: string;
  color: string;
  availableColors: string[];
  size: string;
  availableSizes: string[];
  sizePrices: Record<string, number>;
  qty: number;
  imageUrl: string;
  fromCache: boolean;
}

const DEFAULT_SIZE_SET = ['S', 'M', 'L', 'XL'];
const DEFAULT_COLOR_SET = ['أسود فاحم', 'أبيض', 'بيج', 'عنابي', 'كحلي'];

export const SheinStoreTab: React.FC = () => {
  const {
    currency,
    settings,
    catalog,
    addToCart,
    setActiveTab,
    isStaff,
    effectiveRole,
    upsertCatalogItem,
    notifyMarketerDiscount,
    notifyToast,
  } = useSeloo();

  const [marketerMode, setMarketerMode] = useState<boolean>(
    effectiveRole === 'marketer' || effectiveRole === 'manager'
  );
  const [rawInput, setRawInput] = useState('');
  const [parsing, setParsing] = useState(false);
  const [drafts, setDrafts] = useState<DraftImportItem[]>([]);

  // Manual quick entry fallback
  const [manualTitle, setManualTitle] = useState('');
  const [manualPriceSar, setManualPriceSar] = useState('');
  const [manualUrl, setManualUrl] = useState('');
  const [manualColor, setManualColor] = useState('أسود فاحم');
  const [manualSize, setManualSize] = useState('M');
  const [manualImageUrl, setManualImageUrl] = useState('');
  const [manualNonRefundable, setManualNonRefundable] = useState(false);

  const handleAnalyzeLinks = async () => {
    const entries: ParsedSheinEntry[] = parseSheinShareInput(rawInput);
    if (entries.length === 0) {
      notifyToast('لم يتم العثور على رابط SHEIN أو رقم قطعة صالح', 'error');
      return;
    }

    setParsing(true);
    const resolved: DraftImportItem[] = [];
    for (const entry of entries) {
      let cachedTitle = entry.titleHint;
      let cachedPrice = entry.priceSarHint ? String(entry.priceSarHint) : '';
      let cachedImg = BRAND_IMAGES.kaftan;
      let fromCache = false;
      let sizePrices: Record<string, number> =
        (await readCachedSheinSizePrices(entry.goodsId)) || {};
      let availableColors = [...DEFAULT_COLOR_SET];
      let availableSizes = [...DEFAULT_SIZE_SET];

      const catExisting = catalog.find((c) => c.goodsId === entry.goodsId);
      if (catExisting) {
        cachedTitle = catExisting.title;
        if (!cachedPrice) cachedPrice = String(catExisting.basePriceSar);
        cachedImg = sanitizeImageUrl(catExisting.imageUrl, BRAND_IMAGES.kaftan);
        if (catExisting.colors?.length) availableColors = catExisting.colors;
        if (catExisting.sizes?.length) availableSizes = catExisting.sizes;
        if (catExisting.sizePrices) sizePrices = { ...catExisting.sizePrices, ...sizePrices };
        fromCache = true;
      }

      // Check shared Firestore shein_cache
      try {
        const snap = await getDoc(doc(db, 'shein_cache', entry.goodsId));
        if (snap.exists()) {
          const data = snap.data();
          if (data.title) cachedTitle = String(data.title);
          if (!cachedPrice && data.priceSar) cachedPrice = String(data.priceSar);
          if (data.imageUrl) cachedImg = sanitizeImageUrl(String(data.imageUrl), BRAND_IMAGES.kaftan);
          if (data.sizePrices && typeof data.sizePrices === 'object') {
            sizePrices = { ...sizePrices, ...(data.sizePrices as Record<string, number>) };
          }
          fromCache = true;
        }
      } catch {
        // fallback cleanly
      }

      const classified = classifyBrandAndCategory(cachedTitle, entry.url);
      const numericBase = parseFloat(cachedPrice);
      if (Number.isFinite(numericBase) && numericBase > 0 && Object.keys(sizePrices).length === 0) {
        sizePrices = { S: numericBase, M: numericBase, L: numericBase, XL: numericBase };
      }

      // Detect price drop for Marketer alert if existing catalog price was higher
      if (catExisting && Number.isFinite(numericBase) && numericBase > 0 && numericBase < catExisting.basePriceSar - 0.5) {
        await notifyMarketerDiscount(cachedTitle, catExisting.basePriceSar, numericBase, entry.url);
      }

      resolved.push({
        goodsId: entry.goodsId,
        url: entry.url,
        title: cachedTitle,
        priceSar: cachedPrice,
        marginSar: '15',
        promoHeadline: '',
        category: classified.category,
        color: availableColors[0] || 'أسود فاحم',
        availableColors,
        size: availableSizes[1] || availableSizes[0] || 'M',
        availableSizes,
        sizePrices,
        qty: 1,
        imageUrl: sanitizeImageUrl(cachedImg, BRAND_IMAGES.kaftan),
        fromCache,
      });
    }
    setDrafts(resolved);
    setParsing(false);
    notifyToast(`تم تحليل ${resolved.length} رابط بنجاح`, 'success');
  };

  const handleSizeSelectOnDraft = (idx: number, nextSize: string) => {
    setDrafts((prev) =>
      prev.map((d, i) => {
        if (i !== idx) return d;
        const sizePrice = d.sizePrices[nextSize];
        return {
          ...d,
          size: nextSize,
          priceSar: typeof sizePrice === 'number' && sizePrice > 0 ? String(sizePrice) : d.priceSar,
        };
      })
    );
  };

  const updateDraftSizePrice = (idx: number, size: string, rawVal: string) => {
    const num = parseFloat(rawVal);
    setDrafts((prev) =>
      prev.map((d, i) => {
        if (i !== idx) return d;
        const nextMap = { ...d.sizePrices };
        if (Number.isFinite(num) && num > 0) {
          nextMap[size] = num;
        }
        return {
          ...d,
          sizePrices: nextMap,
          priceSar: d.size === size && Number.isFinite(num) && num > 0 ? String(num) : d.priceSar,
        };
      })
    );
  };

  const addDraftToCart = async (d: DraftImportItem) => {
    const sizeSpecific = d.sizePrices[d.size];
    const price = sizeSpecific && sizeSpecific > 0 ? sizeSpecific : parseFloat(d.priceSar);
    if (!Number.isFinite(price) || price <= 0) {
      notifyToast('يرجى إدخال سعر القطعة بالريال السعودي قبل الإضافة للسلة', 'error');
      return;
    }
    const nr = detectNonRefundable(d.title, d.category);
    const safeImg = sanitizeImageUrl(d.imageUrl, BRAND_IMAGES.kaftan);

    if (Object.keys(d.sizePrices).length > 0) {
      await cacheSheinSizePrices(d.goodsId, d.sizePrices);
    }

    addToCart({
      goodsId: d.goodsId,
      title: d.title.trim() || `منتج SHEIN #${d.goodsId}`,
      imageUrl: safeImg,
      color: d.color || 'أساسي',
      size: d.size || 'One Size',
      availableColors: d.availableColors,
      availableSizes: d.availableSizes,
      sizePrices: Object.keys(d.sizePrices).length > 0 ? d.sizePrices : undefined,
      qty: Math.max(1, d.qty),
      unitPriceSar: price,
      productUrl: d.url,
      source: 'shein',
      nonRefundable: nr.nonRefundable,
      nonRefundableReason: nr.reason,
    });

    if (isStaff) {
      try {
        await setDoc(
          doc(db, 'shein_cache', d.goodsId),
          {
            title: d.title,
            priceSar: price,
            sizePrices: d.sizePrices,
            imageUrl: safeImg,
            sourceUrl: d.url,
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        );
      } catch {
        // non-blocking
      }
    }
  };

  const publishDraftToCatalog = async (d: DraftImportItem) => {
    const base = parseFloat(d.priceSar);
    const margin = parseFloat(d.marginSar) || 0;
    if (!Number.isFinite(base) || base <= 0) {
      notifyToast('أدخل السعر الأساسي بالريال السعودي أولاً', 'error');
      return;
    }
    const nr = detectNonRefundable(d.title, d.category);
    const classified = classifyBrandAndCategory(d.title, d.url, d.category);
    const safeImg = sanitizeImageUrl(d.imageUrl, BRAND_IMAGES.kaftan);

    if (Object.keys(d.sizePrices).length > 0) {
      await cacheSheinSizePrices(d.goodsId, d.sizePrices);
    }

    await upsertCatalogItem({
      title: d.title.trim() || `منتج SHEIN #${d.goodsId}`,
      goodsId: d.goodsId,
      sourceUrl: d.url,
      imageUrl: safeImg,
      brand: classified.brand,
      promoHeadline: d.promoHeadline.trim(),
      category: d.category || classified.category,
      colors: d.availableColors.includes(d.color)
        ? d.availableColors
        : [d.color, ...d.availableColors],
      sizes: d.availableSizes,
      sizePrices: Object.keys(d.sizePrices).length > 0 ? d.sizePrices : undefined,
      basePriceSar: base,
      marginSar: margin,
      region: currency === 'north' ? 'north' : 'south',
      badge: 'new',
      active: true,
      nonRefundable: nr.nonRefundable,
      nonRefundableReason: nr.reason,
    });
  };

  const handleManualAdd = (e: React.FormEvent) => {
    e.preventDefault();
    const price = parseFloat(manualPriceSar);
    if (!manualTitle.trim() || !Number.isFinite(price) || price <= 0) {
      notifyToast('يرجى كتابة اسم القطعة والسعر بالريال السعودي', 'error');
      return;
    }
    const parsed = parseSheinShareInput(manualUrl);
    const gid = parsed[0]?.goodsId || `MAN-${Date.now().toString().slice(-6)}`;
    const nr = detectNonRefundable(manualTitle);
    const safeImg = sanitizeImageUrl(manualImageUrl, BRAND_IMAGES.streetwear);

    if (marketerMode && isStaff) {
      const classified = classifyBrandAndCategory(manualTitle, manualUrl);
      upsertCatalogItem({
        title: manualTitle.trim(),
        goodsId: gid,
        sourceUrl: manualUrl.trim() || '',
        imageUrl: safeImg,
        brand: classified.brand,
        category: classified.category,
        colors: [manualColor || 'أساسي'],
        sizes: ['S', 'M', 'L', 'XL'],
        basePriceSar: price,
        marginSar: 15,
        region: 'south',
        badge: 'new',
        active: true,
        nonRefundable: manualNonRefundable || nr.nonRefundable,
        nonRefundableReason: manualNonRefundable ? 'محدد يدوياً كغير قابل للاسترداد' : nr.reason,
      });
    } else {
      addToCart({
        goodsId: gid,
        title: manualTitle.trim(),
        imageUrl: safeImg,
        color: manualColor || 'أساسي',
        size: manualSize || 'M',
        availableColors: DEFAULT_COLOR_SET,
        availableSizes: DEFAULT_SIZE_SET,
        qty: 1,
        unitPriceSar: price,
        productUrl: manualUrl.trim() || `https://m.shein.com/ar/`,
        source: 'manual',
        nonRefundable: manualNonRefundable || nr.nonRefundable,
        nonRefundableReason: manualNonRefundable ? 'محدد يدوياً كغير قابل للاسترداد' : nr.reason,
      });
    }
    setManualTitle('');
    setManualPriceSar('');
    setManualUrl('');
    setManualImageUrl('');
  };

  return (
    <div className="space-y-8 pb-16">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 border-b border-black/10 dark:border-white/10 pb-6">
        <div>
          <div className="text-xs font-semibold uppercase tracking-wider text-violet-700 dark:text-violet-300">
            {marketerMode ? 'MARKETER WEB STUDIO · وضع تصفح المسوّق' : 'SHEIN LINK & CART SHARE IMPORTER'}
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold mt-1">
            {marketerMode
              ? 'استيراد ونشر SHEIN مباشرة لكتالوج يمن سيلو'
              : 'استيراد روابط وسلال SHEIN'}
          </h1>
          <p className="text-sm text-[#5F5870] dark:text-[#A9A1BA] mt-1">
            {marketerMode
              ? 'صفحة المسوّق الخاصة: الصق روابط المنتجات أو السلال لنشرها مباشرة في كتالوج يمن سيلو مع ضبط هامش الربح وأسعار المقاسات.'
              : 'الصق رابط المنتج، نص المشاركة الكامل، أو رابط السلة المشتركة مع مزامنة الأسعار حسب المقاس.'}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          {/* Marketer Browsing Mode Toggle */}
          {isStaff && (
            <button
              type="button"
              onClick={() => setMarketerMode((v) => !v)}
              className={`px-4 py-2.5 rounded-xl text-xs font-bold flex items-center gap-1.5 border transition-colors ${
                marketerMode
                  ? 'bg-amber-600 text-white border-amber-600'
                  : 'border-amber-500/40 text-amber-700 dark:text-amber-300 hover:bg-amber-500/10'
              }`}
            >
              <Briefcase className="w-4 h-4" />
              <span>{marketerMode ? 'وضع تصفح المسوّق: مفعّل ✓' : 'تفعيل وضع تصفح المسوّق'}</span>
            </button>
          )}
          <a
            href="https://m.shein.com/ar/"
            target="_blank"
            rel="noreferrer"
            className="px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold flex items-center gap-1.5 hover:bg-black/5 dark:hover:bg-white/5"
          >
            <ExternalLink className="w-4 h-4 text-violet-600 dark:text-violet-400" />
            <span>فتح موقع SHEIN</span>
          </a>
          <button
            type="button"
            onClick={() => setActiveTab(marketerMode ? 'catalog' : 'cart')}
            className="px-4 py-2.5 rounded-xl bg-violet-600 text-white text-xs font-bold hover:bg-violet-700"
          >
            {marketerMode ? 'عرض الكتالوج' : 'الانتقال للسلة'}
          </button>
        </div>
      </div>

      {/* Smart Link & Share Text Parser */}
      <div className="rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] p-6 space-y-4">
        <div className="flex items-center gap-2 font-bold text-base">
          <Link2 className="w-5 h-5 text-violet-600 dark:text-violet-400" />
          <span>الصق رابط SHEIN أو عدة روابط دفعة واحدة</span>
        </div>

        <textarea
          rows={4}
          value={rawInput}
          onChange={(e) => setRawInput(e.target.value)}
          placeholder={
            'مثال:\nhttps://onelink.shein.com/... أو https://m.shein.com/ar/product-p-28491032.html\nأو الصق أكثر من رابط في أسطر متعددة...'
          }
          className="w-full p-4 rounded-2xl border border-black/15 dark:border-white/15 bg-[#FAF8F5] dark:bg-[#0D0B14] text-sm focus:outline-none focus:ring-2 focus:ring-violet-500"
        />

        <div className="flex flex-wrap items-center justify-between gap-3">
          <span className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
            يستخرج الأسعار المخزّنة لكل مقاس عبر IndexedDB والكاش المشترك (shein_cache).
          </span>
          <button
            type="button"
            onClick={handleAnalyzeLinks}
            disabled={parsing}
            className="px-6 py-3 rounded-xl bg-violet-600 hover:bg-violet-700 text-white font-bold text-sm flex items-center gap-2 disabled:opacity-60"
          >
            <RefreshCw className={`w-4 h-4 ${parsing ? 'animate-spin' : ''}`} />
            <span>تحليل وجلب البيانات</span>
          </button>
        </div>
      </div>

      {/* Resolved Drafts */}
      {drafts.length > 0 && (
        <div className="space-y-4">
          <h2 className="text-lg font-extrabold">الروابط المستخرجة ({drafts.length})</h2>
          <div className="grid gap-4">
            {drafts.map((d, idx) => {
              const baseSar = parseFloat(d.priceSar) || 0;
              const marginSar = parseFloat(d.marginSar) || 0;
              const effectiveSar = marketerMode ? baseSar + marginSar : baseSar;
              const nr = detectNonRefundable(d.title, d.category);

              return (
                <div
                  key={`${d.goodsId}_${idx}`}
                  className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] grid md:grid-cols-12 gap-5 items-start"
                >
                  <div className="md:col-span-2 space-y-2">
                    <img
                      src={sanitizeImageUrl(d.imageUrl, BRAND_IMAGES.kaftan)}
                      alt={d.title}
                      onError={(e) => {
                        e.currentTarget.src = BRAND_IMAGES.kaftan;
                      }}
                      className="w-full aspect-square object-cover rounded-xl bg-[#F3EFE9] dark:bg-[#1E1830]"
                    />
                    <input
                      type="url"
                      value={d.imageUrl.startsWith('data:') ? '' : d.imageUrl}
                      onChange={(e) => {
                        const val = e.target.value;
                        setDrafts((prev) =>
                          prev.map((x, i) => (i === idx ? { ...x, imageUrl: val } : x))
                        );
                      }}
                      placeholder="تحديث رابط الصورة..."
                      className="w-full px-2.5 py-1.5 rounded-lg border border-black/10 dark:border-white/10 bg-transparent text-[11px]"
                    />
                  </div>

                  <div className="md:col-span-7 space-y-3">
                    <div className="flex flex-wrap items-center gap-2 text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                      <span className="font-mono-num">#{d.goodsId}</span>
                      {d.fromCache && (
                        <span className="flex items-center gap-1 text-emerald-600 dark:text-emerald-400 font-semibold">
                          <CheckCircle2 className="w-3.5 h-3.5" />
                          <span>مخزّن في الكاش</span>
                        </span>
                      )}
                    </div>

                    <input
                      type="text"
                      value={d.title}
                      onChange={(e) => {
                        const val = e.target.value;
                        setDrafts((prev) =>
                          prev.map((x, i) => (i === idx ? { ...x, title: val } : x))
                        );
                      }}
                      className="w-full px-3.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-semibold"
                    />

                    {/* Color Swatch Selector */}
                    <div className="space-y-1.5">
                      <span className="text-[11px] font-bold text-[#5F5870] dark:text-[#A9A1BA]">
                        اللون المختار ({d.color}):
                      </span>
                      <div className="flex flex-wrap gap-1.5">
                        {d.availableColors.map((col) => (
                          <button
                            key={col}
                            type="button"
                            onClick={() =>
                              setDrafts((prev) =>
                                prev.map((x, i) => (i === idx ? { ...x, color: col } : x))
                              )
                            }
                            className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold border flex items-center gap-1.5 ${
                              d.color === col
                                ? 'border-violet-600 bg-violet-600 text-white'
                                : 'border-black/10 dark:border-white/10'
                            }`}
                          >
                            <span
                              className="w-3 h-3 rounded-full border border-black/20 shrink-0"
                              style={{ backgroundColor: colorToHex(col) }}
                            />
                            <span>{col}</span>
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Size & Per-Size Price Sync */}
                    <div className="space-y-2">
                      <span className="text-[11px] font-bold text-[#5F5870] dark:text-[#A9A1BA]">
                        المقاس وسعر كل مقاس (يحدّث السعر تلقائياً عند التغيير):
                      </span>
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                        {d.availableSizes.map((sz) => (
                          <div
                            key={sz}
                            className={`p-2 rounded-xl border text-xs ${
                              d.size === sz
                                ? 'border-violet-600 bg-violet-600/8'
                                : 'border-black/10 dark:border-white/10'
                            }`}
                          >
                            <button
                              type="button"
                              onClick={() => handleSizeSelectOnDraft(idx, sz)}
                              className="font-mono-num font-bold w-full text-right mb-1 text-violet-700 dark:text-violet-300"
                            >
                              {sz} {d.size === sz ? '✓' : ''}
                            </button>
                            <input
                              type="number"
                              step="0.01"
                              value={d.sizePrices[sz] ?? ''}
                              onChange={(e) => updateDraftSizePrice(idx, sz, e.target.value)}
                              placeholder="سعر SAR"
                              className="w-full px-2 py-1 rounded-lg border border-black/10 dark:border-white/10 bg-transparent text-[11px] font-mono-num"
                            />
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* Base price, Qty, and Marketer Fields */}
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
                      <div>
                        <label className="text-[10px] font-bold block mb-0.5">
                          السعر للمقاس ({d.size}) SAR
                        </label>
                        <input
                          type="number"
                          step="0.01"
                          value={d.priceSar}
                          onChange={(e) => {
                            const val = e.target.value;
                            setDrafts((prev) =>
                              prev.map((x, i) => (i === idx ? { ...x, priceSar: val } : x))
                            );
                          }}
                          className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                        />
                      </div>

                      {marketerMode ? (
                        <>
                          <div>
                            <label className="text-[10px] font-bold block mb-0.5">الربح SAR</label>
                            <input
                              type="number"
                              step="0.5"
                              value={d.marginSar}
                              onChange={(e) => {
                                const val = e.target.value;
                                setDrafts((prev) =>
                                  prev.map((x, i) => (i === idx ? { ...x, marginSar: val } : x))
                                );
                              }}
                              className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                            />
                          </div>
                          <div>
                            <label className="text-[10px] font-bold block mb-0.5">التصنيف</label>
                            <select
                              value={d.category}
                              onChange={(e) => {
                                const val = e.target.value;
                                setDrafts((prev) =>
                                  prev.map((x, i) => (i === idx ? { ...x, category: val } : x))
                                );
                              }}
                              className="w-full px-2.5 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-xs"
                            >
                              {CATALOG_CATEGORIES.filter((c) => c !== 'الكل').map((c) => (
                                <option key={c} value={c}>
                                  {c}
                                </option>
                              ))}
                            </select>
                          </div>
                          <div>
                            <label className="text-[10px] font-bold block mb-0.5">
                              عنوان ترويجي
                            </label>
                            <input
                              type="text"
                              value={d.promoHeadline}
                              onChange={(e) => {
                                const val = e.target.value;
                                setDrafts((prev) =>
                                  prev.map((x, i) => (i === idx ? { ...x, promoHeadline: val } : x))
                                );
                              }}
                              placeholder="عرض اليوم..."
                              className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs"
                            />
                          </div>
                        </>
                      ) : (
                        <div>
                          <label className="text-[10px] font-bold block mb-0.5">الكمية</label>
                          <input
                            type="number"
                            min={1}
                            max={99}
                            value={d.qty}
                            onChange={(e) => {
                              const val = parseInt(e.target.value || '1', 10);
                              setDrafts((prev) =>
                                prev.map((x, i) => (i === idx ? { ...x, qty: val } : x))
                              );
                            }}
                            className="w-full px-3 py-2 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs font-mono-num"
                          />
                        </div>
                      )}
                    </div>

                    {nr.nonRefundable && (
                      <div className="flex items-center gap-1.5 text-xs text-amber-700 dark:text-amber-300">
                        <AlertTriangle className="w-3.5 h-3.5" />
                        <span>تحذير: {nr.reason} — غير قابلة للاسترداد الاختياري</span>
                      </div>
                    )}
                  </div>

                  <div className="md:col-span-3 flex flex-col gap-2">
                    <div className="p-3 rounded-xl bg-[#FAF8F5] dark:bg-[#0D0B14] border border-black/5 dark:border-white/5 space-y-1">
                      <div className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">
                        {marketerMode ? 'سعر البيع النهائي في الكتالوج' : `السعر الإجمالي (${d.size})`}
                      </div>
                      <div className="text-sm font-mono-num font-bold text-violet-700 dark:text-violet-300">
                        {effectiveSar > 0
                          ? formatMoney(
                              convertSarToCurrency(
                                marketerMode ? effectiveSar : effectiveSar * d.qty,
                                currency,
                                settings
                              ),
                              currency
                            )
                          : 'أدخل السعر بالريال السعودي'}
                      </div>
                    </div>

                    {marketerMode ? (
                      <button
                        type="button"
                        onClick={() => publishDraftToCatalog(d)}
                        className="w-full py-2.5 rounded-xl bg-amber-600 hover:bg-amber-700 text-white text-xs font-bold flex items-center justify-center gap-1.5"
                      >
                        <Upload className="w-4 h-4" />
                        <span>إضافة إلى كتالوج يمن سيلو</span>
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={() => addDraftToCart(d)}
                        className="w-full py-2.5 rounded-xl bg-violet-600 hover:bg-violet-700 text-white text-xs font-bold flex items-center justify-center gap-1.5"
                      >
                        <ShoppingBag className="w-4 h-4" />
                        <span>إضافة إلى سلة يمن سيلو</span>
                      </button>
                    )}

                    {isStaff && !marketerMode && (
                      <button
                        type="button"
                        onClick={() => publishDraftToCatalog(d)}
                        className="w-full py-2 rounded-xl border border-amber-600/40 text-amber-700 dark:text-amber-300 text-xs font-bold flex items-center justify-center gap-1.5 hover:bg-amber-500/10"
                      >
                        <Upload className="w-3.5 h-3.5" />
                        <span>نشر للكتالوج</span>
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Manual Quick Item Entry */}
      <form
        onSubmit={handleManualAdd}
        className="rounded-3xl border border-black/10 dark:border-white/10 bg-[#F3EFE9] dark:bg-[#1E1830] p-6 space-y-4"
      >
        <div className="flex items-center gap-2 font-bold text-base">
          <Sparkles className="w-5 h-5 text-amber-600 dark:text-amber-400" />
          <span>
            {marketerMode
              ? 'نشر قطعة سريعة لكتالوج يمن سيلو يدوياً'
              : 'إضافة قطعة سريعة يدوياً (في حال تعذر الرابط أو طلب خاص)'}
          </span>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-5 gap-3">
          <input
            type="text"
            value={manualTitle}
            onChange={(e) => setManualTitle(e.target.value)}
            placeholder="اسم القطعة أو الوصف *"
            className="lg:col-span-2 px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
          />
          <input
            type="number"
            step="0.01"
            value={manualPriceSar}
            onChange={(e) => setManualPriceSar(e.target.value)}
            placeholder="السعر بـ SAR *"
            className="px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm font-mono-num"
          />
          <input
            type="text"
            value={manualColor}
            onChange={(e) => setManualColor(e.target.value)}
            placeholder="اللون"
            className="px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
          />
          <input
            type="text"
            value={manualSize}
            onChange={(e) => setManualSize(e.target.value)}
            placeholder="المقاس"
            className="px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
          />
        </div>

        <div className="grid sm:grid-cols-2 gap-3">
          <input
            type="url"
            value={manualUrl}
            onChange={(e) => setManualUrl(e.target.value)}
            placeholder="رابط SHEIN اختياري..."
            className="px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
          />
          <input
            type="url"
            value={manualImageUrl}
            onChange={(e) => setManualImageUrl(e.target.value)}
            placeholder="رابط صورة المنتج (اختياري)..."
            className="px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
          />
        </div>

        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <label className="flex items-center gap-2 text-xs font-semibold cursor-pointer">
            <input
              type="checkbox"
              checked={manualNonRefundable}
              onChange={(e) => setManualNonRefundable(e.target.checked)}
              className="rounded border-gray-300 text-violet-600 focus:ring-violet-500"
            />
            <span>وسم كقطعة غير قابلة للاسترداد</span>
          </label>
          <button
            type="submit"
            className="px-6 py-2.5 rounded-xl bg-[#171321] dark:bg-violet-600 text-white text-sm font-bold hover:opacity-90 shrink-0 flex items-center gap-1.5 justify-center"
          >
            <Plus className="w-4 h-4" />
            <span>{marketerMode ? 'إضافة لكتالوج يمن سيلو' : 'إضافة للسلة'}</span>
          </button>
        </div>
      </form>
    </div>
  );
};

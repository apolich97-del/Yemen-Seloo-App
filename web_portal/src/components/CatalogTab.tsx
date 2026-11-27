import React, { useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  Bell,
  BellRing,
  Copy,
  ExternalLink,
  MessageCircle,
  Search,
  ShoppingBag,
  Tag,
  X,
} from 'lucide-react';
import { useSeloo } from '../context/SelooContext';
import { BRAND_IMAGES, CATALOG_CATEGORIES } from '../data/seedData';
import {
  classifyBrandAndCategory,
  colorToHex,
  computeCurrencyMatrix,
  convertSarToCurrency,
  detectNonRefundable,
  formatMoney,
  sanitizeImageUrl,
} from '../services/pricingService';
import { CatalogItem } from '../types/seloo';

type BrandFilter = 'الكل' | 'SHEIN' | 'يمن سيلو الخاص' | 'المتابَعة';

export const CatalogTab: React.FC = () => {
  const {
    catalog,
    catalogLoading,
    currency,
    settings,
    addToCart,
    setActiveTab,
    followedProductIds,
    toggleFollowProduct,
    deepLinkedProductId,
    clearDeepLinkedProduct,
    notifyToast,
  } = useSeloo();

  const [search, setSearch] = useState('');
  const [selectedBrand, setSelectedBrand] = useState<BrandFilter>('الكل');
  const [selectedCat, setSelectedCat] = useState('الكل');
  const [activeProduct, setActiveProduct] = useState<CatalogItem | null>(null);
  const [chosenColor, setChosenColor] = useState('');
  const [chosenSize, setChosenSize] = useState('');
  const [qty, setQty] = useState(1);

  const openProduct = (item: CatalogItem) => {
    setActiveProduct(item);
    setChosenColor(item.colors[0] || 'أساسي');
    setChosenSize(item.sizes[0] || 'One Size');
    setQty(1);
  };

  // Auto-open product if ?product=<id> deep link is present
  useEffect(() => {
    if (!deepLinkedProductId || catalog.length === 0) return;
    const match = catalog.find(
      (c) => c.goodsId === deepLinkedProductId || c.id === deepLinkedProductId
    );
    if (match) {
      openProduct(match);
    }
  }, [deepLinkedProductId, catalog]);

  const closeProductModal = () => {
    setActiveProduct(null);
    if (deepLinkedProductId) {
      clearDeepLinkedProduct();
    }
  };

  const getItemBrand = (item: CatalogItem): 'SHEIN' | 'يمن سيلو الخاص' => {
    if (item.brand === 'SHEIN' || item.brand === 'يمن سيلو الخاص') {
      return item.brand;
    }
    return classifyBrandAndCategory(item.title, item.sourceUrl, item.category).brand;
  };

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return catalog.filter((item) => {
      const brand = getItemBrand(item);
      const isFollowed =
        followedProductIds.includes(item.goodsId) || followedProductIds.includes(item.id);
      const brandOk =
        selectedBrand === 'الكل' ||
        (selectedBrand === 'المتابَعة' ? isFollowed : brand === selectedBrand);
      const catOk = selectedCat === 'الكل' || item.category === selectedCat;
      const qOk =
        !q ||
        item.title.toLowerCase().includes(q) ||
        item.goodsId.toLowerCase().includes(q) ||
        item.category.toLowerCase().includes(q) ||
        brand.toLowerCase().includes(q);
      return brandOk && catOk && qOk;
    });
  }, [catalog, search, selectedBrand, selectedCat, followedProductIds]);

  const activeUnitSar = useMemo(() => {
    if (!activeProduct) return 0;
    const baseForSize =
      activeProduct.sizePrices && chosenSize && typeof activeProduct.sizePrices[chosenSize] === 'number'
        ? activeProduct.sizePrices[chosenSize]
        : activeProduct.basePriceSar;
    return baseForSize + activeProduct.marginSar;
  }, [activeProduct, chosenSize]);

  const confirmAdd = () => {
    if (!activeProduct) return;
    const nr = detectNonRefundable(
      activeProduct.title,
      activeProduct.category,
      activeProduct.nonRefundableReason
    );
    const sizePricesWithMargin: Record<string, number> | undefined = activeProduct.sizePrices
      ? Object.fromEntries(
          Object.entries(activeProduct.sizePrices).map(([sz, p]) => [
            sz,
            Number(p) + activeProduct.marginSar,
          ])
        )
      : undefined;

    addToCart({
      goodsId: activeProduct.goodsId,
      title: activeProduct.title,
      imageUrl: sanitizeImageUrl(activeProduct.imageUrl, BRAND_IMAGES.kaftan),
      color: chosenColor || 'أساسي',
      size: chosenSize || 'One Size',
      availableColors: activeProduct.colors,
      availableSizes: activeProduct.sizes,
      sizePrices: sizePricesWithMargin,
      qty,
      unitPriceSar: activeUnitSar,
      productUrl: activeProduct.sourceUrl,
      source: 'catalog',
      nonRefundable: activeProduct.nonRefundable || nr.nonRefundable,
      nonRefundableReason: activeProduct.nonRefundableReason || nr.reason,
    });
    closeProductModal();
  };

  const getProductShareUrl = (item: CatalogItem) => {
    const origin =
      typeof window !== 'undefined' ? window.location.origin : 'https://yemenseloo.com';
    return `${origin}/?product=${encodeURIComponent(item.goodsId)}`;
  };

  const handleCopyProductLink = async (item: CatalogItem) => {
    const url = getProductShareUrl(item);
    try {
      await navigator.clipboard.writeText(url);
      notifyToast('تم نسخ رابط المنتج المباشر للمشاركة', 'success');
    } catch {
      notifyToast(url, 'info');
    }
  };

  const handleShareWhatsApp = (item: CatalogItem, sarPrice: number) => {
    const shareUrl = getProductShareUrl(item);
    const local = formatMoney(convertSarToCurrency(sarPrice, currency, settings), currency);
    const msg = [
      `🛍️ *${item.title}*`,
      item.promoHeadline ? `✨ ${item.promoHeadline}` : '',
      `السعر: *${local}* (${sarPrice.toFixed(2)} ر.س)`,
      `شاهد التفاصيل واطلب مباشرة من يمن سيلو:`,
      shareUrl,
    ]
      .filter(Boolean)
      .join('\n');
    const a = document.createElement('a');
    a.href = `https://wa.me/?text=${encodeURIComponent(msg)}`;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.click();
  };

  return (
    <div className="space-y-7 pb-16">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 border-b border-black/10 dark:border-white/10 pb-6">
        <div>
          <div className="text-xs font-semibold uppercase tracking-wider text-violet-700 dark:text-violet-300">
            SEPARATED CATALOG · كتالوج يمن سيلو المستقل
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold mt-1">كتالوج يمن سيلو</h1>
          <p className="text-sm text-[#5F5870] dark:text-[#A9A1BA] mt-1">
            مصنّف تلقائياً حسب العلامة التجارية والنوع، مع متابعة الأسعار ومشاركة الروابط المباشرة.
          </p>
        </div>

        <div className="flex items-center gap-2.5 w-full md:w-auto">
          <div className="relative flex-1 md:w-72">
            <Search className="w-4 h-4 text-[#5F5870] dark:text-[#A9A1BA] absolute top-1/2 -translate-y-1/2 right-3.5" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="ابحث بالاسم أو رقم القطعة..."
              className="w-full pr-10 pl-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm focus:outline-none focus:ring-2 focus:ring-violet-500"
            />
          </div>
          <button
            type="button"
            onClick={() => setActiveTab('shein')}
            className="px-4 py-2.5 rounded-xl border border-violet-600/30 text-violet-700 dark:text-violet-300 text-xs font-bold hover:bg-violet-600/10 transition-colors shrink-0"
          >
            استيراد SHEIN
          </button>
        </div>
      </div>

      {/* Auto Brand Filter + Followed Products Filter */}
      <div className="space-y-3">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs font-bold text-[#5F5870] dark:text-[#A9A1BA] ml-1 flex items-center gap-1">
            <Tag className="w-3.5 h-3.5" />
            <span>العلامة:</span>
          </span>
          {(['الكل', 'SHEIN', 'يمن سيلو الخاص', 'المتابَعة'] as BrandFilter[]).map((br) => {
            const active = selectedBrand === br;
            return (
              <button
                key={br}
                type="button"
                onClick={() => setSelectedBrand(br)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-bold border transition-colors ${
                  active
                    ? 'bg-[#171321] dark:bg-amber-500 dark:text-[#171321] text-white border-transparent'
                    : 'bg-white dark:bg-[#151122] border-black/10 dark:border-white/10 hover:border-violet-500/50'
                }`}
              >
                {br === 'المتابَعة' ? `المتابَعة (${followedProductIds.length})` : br}
              </button>
            );
          })}
        </div>

        {/* Category segmented filter */}
        <div className="flex flex-wrap gap-2">
          {CATALOG_CATEGORIES.map((cat) => {
            const active = selectedCat === cat;
            return (
              <button
                key={cat}
                type="button"
                onClick={() => setSelectedCat(cat)}
                className={`px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition-colors border ${
                  active
                    ? 'bg-violet-600 text-white border-violet-600'
                    : 'bg-white dark:bg-[#151122] border-black/10 dark:border-white/10 hover:border-violet-500/50'
                }`}
              >
                {cat}
              </button>
            );
          })}
        </div>
      </div>

      {catalogLoading ? (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="h-96 rounded-2xl border border-black/10 dark:border-white/10 bg-black/5 dark:bg-white/5 animate-pulse"
            />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="p-12 text-center rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3">
          <p className="font-bold text-lg">لا توجد منتجات مطابقة لبحثك</p>
          <p className="text-sm text-[#5F5870] dark:text-[#A9A1BA]">
            يمكنك لصق أي رابط قطعة أو سلة من SHEIN في تبويب الاستيراد لإضافته فوراً.
          </p>
        </div>
      ) : (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {filtered.map((item) => {
            const sar = item.basePriceSar + item.marginSar;
            const localPrice = convertSarToCurrency(sar, currency, settings);
            const matrix = computeCurrencyMatrix(sar, settings);
            const brand = getItemBrand(item);
            const isFollowed =
              followedProductIds.includes(item.goodsId) || followedProductIds.includes(item.id);
            const nr =
              item.nonRefundable ||
              detectNonRefundable(item.title, item.category).nonRefundable;
            const safeImg = sanitizeImageUrl(item.imageUrl, BRAND_IMAGES.kaftan);

            return (
              <article
                key={item.id}
                className="rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] overflow-hidden flex flex-col hover:-translate-y-0.5 hover:shadow-lg transition-all"
              >
                <div
                  className="aspect-[4/3] bg-[#F3EFE9] dark:bg-[#1E1830] overflow-hidden relative cursor-pointer"
                  onClick={() => openProduct(item)}
                >
                  <img
                    src={safeImg}
                    alt={item.title}
                    onError={(e) => {
                      e.currentTarget.src = BRAND_IMAGES.kaftan;
                    }}
                    className="w-full h-full object-cover"
                  />
                  {item.badge && (
                    <span className="absolute top-3 right-3 px-2.5 py-1 rounded-md text-[11px] font-bold bg-black/75 text-white">
                      {item.badge === 'best'
                        ? 'الأكثر مبيعاً'
                        : item.badge === 'new'
                        ? 'جديد'
                        : item.discountPercent
                        ? `خصم ${item.discountPercent}%`
                        : 'عرض'}
                    </span>
                  )}
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      toggleFollowProduct(item.goodsId);
                    }}
                    className={`absolute top-3 left-3 p-2 rounded-lg backdrop-blur-md transition-colors ${
                      isFollowed
                        ? 'bg-violet-600 text-white'
                        : 'bg-black/55 text-white hover:bg-black/75'
                    }`}
                    title={isFollowed ? 'تتم متابعة السعر' : 'متابعة تنبيهات السعر'}
                  >
                    {isFollowed ? (
                      <BellRing className="w-4 h-4" />
                    ) : (
                      <Bell className="w-4 h-4" />
                    )}
                  </button>
                </div>

                <div className="p-5 flex-1 flex flex-col justify-between gap-4">
                  <div className="space-y-2">
                    <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA] flex items-center justify-between gap-2">
                      <span>
                        <strong className="text-violet-700 dark:text-violet-300">{brand}</strong> ·{' '}
                        {item.category}
                      </span>
                      <span className="font-mono-num">#{item.goodsId}</span>
                    </div>
                    <h3
                      onClick={() => openProduct(item)}
                      className="font-semibold text-base leading-snug cursor-pointer hover:text-violet-600 dark:hover:text-violet-400"
                    >
                      {item.title}
                    </h3>
                    {item.promoHeadline && (
                      <div className="text-xs font-bold text-amber-700 dark:text-amber-300">
                        {item.promoHeadline}
                      </div>
                    )}
                    {/* Visual color dots */}
                    <div className="flex items-center gap-1.5 pt-0.5">
                      {item.colors.slice(0, 5).map((col) => (
                        <span
                          key={col}
                          title={col}
                          className="w-4 h-4 rounded-full border border-black/20 dark:border-white/25 inline-block"
                          style={{ backgroundColor: colorToHex(col) }}
                        />
                      ))}
                      <span className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA] mr-1">
                        {item.sizes.length > 1 ? `${item.sizes.length} مقاسات` : item.sizes[0]}
                      </span>
                    </div>
                    {nr && (
                      <div className="flex items-center gap-1.5 text-xs text-amber-700 dark:text-amber-300">
                        <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
                        <span>غير قابل للاسترداد الاختياري</span>
                      </div>
                    )}
                  </div>

                  <div className="space-y-3 pt-3 border-t border-black/10 dark:border-white/10">
                    <div className="flex items-baseline justify-between gap-2">
                      <div>
                        <span className="font-mono-num font-extrabold text-lg text-violet-700 dark:text-violet-300">
                          {formatMoney(localPrice, currency)}
                        </span>
                        {item.originalPriceSar && item.originalPriceSar > sar && (
                          <span className="font-mono-num text-xs line-through text-[#5F5870] mr-2">
                            {item.originalPriceSar.toFixed(0)} SAR
                          </span>
                        )}
                      </div>
                      <span className="font-mono-num text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                        {sar.toFixed(2)} SAR · ${matrix.usd.toFixed(2)}
                      </span>
                    </div>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => openProduct(item)}
                        className="flex-1 py-2.5 rounded-xl bg-violet-600 hover:bg-violet-700 text-white text-sm font-bold flex items-center justify-center gap-2 transition-colors"
                      >
                        <ShoppingBag className="w-4 h-4" />
                        <span>اختر اللون والمقاس</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => handleCopyProductLink(item)}
                        className="px-3 py-2.5 rounded-xl border border-black/15 dark:border-white/15 hover:border-violet-500/50 text-xs font-bold"
                        title="نسخ رابط المنتج"
                      >
                        <Copy className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      )}

      {/* Product Detail / Variant Picker Modal */}
      {activeProduct && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 backdrop-blur-sm p-4"
          onClick={closeProductModal}
        >
          <div
            className="w-full max-w-2xl rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] overflow-hidden shadow-2xl max-h-[90vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="grid md:grid-cols-2">
              <div className="bg-[#F3EFE9] dark:bg-[#1E1830] aspect-square md:aspect-auto">
                <img
                  src={sanitizeImageUrl(activeProduct.imageUrl, BRAND_IMAGES.kaftan)}
                  alt={activeProduct.title}
                  onError={(e) => {
                    e.currentTarget.src = BRAND_IMAGES.kaftan;
                  }}
                  className="w-full h-full object-cover"
                />
              </div>
              <div className="p-6 flex flex-col justify-between gap-5">
                <div className="space-y-4">
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                        {getItemBrand(activeProduct)} · {activeProduct.category} · #
                        {activeProduct.goodsId}
                      </div>
                      <h2 className="text-lg font-extrabold mt-1 leading-snug">
                        {activeProduct.title}
                      </h2>
                    </div>
                    <button
                      type="button"
                      onClick={closeProductModal}
                      className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/10"
                    >
                      <X className="w-5 h-5" />
                    </button>
                  </div>

                  {/* Live 4-currency matrix reacting to chosenSize */}
                  {(() => {
                    const m = computeCurrencyMatrix(activeUnitSar, settings);
                    return (
                      <div className="p-3.5 rounded-xl bg-[#F3EFE9] dark:bg-[#1E1830] space-y-1 text-xs">
                        <div className="flex justify-between font-bold text-sm text-violet-700 dark:text-violet-300">
                          <span>السعر للمقاس ({chosenSize}):</span>
                          <span className="font-mono-num">
                            {formatMoney(
                              convertSarToCurrency(activeUnitSar, currency, settings),
                              currency
                            )}
                          </span>
                        </div>
                        <div className="flex justify-between text-[#5F5870] dark:text-[#A9A1BA] font-mono-num">
                          <span>سعودي: {m.sar.toFixed(2)} ر.س</span>
                          <span>دولار: ${m.usd.toFixed(2)}</span>
                        </div>
                        <div className="flex justify-between text-[#5F5870] dark:text-[#A9A1BA] font-mono-num">
                          <span>شمال: {m.northFromSar.toLocaleString('en-US')} ر.ي</span>
                          <span>جنوب: {m.southFromSar.toLocaleString('en-US')} ر.ي</span>
                        </div>
                      </div>
                    );
                  })()}

                  {/* Color Picker with Visual Swatches */}
                  <div>
                    <label className="text-xs font-bold block mb-2">اللون ({chosenColor})</label>
                    <div className="flex flex-wrap gap-2">
                      {activeProduct.colors.map((c) => (
                        <button
                          key={c}
                          type="button"
                          onClick={() => setChosenColor(c)}
                          className={`px-3 py-1.5 rounded-lg text-xs font-semibold border flex items-center gap-1.5 ${
                            chosenColor === c
                              ? 'border-violet-600 bg-violet-600 text-white'
                              : 'border-black/15 dark:border-white/15'
                          }`}
                        >
                          <span
                            className="w-3.5 h-3.5 rounded-full border border-black/20 shrink-0"
                            style={{ backgroundColor: colorToHex(c) }}
                          />
                          <span>{c}</span>
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Size Picker showing per-size SAR price if different */}
                  <div>
                    <label className="text-xs font-bold block mb-2">المقاس</label>
                    <div className="flex flex-wrap gap-2">
                      {activeProduct.sizes.map((s) => {
                        const sp = activeProduct.sizePrices?.[s];
                        return (
                          <button
                            key={s}
                            type="button"
                            onClick={() => setChosenSize(s)}
                            className={`px-3 py-1.5 rounded-lg text-xs font-semibold border font-mono-num ${
                              chosenSize === s
                                ? 'border-violet-600 bg-violet-600 text-white'
                                : 'border-black/15 dark:border-white/15'
                            }`}
                          >
                            {s}
                            {typeof sp === 'number'
                              ? ` (${(sp + activeProduct.marginSar).toFixed(0)} ر.س)`
                              : ''}
                          </button>
                        );
                      })}
                    </div>
                  </div>

                  {/* Quantity */}
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold">الكمية</span>
                    <div className="flex items-center gap-3 border border-black/15 dark:border-white/15 rounded-xl px-2 py-1">
                      <button
                        type="button"
                        onClick={() => setQty((q) => Math.max(1, q - 1))}
                        className="w-7 h-7 rounded-lg hover:bg-black/5 dark:hover:bg-white/10 font-bold"
                      >
                        -
                      </button>
                      <span className="font-mono-num font-bold w-6 text-center">{qty}</span>
                      <button
                        type="button"
                        onClick={() => setQty((q) => Math.min(99, q + 1))}
                        className="w-7 h-7 rounded-lg hover:bg-black/5 dark:hover:bg-white/10 font-bold"
                      >
                        +
                      </button>
                    </div>
                  </div>

                  {(activeProduct.nonRefundable ||
                    detectNonRefundable(activeProduct.title, activeProduct.category)
                      .nonRefundable) && (
                    <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/30 text-xs text-amber-800 dark:text-amber-200 flex gap-2">
                      <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
                      <span>
                        هذه القطعة غير قابلة للاسترداد أو الاستبدال الاختياري بعد التثبيت (
                        {activeProduct.nonRefundableReason || 'سياسة القطع الخاصة'}).
                      </span>
                    </div>
                  )}
                </div>

                <div className="space-y-2.5 pt-3 border-t border-black/10 dark:border-white/10">
                  <button
                    type="button"
                    onClick={confirmAdd}
                    className="w-full py-3 rounded-xl bg-violet-600 hover:bg-violet-700 text-white font-bold text-sm"
                  >
                    إضافة إلى السلة
                  </button>

                  {/* Follow + Share Buttons */}
                  <div className="grid grid-cols-3 gap-2">
                    <button
                      type="button"
                      onClick={() => toggleFollowProduct(activeProduct.goodsId)}
                      className={`py-2 rounded-xl border text-xs font-bold flex items-center justify-center gap-1 ${
                        followedProductIds.includes(activeProduct.goodsId)
                          ? 'border-violet-600 bg-violet-600/10 text-violet-700 dark:text-violet-300'
                          : 'border-black/10 dark:border-white/10'
                      }`}
                    >
                      <BellRing className="w-3.5 h-3.5" />
                      <span>
                        {followedProductIds.includes(activeProduct.goodsId)
                          ? 'متابَع ✓'
                          : 'متابعة'}
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={() => handleCopyProductLink(activeProduct)}
                      className="py-2 rounded-xl border border-black/10 dark:border-white/10 text-xs font-bold flex items-center justify-center gap-1 hover:border-violet-500/50"
                    >
                      <Copy className="w-3.5 h-3.5" />
                      <span>نسخ الرابط</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => handleShareWhatsApp(activeProduct, activeUnitSar)}
                      className="py-2 rounded-xl bg-emerald-600 text-white text-xs font-bold flex items-center justify-center gap-1 hover:bg-emerald-700"
                    >
                      <MessageCircle className="w-3.5 h-3.5" />
                      <span>واتساب</span>
                    </button>
                  </div>

                  {activeProduct.sourceUrl && (
                    <a
                      href={activeProduct.sourceUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="w-full py-2 rounded-xl border border-black/10 dark:border-white/10 text-xs font-semibold flex items-center justify-center gap-1.5 text-[#5F5870] dark:text-[#A9A1BA] hover:text-violet-600"
                    >
                      <ExternalLink className="w-3.5 h-3.5" />
                      <span>معاينة المصدر في SHEIN</span>
                    </a>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

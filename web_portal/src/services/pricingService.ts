import {
  AppCurrency,
  AppSettings,
  CartItem,
  CurrencyMatrix,
  Order,
} from '../types/seloo';

export function computeCurrencyMatrix(
  sarAmount: number,
  settings: AppSettings
): CurrencyMatrix {
  const sar = Math.max(0, Number.isFinite(sarAmount) ? sarAmount : 0);
  const sarPerUsd = settings.sarPerUsd > 0 ? settings.sarPerUsd : 3.75;
  const usd = sar / sarPerUsd;
  return {
    sar,
    usd,
    northFromSar: Math.round(sar * settings.rateNorth),
    southFromSar: Math.round(sar * settings.rateSouth),
    northFromUsd: Math.round(usd * settings.usdRateNorth),
    southFromUsd: Math.round(usd * settings.usdRateSouth),
  };
}

export function rateForCurrency(
  currency: AppCurrency,
  settings: AppSettings
): number {
  switch (currency) {
    case 'north':
      return settings.rateNorth;
    case 'south':
      return settings.rateSouth;
    case 'usd':
      return 1 / (settings.sarPerUsd > 0 ? settings.sarPerUsd : 3.75);
    case 'sar':
    default:
      return 1;
  }
}

export function convertSarToCurrency(
  sarAmount: number,
  currency: AppCurrency,
  settings: AppSettings
): number {
  const raw = sarAmount * rateForCurrency(currency, settings);
  if (currency === 'north' || currency === 'south') {
    return Math.round(raw);
  }
  return Math.round(raw * 100) / 100;
}

export function formatMoney(amount: number, currency: AppCurrency): string {
  const safe = Number.isFinite(amount) ? amount : 0;
  switch (currency) {
    case 'sar':
      return `${safe.toFixed(2)} ر.س`;
    case 'usd':
      return `$${safe.toFixed(2)}`;
    case 'north':
      return `${Math.round(safe).toLocaleString('en-US')} ر.ي (شمال)`;
    case 'south':
      return `${Math.round(safe).toLocaleString('en-US')} ر.ي (جنوب)`;
  }
}

export function currencyShortLabel(currency: AppCurrency): string {
  switch (currency) {
    case 'sar':
      return 'ر.س (سعودي)';
    case 'usd':
      return 'USD (دولار)';
    case 'north':
      return 'ر.ي شمال';
    case 'south':
      return 'ر.ي جنوب';
  }
}

export function computeCartTotals(
  items: CartItem[],
  settings: AppSettings,
  currency: AppCurrency,
  discountSar = 0,
  shippingMode: 'office' | 'driver' | 'pickup' = 'office'
) {
  const totalPieces = items.reduce((s, it) => s + Math.max(1, it.qty), 0);
  const subtotalSar = items.reduce(
    (s, it) => s + it.unitPriceSar * Math.max(1, it.qty),
    0
  );
  const shippingFeeSar =
    items.length === 0
      ? 0
      : subtotalSar >= settings.freeShippingThresholdSar
      ? 0
      : totalPieces * settings.shippingPerPieceSar;
  const serviceFeeSar = items.length === 0 ? 0 : settings.serviceFeeSar;
  const deliveryFeeSar =
    items.length === 0 || shippingMode === 'pickup' ? 0 : settings.deliveryFeeSar;

  const totalSar = Math.max(
    0,
    subtotalSar + shippingFeeSar + serviceFeeSar - Math.max(0, discountSar)
  );
  const totalLocal = convertSarToCurrency(totalSar, currency, settings);
  const matrix = computeCurrencyMatrix(totalSar, settings);

  const canDeferred =
    settings.deferredEnabled && totalSar >= settings.deferredThresholdSar;
  const upfrontPercent =
    settings.deferredUpfrontPercent > 0 ? settings.deferredUpfrontPercent : 50;
  const upfrontSar = canDeferred ? (totalSar * upfrontPercent) / 100 : totalSar;
  const upfrontLocal = convertSarToCurrency(upfrontSar, currency, settings);
  const remainingLocal = Math.max(0, totalLocal - upfrontLocal);

  const progressToFreeShipping =
    settings.freeShippingThresholdSar > 0
      ? Math.min(100, Math.round((subtotalSar / settings.freeShippingThresholdSar) * 100))
      : 100;

  return {
    totalPieces,
    subtotalSar,
    shippingFeeSar,
    serviceFeeSar,
    deliveryFeeSar,
    totalSar,
    totalLocal,
    matrix,
    canDeferred,
    upfrontLocal,
    remainingLocal,
    progressToFreeShipping,
    remainingForFreeShippingSar: Math.max(
      0,
      settings.freeShippingThresholdSar - subtotalSar
    ),
  };
}

/**
 * Locked rate matrix for an existing order: honors the exchange rate recorded on the day
 * the order was created (critical business rule for 50% deferred orders).
 */
export function orderLockedRemainingInfo(order: Order) {
  const paid = Math.max(0, order.paidTotalLocal || 0);
  const remaining = Math.max(0, order.totalLocal - paid);
  return {
    lockedRate: order.exchangeRate,
    remainingLocal: remaining,
    totalLocal: order.totalLocal,
    paidLocal: paid,
  };
}

const NON_REFUNDABLE_RULES: { regex: RegExp; reason: string }[] = [
  {
    regex: /(ملابس داخلية|لانجري|حمالة صدر|بوكسر|سروال داخلي|lingerie|underwear|panties|bra\b|boxer)/i,
    reason: 'ملابس داخلية',
  },
  {
    regex: /(ملابس سباحة|سباحة|مايوه|بيكيني|swimsuit|bikini|swimwear)/i,
    reason: 'ملابس سباحة',
  },
  {
    regex: /(إكسسوار|اكسسوار|مجوهرات|أقراط|حلق|سلسال|خاتم|سوار|jewelry|earring|necklace|ring|bracelet|anklet)/i,
    reason: 'إكسسوارات ومجوهرات',
  },
  {
    regex: /(عطر|عطور|مكياج|مستحضرات|تجميل|أحمر شفاه|ماسكارا|beauty|makeup|cosmetic|perfume|fragrance|skincare)/i,
    reason: 'مستحضرات تجميل وعطور',
  },
  {
    regex: /(جوارب|شرابات|socks|stockings|tights|شعر مستعار|باروكة|wig)/i,
    reason: 'جوارب أو مستلزمات شخصية',
  },
  {
    regex: /(تصفية|غير قابل للاسترداد|غير قابل للاسترجاع|final\s*sale|clearance|non[-\s]?returnable|non[-\s]?refundable)/i,
    reason: 'عرض نهائي / غير قابل للاسترداد',
  },
];

export function detectNonRefundable(
  title: string,
  category = '',
  customReason = ''
): { nonRefundable: boolean; reason: string } {
  const combined = `${title} ${category}`.trim();
  if (customReason.trim()) {
    return { nonRefundable: true, reason: customReason.trim() };
  }
  for (const rule of NON_REFUNDABLE_RULES) {
    if (rule.regex.test(combined)) {
      return { nonRefundable: true, reason: rule.reason };
    }
  }
  return { nonRefundable: false, reason: '' };
}

export interface ParsedSheinEntry {
  goodsId: string;
  url: string;
  titleHint: string;
  priceSarHint?: number;
  groupId?: string;
  isCartShare: boolean;
}

export function parseSheinShareInput(raw: string): ParsedSheinEntry[] {
  const cleaned = raw.trim();
  if (!cleaned) return [];

  // Handle sheinlink://applink/share_receiver/?data=...
  if (cleaned.toLowerCase().includes('sheinlink://')) {
    const dataMatch = cleaned.match(/data=([^&\s]+)/i);
    if (dataMatch) {
      try {
        const parsed = JSON.parse(decodeURIComponent(dataMatch[1]));
        const gid = parsed.group_id || parsed.groupId;
        const shc = parsed.shc;
        if (gid) {
          return [
            {
              goodsId: String(gid),
              groupId: String(gid),
              url: `https://m.shein.com/ar/cart/share/landing?group_id=${gid}${shc ? `&shc=${shc}` : ''}`,
              titleHint: `سلة شي إن مشتركة #${gid}`,
              isCartShare: true,
            },
          ];
        }
      } catch {
        // continue to generic URL matcher
      }
    }
  }

  // Extract all URLs from pasted block
  const urls = cleaned.match(/https?:\/\/[^\s"'<>]+/gi) || [];
  const results: ParsedSheinEntry[] = [];
  const seen = new Set<string>();

  for (const u of urls) {
    const goodsMatch =
      u.match(/-p-(\d{5,})\.html/i) ||
      u.match(/[?&]goods_id=(\d{5,})/i) ||
      u.match(/\/goods\/(\d{5,})/i);
    const groupMatch = u.match(/[?&]group_?id=(\d{4,})/i);
    const shortMatch = u.match(/onelink\.shein\.com\/[^\s]+/i);

    const key = goodsMatch?.[1] || groupMatch?.[1] || u;
    if (seen.has(key)) continue;
    seen.add(key);

    // Extract title from slug before -p-
    let titleHint = '';
    const slugMatch = u.match(/shein\.com\/(?:ar\/|en\/)?([a-zA-Z0-9-]+)-p-\d+/i);
    if (slugMatch?.[1]) {
      titleHint = decodeURIComponent(slugMatch[1]).replace(/-/g, ' ').trim();
    } else if (!titleHint) {
      // Check lines of pasted share text (SHEIN share text often puts Arabic title before the URL)
      const lines = cleaned
        .split(/\n+/)
        .map((l) => l.trim())
        .filter((l) => l && !l.startsWith('http'));
      if (lines.length === 1) {
        titleHint = lines[0].slice(0, 90);
      }
    }

    // Try extracting SAR price hint if user pasted SHEIN share snippet
    const priceMatch = cleaned.match(/(\d+(?:\.\d{1,2})?)\s*(?:SAR|SR|ر\.س)/i);

    results.push({
      goodsId:
        goodsMatch?.[1] ||
        groupMatch?.[1] ||
        (shortMatch ? `ONELINK-${Math.abs(hashCode(u)).toString().slice(0, 6)}` : `SH-${Math.abs(hashCode(u)).toString().slice(0, 6)}`),
      groupId: groupMatch?.[1],
      url: u,
      titleHint:
        titleHint ||
        (groupMatch
          ? `سلة شي إن مشتركة #${groupMatch[1]}`
          : goodsMatch
          ? `منتج SHEIN #${goodsMatch[1]}`
          : 'رابط مستورد من SHEIN'),
      priceSarHint: priceMatch ? parseFloat(priceMatch[1]) : undefined,
      isCartShare: Boolean(groupMatch || u.includes('cart/share')),
    });
  }

  // Allow plain goods ID input (e.g., 28491032)
  if (results.length === 0) {
    const idTokens = cleaned.match(/\b\d{6,12}\b/g) || [];
    for (const id of idTokens) {
      if (seen.has(id)) continue;
      seen.add(id);
      results.push({
        goodsId: id,
        url: `https://m.shein.com/ar/product-p-${id}.html`,
        titleHint: `منتج SHEIN #${id}`,
        isCartShare: false,
      });
    }
  }

  return results;
}

function hashCode(str: string): number {
  let h = 0;
  for (let i = 0; i < str.length; i++) {
    h = (Math.imul(31, h) + str.charCodeAt(i)) | 0;
  }
  return h;
}

const COLOR_HEX_MAP: Record<string, string> = {
  أسود: '#171717',
  'أسود فاحم': '#111111',
  'أسود كلاسيك': '#1F1F1F',
  black: '#171717',
  أبيض: '#F9FAFB',
  عاجي: '#FAF5E9',
  white: '#F9FAFB',
  ivory: '#FAF5E9',
  برقوقي: '#581C87',
  'برقوقي × شمبانيا': '#6B21A8',
  بنفسجي: '#7C3AED',
  purple: '#7C3AED',
  عنابي: '#7F1D1D',
  'عنابي داكن': '#6D1821',
  burgundy: '#7F1D1D',
  أحمر: '#DC2626',
  red: '#DC2626',
  وردي: '#EC4899',
  pink: '#EC4899',
  بيج: '#D6C7B2',
  رملي: '#C8B89A',
  beige: '#D6C7B2',
  بني: '#78350F',
  brown: '#78350F',
  'رمادي فحمي': '#374151',
  رمادي: '#6B7280',
  gray: '#6B7280',
  grey: '#6B7280',
  'كحلي داكن': '#1E3A8A',
  كحلي: '#1E40AF',
  navy: '#1E3A8A',
  أزرق: '#2563EB',
  blue: '#2563EB',
  سماوي: '#38BDF8',
  زيتوني: '#4D7C0F',
  أخضر: '#16A34A',
  green: '#16A34A',
  ذهبي: '#D97706',
  شمبانيا: '#E7D1A3',
  gold: '#D97706',
  فضي: '#9CA3AF',
  silver: '#9CA3AF',
};

export function colorToHex(colorName: string): string {
  const clean = colorName.trim().toLowerCase();
  for (const [key, hex] of Object.entries(COLOR_HEX_MAP)) {
    if (clean === key.toLowerCase() || clean.includes(key.toLowerCase())) {
      return hex;
    }
  }
  return '#8B5CF6';
}

export function classifyBrandAndCategory(
  title: string,
  sourceUrl = '',
  explicitCategory = ''
): { brand: 'SHEIN' | 'يمن سيلو الخاص'; category: string } {
  const combined = `${title} ${sourceUrl}`.toLowerCase();
  const brand: 'SHEIN' | 'يمن سيلو الخاص' =
    combined.includes('shein') || combined.includes('onelink') || /^\d{6,}$/.test(sourceUrl)
      ? 'SHEIN'
      : 'يمن سيلو الخاص';

  if (explicitCategory && explicitCategory !== 'الكل') {
    return { brand, category: explicitCategory };
  }
  if (/(حقيبة|شنطة|bag|handbag|إكسسوار|سلسال|خاتم|سوار|نظارة|jewelry)/i.test(combined)) {
    return { brand, category: 'حقائب وإكسسوارات' };
  }
  if (/(حذاء|شوز|صندل|كعب|بوت|sneaker|shoe|heel|boot)/i.test(combined)) {
    return { brand, category: 'أحذية' };
  }
  if (/(رجالي|تيشيرت رجال|بنطلون رجال|جاكيت|hoodie|men|streetwear)/i.test(combined)) {
    return { brand, category: 'أزياء رجالية' };
  }
  if (/(طفل|أطفال|بناتي|ولادي|kids|baby|toddler)/i.test(combined)) {
    return { brand, category: 'أطفال' };
  }
  if (/(منزل|مطبخ|تجميل|مكياج|عطر|home|decor|beauty|makeup)/i.test(combined)) {
    return { brand, category: 'منزل وتجميل' };
  }
  return { brand, category: 'أزياء نسائية' };
}

export function sanitizeImageUrl(url: string | undefined, fallback: string): string {
  const trimmed = (url || '').trim();
  if (!trimmed) return fallback;
  if (trimmed.startsWith('data:image/')) return trimmed;
  if (trimmed.startsWith('/') || trimmed.startsWith('assets/')) return trimmed;
  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol === 'https:') {
      return parsed.toString();
    }
    if (parsed.protocol === 'http:') {
      parsed.protocol = 'https:';
      return parsed.toString();
    }
  } catch {
    return fallback;
  }
  return fallback;
}


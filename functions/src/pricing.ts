import { DocumentSnapshot } from "firebase-admin/firestore";
import {
  DEFAULT_PRICING,
  FALLBACK_RATES,
  FxRates,
  PricingConfig,
} from "./schema";

// يُعاد تصدير هذين النوعين ليستوردهما index.ts من هنا مباشرة.
export type { FxRates, PricingConfig } from "./schema";

/**
 * التقييم والتسعير — دوال نقية قابلة للاختبار بلا Firebase.
 */

/// مُدخل السطر: يُغذّى من Firestore. حقل الإجمالي يُحسب هنا لا يُستقبل.
export type PricedLine = {
  lineId: string;
  quantity: number;
  unitPriceLocal: number;
  lineTotalLocal?: number;
};

export type QuoteResult = {
  itemsSubtotalLocal: number;
  serviceFeeLocal: number;
  shippingLocal: number;
  discountLocal: number;
  grandTotalLocal: number;
  currency: string;
  unitsCount: number;
  linesCount: number;
};

export function roundTo(value: number, step: number): number {
  if (step <= 0) return Math.round(value * 100) / 100;
  return Math.round(value / step) * step;
}

export function pickRate(rates: FxRates, currency: string): number {
  const rate = rates[currency];
  if (typeof rate === "number" && Number.isFinite(rate) && rate > 0) return rate;
  const fallback = FALLBACK_RATES[currency];
  return typeof fallback === "number" && fallback > 0 ? fallback : 1;
}

export function parsePricing(snapshot: DocumentSnapshot | null): PricingConfig {
  const data = snapshot?.exists ? snapshot.data() : null;
  if (!data) return DEFAULT_PRICING;
  return {
    serviceFeePercent: asNumber(
      data.serviceFeePercent,
      DEFAULT_PRICING.serviceFeePercent,
    ),
    serviceFeeMinLocal: asNumber(
      data.serviceFeeMinLocal,
      DEFAULT_PRICING.serviceFeeMinLocal,
    ),
    shippingBaseLocal: asNumber(
      data.shippingBaseLocal,
      DEFAULT_PRICING.shippingBaseLocal,
    ),
    shippingPerItemLocal: asNumber(
      data.shippingPerItemLocal,
      DEFAULT_PRICING.shippingPerItemLocal,
    ),
    freeShippingThresholdLocal: asNumber(
      data.freeShippingThresholdLocal,
      DEFAULT_PRICING.freeShippingThresholdLocal,
    ),
    maxOrderTotalLocal: asNumber(
      data.maxOrderTotalLocal,
      DEFAULT_PRICING.maxOrderTotalLocal,
    ),
    roundingStep: asNumber(data.roundingStep, DEFAULT_PRICING.roundingStep),
  };
}

export function parseRates(snapshot: DocumentSnapshot | null): FxRates {
  const data = snapshot?.exists ? snapshot.data() : null;
  if (!data) return { ...FALLBACK_RATES };
  const out: FxRates = { ...FALLBACK_RATES };
  for (const [key, value] of Object.entries(data)) {
    if (typeof value === "number" && Number.isFinite(value) && value > 0) {
      out[key.toUpperCase()] = value;
    }
  }
  return out;
}

/** يحسب الإجمالي: مجموع السطور + رسوم خدمة + شحن − خصم. */
export function quoteCart(
  lines: PricedLine[],
  pricing: PricingConfig,
  discountLocal = 0,
): QuoteResult {
  const priced: Required<PricedLine>[] = lines.map((line) => ({
    lineId: line.lineId,
    quantity: line.quantity,
    unitPriceLocal: line.unitPriceLocal,
    lineTotalLocal: roundTo(
      line.unitPriceLocal * line.quantity,
      pricing.roundingStep,
    ),
  }));

  const itemsSubtotalLocal = roundTo(
    priced.reduce((sum, line) => sum + line.lineTotalLocal, 0),
    pricing.roundingStep,
  );

  const unitsCount = priced.reduce((sum, line) => sum + line.quantity, 0);
  const linesCount = priced.length;

  const rawServiceFee = itemsSubtotalLocal * pricing.serviceFeePercent;
  const serviceFeeLocal = roundTo(
    Math.max(rawServiceFee, pricing.serviceFeeMinLocal),
    pricing.roundingStep,
  );

  const extraUnits = Math.max(0, unitsCount - 1);
  const shippingCandidate =
    pricing.shippingBaseLocal + pricing.shippingPerItemLocal * extraUnits;
  const shippingLocal =
    itemsSubtotalLocal >= pricing.freeShippingThresholdLocal
      ? 0
      : roundTo(shippingCandidate, pricing.roundingStep);

  const safeDiscount = Math.min(Math.max(0, discountLocal), itemsSubtotalLocal);

  const grandTotalLocal = roundTo(
    itemsSubtotalLocal + serviceFeeLocal + shippingLocal - safeDiscount,
    pricing.roundingStep,
  );

  return {
    itemsSubtotalLocal,
    serviceFeeLocal,
    shippingLocal,
    discountLocal: roundTo(safeDiscount, pricing.roundingStep),
    grandTotalLocal,
    currency: "YER",
    unitsCount,
    linesCount,
  };
}

function asNumber(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
  }

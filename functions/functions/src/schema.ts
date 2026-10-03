import { z } from "zod";

/**
 * مخططات التحقق — كل ما يدخل من العميل يمرّ من هنا.
 * التحقق على الخادم إلزامي: لا يُصدَّق أي شيء وصل من WebView.
 */

export const MAX_QTY_PER_LINE = 50;
export const MAX_LINES_PER_CART = 40;
export const MAX_TITLE_LENGTH = 300;
export const MIN_GOODS_ID_LENGTH = 5;

export const ALLOWED_CURRENCIES = [
  "SAR",
  "AED",
  "USD",
  "YER",
  "KWD",
  "QAR",
  "OMR",
  "BHD",
] as const;

export const ALLOWED_SOURCES = ["jsonld", "globals", "meta", "dom", "merged"] as const;

const digitsOnly = /^\d+$/;
const httpsOrHttp = /^https?:\/\//i;

export const sheinDraftSchema = z.object({
  goodsId: z
    .string()
    .trim()
    .min(MIN_GOODS_ID_LENGTH, "معرّف المنتج قصير جدًا")
    .max(32, "معرّف المنتج أطول من الحد")
    .regex(digitsOnly, "معرّف المنتج يجب أن يكون رقميًا"),
  productUrl: z
    .string()
    .trim()
    .max(2048)
    .refine((v) => httpsOrHttp.test(v), "رابط المنتج غير صالح"),
  title: z.string().trim().min(1, "اسم المنتج مطلوب").max(MAX_TITLE_LENGTH),
  imageUrl: z.string().trim().max(2048).optional().default(""),
  price: z
    .number()
    .positive("السعر يجب أن يكون أكبر من صفر")
    .max(1_000_000, "السعر غير منطقي"),
  currency: z.enum(ALLOWED_CURRENCIES).default("SAR"),
  quantity: z.number().int().min(1).max(MAX_QTY_PER_LINE),
  color: z.string().trim().max(120).optional().default(""),
  size: z.string().trim().max(64).optional().default(""),
  sku: z.string().trim().max(120).optional().default(""),
  variantId: z.string().trim().max(120).optional().default(""),
  extractSource: z.enum(ALLOWED_SOURCES).optional().default("merged"),
  clientTs: z.number().int().nonnegative().optional(),
});

export type SheinDraftInput = z.infer<typeof sheinDraftSchema>;

export const quantitySchema = z.object({
  lineId: z.string().trim().min(1).max(160),
  quantity: z.number().int().min(1).max(MAX_QTY_PER_LINE),
});

export const lineIdSchema = z.object({
  lineId: z.string().trim().min(1).max(160),
});

export const submitOrderSchema = z.object({
  contactPhone: z
    .string()
    .trim()
    .regex(/^\+?[0-9]{7,15}$/, "رقم هاتف غير صالح"),
  addressLine: z.string().trim().min(5).max(400),
  city: z.string().trim().min(2).max(120),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

export type SubmitOrderInput = z.infer<typeof submitOrderSchema>;

/** وثيقة التسعير العامة (meta/pricing). */
export type PricingConfig = {
  serviceFeePercent: number;
  serviceFeeMinLocal: number;
  shippingBaseLocal: number;
  shippingPerItemLocal: number;
  freeShippingThresholdLocal: number;
  maxOrderTotalLocal: number;
  roundingStep: number;
};

export const DEFAULT_PRICING: PricingConfig = {
  serviceFeePercent: 0.07,
  serviceFeeMinLocal: 500,
  shippingBaseLocal: 2500,
  shippingPerItemLocal: 600,
  freeShippingThresholdLocal: 120000,
  maxOrderTotalLocal: 5_000_000,
  roundingStep: 1,
};

/** أسعار الصرف: كل عملة مقابلة للريال اليمني (YER). */
export type FxRates = Record<string, number>;

export const FALLBACK_RATES: FxRates = {
  YER: 1,
  SAR: 72,
  AED: 74,
  USD: 270,
  KWD: 880,
  QAR: 74,
  OMR: 700,
  BHD: 715,
};

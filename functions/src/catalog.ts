import * as admin from "firebase-admin";
import { Firestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

/**
 * التسعير والكتالوج والمحافظ — مصدر الحقيقة الوحيد للسعر.
 *
 * قاعدة صارمة: لا يُقبل أي سعر من العميل. كل سعر سطر يُقرأ من
 * products/{goodsId}، وإن غاب المنتج، أو كان موقوفاً، يُرفض الطلب.
 */

export const PRODUCTS = "products";
export const SETTINGS_APP = "settings/app";
export const COUPONS = "coupons";
export const COUNTERS = "counters";

export const DEFAULT_MAX_MANUAL_PRICE_SAR = 100_000;

export type Settings = {
  rateNorth: number;
  rateSouth: number;
  shippingFeeSar: number;
  deliveryFeeSar: number;
  /** رسوم التوصيل بالعملة المحلية — تُعدَّل من اللوحة حسب الاتفاق. */
  deliveryFeeNorthLocal: number;
  deliveryFeeSouthLocal: number;
  deliveryFeeSarLocal: number;
  freeShippingThresholdSar: number;
  maxManualPriceSar: number;
  /** رسوم خدمة يمن سيلو الثابتة على كل طلب (بالريال السعودي). */
  serviceFeeSar: number;
  /** شحن لكل قطعة عند بقاء الطلب تحت حد الشحن المجاني. */
  shippingPerPieceSar: number;
  /** مدة التوصيل المتوقعة بالأيام — تُعدَّل من لوحة الإدارة. */
  deliveryMinDays: number;
  deliveryMaxDays: number;
};

export const DEFAULT_SETTINGS: Settings = {
  rateNorth: 140,
  rateSouth: 413,
  shippingFeeSar: 0,
  deliveryFeeSar: 0,
  deliveryFeeNorthLocal: 1500,
  deliveryFeeSouthLocal: 1000,
  deliveryFeeSarLocal: 0,
  freeShippingThresholdSar: 75,
  maxManualPriceSar: DEFAULT_MAX_MANUAL_PRICE_SAR,
  serviceFeeSar: 1.22,
  shippingPerPieceSar: 1,
  deliveryMinDays: 15,
  deliveryMaxDays: 20,
};

export type Product = {
  goodsId: string;
  titleAr: string;
  priceSar: number;
  imageUrl: string;
  isManual: boolean;
  active: boolean;
};

/** عملات التطبيق الثلاث — كما في AppCurrency على العميل. */
export const CURRENCIES = ["sar", "north", "south"] as const;
export type Currency = (typeof CURRENCIES)[number];

export type Account = {
  id: string;
  bankAr: string;
  titleAr: string;
  numbers: string[];
};

/**
 * المحافظ — الهوية بالمعرّف لا بالرقم.
 * «شلن» و«جيب» محفظتان مختلفتان بنفس الرقم 775801198 وهذا مقصود.
 */
export const ACCOUNTS: Record<string, Account> = {
  kuraimi_yemeni: {
    id: "kuraimi_yemeni",
    bankAr: "بنك الكريمي",
    titleAr: "الكريمي — حساب يمني",
    numbers: ["3141952047", "3055509637"],
  },
  kuraimi_saudi: {
    id: "kuraimi_saudi",
    bankAr: "بنك الكريمي",
    titleAr: "الكريمي — حساب سعودي",
    numbers: ["3168803857", "3116991917"],
  },
  qatibi: {
    id: "qatibi",
    bankAr: "القطيبي",
    titleAr: "القطيبي",
    numbers: ["480642452"],
  },
  shilling: {
    id: "shilling",
    bankAr: "شلن",
    titleAr: "شلن",
    numbers: ["600589797", "775801198"],
  },
  jaib: {
    id: "jaib",
    bankAr: "جيب",
    titleAr: "جيب",
    numbers: ["2291789", "775801198"],
  },
};

export const ALLOWED_ACCOUNTS_BY_CURRENCY: Record<Currency, string[]> = {
  sar: ["kuraimi_saudi", "qatibi"],
  north: ["kuraimi_yemeni", "qatibi", "shilling", "jaib"],
  south: ["kuraimi_yemeni", "qatibi", "shilling", "jaib"],
};

export function isCurrency(value: unknown): value is Currency {
  return typeof value === "string" && (CURRENCIES as readonly string[]).includes(value);
}

export function rateFor(currency: Currency, s: Settings): number {
  switch (currency) {
    case "north":
      return s.rateNorth;
    case "south":
      return s.rateSouth;
    case "sar":
    default:
      return 1;
  }
}

export function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** الريال السعودي بمنزلتين، اليمنيان بلا كسور — مطابق لـ roundMoney في العميل. */
export function roundMoney(value: number, currency: Currency): number {
  return currency === "sar" ? round2(value) : Math.round(value);
}

function num(value: unknown, fallback: number): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) && n >= 0 ? n : fallback;
}

export async function loadSettings(db: Firestore): Promise<Settings> {
  const snap = await db.doc(SETTINGS_APP).get();
  const data = snap.exists ? (snap.data() as Record<string, unknown>) : null;
  if (!data) return { ...DEFAULT_SETTINGS };
  return {
    rateNorth: num(data.rateNorth, DEFAULT_SETTINGS.rateNorth),
    rateSouth: num(data.rateSouth, DEFAULT_SETTINGS.rateSouth),
    shippingFeeSar: num(data.shippingFeeSar, DEFAULT_SETTINGS.shippingFeeSar),
    deliveryFeeSar: 0,
    deliveryFeeNorthLocal: num(
      data.deliveryFeeNorthLocal,
      DEFAULT_SETTINGS.deliveryFeeNorthLocal,
    ),
    deliveryFeeSouthLocal: num(
      data.deliveryFeeSouthLocal,
      DEFAULT_SETTINGS.deliveryFeeSouthLocal,
    ),
    deliveryFeeSarLocal: num(
      data.deliveryFeeSarLocal,
      DEFAULT_SETTINGS.deliveryFeeSarLocal,
    ),
    freeShippingThresholdSar: num(
      data.freeShippingThresholdSar,
      DEFAULT_SETTINGS.freeShippingThresholdSar,
    ),
    maxManualPriceSar: num(
      data.maxManualPriceSar,
      DEFAULT_SETTINGS.maxManualPriceSar,
    ),
    serviceFeeSar: num(data.serviceFeeSar, DEFAULT_SETTINGS.serviceFeeSar),
    shippingPerPieceSar: num(
      data.shippingPerPieceSar,
      DEFAULT_SETTINGS.shippingPerPieceSar,
    ),
    deliveryMinDays: num(data.deliveryMinDays, DEFAULT_SETTINGS.deliveryMinDays),
    deliveryMaxDays: num(data.deliveryMaxDays, DEFAULT_SETTINGS.deliveryMaxDays),
  };
}

/** يقرأ منتجات كل السلة دفعة واحدة (getAll) أو null لمن لا وثيقة له. */
export async function loadProducts(
  db: Firestore,
  goodsIds: string[],
): Promise<Map<string, Product | null>> {
  const out = new Map<string, Product | null>();
  const ids = Array.from(new Set(goodsIds.filter((id) => id.length > 0)));
  if (!ids.length) return out;

  const chunks: string[][] = [];
  for (let i = 0; i < ids.length; i += 300) chunks.push(ids.slice(i, i + 300));

  for (const chunk of chunks) {
    const snaps = await db.getAll(
      ...chunk.map((id) => db.collection(PRODUCTS).doc(id)),
    );
    for (const snap of snaps) {
      if (!snap.exists) {
        out.set(snap.id, null);
        continue;
      }
      const data = snap.data() as Record<string, unknown>;
      const priceSar = Number(data.priceSar);
      if (!Number.isFinite(priceSar) || priceSar <= 0) {
        out.set(snap.id, null);
        continue;
      }
      out.set(snap.id, {
        goodsId: snap.id,
        titleAr: typeof data.titleAr === "string" ? data.titleAr : "",
        priceSar,
        imageUrl: typeof data.imageUrl === "string" ? data.imageUrl : "",
        isManual: data.isManual === true,
        active: data.active !== false,
      });
    }
  }
  return out;
}

/* ============================ الأسطر والتسعير ============================ */

export type ItemInput = {
  goodsId: string;
  qty: number;
  color: string;
  size: string;
  sku: string;
  productUrl: string;
};

export type PricedLine = {
  goodsId: string;
  sku: string;
  title: string;
  imageUrl: string;
  color: string;
  size: string;
  qty: number;
  unitPriceSar: number;
  lineTotalSar: number;
  productUrl: string;
};

export type Totals = {
  lines: PricedLine[];
  subtotalSar: number;
  shippingFeeSar: number;
  deliveryFeeSar: number;
  serviceFeeSar: number;
  discountSar: number;
  totalSar: number;
  totalLocal: number;
  rate: number;
  couponCode: string;
};

export type Coupon = {
  code: string;
  active: boolean;
  isPercent: boolean;
  value: number;
  minOrderSar: number;
  expiresAt: Date | null;
};

export async function loadCoupon(
  db: Firestore,
  rawCode: string,
): Promise<Coupon | null> {
  const code = String(rawCode || "").trim().toUpperCase();
  if (!code) return null;
  const snap = await db.collection(COUPONS).doc(code).get();
  if (!snap.exists) return null;
  const d = snap.data() as Record<string, unknown>;
  const expiresRaw = d.expiresAt as { toDate?: () => Date } | undefined;
  return {
    code,
    active: d.active === true,
    isPercent: d.isPercent === true,
    value: num(d.value, 0),
    minOrderSar: num(d.minOrderSar, 0),
    expiresAt:
      expiresRaw && typeof expiresRaw.toDate === "function"
        ? expiresRaw.toDate()
        : null,
  };
}

/**
 * يبني الأسطر المسعّرة من الكتالوج — لا سعر من العميل إطلاقاً.
 * strict = true (submitOrder): منتج مفقود أو موقوف ← رفض.
 * strict = false (quoteCart): تُستبعد الأسطر غير المسعّرة وتُعلن.
 */
export async function priceItems(
  db: Firestore,
  items: ItemInput[],
  strict: boolean,
): Promise<{ lines: PricedLine[]; unpricedGoodsIds: string[] }> {
  const products = await loadProducts(
    db,
    items.map((i) => i.goodsId),
  );
  const lines: PricedLine[] = [];
  const unpricedGoodsIds: string[] = [];

  for (const item of items) {
    const product = products.get(item.goodsId) ?? null;

    if (!product || product.active === false) {
      if (strict) {
        throw new HttpsError(
          "failed-precondition",
          product
            ? "المنتج غير متاح للبيع حالياً"
            : "المنتج غير مسعّر على السيرفر",
          { goodsId: item.goodsId },
        );
      }
      unpricedGoodsIds.push(item.goodsId);
      continue;
    }

    const unitPriceSar = round2(product.priceSar);
    lines.push({
      goodsId: item.goodsId,
      sku: item.sku,
      title: product.titleAr || item.sku,
      imageUrl: product.imageUrl,
      color: item.color,
      size: item.size,
      qty: item.qty,
      unitPriceSar,
      lineTotalSar: round2(unitPriceSar * item.qty),
      productUrl: item.productUrl,
    });
  }

  return { lines, unpricedGoodsIds };
}

export function computeTotals(
  lines: PricedLine[],
  settings: Settings,
  currency: Currency,
  coupon: Coupon | null,
): Totals {
  const subtotalSar = round2(
    lines.reduce((sum, l) => sum + l.lineTotalSar, 0),
  );

  const units = lines.reduce((sum, l) => sum + l.qty, 0);
  // نفس معادلة السلة: شحن لكل قطعة حتى بلوغ حد الشحن المجاني.
  const shippingFeeSar =
    subtotalSar >= settings.freeShippingThresholdSar
      ? 0
      : round2(units * settings.shippingPerPieceSar);
  const serviceFeeSar = round2(settings.serviceFeeSar);
  const rate = rateFor(currency, settings);
  // رسوم التوصيل اتفاقية بالعملة المحلية: 1500 شمال · 1000 جنوب · 0 سعودي.
  const deliveryLocal =
    currency === "north"
      ? settings.deliveryFeeNorthLocal
      : currency === "south"
        ? settings.deliveryFeeSouthLocal
        : settings.deliveryFeeSarLocal;
  const deliveryFeeSar = round2(deliveryLocal / rate);

  let discountSar = 0;
  let couponCode = "";
  if (coupon) {
    const expired =
      coupon.expiresAt !== null && coupon.expiresAt.getTime() < Date.now();
    const eligible =
      coupon.active &&
      !expired &&
      subtotalSar >= coupon.minOrderSar &&
      coupon.value > 0;
    if (eligible) {
      discountSar = coupon.isPercent
        ? round2(subtotalSar * (coupon.value / 100))
        : round2(coupon.value);
      if (discountSar > subtotalSar) discountSar = subtotalSar;
      couponCode = coupon.code;
    }
  }

  const totalSar = round2(
    Math.max(
      0,
      subtotalSar + shippingFeeSar + serviceFeeSar + deliveryFeeSar - discountSar,
    ),
  );
  const totalLocal = Math.max(
    0,
    roundMoney(
      (subtotalSar + shippingFeeSar + serviceFeeSar - discountSar) * rate +
        deliveryLocal,
      currency,
    ),
  );

  return {
    lines,
    subtotalSar,
    shippingFeeSar,
    deliveryFeeSar,
    serviceFeeSar,
    discountSar,
    totalSar,
    totalLocal,
    rate,
    couponCode,
  };
}

/* ============================ الدفع ============================ */

export type PaymentInput = {
  accountId: string;
  accountNumber: string;
  senderName: string;
  refNo: string;
  note: string;
  proofUrl: string;
  amount: number;
};

const digits = /^\d{6,20}$/;

/**
 * التحقق من الحوالة: الهوية بالمعرّف، والرقم يُفحص شكلاً فقط.
 * لا مطابقة «هل الرقم ينتمي للمحفظة» لأن شلن وجيب يتشاركان رقماً واحداً.
 */
export function validatePayment(
  raw: unknown,
  currency: Currency,
): PaymentInput {
  const p = (raw ?? {}) as Record<string, unknown>;
  const accountId = String(p.accountId ?? "").trim();
  const account = ACCOUNTS[accountId];

  if (!account) {
    throw new HttpsError("invalid-argument", "محفظة غير معروفة", {
      accountId,
    });
  }
  if (!ALLOWED_ACCOUNTS_BY_CURRENCY[currency].includes(accountId)) {
    throw new HttpsError(
      "invalid-argument",
      "هذه المحفظة لا تستقبل عملة الطلب",
      { accountId, currency },
    );
  }

  const accountNumber = String(p.accountNumber ?? "").replace(/\s+/g, "");
  if (!digits.test(accountNumber)) {
    throw new HttpsError(
      "invalid-argument",
      "رقم المحفظة يجب أن يكون من 6 إلى 20 رقماً",
      { accountNumber },
    );
  }

  const senderName = String(p.senderName ?? "").trim();
  if (senderName.length < 3 || senderName.length > 120) {
    throw new HttpsError("invalid-argument", "اسم المرسل غير صالح");
  }

  const refNo = String(p.refNo ?? "").trim();
  if (refNo.length < 3 || refNo.length > 80) {
    throw new HttpsError("invalid-argument", "رقم العملية غير صالح");
  }

  return {
    accountId,
    accountNumber,
    senderName,
    refNo,
    note: String(p.note ?? "").trim().slice(0, 300),
    proofUrl: String(p.proofUrl ?? "").trim().slice(0, 2048),
    amount: num(p.amount, 0),
  };
}

/** رقم الطلب: YS-2026-000123 — تسلسل ذرّي داخل معاملة. */
export async function nextOrderNo(
  db: Firestore,
  tx: admin.firestore.Transaction,
): Promise<string> {
  const ref = db.collection(COUNTERS).doc("orders");
  const snap = await tx.get(ref);
  const last = snap.exists ? num((snap.data() as Record<string, unknown>).value, 0) : 0;
  const next = last + 1;
  tx.set(ref, { value: next, updatedAt: FieldValue.serverTimestamp() });
  return `YS-${new Date().getFullYear()}-${String(next).padStart(6, "0")}`;
}

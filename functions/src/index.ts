import * as admin from "firebase-admin";
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import {
  FieldValue,
  Firestore,
  QueryDocumentSnapshot,
  Timestamp,
} from "firebase-admin/firestore";
import { z } from "zod";

import {
  ALLOWED_CURRENCIES,
  MAX_LINES_PER_CART,
  MAX_QTY_PER_LINE,
  PRODUCTS_COLLECTION,
  PricingConfig,
  SETTINGS_APP_DOC,
  sheinDraftSchema,
  quantitySchema,
  lineIdSchema,
  parseProduct,
  parseMaxManualPriceSar,
} from "./schema";
import {
  FxRates,
  parsePricing,
  parseRates,
  pickRate,
  quoteCart as buildQuote,
  roundTo,
} from "./pricing";

admin.initializeApp();
const db: Firestore = admin.firestore();

const REGION = "europe-west1";
const USERS = "users";
const CART = "cart";
const META = "meta";
const PRODUCTS = PRODUCTS_COLLECTION;

/** إعدادات مشتركة: منطقة واحدة + App Check إلزامي. */
const baseOpts = {
  region: REGION,
  enforceAppCheck: true,
  cors: true,
} as const;

type CartLineDoc = {
  lineId: string;
  goodsId: string;
  productUrl: string;
  title: string;
  imageUrl: string;
  color: string;
  size: string;
  quantity: number;
  priceOriginal: number;
  currency: string;
  exchangeRate: number;
  unitPriceLocal: number;
  source: string;
  sku?: string;
  variantId?: string;
  status: "draft" | "reserved";
  addedAt: Timestamp | FieldValue;
  /** ⭐ يُكتب من addManualLine فقط — لا يُقبل من الجسر أبداً. */
  isManual?: boolean;
  /** ⭐ سعر السطر اليدوي بالريال، يُكتب من السيرفر فقط. */
  manualPriceSar?: number;
};

/**
 * سطر مسعّر من السيرفر.
 * unitPriceSar يأتي من products/{goodsId} (أو من الإضافة اليدوية المسقوفة)،
 * وunitPriceLocal هو ناتج التحويل بسعر الصرف المحفوظ.
 */
type ServerPricedLine = {
  lineId: string;
  goodsId: string;
  titleAr: string;
  imageUrl: string;
  color: string;
  size: string;
  quantity: number;
  unitPriceSar: number;
  unitPriceLocal: number;
  lineTotalLocal: number;
  priceSource: "product" | "manual";
  isManual: boolean;
};

function requireUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "يجب تسجيل الدخول لإتمام هذه العملية",
    );
  }
  return uid;
}

function cartRef(uid: string) {
  return db.collection(USERS).doc(uid).collection(CART);
}

function lineIdFor(goodsId: string, color: string, size: string): string {
  const raw = `${goodsId}_${color}_${size}`.toLowerCase();
  return raw.replace(/[^a-z0-9_\u0600-\u06FF]+/g, "-").slice(0, 150);
}

function parseOrThrow<S extends z.ZodTypeAny>(
  schema: S,
  data: unknown,
  message: string,
): z.output<S> {
  const parsed = schema.safeParse(data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", message, {
      issues: parsed.error.issues.map((i) => ({
        path: i.path.join("."),
        message: i.message,
      })),
    });
  }
  return parsed.data;
}

async function loadPricingAndRates(): Promise<{
  pricing: PricingConfig;
  rates: FxRates;
}> {
  const [pricingSnap, ratesSnap] = await Promise.all([
    db.doc(`${META}/pricing`).get(),
    db.doc(`${META}/fxRates`).get(),
  ]);
  return {
    pricing: parsePricing(pricingSnap),
    rates: parseRates(ratesSnap),
  };
}

/** سقف سعر السطر اليدوي — من settings/app، والافتراضي 100000.
 *  ملاحظة: إن كانت وثيقة settings/app غير موجودة (أو الحقل غير رقمي)
 *  نرجع إلى 100000 بدل تعطيل كل الطلبات. */
async function loadMaxManualPriceSar(): Promise<number> {
  const snap = await db.doc(SETTINGS_APP_DOC).get();
  return parseMaxManualPriceSar(snap.exists ? snap.data() : null);
}

/**
 * ⭐ مصدر السعر الوحيد: السيرفر.
 *
 * تُقرأ كل منتجات السلة دفعة واحدة من products/{goodsId}، ويُتجاهل تماماً
 * أي سعر وصل من العميل أو حُفظ في وثيقة السلة. الاستثناء الوحيد هو سطر
 * يدوي كتبه addManualLine على السيرفر، بشرط سعر موجب لا يتجاوز السقف.
 */
async function priceCartLinesFromServer(
  cartDocs: QueryDocumentSnapshot[],
  strict = true,
): Promise<{
  lines: ServerPricedLine[];
  pricing: PricingConfig;
  /** سعر صرف SAR→YER المستخدم في التحويل، يُحفظ على الطلب. */
  fxRateSar: number;
  /**
   * معرّفات الأسطر التي تعذّر تسعيرها (منتج غير مسجّل في products).
   * تُملأ فقط في الوضع غير الصارم (quoteCart): العرض لا ينهار،
   * لكن canCheckout تصبح false حتى يُسعَّر المنتج.
   */
  unpricedGoodsIds: string[];
}> {
  const { pricing, rates } = await loadPricingAndRates();
  const maxManualPriceSar = await loadMaxManualPriceSar();
  const sarRate = pickRate(rates, "SAR");

  const goodsIds = Array.from(
    new Set(
      cartDocs
        .map((doc) => String(doc.data().goodsId ?? "").trim())
        .filter((id) => id.length > 0),
    ),
  );

  const productSnaps = goodsIds.length
    ? await db.getAll(
        ...goodsIds.map((id) => db.collection(PRODUCTS).doc(id)),
      )
    : [];
  const productById = new Map<string, ReturnType<typeof parseProduct>>();
  productSnaps.forEach((snap) => {
    productById.set(snap.id, parseProduct(snap.exists ? snap.data() : null));
  });

  const lines: ServerPricedLine[] = [];
  const unpricedGoodsIds: string[] = [];

  for (const doc of cartDocs) {
    const data = doc.data();
    const goodsId = String(data.goodsId ?? "").trim();
    if (!goodsId) {
      throw new HttpsError("failed-precondition", "سطر بلا معرّف منتج", {
        details: { goodsId: "" },
      });
    }

    const rawQty = Number(data.quantity ?? 1);
    const quantity =
      Number.isFinite(rawQty) && rawQty >= 1 && rawQty <= MAX_QTY_PER_LINE
        ? Math.floor(rawQty)
        : 1;

    const isManual = data.isManual === true;
    const product = productById.get(goodsId) ?? null;

    let unitPriceSar = 0;
    let priceSource: "product" | "manual" = "product";

    if (product && product.active) {
      // 1) منتج معروف ومُسعّر على السيرفر: سعره هو الحاكم.
      unitPriceSar = product.priceSar;
      priceSource = "product";
    } else if (isManual) {
      // 2) سطر يدوي (كتبه السيرفر): سعره مقبول لكن مسقوف.
      const manualPrice = Number(data.manualPriceSar);
      if (!Number.isFinite(manualPrice) || manualPrice <= 0) {
        throw new HttpsError(
          "failed-precondition",
          "سعر السطر اليدوي غير صالح",
          { details: { goodsId } },
        );
      }
      if (manualPrice > maxManualPriceSar) {
        throw new HttpsError(
          "failed-precondition",
          "سعر السطر اليدوي يتجاوز الحد الأقصى",
          { details: { goodsId } },
        );
      }
      unitPriceSar = manualPrice;
      priceSource = "manual";
    } else if (product && !product.active) {
      // 3) المنتج موجود لكنه موقوف.
      if (!strict) {
        unpricedGoodsIds.push(goodsId);
        continue;
      }
      throw new HttpsError(
        "failed-precondition",
        "المنتج غير متاح للبيع حالياً",
        { details: { goodsId } },
      );
    } else {
      // 4) لا وثيقة منتج ولا سطر يدوي → لا يمكن تسعيره.
      if (!strict) {
        unpricedGoodsIds.push(goodsId);
        continue;
      }
      throw new HttpsError(
        "failed-precondition",
        "المنتج غير مسعّر على السيرفر",
        { details: { goodsId } },
      );
    }

    const unitPriceLocal = roundTo(unitPriceSar * sarRate, pricing.roundingStep);
    const lineTotalLocal = roundTo(
      unitPriceLocal * quantity,
      pricing.roundingStep,
    );

    lines.push({
      lineId: doc.id,
      goodsId,
      titleAr: product?.titleAr || String(data.title ?? ""),
      imageUrl: product?.imageUrl || String(data.imageUrl ?? ""),
      color: String(data.color ?? ""),
      size: String(data.size ?? ""),
      quantity,
      unitPriceSar,
      unitPriceLocal,
      lineTotalLocal,
      priceSource,
      isManual,
    });
  }

  return { lines, pricing, fxRateSar: sarRate, unpricedGoodsIds };
}

/** تحويل أسطر السيرفر إلى صيغة pricing.quoteCart بلا أي تغيير في المعادلة. */
function toQuoteInput(lines: ServerPricedLine[]) {
  return lines.map((line) => ({
    lineId: line.lineId,
    quantity: line.quantity,
    unitPriceLocal: line.unitPriceLocal,
  }));
}

/* ============================ addToCart ============================ */

export const addToCart = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const draft = parseOrThrow(
    sheinDraftSchema,
    request.data,
    "بيانات المنتج غير مكتملة",
  );

  const ref = cartRef(uid);
  const existing = await ref.limit(MAX_LINES_PER_CART + 1).get();
  const lineId = lineIdFor(draft.goodsId, draft.color, draft.size);
  const alreadyThere = existing.docs.some((doc) => doc.id === lineId);

  if (!alreadyThere && existing.size >= MAX_LINES_PER_CART) {
    throw new HttpsError(
      "resource-exhausted",
      `تجاوزت الحد الأقصى (${MAX_LINES_PER_CART} منتجًا)`,
    );
  }

  // ⚠️ draft.price سعر شي إن وقت الإضافة: يُحفظ للعرض والمقارنة فقط.
  // التسعير النهائي لا يأتي من العميل: submitOrder/quoteCart يقرآن
  // products/{goodsId} ويتجاهلان هذه القيمة تماماً.
  const { rates } = await loadPricingAndRates();
  const currency = draft.currency.toUpperCase();
  if (!(ALLOWED_CURRENCIES as readonly string[]).includes(currency)) {
    throw new HttpsError("invalid-argument", "عملة غير مدعومة");
  }
  const exchangeRate = pickRate(rates, currency);
  const unitPriceLocal = roundTo(draft.price * exchangeRate, 1);

  const previousQuantity = alreadyThere
    ? Number(existing.docs.find((d) => d.id === lineId)?.data().quantity ?? 0)
    : 0;
  const nextQuantity = Math.min(
    MAX_QTY_PER_LINE,
    previousQuantity + draft.quantity,
  );

  const payload: CartLineDoc = {
    lineId,
    goodsId: draft.goodsId,
    productUrl: draft.productUrl,
    title: draft.title,
    imageUrl: draft.imageUrl ?? "",
    color: draft.color ?? "",
    size: draft.size ?? "",
    quantity: nextQuantity,
    priceOriginal: draft.price,
    currency,
    exchangeRate,
    unitPriceLocal,
    source: draft.extractSource ?? "merged",
    sku: draft.sku ?? "",
    variantId: draft.variantId ?? "",
    status: "draft",
    addedAt: FieldValue.serverTimestamp(),
  };

  await ref.doc(lineId).set(payload, { merge: true });

  const cartCount = alreadyThere ? existing.size : existing.size + 1;

  return {
    status: "ok",
    message: alreadyThere
      ? "تم تحديث الكمية في سلة يمن سيلو"
      : "تمت الإضافة إلى سلة يمن سيلو",
    cartCount,
    lineId,
    unitPriceLocal,
    quantity: nextQuantity,
  };
});

/* ======================= addManualLine (اختياري) =======================
 * الإضافة اليدوية: السطر الوحيد الذي يجوز أن يأتي بسعر غير موجود في
 * products. السعر يُكتب هنا على السيرفر، ولا يستطيع العميل تعديله،
 * ويُسقف بـ maxManualPriceSar عند التسعير.
 * ==================================================================== */

const manualLineSchema = z.object({
  goodsId: z.string().trim().regex(/^\d+$/, "معرّف المنتج يجب أن يكون رقميًا").min(5).max(32),
  titleAr: z.string().trim().min(1).max(300),
  priceSar: z.number().positive("السعر يجب أن يكون أكبر من صفر"),
  quantity: z.number().int().min(1).max(MAX_QTY_PER_LINE).default(1),
  color: z.string().trim().max(120).optional().default(""),
  size: z.string().trim().max(64).optional().default(""),
  imageUrl: z.string().trim().max(2048).optional().default(""),
});

export const addManualLine = onCall(
  { ...baseOpts, enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "مطلوب تسجيل الدخول");
    const role = (request.auth?.token as Record<string, unknown> | undefined)
      ?.role;
    if (role !== "agent" && role !== "manager") {
      throw new HttpsError(
        "permission-denied",
        "الإضافة اليدوية محجوزة للموظفين",
      );
    }

    const input = parseOrThrow(
      manualLineSchema,
      request.data,
      "بيانات السطر اليدوي غير مكتملة",
    );

    const maxManualPriceSar = await loadMaxManualPriceSar();
    if (input.priceSar > maxManualPriceSar) {
      throw new HttpsError(
        "invalid-argument",
        `سعر السطر اليدوي يتجاوز الحد الأقصى (${maxManualPriceSar})`,
      );
    }

    const targetUid = String(
      (request.data as { targetUid?: string })?.targetUid ?? uid,
    );
    const ref = cartRef(targetUid);
    const lineId = lineIdFor(input.goodsId, input.color, input.size);
    const { rates } = await loadPricingAndRates();
    const exchangeRate = pickRate(rates, "SAR");

    const payload: CartLineDoc = {
      lineId,
      goodsId: input.goodsId,
      productUrl: "",
      title: input.titleAr,
      imageUrl: input.imageUrl ?? "",
      color: input.color ?? "",
      size: input.size ?? "",
      quantity: input.quantity,
      priceOriginal: input.priceSar,
      currency: "SAR",
      exchangeRate,
      unitPriceLocal: roundTo(input.priceSar * exchangeRate, 1),
      source: "manual",
      sku: "",
      variantId: "",
      status: "draft",
      addedAt: FieldValue.serverTimestamp(),
      isManual: true,
      manualPriceSar: input.priceSar,
    };

    await ref.doc(lineId).set(payload, { merge: true });
    return { status: "ok", message: "تمت الإضافة اليدوية", lineId };
  },
);

/* ============================ updateCartLine ============================ */

export const updateCartLine = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const input = parseOrThrow(
    quantitySchema,
    request.data,
    "بيانات الكمية غير صالحة",
  );
  const docRef = cartRef(uid).doc(input.lineId);
  const snap = await docRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "المنتج غير موجود في السلة");
  }
  await docRef.update({
    quantity: input.quantity,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {
    status: "ok",
    message: "تم تحديث الكمية",
    lineId: input.lineId,
    quantity: input.quantity,
  };
});

/* ============================ removeCartLine ============================ */

export const removeCartLine = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const input = parseOrThrow(
    lineIdSchema,
    request.data,
    "معرّف السطر غير صالح",
  );
  const docRef = cartRef(uid).doc(input.lineId);
  const snap = await docRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "المنتج غير موجود في السلة");
  }
  await docRef.delete();
  const remaining = await cartRef(uid).count().get();
  return {
    status: "ok",
    message: "تم حذف المنتج",
    cartCount: remaining.data().count,
  };
});

/* ============================ clearCart ============================ */

export const clearCart = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const ref = cartRef(uid);
  const docs = await ref.listDocuments();
  const chunks: Promise<unknown>[] = [];
  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    docs.slice(i, i + 400).forEach((doc) => batch.delete(doc));
    chunks.push(batch.commit());
  }
  await Promise.all(chunks);
  return { status: "ok", message: "تم تفريغ السلة", cartCount: 0 };
});

/* ============================ quoteCart ============================ */

export const quoteCart = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const snap = await cartRef(uid).get();
  // quoteCart لا يرفض: يعرض ما يستطيع تسعيره ويُعلن بقية الأسطر،
  // والرفض الحقيقي في submitOrder. (وإلا تعطّلت شاشة السلة قبل تعبئة الكتالوج.)
  const { lines, pricing, unpricedGoodsIds } = await priceCartLinesFromServer(
    snap.docs,
    false,
  );
  const quote = buildQuote(toQuoteInput(lines), pricing);

  return {
    ...quote,
    canCheckout: unpricedGoodsIds.length === 0,
    unpricedGoodsIds,
    lines: lines.map((line) => ({
      lineId: line.lineId,
      goodsId: line.goodsId,
      titleAr: line.titleAr,
      imageUrl: line.imageUrl,
      color: line.color,
      size: line.size,
      quantity: line.quantity,
      unitPriceSar: line.unitPriceSar,
      unitPriceLocal: line.unitPriceLocal,
      lineTotalLocal: line.lineTotalLocal,
      priceSource: line.priceSource,
    })),
  };
});

/* ============ دورة حياة الطلب ============ */
// submitOrder · attachPayment · confirmPayment · advanceOrderStatus · requestExpedite
// تعيش في orders.ts وتُصدَّر من هنا لأن هذا هو ملف الدخول.
export {
  submitOrder,
  attachPayment,
  confirmPayment,
  advanceOrderStatus,
  requestExpedite,
  updateOrderDraft,
  approveOrderDraft,
} from "./orders";


/* ═══════════ كتالوج: تسجيل منتجات شي إن المستوردة ═══════════ */
/**
 * يسجّل منتجات الاستيراد في products/{goodsId}.
 * السعر يأتي من الصفحة كما رآه العميل، ويُقيَّد بسقف السعر اليدوي
 * حتى لا يُستخدم لتضخيم الطلبات.
 */
export const registerImportedProducts = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);

  const raw = (request.data as Record<string, unknown> | undefined)?.items;
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new HttpsError("invalid-argument", "لا توجد منتجات للتسجيل");
  }
  if (raw.length > 60) {
    throw new HttpsError("invalid-argument", "الحد الأعلى 60 منتجاً في الدفعة");
  }

  const maxPrice = await loadMaxManualPriceSar();
  const batch = db.batch();
  let registered = 0;
  let skipped = 0;

  for (const entry of raw) {
    const item = (entry ?? {}) as Record<string, unknown>;
    const goodsId = String(item.goodsId ?? "").trim();
    const price = Number(item.priceSar);
    if (!goodsId || goodsId.length > 64) {
      skipped++;
      continue;
    }
    if (!Number.isFinite(price) || price <= 0 || price > maxPrice) {
      skipped++;
      continue;
    }
    batch.set(
      db.collection(PRODUCTS).doc(goodsId),
      {
        titleAr: String(item.titleAr ?? "").slice(0, 200),
        priceSar: Math.round(price * 100) / 100,
        imageUrl: String(item.imageUrl ?? "").slice(0, 2048),
        productUrl: String(item.productUrl ?? "").slice(0, 2048),
        source: "shein-import",
        active: true,
        registeredBy: uid,
        registeredAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    registered++;
  }

  if (registered > 0) await batch.commit();
  return { registered, skipped };
});

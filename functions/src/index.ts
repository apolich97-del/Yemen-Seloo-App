import * as admin from "firebase-admin";
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import { FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";
import { z } from "zod";

import {
  ALLOWED_CURRENCIES,
  MAX_LINES_PER_CART,
  MAX_QTY_PER_LINE,
  PricingConfig,
  sheinDraftSchema,
  quantitySchema,
  lineIdSchema,
  submitOrderSchema,
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
const ORDERS = "orders";
const META = "meta";

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

  const { rates } = await loadPricingAndRates();
  const currency = draft.currency.toUpperCase();
  if (!(ALLOWED_CURRENCIES as readonly string[]).includes(currency)) {
    throw new HttpsError("invalid-argument", "عملة غير مدعومة");
  }
  const exchangeRate = pickRate(rates, currency);
  const unitPriceLocal = roundTo(draft.price * exchangeRate, 1);

  const previousQuantity = alreadyThere
    ? Number(
        existing.docs.find((d) => d.id === lineId)?.data().quantity ?? 0,
      )
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
  const { pricing } = await loadPricingAndRates();

  const lines = snap.docs.map((doc) => {
    const data = doc.data();
    return {
      lineId: doc.id,
      quantity: Number(data.quantity ?? 1),
      unitPriceLocal: Number(data.unitPriceLocal ?? 0),
    };
  });

  const quote = buildQuote(lines, pricing);
  const detailedLines = snap.docs.map((doc) => {
    const data = doc.data();
    return {
      lineId: doc.id,
      goodsId: data.goodsId ?? "",
      productUrl: data.productUrl ?? "",
      title: data.title ?? "",
      imageUrl: data.imageUrl ?? "",
      color: data.color ?? "",
      size: data.size ?? "",
      quantity: Number(data.quantity ?? 1),
      priceOriginal: Number(data.priceOriginal ?? 0),
      currency: data.currency ?? "SAR",
      exchangeRate: Number(data.exchangeRate ?? 1),
      unitPriceLocal: Number(data.unitPriceLocal ?? 0),
      source: data.source ?? "unknown",
      sku: data.sku ?? "",
      variantId: data.variantId ?? "",
    };
  });

  return { ...quote, lines: detailedLines };
});

/* ============================ submitOrder ============================ */

export const submitOrder = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const shipping = parseOrThrow(
    submitOrderSchema,
    request.data,
    "بيانات التوصيل غير مكتملة",
  );

  const cartSnap = await cartRef(uid).get();
  if (cartSnap.empty) {
    throw new HttpsError("failed-precondition", "السلة فارغة");
  }
  if (cartSnap.size > MAX_LINES_PER_CART) {
    throw new HttpsError(
      "failed-precondition",
      "عدد المنتجات أكبر من الحد المسموح",
    );
  }

  const { pricing } = await loadPricingAndRates();
  const lines = cartSnap.docs.map((doc) => {
    const data = doc.data();
    return {
      lineId: doc.id,
      quantity: Number(data.quantity ?? 1),
      unitPriceLocal: Number(data.unitPriceLocal ?? 0),
    };
  });
  const quote = buildQuote(lines, pricing);

  if (quote.grandTotalLocal > pricing.maxOrderTotalLocal) {
    throw new HttpsError(
      "failed-precondition",
      "إجمالي الطلب يتجاوز الحد الأقصى المسموح",
    );
  }

  const orderRef = db.collection(ORDERS).doc();
  const orderPayload = {
    orderId: orderRef.id,
    uid,
    status: "unpaid",
    lines: cartSnap.docs.map((doc) => ({ ...doc.data(), lineId: doc.id })),
    itemsSubtotalLocal: quote.itemsSubtotalLocal,
    serviceFeeLocal: quote.serviceFeeLocal,
    shippingLocal: quote.shippingLocal,
    discountLocal: quote.discountLocal,
    grandTotalLocal: quote.grandTotalLocal,
    currency: "YER",
    unitsCount: quote.unitsCount,
    linesCount: quote.linesCount,
    shippingAddress: {
      contactPhone: shipping.contactPhone,
      addressLine: shipping.addressLine,
      city: shipping.city,
      lat: shipping.lat,
      lng: shipping.lng,
    },
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  const batch = db.batch();
  batch.set(orderRef, orderPayload);
  batch.set(orderRef.collection("events").doc(), {
    type: "created",
    at: FieldValue.serverTimestamp(),
    by: uid,
    from: null,
    to: "unpaid",
  });
  cartSnap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  return {
    status: "ok",
    message: "تم إنشاء الطلب، يرجى إتمام الدفع",
    orderId: orderRef.id,
    grandTotalLocal: quote.grandTotalLocal,
    currency: "YER",
    cartCount: 0,
  };
});

/* ============ الانتقال الآمن لحالات الطلب ============ */

const STATUS_FLOW: Record<string, string[]> = {
  unpaid: ["paid", "cancelled"],
  paid: ["purchasing", "cancelled"],
  purchasing: ["purchased", "cancelled"],
  purchased: ["shipped"],
  shipped: ["delivered"],
  delivered: [],
  cancelled: [],
};

export const advanceOrderStatus = onCall(
  { ...baseOpts, enforceAppCheck: false },
  async (request) => {
    const data = request.data as { orderId?: string; to?: string };
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "مطلوب تسجيل الدخول");

    const orderId = typeof data.orderId === "string" ? data.orderId : "";
    const target = typeof data.to === "string" ? data.to : "";
    if (!orderId || !target) {
      throw new HttpsError("invalid-argument", "orderId و to مطلوبان");
    }

    const isAgent = Boolean(
      (request.auth?.token as Record<string, unknown> | undefined)?.role ===
        "agent",
    );
    const orderRef = db.collection(ORDERS).doc(orderId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef);
      if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
      const current = String(snap.data()?.status ?? "unpaid");
      const owner = String(snap.data()?.uid ?? "");

      if (!isAgent && owner !== uid) {
        throw new HttpsError("permission-denied", "لا تملك هذا الطلب");
      }
      if (!isAgent && !(current === "unpaid" && target === "paid")) {
        throw new HttpsError(
          "permission-denied",
          "تغيير الحالة محجوز لموظفي الدعم",
        );
      }

      const allowed = STATUS_FLOW[current] ?? [];
      if (!allowed.includes(target)) {
        throw new HttpsError(
          "failed-precondition",
          `انتقال غير مسموح: ${current} → ${target}`,
        );
      }

      tx.update(orderRef, {
        status: target,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(orderRef.collection("events").doc(), {
        type: "status",
        at: FieldValue.serverTimestamp(),
        by: uid,
        from: current,
        to: target,
      });
    });

    return { status: "ok", message: "تم تحديث حالة الطلب", orderId, to: target };
  },
);

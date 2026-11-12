import * as admin from "firebase-admin";
import { DocumentData, FieldValue, Firestore, Timestamp, UpdateData } from "firebase-admin/firestore";
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";

import {
  ACCOUNTS,
  ALLOWED_ACCOUNTS_BY_CURRENCY,
  computeTotals,
  isCurrency,
  loadCoupon,
  loadSettings,
  nextOrderNo,
  priceItems,
  round2,
  roundMoney,
  validatePayment,
  Totals,
  Currency,
  ItemInput,
  PaymentInput,
} from "./catalog";

/** سقف عمولة القطعة الواحدة بالريال — يمنع رقماً فاسداً من العميل. */
const MAX_COMMISSION_PER_PIECE_SAR = 100;

/**
 * دورة حياة الطلب — كل كتابة على orders تمرّ من هنا.
 * العميل يقرأ فقط، ولا يرسل سعراً: السعر يُقرأ من products/{goodsId}.
 */

const REGION = "europe-west1";
const USERS = "users";
const CART = "cart";
const ORDERS = "orders";
const ALERTS = "alerts";

/**
 * ملاحظة مقصودة: enforceAppCheck = false.
 * التطبيق لا يضم firebase_app_check بعد، وتشغيله هنا يعني رفض كل استدعاء.
 * تُعاد إلى true بعد تهيئة App Check في التطبيق (خطوة مذكورة في README).
 */
const baseOpts = { region: REGION, enforceAppCheck: false, cors: true } as const;

const MAX_QTY = 50;
const MAX_ITEMS = 60;
const EXPEDITE_COOLDOWN_MS = 12 * 60 * 60 * 1000;

export const STATUSES = [
  "unpaid",
  "verifying",
  "processing",
  "shipped",
  "outForDelivery",
  "delivered",
  "cancelled",
] as const;
export type OrderStatus = (typeof STATUSES)[number];

/** آلة الحالات — نفس القائمة في order.dart، والسيرفر هو من يفرضها. */
export const TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  unpaid: ["verifying", "cancelled"],
  verifying: ["processing", "unpaid", "cancelled"],
  processing: ["shipped", "cancelled"],
  shipped: ["outForDelivery", "cancelled"],
  outForDelivery: ["delivered", "shipped"],
  delivered: [],
  cancelled: [],
};

const STAFF_ROLES = ["manager", "support", "shipping", "courier", "accounting", "agent"];
const PAYMENT_ROLES = ["manager", "accounting", "agent"];

function db(): Firestore {
  return admin.firestore();
}

function requireUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول لإتمام هذه العملية");
  }
  return uid;
}

function roleOf(request: CallableRequest<unknown>): string {
  return String(
    (request.auth?.token as Record<string, unknown> | undefined)?.role ?? "",
  );
}

function requireRole(
  request: CallableRequest<unknown>,
  allowed: string[],
  message: string,
): string {
  const role = roleOf(request);
  if (!allowed.includes(role)) {
    throw new HttpsError("permission-denied", message);
  }
  return role;
}

/** تطبيع أسطر العميل: الأسماء والكميات فقط، ولا سعر مقبول. */
function parseItems(raw: unknown): ItemInput[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new HttpsError("invalid-argument", "السلة فارغة");
  }
  if (raw.length > MAX_ITEMS) {
    throw new HttpsError("failed-precondition", "عدد المنتجات أكبر من الحد المسموح");
  }

  const items: ItemInput[] = [];
  for (const entry of raw) {
    const item = (entry ?? {}) as Record<string, unknown>;
    const goodsId = String(item.goodsId ?? "").trim();
    if (!/^\d{5,32}$/.test(goodsId)) {
      throw new HttpsError("invalid-argument", "معرّف منتج غير صالح", { goodsId });
    }
    const rawQty = Number(item.qty ?? item.quantity ?? 1);
    const qty = Math.max(1, Math.min(MAX_QTY, Math.floor(rawQty) || 1));
    items.push({
      goodsId,
      qty,
      color: String(item.color ?? "").trim().slice(0, 40),
      size: String(item.size ?? "").trim().slice(0, 30),
      sku: String(item.sku ?? "").trim().slice(0, 120),
      productUrl: String(item.productUrl ?? "").trim().slice(0, 2048),
    });
  }
  return items;
}

function parseAddress(raw: unknown): Record<string, unknown> {
  const a = (raw ?? {}) as Record<string, unknown>;
  const out: Record<string, unknown> = {
    city: String(a.city ?? "").trim(),
    district: String(a.district ?? "").trim(),
    line: String(a.line ?? a.addressLine ?? "").trim(),
    phone: String(a.phone ?? a.contactPhone ?? "").trim(),
    receiverName: String(a.receiverName ?? "").trim(),
  };
  if (a.lat !== undefined && a.lat !== null) out.lat = Number(a.lat);
  if (a.lng !== undefined && a.lng !== null) out.lng = Number(a.lng);

  if (!out.city || !out.line || !out.receiverName) {
    throw new HttpsError("invalid-argument", "العنوان غير مكتمل");
  }
  if (!/^\+?[0-9]{7,15}$/.test(String(out.phone))) {
    throw new HttpsError("invalid-argument", "رقم هاتف غير صالح");
  }
  return out;
}

/**
 * عمولة المندوب: بند داخلي.
 * تُحسب على السيرفر من عدد القطع الحقيقي، والعميل يرسل سعر القطعة فقط.
 * لا تدخل totalSar/totalLocal إطلاقاً.
 */
function buildCommission(raw: unknown, totals: Totals) {
  const input = (raw ?? {}) as { perPieceSar?: unknown; approved?: unknown };
  const perPiece = Number(input.perPieceSar ?? 0);
  const safe = Number.isFinite(perPiece) && perPiece > 0
    ? Math.min(round2(perPiece), MAX_COMMISSION_PER_PIECE_SAR)
    : 0;
  const totalPieces = totals.lines.reduce((sum, line) => sum + line.qty, 0);
  const totalSar = round2(safe * totalPieces);
  return {
    perPieceSar: safe,
    totalPieces,
    totalSar,
    totalLocal: Math.round(totalSar * totals.rate),
    approved: input.approved === true,
  };
}

/* ============================ submitOrder ============================ */

export const submitOrder = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const data = (request.data ?? {}) as Record<string, unknown>;

  const currencyRaw = String(data.currency ?? "sar");
  if (!isCurrency(currencyRaw)) {
    throw new HttpsError("invalid-argument", "عملة غير مدعومة");
  }
  const currency: Currency = currencyRaw;

  const items = parseItems(data.items);
  const address = parseAddress(data.address);
  const coupon = await loadCoupon(db(), String(data.couponCode ?? ""));

  const { lines } = await priceItems(db(), items, true);
  const settings = await loadSettings(db());
  const totals = computeTotals(lines, settings, currency, coupon);

  const paymentRaw = data.payment;
  const payment: PaymentInput | null =
    paymentRaw === undefined || paymentRaw === null
      ? null
      : validatePayment(paymentRaw, currency);

  if (payment) {
    payment.amount = totals.totalLocal;
  }

  const orderRef = db().collection(ORDERS).doc();
  const status: OrderStatus = payment ? "verifying" : "unpaid";
  const commission = buildCommission(data.commission, totals);
  const timeline = [
    {
      status,
      at: Timestamp.now(),
      byName: "النظام",
      note: payment ? "تم رفع بيانات الحوالة" : "تم إنشاء الطلب",
    },
  ];

  await db().runTransaction(async (tx) => {
    const orderNo = await nextOrderNo(db(), tx);
    tx.set(orderRef, {
      orderNo,
      userId: uid,
      currency,
      exchangeRate: totals.rate,
      items: totals.lines.map((line) => ({
        goodsId: line.goodsId,
        sku: line.sku,
        title: line.title,
        imageUrl: line.imageUrl,
        color: line.color,
        size: line.size,
        qty: line.qty,
        unitPriceSar: line.unitPriceSar,
        productUrl: line.productUrl,
      })),
      deliveryMinDays: settings.deliveryMinDays,
      deliveryMaxDays: settings.deliveryMaxDays,
      subtotalSar: totals.subtotalSar,
      shippingFeeSar: totals.shippingFeeSar,
      serviceFeeSar: totals.serviceFeeSar,
      deliveryFeeSar: totals.deliveryFeeSar,
      discountSar: totals.discountSar,
      totalSar: totals.totalSar,
      totalLocal: totals.totalLocal,
      couponCode: totals.couponCode,
      // ── عمولة المندوب: بند داخلي ──────────────────────────────────
      // لا تُضاف إلى totalSar ولا totalLocal. العميل لا يراها،
      // ولا تُشارك مع الشركة إلا بموافقة المندوب (approved).
      commission,
      address,
      // فكرة يمن: نسخة واحدة معتمدة + سجل التعديلات محفوظ داخلياً
      revision: 1,
      approvedAt: Timestamp.now(),
      approvedByName: "العميل",
      editingLocked: false,
      revisions: [
        {
          revision: 1,
          at: Timestamp.now(),
          byName: "العميل",
          totalSar: totals.totalSar,
          totalLocal: totals.totalLocal,
          itemCount: totals.lines.length,
          pieceCount: totals.lines.reduce((a, l) => a + l.qty, 0),
          note: "النسخة الأولى",
        },
      ],
      status,
      timeline,
      payment: payment
        ? {
            accountId: payment.accountId,
            accountTitleAr: ACCOUNTS[payment.accountId]?.titleAr ?? "",
            accountNumber: payment.accountNumber,
            senderName: payment.senderName,
            refNo: payment.refNo,
            note: payment.note,
            proofUrl: payment.proofUrl,
            amount: payment.amount,
            submittedAt: Timestamp.now(),
          }
        : null,
      trackingNo: "",
      courierName: "",
      proofImageUrl: "",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  // السلة المحلية يفرّغها التطبيق بعد النجاح؛ ننظّف نسخة Firestore إن وُجدت.
  try {
    const cartRefs = await db().collection(USERS).doc(uid).collection(CART).listDocuments();
    if (cartRefs.length) {
      const batch = db().batch();
      cartRefs.forEach((ref) => batch.delete(ref));
      await batch.commit();
    }
  } catch (_) {
    // ليست حرجة: الطلب أُنشئ بالفعل.
  }

  const created = await orderRef.get();
  return {
    status: "ok",
    message: "تم إنشاء الطلب",
    orderId: orderRef.id,
    orderNo: String(created.data()?.orderNo ?? orderRef.id),
    totalSar: totals.totalSar,
    totalLocal: totals.totalLocal,
    currency,
    orderStatus: status,
  };
});

/* ============================ attachPayment ============================ */

export const attachPayment = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const data = (request.data ?? {}) as Record<string, unknown>;
  const orderId = String(data.orderId ?? "").trim();
  if (!orderId) throw new HttpsError("invalid-argument", "orderId مطلوب");

  const ref = db().collection(ORDERS).doc(orderId);

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
    const order = snap.data() as Record<string, unknown>;
    if (String(order.userId ?? "") !== uid) {
      throw new HttpsError("permission-denied", "لا تملك هذا الطلب");
    }
    if (order.status !== "unpaid") {
      throw new HttpsError("failed-precondition", "لا يمكن إرفاق حوالة في هذه الحالة");
    }

    const currencyRaw = String(order.currency ?? "sar");
    const currency: Currency = isCurrency(currencyRaw) ? currencyRaw : "sar";
    const payment = validatePayment(data, currency);
    payment.amount = Number(order.totalLocal ?? 0);

    tx.update(ref, {
      payment: {
        accountId: payment.accountId,
        accountTitleAr: ACCOUNTS[payment.accountId]?.titleAr ?? "",
        accountNumber: payment.accountNumber,
        senderName: payment.senderName,
        refNo: payment.refNo,
        note: payment.note,
        proofUrl: payment.proofUrl,
        amount: payment.amount,
        submittedAt: Timestamp.now(),
      },
      status: "verifying",
      timeline: FieldValue.arrayUnion({
        status: "verifying",
        at: Timestamp.now(),
        byName: "العميل",
        note: "تم رفع بيانات الحوالة",
      }),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return { status: "ok", message: "تم إرفاق الحوالة، بانتظار تأكيد المحاسبة" };
});

/* ============================ confirmPayment ============================ */

export const confirmPayment = onCall(baseOpts, async (request) => {
  requireUid(request);
  requireRole(request, PAYMENT_ROLES, "تأكيد الحوالات محجوز للمحاسبة");

  const data = (request.data ?? {}) as Record<string, unknown>;
  const orderId = String(data.orderId ?? "").trim();
  const approve = data.approve !== false;
  const note = String(data.note ?? "").trim().slice(0, 300);
  if (!orderId) throw new HttpsError("invalid-argument", "orderId مطلوب");

  const ref = db().collection(ORDERS).doc(orderId);
  const byName = String(data.byName ?? "المحاسبة");

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
    const order = snap.data() as Record<string, unknown>;
    const current = String(order.status ?? "unpaid");
    if (current !== "verifying") {
      throw new HttpsError("failed-precondition", "الطلب ليس بانتظار تأكيد الدفع");
    }

    const target: OrderStatus = approve ? "processing" : "unpaid";
    const payment = (order.payment ?? {}) as Record<string, unknown>;

    tx.update(ref, {
      status: target,
      payment: approve
        ? {
            ...payment,
            confirmedAt: Timestamp.now(),
            confirmedByName: byName,
          }
        : {
            ...payment,
            amount: 0,
          },
      timeline: FieldValue.arrayUnion({
        status: target,
        at: Timestamp.now(),
        byName,
        note: approve ? note || "تم تأكيد الحوالة" : note || "تم رفض الحوالة",
      }),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    status: "ok",
    message: approve ? "تم تأكيد الدفع" : "تم رفض الحوالة وإرجاع الطلب لغير مدفوع",
  };
});

/* ============================ advanceOrderStatus ============================ */

export const advanceOrderStatus = onCall(baseOpts, async (request) => {
  requireUid(request);
  const role = requireRole(request, STAFF_ROLES, "تغيير الحالة محجوز للطاقم");

  const data = (request.data ?? {}) as Record<string, unknown>;
  const orderId = String(data.orderId ?? "").trim();
  const target = String(data.to ?? "").trim() as OrderStatus;
  if (!orderId) throw new HttpsError("invalid-argument", "orderId مطلوب");
  if (!(STATUSES as readonly string[]).includes(target)) {
    throw new HttpsError("invalid-argument", "حالة غير معروفة", { to: target });
  }

  const trackingNo = String(data.trackingNo ?? "").trim().slice(0, 60);
  const courierName = String(data.courierName ?? "").trim().slice(0, 80);
  const proofUrl = String(data.proofUrl ?? "").trim().slice(0, 2048);
  const note = String(data.note ?? "").trim().slice(0, 300);

  if (target === "shipped" && !trackingNo) {
    throw new HttpsError("invalid-argument", "رقم التتبع مطلوب عند الشحن");
  }
  if (target === "delivered" && !proofUrl) {
    throw new HttpsError("invalid-argument", "صورة إثبات التسليم مطلوبة");
  }
  if (target === "delivered" && !["courier", "shipping", "manager", "agent"].includes(role)) {
    throw new HttpsError("permission-denied", "إثبات التسليم محجوز للتوصيل والشحن");
  }

  const ref = db().collection(ORDERS).doc(orderId);

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
    const order = snap.data() as Record<string, unknown>;
    const current = String(order.status ?? "unpaid") as OrderStatus;

    if (!(TRANSITIONS[current] ?? []).includes(target)) {
      throw new HttpsError(
        "failed-precondition",
        `انتقال غير مسموح: ${current} → ${target}`,
      );
    }

    // بعد بدء التنفيذ لا يُعدَّل الطلب من العميل إطلاقاً.
    const lockEdit = !["unpaid", "verifying"].includes(target);

    const patch: Record<string, unknown> = {
      status: target,
      ...(lockEdit ? { editingLocked: true, editingLockedAt: Timestamp.now() } : {}),
      updatedAt: FieldValue.serverTimestamp(),
      timeline: FieldValue.arrayUnion({
        status: target,
        at: Timestamp.now(),
        byName: role,
        note,
      }),
    };
    if (trackingNo) patch.trackingNo = trackingNo;
    if (courierName) patch.courierName = courierName;
    if (proofUrl) patch.proofImageUrl = proofUrl;

    tx.update(ref, patch as UpdateData<DocumentData>);
  });

  return { status: "ok", message: "تم تحديث حالة الطلب", to: target };
});

/* ============================ requestExpedite ============================ */

export const requestExpedite = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const data = (request.data ?? {}) as Record<string, unknown>;
  const orderId = String(data.orderId ?? "").trim();
  if (!orderId) throw new HttpsError("invalid-argument", "orderId مطلوب");

  const ref = db().collection(ORDERS).doc(orderId);

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
    const order = snap.data() as Record<string, unknown>;
    if (String(order.userId ?? "") !== uid) {
      throw new HttpsError("permission-denied", "لا تملك هذا الطلب");
    }
    if (["delivered", "cancelled"].includes(String(order.status ?? ""))) {
      throw new HttpsError("failed-precondition", "الطلب منتهٍ");
    }

    const last = order.expediteRequestedAt as
      | { toMillis?: () => number }
      | undefined;
    if (last && typeof last.toMillis === "function") {
      const elapsed = Date.now() - last.toMillis();
      if (elapsed < EXPEDITE_COOLDOWN_MS) {
        throw new HttpsError(
          "resource-exhausted",
          "أُرسل طلب تسريع خلال آخر 12 ساعة",
        );
      }
    }

    tx.update(ref, {
      expediteRequestedAt: Timestamp.now(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(db().collection(ALERTS).doc(), {
      type: "expedite",
      orderId,
      orderNo: String(order.orderNo ?? ""),
      userId: uid,
      createdAt: FieldValue.serverTimestamp(),
      seen: false,
    });
  });

  return { status: "ok", message: "تم إرسال طلب التسريع للفريق" };
});

/** يُستخدم من الإدارة لعرض المحافظ المسموحة في اللوحة. */
export function accountsForCurrency(currency: Currency): string[] {
  return ALLOWED_ACCOUNTS_BY_CURRENCY[currency];
}

export { roundMoney };


/* ═══════════ فكرة يمن: تعديل الطلب واعتماد آخر نسخة ═══════════ */

/** المنتجات قابلة للتعديل فقط قبل الإغلاق وقبل بدء التنفيذ. */
function assertEditable(order: Record<string, unknown>) {
  const status = String(order.status ?? "unpaid") as OrderStatus;
  if (order.editingLocked === true) {
    throw new HttpsError(
      "failed-precondition",
      "تم إغلاق تعديل هذا الطلب — تواصل مع يمن سيلو",
    );
  }
  if (!["unpaid", "verifying"].includes(status)) {
    throw new HttpsError(
      "failed-precondition",
      "لا يمكن تعديل الطلب بعد بدء التنفيذ",
    );
  }
}

/**
 * تعديل الطلب نفسه — لا ينشئ طلباً جديداً.
 * كل تعديل يرفع رقم النسخة ويحفظ لقطة داخلية في revisions،
 * ويعيد الطلب إلى «قيد التعديل» حتى يعتمد العميل آخر تعديل.
 */
export const updateOrderDraft = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const data = (request.data ?? {}) as Record<string, unknown>;
  const orderId = String(data.orderId ?? "").trim();
  if (!orderId) throw new HttpsError("invalid-argument", "orderId مطلوب");

  const currencyRaw = String(data.currency ?? "sar");
  if (!isCurrency(currencyRaw)) {
    throw new HttpsError("invalid-argument", "عملة غير مدعومة");
  }
  const currency: Currency = currencyRaw;

  const items = parseItems(data.items);
  const coupon = await loadCoupon(db(), String(data.couponCode ?? ""));
  const note = String(data.note ?? "").trim().slice(0, 200);

  const { lines } = await priceItems(db(), items, true);
  const settings = await loadSettings(db());
  const totals = computeTotals(lines, settings, currency, coupon);

  const ref = db().collection(ORDERS).doc(orderId);

  return db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");

    const order = snap.data() as Record<string, unknown>;
    if (String(order.userId ?? "") !== uid) {
      throw new HttpsError("permission-denied", "هذا الطلب ليس لك");
    }
    assertEditable(order);

    const revision = Number(order.revision ?? 1) + 1;
    const snapshot = {
      revision,
      at: Timestamp.now(),
      byName: "العميل",
      totalSar: totals.totalSar,
      totalLocal: totals.totalLocal,
      itemCount: totals.lines.length,
      pieceCount: totals.lines.reduce((a, l) => a + l.qty, 0),
      note: note || "تعديل السلة",
    };

    tx.update(ref, {
      items: totals.lines.map((line) => ({
        goodsId: line.goodsId,
        sku: line.sku,
        title: line.title,
        imageUrl: line.imageUrl,
        color: line.color,
        size: line.size,
        qty: line.qty,
        unitPriceSar: line.unitPriceSar,
        productUrl: line.productUrl,
      })),
      currency,
      exchangeRate: totals.rate,
      subtotalSar: totals.subtotalSar,
      shippingFeeSar: totals.shippingFeeSar,
      serviceFeeSar: totals.serviceFeeSar,
      deliveryFeeSar: totals.deliveryFeeSar,
      discountSar: totals.discountSar,
      totalSar: totals.totalSar,
      totalLocal: totals.totalLocal,
      couponCode: totals.couponCode,
      revision,
      revisions: FieldValue.arrayUnion(snapshot),
      approvedAt: null,
      approvedByName: "",
      status: "unpaid",
      payment: null,
      updatedAt: FieldValue.serverTimestamp(),
      timeline: FieldValue.arrayUnion({
        status: "unpaid",
        at: Timestamp.now(),
        byName: "العميل",
        note: `تعديل رقم ${revision} — بانتظار الاعتماد`,
      }),
    });

    return {
      orderId,
      orderNo: String(order.orderNo ?? orderId),
      revision,
      totalSar: totals.totalSar,
      totalLocal: totals.totalLocal,
      needsApproval: true,
    };
  });
});

/** تثبيت آخر نسخة باعتبارها النسخة المعتمدة. */
export const approveOrderDraft = onCall(baseOpts, async (request) => {
  const uid = requireUid(request);
  const data = (request.data ?? {}) as Record<string, unknown>;
  const orderId = String(data.orderId ?? "").trim();
  if (!orderId) throw new HttpsError("invalid-argument", "orderId مطلوب");

  const ref = db().collection(ORDERS).doc(orderId);

  return db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");

    const order = snap.data() as Record<string, unknown>;
    if (String(order.userId ?? "") !== uid) {
      throw new HttpsError("permission-denied", "هذا الطلب ليس لك");
    }
    assertEditable(order);

    const at = Timestamp.now();
    tx.update(ref, {
      approvedAt: at,
      approvedByName: "العميل",
      updatedAt: FieldValue.serverTimestamp(),
      timeline: FieldValue.arrayUnion({
        status: String(order.status ?? "unpaid"),
        at,
        byName: "العميل",
        note: `اعتماد النسخة ${Number(order.revision ?? 1)}`,
      }),
    });

    return {
      orderId,
      orderNo: String(order.orderNo ?? orderId),
      revision: Number(order.revision ?? 1),
      approvedAt: at.toDate().toISOString(),
    };
  });
});

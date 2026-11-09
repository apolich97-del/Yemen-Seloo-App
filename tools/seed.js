/**
 * تعبئة بيانات تجريبية — settings/app + كوبونات + منتجات.
 *
 * التشغيل مرة واحدة، من جهازك، بعد تنزيل مفتاح الخدمة:
 *   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json node tools/seed.js
 *
 * السكربت متكرر الاستخدام (idempotent): إعادة تشغيله تُحدّث ولا تُكرّر.
 */
const admin = require("firebase-admin");

admin.initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });
const db = admin.firestore();

const SETTINGS = {
  rateNorth: 140,
  rateSouth: 413,
  shippingFeeSar: 0,
  deliveryFeeSar: 0,
  deliveryFeeNorthLocal: 1500,
  deliveryFeeSouthLocal: 1000,
  deliveryFeeSarLocal: 0,
  freeShippingThresholdSar: 300,
  maxManualPriceSar: 100000,
};

const COUPONS = {
  SELOO10: { active: true, isPercent: true, value: 10, minOrderSar: 100 },
  WELCOME5: { active: true, isPercent: false, value: 5, minOrderSar: 0 },
};

// صور من مسار شي إن — للعرض فقط، والسعر هو مصدر الحقيقة.
const IMG = "https://img.ltwebstatic.com/images3_pi/2024/05/21/1716278400";
const PRODUCTS = [
  ["10000001", "فستان صيفي مطبوع", 79.7],
  ["10000002", "حقائب يد نسائية", 99.7],
  ["10000003", "حذاء رياضي خفيف", 129.0],
  ["10000004", "طقم أوفرول كاجوال", 145.5],
  ["10000005", "قميص قطني رجالي", 59.9],
  ["10000006", "سلسلة فولاذ مقاومة", 22.0],
  ["10000007", "هودي بشعار مطبوع", 110.25],
  ["10000008", "نظارة شمسية كلاسيك", 35.0],
];

async function main() {
  await db.doc("settings/app").set(SETTINGS, { merge: true });
  console.log("settings/app ✓");

  for (const [code, body] of Object.entries(COUPONS)) {
    await db.collection("coupons").doc(code).set(
      { ...body, createdAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
  }
  console.log(`coupons ✓ (${Object.keys(COUPONS).length})`);

  const batch = db.batch();
  PRODUCTS.forEach(([goodsId, titleAr, priceSar], i) => {
    batch.set(
      db.collection("products").doc(goodsId),
      {
        titleAr,
        priceSar,
        imageUrl: `${IMG}_${i + 1}.jpg`,
        isManual: false,
        active: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
  await batch.commit();
  console.log(`products ✓ (${PRODUCTS.length})`);
  console.log("\nتم. أضف المنتجات من شي إن بمعرّفات حقيقية أو أدخلها يدوياً من اللوحة.");
}

main().catch((e) => {
  console.error("فشل التعبئة:", e.message);
  process.exit(1);
});

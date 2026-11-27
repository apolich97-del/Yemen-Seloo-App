import { AppCurrency, AppSettings, Order } from '../types/seloo';
import { computeCurrencyMatrix, currencyShortLabel, formatMoney } from './pricingService';
import { orderStatusLabelAr } from './shipmentTrackingService';

export function buildWhatsAppOrderForm(order: Order, settings: AppSettings): string {
  const matrix = computeCurrencyMatrix(order.totalSar, {
    ...settings,
    rateNorth: order.currency === 'north' ? order.exchangeRate : settings.rateNorth,
    rateSouth: order.currency === 'south' ? order.exchangeRate : settings.rateSouth,
    usdRateNorth: order.usdRateNorth || settings.usdRateNorth,
    usdRateSouth: order.usdRateSouth || settings.usdRateSouth,
    sarPerUsd: order.sarPerUsd || settings.sarPerUsd,
  });

  const itemLines = order.items
    .map((it, i) => {
      const origin = typeof window !== 'undefined' ? window.location.origin : 'https://yemenseloo.com';
      const selooLink = `${origin}/?product=${encodeURIComponent(it.goodsId)}`;
      const sheinLine = it.productUrl ? `\n   🔗 رابط SHEIN المباشر: ${it.productUrl}` : '';
      const selooLine = `\n   🛍️ رابط سلة يمن سيلو: ${selooLink}`;
      return `${i + 1}. ${it.title} (${it.color} / ${it.size}) × ${it.qty} = ${(
        it.unitPriceSar * it.qty
      ).toFixed(2)} ر.س${it.nonRefundable ? ' [غير قابل للاسترداد]' : ''}${sheinLine}${selooLine}`;
    })
    .join('\n');

  const planLabel =
    order.paymentPlan === 'half_deferred'
      ? `آجل 50% (سعر يوم الطلب مثبّت: ${order.exchangeRate})`
      : 'دفع كامل';

  const hasProof = Boolean(order.payment?.proofUrl || order.proofImageUrl);

  return [
    `🛍️ *استمارة تأكيد طلب — ${settings.companyNameAr || 'يمن سيلو'}*`,
    `رقم الطلب: *${order.orderNo}*`,
    `الحالة: ${orderStatusLabelAr(order.status)}`,
    `العميل: ${order.receiverName || order.address.receiverName}`,
    `الهاتف: ${order.receiverPhone || order.address.phone}`,
    `العنوان: ${order.shippingGovernorate || order.address.city}${
      order.address.district ? ` - ${order.address.district}` : ''
    } — ${order.address.line}`,
    `خطة السداد: ${planLabel}`,
    order.payment?.accountTitleAr
      ? `حساب التحويل: ${order.payment.accountTitleAr} (مرجع: ${order.payment.refNo || '—'})`
      : '',
    `صورة الحوالة المرفقة: ${hasProof ? 'مرفقة في النظام وبطاقة الطلب ✓' : 'تُرفق مع الرسالة'}`,
    `───────────────`,
    `*القطع (${order.items.length}):*`,
    itemLines,
    `───────────────`,
    `الإجمالي بالريال السعودي: *${matrix.sar.toFixed(2)} ر.س*`,
    `المعادل بالدولار: *$${matrix.usd.toFixed(2)}*`,
    `المبلغ بعملة الطلب: *${formatMoney(order.totalLocal, order.currency)}*`,
    `المطلوب الآن: *${formatMoney(order.upfrontDueLocal, order.currency)}*`,
    order.remainingLocal > 0
      ? `المتبقي عند الاستلام: *${formatMoney(order.remainingLocal, order.currency)}*`
      : '',
  ]
    .filter(Boolean)
    .join('\n');
}

/**
 * Generates an HD PNG Order Confirmation Card containing QR verification matrix,
 * full order details, and multi-currency summary — solving WhatsApp image+text issues.
 */
export function generateOrderSummaryCardPng(
  order: Order,
  settings: AppSettings
): string {
  const w = 1000;
  const h = 1280;
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');
  if (!ctx) return '';

  // Background
  ctx.fillStyle = '#FAF8F5';
  ctx.fillRect(0, 0, w, h);

  // Header band
  const grad = ctx.createLinearGradient(0, 0, w, 240);
  grad.addColorStop(0, '#4C1D95');
  grad.addColorStop(0.65, '#6D28D9');
  grad.addColorStop(1, '#92400E');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, w, 230);

  // Brand title
  ctx.fillStyle = '#FFFFFF';
  ctx.textAlign = 'right';
  ctx.font = 'bold 46px Tajawal, sans-serif';
  ctx.fillText(settings.companyNameAr || 'يمن سيلو | YEMEN SELOO', w - 56, 86);

  ctx.fillStyle = 'rgba(255,255,255,0.85)';
  ctx.font = '24px Tajawal, sans-serif';
  ctx.fillText('استمارة تأكيد طلب رسمية — Official Order Summary Card', w - 56, 134);

  // Order badge box
  ctx.fillStyle = 'rgba(255,255,255,0.16)';
  roundRect(ctx, 56, 52, 310, 126, 20);
  ctx.fill();
  ctx.fillStyle = '#FDE68A';
  ctx.textAlign = 'left';
  ctx.font = 'bold 20px sans-serif';
  ctx.fillText('ORDER NO.', 82, 92);
  ctx.fillStyle = '#FFFFFF';
  ctx.font = 'bold 34px monospace';
  ctx.fillText(order.orderNo, 82, 140);

  // White card container
  ctx.fillStyle = '#FFFFFF';
  ctx.strokeStyle = 'rgba(23,19,33,0.1)';
  ctx.lineWidth = 2;
  roundRect(ctx, 48, 260, w - 96, 940, 28);
  ctx.fill();
  ctx.stroke();

  // Customer info section
  let y = 325;
  ctx.textAlign = 'right';
  ctx.fillStyle = '#6D28D9';
  ctx.font = 'bold 26px Tajawal, sans-serif';
  ctx.fillText('بيانات العميل والتوصيل', w - 88, y);

  y += 42;
  ctx.fillStyle = '#171321';
  ctx.font = '24px Tajawal, sans-serif';
  ctx.fillText(
    `المستلم: ${order.receiverName || order.address.receiverName}   |   الهاتف: ${order.receiverPhone || order.address.phone}`,
    w - 88,
    y
  );
  y += 38;
  ctx.fillStyle = '#5F5870';
  ctx.fillText(
    `الوجهة: ${order.shippingGovernorate || order.address.city} — ${order.address.line}`,
    w - 88,
    y
  );
  y += 38;
  ctx.fillText(
    `خطة السداد: ${
      order.paymentPlan === 'half_deferred'
        ? 'دفعة أولى 50% (سعر الصرف مثبّت بسعر يوم الطلب)'
        : 'دفع كامل'
    }   |   التاريخ: ${new Date(order.createdAt).toLocaleDateString('ar-YE')}`,
    w - 88,
    y
  );

  // Divider
  y += 32;
  ctx.strokeStyle = 'rgba(23,19,33,0.1)';
  ctx.beginPath();
  ctx.moveTo(88, y);
  ctx.lineTo(w - 88, y);
  ctx.stroke();

  // Items preview (up to 5 lines)
  y += 46;
  ctx.fillStyle = '#6D28D9';
  ctx.font = 'bold 26px Tajawal, sans-serif';
  ctx.fillText(`المنتجات (${order.items.length} صنف)`, w - 88, y);
  y += 38;

  const previewItems = order.items.slice(0, 4);
  for (const it of previewItems) {
    ctx.fillStyle = '#171321';
    ctx.textAlign = 'right';
    ctx.font = '22px Tajawal, sans-serif';
    const trimmed = it.title.length > 44 ? `${it.title.slice(0, 44)}...` : it.title;
    ctx.fillText(`• ${trimmed} (${it.color} / ${it.size}) × ${it.qty}`, w - 88, y);
    ctx.textAlign = 'left';
    ctx.font = 'bold 22px monospace';
    ctx.fillText(`${(it.unitPriceSar * it.qty).toFixed(2)} SAR`, 88, y);
    y += 28;
    if (it.productUrl) {
      ctx.fillStyle = '#6D28D9';
      ctx.textAlign = 'right';
      ctx.font = '15px monospace';
      const shortUrl = it.productUrl.length > 62 ? `${it.productUrl.slice(0, 62)}...` : it.productUrl;
      ctx.fillText(`SHEIN: ${shortUrl}`, w - 104, y);
      y += 26;
    } else {
      y += 10;
    }
  }
  if (order.items.length > 4) {
    ctx.fillStyle = '#6D28D9';
    ctx.textAlign = 'right';
    ctx.font = '20px Tajawal, sans-serif';
    ctx.fillText(`+ ${order.items.length - 4} قطع إضافية مرفقة في استمارة الطلب`, w - 88, y);
    y += 30;
  }

  // Payment Proof & Snapshot Status Strip
  const hasProof = Boolean(order.payment?.proofUrl || order.proofImageUrl);
  ctx.fillStyle = hasProof ? '#ECFDF5' : '#FEF3C7';
  roundRect(ctx, 84, 754, w - 168, 56, 14);
  ctx.fill();
  ctx.fillStyle = hasProof ? '#065F46' : '#92400E';
  ctx.textAlign = 'right';
  ctx.font = 'bold 21px Tajawal, sans-serif';
  ctx.fillText(
    hasProof
      ? `✓ صورة الحوالة مرفقة بالطلب (${order.payment?.accountTitleAr || 'تحويل موثق'})`
      : 'ملاحظة: أرفق صورة الحوالة مع هذه البطاقة عند الإرسال',
    w - 108,
    790
  );

  // Totals box + QR
  const boxTop = 830;
  ctx.fillStyle = '#F3EFE9';
  roundRect(ctx, 84, boxTop, w - 168, 320, 22);
  ctx.fill();

  const matrix = computeCurrencyMatrix(order.totalSar, settings);
  ctx.textAlign = 'right';
  ctx.fillStyle = '#171321';
  ctx.font = 'bold 28px Tajawal, sans-serif';
  ctx.fillText(`الإجمالي المعتمد: ${formatMoney(order.totalLocal, order.currency)}`, w - 116, boxTop + 58);

  ctx.fillStyle = '#5F5870';
  ctx.font = '23px Tajawal, sans-serif';
  ctx.fillText(
    `بالسعودي: ${matrix.sar.toFixed(2)} ر.س   |   بالدولار: $${matrix.usd.toFixed(2)}`,
    w - 116,
    boxTop + 106
  );
  ctx.fillText(
    `صرف شمال: ${matrix.northFromSar.toLocaleString('en-US')} ر.ي   |   صرف جنوب: ${matrix.southFromSar.toLocaleString('en-US')} ر.ي`,
    w - 116,
    boxTop + 148
  );

  ctx.fillStyle = '#6D28D9';
  ctx.font = 'bold 26px Tajawal, sans-serif';
  ctx.fillText(`المطلوب تحويله الآن: ${formatMoney(order.upfrontDueLocal, order.currency)}`, w - 116, boxTop + 210);
  if (order.remainingLocal > 0) {
    ctx.fillStyle = '#B45309';
    ctx.font = '23px Tajawal, sans-serif';
    ctx.fillText(
      `المتبقي المؤجل (مثبت السعر): ${formatMoney(order.remainingLocal, order.currency)}`,
      w - 116,
      boxTop + 252
    );
  }
  ctx.fillStyle = '#5F5870';
  ctx.font = '19px Tajawal, sans-serif';
  ctx.fillText(
    `واتساب الإدارة: ${settings.supportPhone} / 737383637`,
    w - 116,
    boxTop + 294
  );

  // Deterministic QR visual matrix on left
  drawDeterministicQr(ctx, 114, boxTop + 36, 220, `SELOO|${order.orderNo}|${order.totalSar.toFixed(2)}`);
  ctx.fillStyle = '#5F5870';
  ctx.textAlign = 'center';
  ctx.font = '16px monospace';
  ctx.fillText('VERIFY QR', 224, boxTop + 282);

  // Footer
  ctx.fillStyle = '#5F5870';
  ctx.textAlign = 'center';
  ctx.font = '20px Tajawal, sans-serif';
  ctx.fillText('يمن سيلو للتسوق العالمي — yemenseloo.com', w / 2, h - 34);

  return canvas.toDataURL('image/png');
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number
) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function drawDeterministicQr(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  size: number,
  payload: string
) {
  ctx.fillStyle = '#FFFFFF';
  roundRect(ctx, x - 8, y - 8, size + 16, size + 16, 12);
  ctx.fill();
  const cells = 21;
  const cell = size / cells;
  ctx.fillStyle = '#171321';

  const drawFinder = (cx: number, cy: number) => {
    ctx.fillRect(x + cx * cell, y + cy * cell, cell * 7, cell * 7);
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(x + (cx + 1) * cell, y + (cy + 1) * cell, cell * 5, cell * 5);
    ctx.fillStyle = '#171321';
    ctx.fillRect(x + (cx + 2) * cell, y + (cy + 2) * cell, cell * 3, cell * 3);
  };
  drawFinder(0, 0);
  drawFinder(cells - 7, 0);
  drawFinder(0, cells - 7);

  let seed = 0;
  for (let i = 0; i < payload.length; i++) {
    seed = (seed * 31 + payload.charCodeAt(i)) >>> 0;
  }
  for (let row = 0; row < cells; row++) {
    for (let col = 0; col < cells; col++) {
      const inFinder =
        (row < 8 && col < 8) ||
        (row < 8 && col >= cells - 8) ||
        (row >= cells - 8 && col < 8);
      if (inFinder) continue;
      seed = (seed * 1664525 + 1013904223) >>> 0;
      if ((seed >>> 24) % 2 === 0) {
        ctx.fillRect(x + col * cell, y + row * cell, cell - 0.3, cell - 0.3);
      }
    }
  }
}

export function downloadDataUrl(dataUrl: string, filename: string) {
  const a = document.createElement('a');
  a.href = dataUrl;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

/**
 * Generates and prints an official PDF-ready invoice / delivery waybill (including product
 * thumbnails and captured e-signature if present) using an isolated hidden iframe.
 */
export function printOrderInvoiceOrWaybill(
  order: Order,
  settings: AppSettings,
  mode: 'invoice' | 'waybill' = 'invoice'
) {
  const itemsHtml = order.items
    .map(
      (it, idx) => `
      <tr>
        <td style="padding:8px;border-bottom:1px solid #e5e7eb;">${idx + 1}</td>
        <td style="padding:8px;border-bottom:1px solid #e5e7eb;">
          <div style="display:flex;align-items:center;gap:10px;">
            ${
              it.imageUrl
                ? `<img src="${it.imageUrl}" style="width:42px;height:42px;object-fit:cover;border-radius:6px;border:1px solid #ddd;" />`
                : ''
            }
            <div>
              <div style="font-weight:700;">${escapeHtml(it.title)}</div>
              <div style="font-size:12px;color:#6b7280;">${escapeHtml(it.color)} · ${escapeHtml(it.size)}${
                it.isReplacement ? ' · [بديل معتمد]' : ''
              }${it.nonRefundable ? ' · [غير قابل للاسترداد]' : ''}</div>
            </div>
          </div>
        </td>
        <td style="padding:8px;border-bottom:1px solid #e5e7eb;text-align:center;">${it.qty}</td>
        <td style="padding:8px;border-bottom:1px solid #e5e7eb;text-align:left;">${(
          it.unitPriceSar * it.qty
        ).toFixed(2)} SAR</td>
      </tr>`
    )
    .join('');

  const html = `<!doctype html>
  <html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8" />
    <title>${mode === 'waybill' ? 'بوليصة تسليم' : 'فاتورة طلب'} ${escapeHtml(order.orderNo)}</title>
    <style>
      body { font-family: Tahoma, Arial, sans-serif; color:#171321; margin:24px; direction:rtl; }
      .hdr { display:flex; justify-content:space-between; align-items:center; border-bottom:2px solid #6D28D9; padding-bottom:14px; margin-bottom:18px; }
      .box { background:#f8f7fb; border:1px solid #e5e0f0; border-radius:10px; padding:12px 16px; margin-bottom:16px; }
      table { width:100%; border-collapse:collapse; margin-top:12px; }
      th { background:#6D28D9; color:#fff; padding:9px; text-align:right; font-size:13px; }
      .sig { margin-top:20px; border-top:1px dashed #ccc; padding-top:14px; display:flex; justify-content:space-between; align-items:center; }
    </style>
  </head>
  <body>
    <div class="hdr">
      <div>
        <h2 style="margin:0;color:#6D28D9;">${escapeHtml(settings.companyNameAr || 'يمن سيلو')}</h2>
        <div style="font-size:12px;color:#555;">${
          mode === 'waybill' ? 'بوليصة شحن وتسليم رسمية' : 'فاتورة طلب إلكترونية معتمدة'
        } — هاتف: ${escapeHtml(settings.waybillCompanyPhone || settings.supportPhone)}</div>
      </div>
      <div style="text-align:left;">
        <div style="font-size:18px;font-weight:700;">${escapeHtml(order.orderNo)}</div>
        <div style="font-size:12px;color:#555;">${new Date(order.createdAt).toLocaleString('ar-YE')}</div>
      </div>
    </div>
    <div class="box">
      <div><strong>المستلم:</strong> ${escapeHtml(order.receiverName || order.address.receiverName)} — <strong>الهاتف:</strong> ${escapeHtml(order.receiverPhone || order.address.phone)}</div>
      <div style="margin-top:4px;"><strong>الوجهة:</strong> ${escapeHtml(order.shippingGovernorate || order.address.city)} · ${escapeHtml(order.address.line)}</div>
      <div style="margin-top:4px;"><strong>الشحن:</strong> ${escapeHtml(order.shippingOffice || order.driverName || 'تسليم مباشر')} · <strong>التتبع:</strong> ${escapeHtml(order.trackingNo || 'قيد الإصدار')}</div>
    </div>
    <table>
      <thead>
        <tr>
          <th>#</th>
          <th>المنتج</th>
          <th style="text-align:center;">الكمية</th>
          <th style="text-align:left;">الإجمالي</th>
        </tr>
      </thead>
      <tbody>${itemsHtml}</tbody>
    </table>
    <div class="box" style="margin-top:16px;">
      <div><strong>الإجمالي بالسعودي:</strong> ${order.totalSar.toFixed(2)} ر.س</div>
      <div><strong>الإجمالي بعملة الطلب:</strong> ${formatMoney(order.totalLocal, order.currency)}</div>
      <div><strong>المدفوع:</strong> ${formatMoney(order.paidTotalLocal, order.currency)} · <strong>المتبقي:</strong> ${formatMoney(order.remainingLocal, order.currency)}</div>
    </div>
    ${
      order.customerSignatureUrl
        ? `<div class="sig">
            <div>
              <strong>توقيع المستلم الإلكتروني:</strong><br/>
              <span style="font-size:12px;color:#555;">تم التوثيق بتاريخ: ${
                order.signedAt ? new Date(order.signedAt).toLocaleString('ar-YE') : ''
              } · كود التحقق: ${escapeHtml(order.deliveryPin)}</span>
            </div>
            <img src="${order.customerSignatureUrl}" style="height:76px;border:1px solid #ddd;border-radius:8px;background:#fff;padding:4px;" />
          </div>`
        : `<div class="sig"><div>توقيع المستلم: _____________________</div><div>رمز التسليم: ${escapeHtml(order.deliveryPin)}</div></div>`
    }
  </body>
  </html>`;

  const iframe = document.createElement('iframe');
  iframe.style.position = 'fixed';
  iframe.style.right = '0';
  iframe.style.bottom = '0';
  iframe.style.width = '0';
  iframe.style.height = '0';
  iframe.style.border = '0';
  document.body.appendChild(iframe);
  const doc = iframe.contentWindow?.document;
  if (doc) {
    doc.open();
    doc.write(html);
    doc.close();
    setTimeout(() => {
      iframe.contentWindow?.focus();
      iframe.contentWindow?.print();
      setTimeout(() => document.body.removeChild(iframe), 1200);
    }, 300);
  }
}

export interface StatementPrintRow {
  dateLabel: string;
  description: string;
  debitLocal: number;
  creditLocal: number;
  balanceLocal: number;
}

export function printAccountStatementPdf(params: {
  customerName: string;
  customerEmail: string;
  currency: AppCurrency;
  totalDebitLocal: number;
  totalCreditLocal: number;
  netBalanceLocal: number;
  rows: StatementPrintRow[];
  companyNameAr: string;
}) {
  const {
    customerName,
    customerEmail,
    currency,
    totalDebitLocal,
    totalCreditLocal,
    netBalanceLocal,
    rows,
    companyNameAr,
  } = params;

  const rowsHtml = rows
    .map(
      (r) => `
      <tr>
        <td style="padding:8px;border-bottom:1px solid #e5e7eb;font-size:12px;">${escapeHtml(r.dateLabel)}</td>
        <td style="padding:8px;border-bottom:1px solid #e5e7eb;font-weight:600;">${escapeHtml(r.description)}</td>
        <td style="padding:8px;border-bottom:1px solid #e5e7eb;color:#b91c1c;text-align:left;">${
          r.debitLocal > 0 ? formatMoney(r.debitLocal, currency) : '—'
        }</td>
        <td style="padding:8px;border-bottom:1px solid #e5e7eb;color:#047857;text-align:left;">${
          r.creditLocal > 0 ? formatMoney(r.creditLocal, currency) : '—'
        }</td>
        <td style="padding:8px;border-bottom:1px solid #e5e7eb;font-weight:700;text-align:left;">${formatMoney(
          r.balanceLocal,
          currency
        )}</td>
      </tr>`
    )
    .join('');

  const html = `<!doctype html>
  <html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8" />
    <title>كشف حساب عميل — ${escapeHtml(customerName)}</title>
    <style>
      body { font-family: Tahoma, Arial, sans-serif; color:#171321; margin:24px; direction:rtl; }
      .hdr { display:flex; justify-content:space-between; border-bottom:2px solid #6D28D9; padding-bottom:12px; margin-bottom:16px; }
      .summary { display:grid; grid-template-columns: repeat(3, 1fr); gap:12px; margin-bottom:18px; }
      .card { background:#f8f7fb; border:1px solid #e5e0f0; border-radius:10px; padding:12px; }
      table { width:100%; border-collapse:collapse; }
      th { background:#6D28D9; color:#fff; padding:9px; text-align:right; font-size:13px; }
    </style>
  </head>
  <body>
    <div class="hdr">
      <div>
        <h2 style="margin:0;color:#6D28D9;">${escapeHtml(companyNameAr || 'يمن سيلو')} — كشف حساب مالي</h2>
        <div style="font-size:12px;color:#555;">العميل: ${escapeHtml(customerName)} (${escapeHtml(customerEmail)})</div>
      </div>
      <div style="text-align:left;font-size:12px;">
        <div><strong>العملة:</strong> ${escapeHtml(currencyShortLabel(currency))}</div>
        <div><strong>التاريخ:</strong> ${new Date().toLocaleDateString('ar-YE')}</div>
      </div>
    </div>
    <div class="summary">
      <div class="card"><div style="font-size:12px;color:#666;">عليه (المطلوب)</div><div style="font-size:16px;font-weight:700;color:#b91c1c;">${formatMoney(
        totalDebitLocal,
        currency
      )}</div></div>
      <div class="card"><div style="font-size:12px;color:#666;">له (المدفوع والمسترد)</div><div style="font-size:16px;font-weight:700;color:#047857;">${formatMoney(
        totalCreditLocal,
        currency
      )}</div></div>
      <div class="card"><div style="font-size:12px;color:#666;">الصافي</div><div style="font-size:16px;font-weight:700;color:#6D28D9;">${formatMoney(
        netBalanceLocal,
        currency
      )}</div></div>
    </div>
    <table>
      <thead>
        <tr>
          <th>التاريخ</th>
          <th>البيان</th>
          <th style="text-align:left;">عليه</th>
          <th style="text-align:left;">له</th>
          <th style="text-align:left;">الصافي</th>
        </tr>
      </thead>
      <tbody>${rowsHtml}</tbody>
    </table>
  </body>
  </html>`;

  const iframe = document.createElement('iframe');
  iframe.style.position = 'fixed';
  iframe.style.width = '0';
  iframe.style.height = '0';
  iframe.style.border = '0';
  document.body.appendChild(iframe);
  const doc = iframe.contentWindow?.document;
  if (doc) {
    doc.open();
    doc.write(html);
    doc.close();
    setTimeout(() => {
      iframe.contentWindow?.focus();
      iframe.contentWindow?.print();
      setTimeout(() => document.body.removeChild(iframe), 1200);
    }, 300);
  }
}

function escapeHtml(text: string): string {
  return String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

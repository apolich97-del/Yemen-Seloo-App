/**
 * Yemen Seloo — Overlay JS (نسخة الزحف الكاملة)
 * 1) زر "أضف إلى سلة سيلو" في صفحات المنتجات (تصفح عادي)
 * 2) زر "استيراد سلة شي إن" في صفحة السلة — زحف بالنقر: منتج منتج
 * الجسر: flutter_inappwebview.callHandler('selooBridge', {action, payload})
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var ACTION_ADD = 'addToCart';
  var ACTION_CRAWL_START = 'startClickCrawl';
  var ACTION_CRAWL_FAIL = 'crawlStepFailed';
  var STORE_KEY = 'seloo_crawl_items';
  var UNTIL_KEY = 'seloo_crawl_until';

  function q(s) { try { return document.querySelector(s); } catch (e) { return null; } }
  function qa(s) { try { return Array.prototype.slice.call(document.querySelectorAll(s)); } catch (e) { return []; } }
  function txt(el) { return (el && (el.innerText || el.textContent) ? (el.innerText || el.textContent) : '').replace(/\s+/g, ' ').trim(); }

  function parsePrice(raw) {
    if (!raw) return null;
    var s = String(raw).replace(/[\u0660-\u0669]/g, function (d) {
      return String.fromCharCode(d.charCodeAt(0) - 0x0660 + 48);
    });
    var m = s.replace(/[\u066B\u066C,٬\s]/g, '').match(/\d+(\.\d+)?/);
    if (!m) return null;
    var n = parseFloat(m[0]);
    return (isFinite(n) && n > 0) ? n : null;
  }

  function toast(message) {
    var box = document.getElementById('seloo-toast');
    if (!box) {
      box = document.createElement('div');
      box.id = 'seloo-toast';
      box.style.cssText = 'position:fixed;top:16px;left:12px;right:12px;z-index:2147483647;padding:12px;border-radius:10px;background:#fff;color:#333;font-size:14px;text-align:center;box-shadow:0 3px 14px rgba(0,0,0,.2)';
      document.documentElement.appendChild(box);
    }
    box.textContent = message;
    setTimeout(function () { if (box && box.parentNode) box.parentNode.removeChild(box); }, 3500);
  }

  function callBridge(action, payload) {
    return new Promise(function (resolve) {
      if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
        try {
          window.flutter_inappwebview.callHandler(BRIDGE, { action: action, payload: payload })
            .then(function (r) { resolve(r || { status: 'ok' }); })
            .catch(function () { resolve({ status: 'error' }); });
          return;
        } catch (e) {}
      }
      resolve({ status: 'offline' });
    });
  }

  // ═══════════════════════════════════════════════
  // حالة الزحف (sessionStorage يبقى عبر تنقلات الصفحة)
  // ═══════════════════════════════════════════════
  function crawlActive() {
    try {
      var until = parseInt(sessionStorage.getItem(UNTIL_KEY) || '0', 10);
      if (Date.now() < until) return true;
      sessionStorage.removeItem(UNTIL_KEY);
    } catch (e) {}
    return false;
  }

  function readCrawlItems() {
    try { return JSON.parse(sessionStorage.getItem(STORE_KEY) || '[]') || []; }
    catch (e) { return []; }
  }

  function saveCrawlItems(items) {
    try { sessionStorage.setItem(STORE_KEY, JSON.stringify(items)); } catch (e) {}
  }

  // ═══════════════════════════════════════════════
  // قراءة صفحة المنتج الحالية → payload مطابق
  // لـ SheinDraft.fromBridgePayload حرفياً
  // ═══════════════════════════════════════════════
  function readCurrentProduct() {
    var m = window.location.href.match(/-p-(\d+)\.html/);
    if (!m) return null;

    var goodsId = m[1];

    var title = '';
    var h1 = q('h1');
    if (h1) title = txt(h1);
    if (!title) { var og = q('meta[property="og:title"]'); if (og) title = (og.content || '').trim(); }
    if (!title) title = (document.title || '').trim();
    title = title.slice(0, 300);
    if (!title) title = 'منتج SHEIN #' + goodsId;

    var price = null;
    var priceEls = qa('[class*="price"], [class*="Price"]');
    for (var i = 0; i < priceEls.length; i++) {
      var p = parsePrice(txt(priceEls[i]));
      if (p) { price = p; break; }
    }
    if (!price) {
      var pm = q('meta[property="product:price:amount"], meta[property="og:price:amount"]');
      if (pm) price = parsePrice(pm.content);
    }
    if (!price) price = 0.01; // تعذّر قراءة السعر — يُعدّل يدوياً في السلة

    var imageUrl = '';
    var img = q('.crop-image-container img, .product-intro__main-image img, [class*="main-image"] img, [class*="goods-img"] img');
    if (img) imageUrl = img.getAttribute('src') || img.getAttribute('data-src') || '';
    if (!imageUrl) { var ogi = q('meta[property="og:image"]'); if (ogi) imageUrl = ogi.content || ''; }
    if (imageUrl.indexOf('//') === 0) imageUrl = 'https:' + imageUrl;

    var size = '';
    var sizeEl = q('.product-intro__size-choose .selected, [class*="size"] [class*="selected"], [class*="size"] [class*="active"]');
    if (sizeEl) size = (sizeEl.getAttribute('title') || txt(sizeEl)).slice(0, 30);

    var color = '';
    var colorEl = q('.product-intro__color-choose .selected, [class*="color"] [class*="selected"], [class*="color"] [class*="active"]');
    if (colorEl) color = (colorEl.getAttribute('title') || txt(colorEl)).slice(0, 30);

    return {
      goodsId: goodsId,
      productUrl: window.location.href,
      title: title,
      imageUrl: imageUrl,
      sourcePrice: price,
      sourceCurrency: 'SAR',
      quantity: 1,
      color: color,
      size: size,
      options: {},
      sourceStore: 'SHEIN',
      sku: '',
      variantId: '',
      source: 'webview-product'
    };
  }

  // ═══════════════════════════════════════════════
  // دوال الزحف التي تستدعيها شاشة WebView
  // ═══════════════════════════════════════════════
  window.__selooAddCurrentProduct = function () {
    var p = readCurrentProduct();
    if (p) {
      callBridge(ACTION_ADD, p);
      if (crawlActive()) toast('✓ أُضيف: ' + p.title.slice(0, 40));
      return true;
    }
    callBridge(ACTION_CRAWL_FAIL, {});
    return false;
  };

  window.__selooClickNext = function (i) {
    var items = readCrawlItems();
    var it = items && items[i];
    if (it && it.url) {
      try { window.location.href = it.url; return; } catch (e) {}
    }
    // انتهت القائمة أو ضاع الكشف — ننهي عبر فشل الخطوة
    try { sessionStorage.removeItem(UNTIL_KEY); } catch (e) {}
    callBridge(ACTION_CRAWL_FAIL, {});
  };

  // ═══════════════════════════════════════════════
  // صفحة سلة شي إن: زر بدء الاستيراد بالنقر
  // ═══════════════════════════════════════════════
  function isCartPage() {
    return /\/cart(\/|\?|$)/i.test(window.location.pathname);
  }

  function collectCartItems() {
    var seen = {};
    var list = [];

    function addAnchor(a) {
      var href = a.getAttribute('href') || '';
      var m = href.match(/-p-(\d+)\.html/);
      if (!m) return;
      var id = m[1];
      if (seen[id]) return;
      seen[id] = true;
      var abs = href;
      if (!/^https?:/i.test(abs)) {
        try { abs = new URL(abs, window.location.origin).href; }
        catch (e) { abs = 'https://ar.shein.com/-p-' + id + '.html'; }
      }
      list.push({ goodsId: id, url: abs });
    }

    var scoped = 0;
    qa('[class*="cart-item"], [class*="CartItem"], [class*="cartItem"]').forEach(function (w) {
      if (!w.querySelectorAll) return;
      var anchors = Array.prototype.slice.call(w.querySelectorAll('a[href*="-p-"]'));
      anchors.forEach(addAnchor);
      scoped += anchors.length;
    });

    if (!scoped) qa('a[href*="-p-"]').forEach(addAnchor);

    return list;
  }

  function buildCartButton() {
    var id = 'seloo-crawl-btn';
    var btn = document.getElementById(id);
    var count = collectCartItems().length;

    if (btn) {
      btn.textContent = '📥 استيراد سلة شي إن إلى سيلو' + (count ? ' (' + count + ')' : '');
      return;
    }

    btn = document.createElement('button');
    btn.id = id;
    btn.type = 'button';
    btn.style.cssText = 'position:fixed;bottom:18px;left:12px;right:12px;z-index:2147483000;background:#10b981;color:#fff;border:0;border-radius:12px;min-height:52px;font-size:16px;font-weight:700;box-shadow:0 4px 16px rgba(0,0,0,.25);cursor:pointer';
    btn.textContent = '📥 استيراد سلة شي إن إلى سيلو' + (count ? ' (' + count + ')' : '');

    btn.addEventListener('click', function () {
      var items = collectCartItems();
      if (!items.length) {
        toast('لم أجد منتجات في سلة شي إن — افتح السلة وانتظر تحميلها.');
        return;
      }
      saveCrawlItems(items);
      try {
        sessionStorage.setItem(UNTIL_KEY, String(Date.now() + items.length * 20000 + 30000));
      } catch (e) {}
      callBridge(ACTION_CRAWL_START, { total: items.length });
      toast('بدأ استيراد ' + items.length + ' منتج — لا تغلق هذه الشاشة.');
      setTimeout(function () { window.location.href = items[0].url; }, 500);
    });

    document.body.appendChild(btn);
  }

  function removeCartButton() {
    var b = document.getElementById('seloo-crawl-btn');
    if (b) b.parentNode.removeChild(b);
  }

  // ═══════════════════════════════════════════════
  // زر المنتج المفرد (تصفح عادي)
  // ═══════════════════════════════════════════════
  function buildFab() {
    if (document.getElementById('seloo-fab')) return;

    var fab = document.createElement('button');
    fab.id = 'seloo-fab';
    fab.type = 'button';
    fab.textContent = '🛒 أضف إلى سلة سيلو';
    fab.style.cssText = 'position:fixed;bottom:100px;right:16px;z-index:2147483000;background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:14px 20px;font-size:15px;font-weight:700;box-shadow:0 6px 20px rgba(124,58,237,.5);cursor:pointer';

    fab.addEventListener('click', function () {
      if (fab.disabled) return;
      var p = readCurrentProduct();
      if (!p) { toast('تعذر قراءة بيانات المنتج.'); return; }
      fab.disabled = true;
      fab.textContent = 'جارٍ الإضافة...';
      callBridge(ACTION_ADD, p).then(function (r) {
        var st = r && r.status ? r.status : 'ok';
        if (st === 'offline') {
          toast('تعذر الاتصال بالتطبيق. حاول مجددًا.');
        } else if (st === 'invalid' || st === 'error') {
          toast((r && r.message) ? r.message : 'فشلت الإضافة.');
        } else {
          toast('✓ أُضيف المنتج إلى سلة سيلو');
        }
        fab.disabled = false;
        fab.textContent = '🛒 أضف إلى سلة سيلو';
      });
    });

    document.body.appendChild(fab);
  }

  function removeFab() {
    var f = document.getElementById('seloo-fab');
    if (f) f.parentNode.removeChild(f);
  }

  // ═══════════════════════════════════════════════
  // المزامنة (صفحات شي إن تتغير بلا إعادة تحميل)
  // ═══════════════════════════════════════════════
  function sync() {
    var product = /-p-\d+\.html/i.test(window.location.href);
    if (product) {
      if (crawlActive()) { removeFab(); return; } // أثناء الزحف الشاشة تضيف تلقائياً
      buildFab();
      removeCartButton();
      return;
    }
    removeFab();
    if (isCartPage()) {
      buildCartButton();
    } else {
      removeCartButton();
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { setTimeout(sync, 500); });
  } else {
    setTimeout(sync, 500);
  }

  setInterval(function () { sync(); }, 1500);
})();

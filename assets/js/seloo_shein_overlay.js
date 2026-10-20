/**
 * Yemen Seloo — Overlay JS
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var FAB_ID = 'seloo-fab';
  var TOAST_ID = 'seloo-toast';
  var sending = false;

  function log() {
    try { console.log.apply(console, ['[seloo]'].concat(Array.prototype.slice.call(arguments))); } catch (e) {}
  }

  function q(s) { try { return document.querySelector(s); } catch (e) { return null; } }
  function qa(s) { try { return Array.prototype.slice.call(document.querySelectorAll(s)); } catch (e) { return []; } }

  function visible(el) {
    if (!el) return false;
    try { var r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0; } catch (e) { return false; }
  }

  function goodsIdFromUrl() {
    var m = location.href.match(/-p-(\d{5,})\.html/i);
    return m ? m[1] : null;
  }

  function text(sel) { var el = q(sel); return el ? (el.textContent || '').trim() : null; }
  function attr(sel, name) { var el = q(sel); return el ? (el.getAttribute(name) || '').trim() : null; }

  function parsePrice(raw) {
    if (!raw) return null;
    var s = String(raw).replace(/[\u0660-\u0669]/g, function (d) { return String.fromCharCode(d.charCodeAt(0) - 0x0660 + 48); });
    var m = s.replace(/[٬,\s]/g, '').match(/\d+(\.\d+)?/);
    if (!m) return null;
    var n = parseFloat(m[0]);
    return (isFinite(n) && n > 0) ? n : null;
  }

  function getProductImage() {
    var selectors = ['.product-intro__main-image img','.crop-image-container img','[class*="productIntro"] img','.swiper-slide-active img','.gallery-top img','img[class*="main-image"]'];
    function normalize(src) { if (!src) return ''; src = String(src).trim(); if (src.indexOf('//') === 0) src = 'https:' + src; if (src.indexOf('http') !== 0) return ''; return src; }
    for (var i = 0; i < selectors.length; i++) {
      var imgs = qa(selectors[i]);
      for (var j = 0; j < imgs.length; j++) {
        var el = imgs[j];
        var candidates = [el.getAttribute('data-src'),el.getAttribute('src'),el.currentSrc];
        for (var c = 0; c < candidates.length; c++) {
          var src = normalize(candidates[c]);
          if (src && src.toLowerCase().indexOf('logo') === -1 && src.toLowerCase().indexOf('svg') === -1) return src.split('?')[0];
        }
      }
    }
    var og = attr('meta[property="og:image"]', 'content');
    return og ? normalize(og) : '';
  }

  function readSelectedVariants() {
    var color = '', size = '', options = {};
    var colorEl = q('.product-intro__color-choose .selected') || q('[class*="color"] [class*="active"]');
    if (colorEl) color = colorEl.getAttribute('title') || colorEl.innerText.trim();
    var sizeEl = q('.product-intro__size-choose .selected') || q('[class*="size"] [class*="active"]');
    if (sizeEl) size = sizeEl.innerText.trim();
    var groups = qa('.product-intro__attr-choose');
    groups.forEach(function (g) {
      var k = g.querySelector('.product-intro__attr-name'), v = g.querySelector('.selected');
      if (k && v) options[k.innerText.trim()] = v.innerText.trim();
    });
    return { color: color, size: size, options: options };
  }

  function collectProduct() {
    var goodsId = goodsIdFromUrl();
    if (!goodsId) return null;
    var variants = readSelectedVariants();
    var title = text('h1') || attr('meta[property="og:title"]', 'content');
    var price = parsePrice(text('[class*="price"]')) || parsePrice(attr('meta[property="product:price:amount"]', 'content'));
    if (!title || !price) return null;
    return { goodsId: String(goodsId), productUrl: location.href.split('#')[0], title: title, imageUrl: getProductImage(), price: price, currency: 'SAR', color: variants.color, size: variants.size, options: variants.options, quantity: 1, source: 'merged' };
  }

  function ensureStyle() {
    if (document.getElementById('seloo-style')) return;
    var s = document.createElement('style');
    s.id = 'seloo-style';
    s.textContent = '#' + FAB_ID + '{position:fixed;bottom:100px;right:16px;z-index:2147483000;background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:14px 20px;font-size:15px;font-weight:700;box-shadow:0 6px 20px rgba(124,58,237,.5)}';
    document.head.appendChild(s);
  }

  function toast(msg) {
    var el = document.getElementById(TOAST_ID);
    if (!el) { el = document.createElement('div'); el.id = TOAST_ID; document.body.appendChild(el); }
    el.textContent = msg;
    el.style.cssText = 'position:fixed;bottom:160px;left:50%;transform:translateX(-50%);z-index:2147483000;background:#111827;color:#fff;padding:12px 18px;border-radius:10px;font-size:14px;text-align:center;direction:rtl';
    clearTimeout(el.__t);
    el.__t = setTimeout(function () { el.style.display = 'none'; }, 3500);
  }

  function callBridge(action, payload) {
    return new Promise(function (resolve) {
      if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) { resolve({ status: 'offline' }); return; }
      try {
        window.flutter_inappwebview.callHandler(BRIDGE, { action: action, payload: payload }).then(function (r) { resolve(r || { status: 'ok' }); });
      } catch (e) { resolve({ status: 'error' }); }
    });
  }

  function buildFab() {
    ensureStyle();
    if (document.getElementById(FAB_ID)) return;
    var fab = document.createElement('button');
    fab.id = FAB_ID; fab.type = 'button'; fab.textContent = '🛒 أضف إلى سلة سيلو';
    fab.addEventListener('click', function () {
      if (sending) return;
      var product = collectProduct();
      if (!product) { toast('تعذّر قراءة المنتج'); return; }
      sending = true; fab.disabled = true; fab.textContent = 'جارٍ الإضافة…';
      setTimeout(function () {
        callBridge('addToCart', product).then(function (r) {
          sending = false; fab.disabled = false; fab.textContent = '🛒 أضف إلى سلة سيلو';
          if (r && r.status === 'ok') { toast('تمت الإضافة ✓'); }
          else { toast(r && r.message ? r.message : 'فشلت الإضافة'); }
        });
      }, 500);
    });
    document.body.appendChild(fab);
  }

  function removeFab() { var f = document.getElementById(FAB_ID); if (f) f.remove(); }

  function sync() {
    if (!goodsIdFromUrl()) { removeFab(); return; }
    buildFab();
  }

  var lastUrl = location.href;
  setInterval(function () { if (location.href !== lastUrl) { lastUrl = location.href; setTimeout(sync, 800); } }, 2000);

  function scheduleSync() { setTimeout(sync, 1200); }
  
  function boot() {
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', scheduleSync); }
    else { scheduleSync(); }
  }
  boot();

  /* =========================================================
   * ⭐ [الحل B] استيراد سلة SHEIN كاملة + التشخيص
   * ========================================================= */
  (function () {
    if (window.__selooImportReady) return;
    window.__selooImportReady = true;

    function selooSend(action, payload) {
      try { window.flutter_inappwebview.callHandler(BRIDGE, { action: action, payload: payload }); return true; } catch (e) { return false; }
    }

    function txt(el) { return (el && el.textContent ? el.textContent : '').replace(/\s+/g, ' ').trim(); }

    function extractPrice(scope) {
      var els = scope.querySelectorAll('[class*="price"], [class*="Price"]');
      for (var i = 0; i < els.length; i++) {
        var m = txt(els[i]).match(/[\d]+[.,]?[\d]*/);
        if (m) { var v = parseFloat(m[0].replace(/,/g, '')); if (v >= 0.5 && v <= 100000) return v; }
      }
      return null;
    }

    function extractCartItems() {
      var items = [];
      var wrappers = document.querySelectorAll('[class*="cart-item"], [class*="cartItem"], [class*="CartItem"], [class*="cartItem___"]');
      
      wrappers.forEach(function (w) {
        var link = w.querySelector('a[href*="goods_id"], a[href*="-p-"]');
        var href = link ? link.getAttribute('href') : '';
        var gid = (href.match(/goods_id[=%\/]?(\d+)/i) || href.match(/-p-(\d+)/) || [])[1];
        if (!gid) return;
        
        var nameEl = w.querySelector('[class*="name"], [class*="title"]');
        var imgEl = w.querySelector('img');
        
        // ⭐ التشخيص: تخزين كود HTML الأول
        var rawHtml = w.outerHTML ? w.outerHTML.substring(0, 500) : 'No HTML'; 

        items.push({
          goodsId: gid,
          title: txt(nameEl) || 'منتج SHEIN',
          price: extractPrice(w),
          image: imgEl ? (imgEl.getAttribute('src') || '') : '',
          quantity: 1,
          url: href,
          html: rawHtml // نمرر الكود للـ Flutter
        });
      });
      return items;
    }

    function toPayload(item) {
      var digits = String(item.goodsId || '').replace(/\D/g, '');
      return {
        goodsId: digits,
        productUrl: item.url || ('https://m.shein.com/ar/-p-' + digits + '.html'),
        title: item.title,
        imageUrl: item.image,
        sourcePrice: item.price || 0.01,
        sourceCurrency: 'SAR',
        quantity: 1,
        sourceStore: 'SHEIN', source: 'cart_share'
      };
    }

    function injectImportFab() {
      if (location.pathname.indexOf('cart') === -1) return;
      if (document.getElementById('seloo-import-fab')) return;
      
      var fab = document.createElement('div');
      fab.id = 'seloo-import-fab';
      fab.textContent = '📤 إرسال السلة إلى يمن سيلو';
      fab.style.cssText = 'position:fixed;bottom:24px;left:16px;right:16px;z-index:2147483647;background:#7c3aed;color:#fff;padding:14px;border-radius:14px;font-size:16px;text-align:center;';
      
      fab.onclick = function () {
        var items = extractCartItems();
        if (items.length === 0) { alert('لم يتم العثور على منتجات'); return; }
        
        // ⭐ إرسال التشخيص
        if (items[0].html) {
          selooSend('debugHtml', { html: items[0].html });
        }

        var i = 0;
        function next() {
          if (i >= items.length) { selooSend('importComplete', { count: items.length, lines: items.map(toPayload) }); return; }
          selooSend('addToCart', toPayload(items[i])); i++; setTimeout(next, 200);
        }
        next();
      };
      document.body.appendChild(fab);
    }

    setTimeout(injectImportFab, 2000);
  })();
})();

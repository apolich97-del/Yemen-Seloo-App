/**
 * Yemen Seloo — أبسط نسخة ممكنة.
 * لا يتحقق من نجاح SHEIN. فقط ينقر الزر ويرسل مباشرة.
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
    try {
      var r = el.getBoundingClientRect();
      return r.width > 0 && r.height > 0;
    } catch (e) { return false; }
  }

  function goodsIdFromUrl() {
    var m = location.href.match(/-p-(\d{5,})\.html/i);
    return m ? m[1] : null;
  }

  function text(sel) {
    var el = q(sel);
    return el ? (el.textContent || '').trim() : null;
  }
  function attr(sel, name) {
    var el = q(sel);
    return el ? (el.getAttribute(name) || '').trim() : null;
  }

  function parsePrice(raw) {
    if (!raw) return null;
    var s = String(raw).replace(/[\u0660-\u0669]/g, function (d) {
      return String.fromCharCode(d.charCodeAt(0) - 0x0660 + 48);
    });
    var m = s.replace(/[٬,\s]/g, '').match(/\d+(\.\d+)?/);
    if (!m) return null;
    var n = parseFloat(m[0]);
    return (isFinite(n) && n > 0) ? n : null;
  }

  function findSheinButton() {
    var all = qa('button, [role="button"], a, div[class*="btn"]');
    for (var i = 0; i < all.length; i++) {
      var b = all[i];
      if (!visible(b)) continue;
      var t = (b.textContent || '').trim();
      if (!t || t.length > 60) continue;
      if (
        t.indexOf('أضف إلى عربة التسوق') !== -1 ||
        t.indexOf('أضف إلى السلة') !== -1 ||
        t.indexOf('أضف للسلة') !== -1 ||
        t.indexOf('أضف إلى الحقيبة') !== -1 ||
        t.indexOf('أضف للحقيبة') !== -1 ||
        t.toLowerCase().indexOf('add to cart') !== -1 ||
        t.toLowerCase().indexOf('add to bag') !== -1
      ) {
        log('زر SHEIN:', t);
        return b;
      }
    }
    return null;
  }

  function collectProduct() {
    var goodsId = goodsIdFromUrl();
    if (!goodsId) return null;
    var title = text('h1') || attr('meta[property="og:title"]', 'content');
    var price = parsePrice(text('[class*="price"]')) ||
                parsePrice(attr('meta[property="product:price:amount"]', 'content'));
    if (!title || !price) return null;
    var imageUrl = attr('meta[property="og:image"]', 'content') || '';
    return {
      goodsId: String(goodsId),
      productUrl: location.href.split('#')[0],
      title: title,
      imageUrl: imageUrl,
      price: price,
      currency: 'SAR',
      color: '',
      size: '',
      quantity: 1,
      sku: '',
      variantId: '',
      source: 'merged'
    };
  }

  function ensureStyle() {
    if (document.getElementById('seloo-style')) return;
    var s = document.createElement('style');
    s.id = 'seloo-style';
    s.textContent =
      '#' + FAB_ID + '{position:fixed;bottom:100px;right:16px;z-index:2147483000;' +
      'background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:14px 20px;' +
      'font-size:15px;font-weight:700;font-family:inherit;direction:rtl;cursor:pointer;' +
      'box-shadow:0 6px 20px rgba(124,58,237,.5)}' +
      '#' + FAB_ID + '[disabled]{opacity:.6}' +
      '#' + TOAST_ID + '{position:fixed;bottom:160px;left:50%;transform:translateX(-50%);' +
      'z-index:2147483000;background:#111827;color:#fff;padding:12px 18px;border-radius:10px;' +
      'font-size:14px;max-width:88vw;text-align:center;direction:rtl}';
    document.head.appendChild(s);
  }

  function toast(msg) {
    var el = document.getElementById(TOAST_ID);
    if (!el) {
      el = document.createElement('div');
      el.id = TOAST_ID;
      document.body.appendChild(el);
    }
    el.textContent = msg;
    el.style.display = 'block';
    clearTimeout(el.__t);
    el.__t = setTimeout(function () { el.style.display = 'none'; }, 3500);
  }

  function callBridge(action, payload) {
    return new Promise(function (resolve) {
      if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) {
        resolve({ status: 'offline', message: 'لا جسر' });
        return;
      }
      var done = false;
      var tm = setTimeout(function () {
        if (done) return;
        done = true;
        resolve({ status: 'timeout', message: 'انتهت مهلة الاتصال' });
      }, 10000);
      try {
        window.flutter_inappwebview
          .callHandler(BRIDGE, { action: action, payload: payload }, action)
          .then(function (r) {
            if (done) return;
            done = true;
            clearTimeout(tm);
            resolve(r || { status: 'ok' });
          })
          .catch(function (e) {
            if (done) return;
            done = true;
            clearTimeout(tm);
            log('bridge err', e);
            resolve({ status: 'error', message: 'خطأ الجسر' });
          });
      } catch (e) {
        if (done) return;
        done = true;
        clearTimeout(tm);
        resolve({ status: 'error', message: 'استثناء' });
      }
    });
  }

  function buildFab() {
    ensureStyle();
    if (document.getElementById(FAB_ID)) return;
    var fab = document.createElement('button');
    fab.id = FAB_ID;
    fab.type = 'button';
    fab.textContent = 'أضف إلى سلة سيلو';

    fab.addEventListener('click', function () {
      if (sending) return;

      var product = collectProduct();
      if (!product) {
        toast('تعذّر قراءة المنتج');
        return;
      }

      sending = true;
      fab.disabled = true;
      var original = fab.textContent;
      fab.textContent = 'جارٍ الإضافة…';

      var sheinBtn = findSheinButton();
      if (sheinBtn) {
        try { sheinBtn.click(); } catch (e) { log('click err', e); }
        log('تم النقر على SHEIN');
      } else {
        log('لم أجد زر SHEIN');
      }

      setTimeout(function () {
        callBridge('addToCart', product).then(function (r) {
          sending = false;
          fab.disabled = false;
          var st = r && r.status ? r.status : 'error';
          if (st === 'ok') {
            fab.textContent = 'تمت الإضافة ✓';
            toast('تمت الإضافة إلى سلتي SHEIN وسيلو ✓' +
                  (r.cartCount ? ' (' + r.cartCount + ')' : ''));
            setTimeout(function () { fab.textContent = original; }, 2000);
          } else if (st === 'unauthenticated') {
            fab.textContent = original;
            toast('سجّل الدخول أولًا');
          } else {
            fab.textContent = original;
            toast((r && r.message) ? r.message : 'فشلت الإضافة');
          }
        });
      }, 1500);
    });

    document.body.appendChild(fab);
  }

  function removeFab() {
    var f = document.getElementById(FAB_ID);
    if (f && f.parentNode) f.parentNode.removeChild(f);
  }

  function sync() {
    if (!goodsIdFromUrl()) { removeFab(); return; }
    buildFab();
  }

  var lastUrl = location.href;
  setInterval(function () {
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      setTimeout(sync, 1200);
    }
  }, 2000);

  window.addEventListener('popstate', function () { setTimeout(sync, 1200); });
  window.__selooRefresh = function () { sync(); };
  window.__selooSetCartCount = function () {};
  window.__selooToast = function (m) { toast(m); };

  function boot() {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function () { setTimeout(sync, 1200); });
    } else {
      setTimeout(sync, 1200);
    }
  }
  boot();
})();

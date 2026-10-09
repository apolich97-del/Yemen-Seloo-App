/**
 * Yemen Seloo — Overlay JS (نسخة محسّنة 2026-10)
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var FAB_ID = 'seloo-fab';
  var TOAST_ID = 'seloo-toast';
  var sending = false;

  function log() {
    try {
      console.log.apply(console,
        ['[seloo]'].concat(Array.prototype.slice.call(arguments)));
    } catch (e) {}
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
    var s = String(raw).replace(/[\u0660-\u0669]/g, function (d) {
      return String.fromCharCode(d.charCodeAt(0) - 0x0660 + 48);
    });
    var m = s.replace(/[٬,\s]/g, '').match(/\d+(\.\d+)?/);
    if (!m) return null;
    var n = parseFloat(m[0]);
    return (isFinite(n) && n > 0) ? n : null;
  }

  // ⭐ استخراج صورة المنتج
  function getProductImage() {
    var selectors = [
      '.product-intro__main-image img',
      '.crop-image-container img',
      '.product-intro__gallery img',
      '[class*="productIntro"] img',
      '[class*="product-intro"] img',
      '.swiper-slide-active img',
      '.gallery-top img',
      'img[class*="main-image"]',
      'img[class*="goods-image"]',
      'img[class*="product-image"]',
      'img[class*="j-image"]',
      '.crop-image img',
      'div[class*="crop"] img',
      'div[class*="product"] img'
    ];
    for (var i = 0; i < selectors.length; i++) {
      var imgs = qa(selectors[i]);
      for (var j = 0; j < imgs.length; j++) {
        var el = imgs[j];
        var src = el.getAttribute('data-src') ||
                  el.getAttribute('data-original') ||
                  el.getAttribute('src') ||
                  el.currentSrc || '';
        if (!src || src.indexOf('http') !== 0) continue;
        var lower = src.toLowerCase();
        if (lower.indexOf('logo') !== -1) continue;
        if (lower.indexOf('shein-logo') !== -1) continue;
        if (lower.indexOf('avatar') !== -1) continue;
        if (lower.indexOf('icon') !== -1) continue;
        if (lower.indexOf('/common/') !== -1 && lower.indexOf('product') === -1) continue;
        return src.split('?')[0];
      }
    }
    var og = attr('meta[property="og:image"]', 'content');
    if (og && og.indexOf('http') === 0) {
      var l = og.toLowerCase();
      if (l.indexOf('logo') === -1 && l.indexOf('shein-logo') === -1) return og;
    }
    return '';
  }

  // ⭐ قراءة اللون والمقاس (محسّنة بمحددات متعددة)
  function readSelectedVariants() {
    var color = '';
    var size = '';
    var options = {};

    // اللون: جرّب محددات متعددة
    var colorSelectors = [
      '.product-intro__color-choose .selected',
      '.product-intro__color-choose [class*="active"]',
      '[class*="color"] [class*="selected"]',
      '[class*="color"] [class*="active"]'
    ];
    for (var ci = 0; ci < colorSelectors.length; ci++) {
      var cEl = q(colorSelectors[ci]);
      if (cEl) {
        color = cEl.getAttribute('title') ||
                cEl.getAttribute('data-title') ||
                cEl.innerText.trim();
        if (color) break;
      }
    }

    // المقاس: جرّب محددات متعددة
    var sizeSelectors = [
      '.product-intro__size-choose .selected',
      '.product-intro__size-choose [class*="active"]',
      '[class*="size"] [class*="selected"]',
      '[class*="size"] [class*="active"]'
    ];
    for (var si = 0; si < sizeSelectors.length; si++) {
      var sEl = q(sizeSelectors[si]);
      if (sEl) {
        size = sEl.innerText.trim();
        if (size) break;
      }
    }

    // خيارات إضافية
    var optionGroups = qa('.product-intro__attr-choose');
    optionGroups.forEach(function (group) {
      var labelEl = group.querySelector('.product-intro__attr-name');
      var selectedEl = group.querySelector('.selected') ||
                       group.querySelector('[class*="active"]');
      if (labelEl && selectedEl) {
        var key = labelEl.innerText.trim();
        var value = selectedEl.getAttribute('title') ||
                    selectedEl.innerText.trim();
        if (key && value) options[key] = value;
      }
    });

    return { color: color, size: size, options: options };
  }

  window.__selooDiagnoseVariants = function () {
    var v = readSelectedVariants();
    console.log('[Seloo Diagnose]', JSON.stringify(v));
    return v;
  };

  function blockExternalLogins() {
    var loginButtons = qa('a[href*="accounts.google.com"], a[href*="appleid.apple.com"]');
    loginButtons.forEach(function (btn) {
      if (!btn.__selooBlocked) {
        btn.__selooBlocked = true;
        btn.addEventListener('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          toast('يرجى استخدام خيارات تسجيل الدخول الأخرى.');
        });
      }
    });
  }

  function preventSheinNativeAddToCart() {
    document.addEventListener('click', function (e) {
      var target = e.target.closest('button, [role="button"], a');
      if (target && visible(target)) {
        var t = (target.textContent || '').trim();
        if (
          t.indexOf('أضف إلى عربة التسوق') !== -1 ||
          t.indexOf('أضف إلى السلة') !== -1 ||
          t.indexOf('أضف للسلة') !== -1 ||
          t.toLowerCase().indexOf('add to cart') !== -1 ||
          t.toLowerCase().indexOf('add to bag') !== -1
        ) {
          e.preventDefault();
          e.stopPropagation();
          toast('يرجى استخدام زر "أضف إلى سلة سيلو" بالأسفل.');
          return false;
        }
      }
    }, true);
  }

  function collectProduct() {
    var goodsId = goodsIdFromUrl();
    if (!goodsId) return null;

    var variants = readSelectedVariants();
    var title = text('h1') || attr('meta[property="og:title"]', 'content');
    var price = parsePrice(text('[class*="price"]')) ||
                parsePrice(attr('meta[property="product:price:amount"]', 'content'));

    if (!title || !price) return null;

    var imageUrl = getProductImage();
    var editId = window.__SELOO_EDITING_LINE_ID__ || '';

    return {
      goodsId: String(goodsId),
      productUrl: location.href.split('#')[0],
      title: title,
      imageUrl: imageUrl,
      price: price,
      currency: 'SAR',
      color: variants.color,
      size: variants.size,
      options: variants.options,
      quantity: 1,
      sku: '',
      variantId: '',
      editingLineId: editId,
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

      // ⭐ زيادة الوقت إلى 800ms (كان 300ms - يسبب التعليق)
      setTimeout(function () {
        callBridge('addToCart', product).then(function (r) {
          sending = false;
          fab.disabled = false;
          var st = r && r.status ? r.status : 'error';
          if (st === 'ok') {
            fab.textContent = 'تمت الإضافة ✓';
            toast('تمت الإضافة إلى سلتك ✓' +
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
      }, 800); // ⭐ تم التعديل
    });

    document.body.appendChild(fab);
  }

  function removeFab() {
    var f = document.getElementById(FAB_ID);
    if (f && f.parentNode) f.parentNode.removeChild(f);
  }

  // ⭐ فرض اللغة العربية على SHEIN
  function enforceArabic() {
    try {
      // إذا كنا على صفحة إنجليزية، نغيّر اللغة
      var html = document.documentElement;
      if (html && html.lang && html.lang.toLowerCase().indexOf('en') === 0) {
        // محاولة تغيير اللغة عبر الرابط
        if (location.host.indexOf('sa.shein.com') !== -1 &&
            location.pathname.indexOf('/ar/') === -1) {
          var newPath = location.pathname.replace(/^\/[a-z]{2}\//, '/ar/');
          if (newPath === location.pathname) {
            newPath = '/ar' + location.pathname;
          }
          // ⚠️ لا نُعيد التوجيه تلقائياً لتجنب الحلقات
          log('English detected, consider redirect');
        }
      }
    } catch (e) {}
  }

  function sync() {
    if (!goodsIdFromUrl()) { removeFab(); return; }
    buildFab();
    blockExternalLogins();
    enforceArabic();
  }

  var lastUrl = location.href;
  var urlCheckTimer = setInterval(function () {
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      setTimeout(sync, 800);
    }
  }, 4000);

  window.addEventListener('beforeunload', function () {
    if (urlCheckTimer) clearInterval(urlCheckTimer);
  });

  window.addEventListener('popstate', function () { setTimeout(sync, 800); });
  window.__selooRefresh = function () { sync(); };
  window.__selooSetCartCount = function () {};
  window.__selooToast = function (m) { toast(m); };

  function scheduleSync() {
    if (typeof requestIdleCallback !== 'undefined') {
      requestIdleCallback(sync, { timeout: 2000 });
    } else {
      setTimeout(sync, 1200);
    }
  }

  function boot() {
    preventSheinNativeAddToCart();
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', scheduleSync);
    } else {
      scheduleSync();
    }
  }
  boot();
})();

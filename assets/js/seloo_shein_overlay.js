/**
 * Yemen Seloo — Overlay JS (Commit 3 + Image Fix)
 * - إزالة findSheinButton ومنع النقر على زر SHEIN الأصلي.
 * - قراءة اللون والمقاس والخيارات (readSelectedVariants).
 * - استخراج صورة المنتج الحقيقية (getProductImage).
 * - منع تسجيل الدخول عبر Google/Apple.
 * - استقبال editingLineId من Flutter.
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var FAB_ID = 'seloo-fab';
  var TOAST_ID = 'seloo-toast';
  var sending = false;

  function log() {
    try {
      console.log.apply(console, ['[seloo]'].concat(Array.prototype.slice.call(arguments)));
    } catch (e) {}
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

  // ⭐ استخراج صورة المنتج الحقيقية (وليس شعار SHEIN)
  function getProductImage() {
    var selectors = [
      '.product-intro__main-image img',
      '.crop-image-container img',
      '[class*="productIntro"] img[class*="main"]',
      '[class*="product-intro"] img',
      'img[class*="main-image"]',
      'img[class*="goods-image"]',
      'img[class*="product-image"]',
      '.swiper-slide-active img',
      '.gallery-top img',
      '[class*="j-image"] img',
      '[class*="crop-image"] img'
    ];
    for (var i = 0; i < selectors.length; i++) {
      var el = q(selectors[i]);
      if (el) {
        var src = el.getAttribute('data-src') ||
                  el.getAttribute('src') ||
                  el.currentSrc || '';
        if (src && src.indexOf('http') === 0) {
          // استبعاد شعارات SHEIN والصور العامة
          if (src.indexOf('logo') !== -1) continue;
          if (src.indexOf('shein-logo') !== -1) continue;
          if (src.indexOf('common') !== -1 && src.indexOf('product') === -1) continue;
          // إزالة معاملات التصغير للحصول على أعلى دقة
          return src.split('?')[0];
        }
      }
    }
    // Fallback: og:image (مع استبعاد الشعارات)
    var og = attr('meta[property="og:image"]', 'content');
    if (og && og.indexOf('http') === 0 &&
        og.indexOf('logo') === -1 &&
        og.indexOf('shein-logo') === -1) {
      return og;
    }
    return '';
  }

  // ⭐ قراءة اللون والمقاس والخيارات
  function readSelectedVariants() {
    var color = '';
    var size = '';
    var options = {};

    // قراءة اللون
    var colorEl = q('.product-intro__color-choose .selected');
    if (colorEl) color = colorEl.getAttribute('title') || colorEl.innerText.trim();

    // قراءة المقاس
    var sizeEl = q('.product-intro__size-choose .selected');
    if (sizeEl) size = sizeEl.innerText.trim();

    // قراءة الخيارات الأخرى (Options)
    var optionGroups = qa('.product-intro__attr-choose');
    optionGroups.forEach(function (group) {
      var labelEl = group.querySelector('.product-intro__attr-name');
      var selectedEl = group.querySelector('.selected');
      if (labelEl && selectedEl) {
        var key = labelEl.innerText.trim();
        var value = selectedEl.getAttribute('title') || selectedEl.innerText.trim();
        if (key && value) options[key] = value;
      }
    });

    return { color: color, size: size, options: options };
  }

  // ⭐ دالة التشخيص (للمساعدة في التطوير)
  window.__selooDiagnoseVariants = function () {
    var variants = readSelectedVariants();
    console.log('[Seloo Diagnose] Variants:', JSON.stringify(variants));
    return variants;
  };

  // ⭐ منع تسجيل الدخول عبر Google/Apple
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

  // ⭐ منع النقر على زر SHEIN الأصلي (Add to Cart)
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

    // ⭐ استخدام دالة الصورة الجديدة
    var imageUrl = getProductImage();

    // قراءة editingLineId من المتغير العام الذي يمرره Flutter
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

      // تم حذف كود النقر على زر SHEIN الأصلي
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
      }, 300);
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
    blockExternalLogins();
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
    // منع النقر على زر SHEIN الأصلي فوراً
    preventSheinNativeAddToCart();

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function () { setTimeout(sync, 1200); });
    } else {
      setTimeout(sync, 1200);
    }
  }
  boot();
})();

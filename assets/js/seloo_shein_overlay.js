/**
 * Yemen Seloo — Overlay JS
 * - قراءة اللون والمقاس والخيارات.
 * - استخراج صورة المنتج (مصادر متعددة).
 * - منع تسجيل الدخول الخارجي (مُعطّل مؤقتاً).
 * - ⭐ زر موحّد: يضيف لسلة SHEIN + سلة يمن سيلو معاً.
 * - ⭐ استيراد سلة SHEIN كاملة عبر WebView.
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

  // ⭐ استخراج صورة المنتج
  function getProductImage() {
    var selectors = [
      '.product-intro__main-image img',
      '.crop-image-container img',
      '.product-intro__gallery img',
      '.goods-detail__img img',
      '[class*="productIntro"] img',
      '[class*="product-intro"] img',
      '[class*="goods-detail"] img',
      '[class*="detail-image"] img',
      '[class*="main-image"] img',
      '.swiper-slide-active img',
      '.gallery-top img',
      'img[class*="main-image"]',
      'img[class*="goods-image"]',
      'img[class*="product-image"]',
      'img[class*="detail-image"]',
      'img[class*="j-image"]',
      'img[data-testid*="product"]',
      'img[alt*="product"]',
      'img[alt*="Product"]',
      'img[alt*="goods"]',
      '.crop-image img',
      'div[class*="crop"] img',
      'div[class*="product"] img',
      'div[class*="goods"] img'
    ];

    function normalize(src) {
      if (!src) return '';
      src = String(src).trim();
      if (src.indexOf('//') === 0) src = 'https:' + src;
      if (src.indexOf('http') !== 0) return '';
      return src;
    }

    function isBad(lower) {
      if (lower.indexOf('logo') !== -1) return true;
      if (lower.indexOf('shein-logo') !== -1) return true;
      if (lower.indexOf('avatar') !== -1) return true;
      if (lower.indexOf('icon') !== -1) return true;
      if (lower.indexOf('.svg') !== -1) return true;
      if (lower.indexOf('/common/') !== -1 && lower.indexOf('product') === -1) return true;
      if (lower.indexOf('placeholder') !== -1) return true;
      return false;
    }

    for (var i = 0; i < selectors.length; i++) {
      var imgs = qa(selectors[i]);
      for (var j = 0; j < imgs.length; j++) {
        var el = imgs[j];
        var candidates = [
          el.getAttribute('data-src'),
          el.getAttribute('data-original'),
          el.getAttribute('data-lazy-src'),
          el.getAttribute('data-image'),
          el.getAttribute('data-img'),
          el.getAttribute('src'),
          el.currentSrc
        ];

        var srcset = el.getAttribute('srcset');
        if (srcset) {
          var parts = srcset.split(',');
          for (var k = 0; k < parts.length; k++) {
            var p = parts[k].trim().split(/\s+/)[0];
            candidates.push(p);
          }
        }

        try {
          var style = window.getComputedStyle(el);
          var bg = style.backgroundImage || '';
          var m = bg.match(/url\(["']?([^"')]+)["']?\)/);
          if (m && m[1]) candidates.push(m[1]);
        } catch (e) {}

        for (var c = 0; c < candidates.length; c++) {
          var src = normalize(candidates[c]);
          if (!src) continue;
          if (isBad(src.toLowerCase())) continue;
          return src.split('?')[0];
        }
      }
    }

    var og = attr('meta[property="og:image"]', 'content');
    var ogSrc = normalize(og);
    if (ogSrc) {
      if (!isBad(ogSrc.toLowerCase())) return ogSrc;
    }
    return '';
  }

  // ⭐ قراءة اللون والمقاس
  function readSelectedVariants() {
    var color = '';
    var size = '';
    var options = {};

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

  window.__selooDiagnoseImage = function () {
    var p = collectProduct();
    console.log('[Seloo Image Diagnose]', JSON.stringify({
      goodsId: p ? p.goodsId : null,
      title: p ? p.title : null,
      imageUrl: p ? p.imageUrl : null,
      color: p ? p.color : null,
      size: p ? p.size : null
    }));
    return p;
  };

  window.__selooDiagnoseVariants = function () {
    var v = readSelectedVariants();
    console.log('[Seloo Diagnose]', JSON.stringify(v));
    return v;
  };

  // ⭐ مُعطّل — نحتاج تسجيل الدخول لقراءة سلة SHEIN
  function blockExternalLogins() {
    return;
  }

  // ⭐ مُعطّل — نسمح بالإضافة لسلة SHEIN الأصلية
  function preventSheinNativeAddToCart() {
    return;
  }

  // ⭐ حجب أيقونة سلة SHEIN
  function blockSheinCartIcon() {
    var cartSelectors = [
      'a[href*="/cart"]:not([href*="add"])',
      'a[href*="/shopping-cart"]',
      'a[data-testid*="cart-icon"]'
    ];

    cartSelectors.forEach(function (sel) {
      var icons = qa(sel);
      icons.forEach(function (icon) {
        if (icon.__selooBlockedCart) return;
        icon.__selooBlockedCart = true;
        icon.addEventListener('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('selooBridge', {
              action: 'openYamanCart',
              payload: {}
            });
          }
          return false;
        }, true);
      });
    });
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

  // ⭐ إضافة زر SHEIN الأصلي (محاولة ذكية)
  function clickSheinNativeAddToCart() {
    var selectors = [
      'button[class*="add-to-cart"]',
      'button[class*="addToBag"]',
      'button[class*="add-to-bag"]',
      'button[data-testid*="add-to-cart"]',
      'button[data-testid*="addToBag"]',
      'button[aria-label*="أضف"]',
      'button[aria-label*="add to"]',
      '[class*="product-intro__add"] button',
      '[class*="goods-action"] button'
    ];

    for (var i = 0; i < selectors.length; i++) {
      var btns = qa(selectors[i]);
      for (var j = 0; j < btns.length; j++) {
        var btn = btns[j];
        if (!visible(btn)) continue;
        var txt = (btn.textContent || '').trim();
        if (
          txt.indexOf('أضف') !== -1 ||
          txt.indexOf('Add to') !== -1 ||
          txt.indexOf('أضف إلى') !== -1
        ) {
          try {
            btn.click();
            log('نقرت على زر SHEIN الأصلي');
            return true;
          } catch (e) {
            log('فشل نقر زر SHEIN', e);
          }
        }
      }
    }
    log('لم أجد زر SHEIN الأصلي');
    return false;
  }

  // ⭐ تأكيد Dialog إضافة SHEIN (إن وُجد)
  function confirmSheinDialog() {
    setTimeout(function () {
      var dialogSelectors = [
        '[role="dialog"] button[class*="confirm"]',
        '[role="dialog"] button[class*="add"]',
        '[class*="drawer"] button[class*="confirm"]',
        '[class*="modal"] button[class*="add"]',
        '[class*="modal"] button[class*="confirm"]'
      ];
      for (var i = 0; i < dialogSelectors.length; i++) {
        var btns = qa(dialogSelectors[i]);
        for (var j = 0; j < btns.length; j++) {
          if (visible(btns[j])) {
            try {
              btns[j].click();
              log('أكدت dialog SHEIN');
              return;
            } catch (e) {}
          }
        }
      }
    }, 1200);
  }

  function ensureStyle() {
    if (document.getElementById('seloo-style')) return;
    var s = document.createElement('style');
    s.id = 'seloo-style';
    s.textContent =
      '#' + FAB_ID + '{position:fixed;bottom:100px;right:16px;z-index:2147483000;' +
      'background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:12px 18px;' +
      'font-size:14px;font-weight:700;font-family:inherit;direction:rtl;cursor:pointer;' +
      'box-shadow:0 6px 20px rgba(124,58,237,.5);display:flex;flex-direction:column;gap:4px;align-items:flex-end}' +
      '#' + FAB_ID + '[disabled]{opacity:.6}' +
      '#' + FAB_ID + ' .seloo-main{font-size:15px;font-weight:900}' +
      '#' + FAB_ID + ' .seloo-sub{font-size:11px;opacity:.85;display:flex;align-items:center;gap:4px}' +
      '#' + FAB_ID + ' .seloo-chk{width:14px;height:14px;cursor:pointer;accent-color:#fff}' +
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

    var fab = document.createElement('div');
    fab.id = FAB_ID;

    var main = document.createElement('div');
    main.className = 'seloo-main';
    main.textContent = '🛒 أضف إلى سلة سيلو';

    var sub = document.createElement('div');
    sub.className = 'seloo-sub';
    var chk = document.createElement('input');
    chk.type = 'checkbox';
    chk.className = 'seloo-chk';
    chk.checked = true;
    chk.id = 'seloo-also-shein';
    var lbl = document.createElement('span');
    lbl.textContent = 'أيضاً إلى SHEIN';
    sub.appendChild(chk);
    sub.appendChild(lbl);

    fab.appendChild(main);
    fab.appendChild(sub);

    // حفظ التفضيل
    try {
      var saved = localStorage.getItem('seloo-also-shein');
      if (saved === '0') chk.checked = false;
    } catch (e) {}
    chk.addEventListener('change', function () {
      try {
        localStorage.setItem('seloo-also-shein', chk.checked ? '1' : '0');
      } catch (e) {}
    });

    fab.addEventListener('click', function (e) {
      if (e.target === chk) return;
      if (sending) return;

      var product = collectProduct();
      if (!product) {
        toast('تعذّر قراءة المنتج');
        return;
      }

      sending = true;
      fab.style.opacity = '0.6';
      main.textContent = 'جارٍ الإضافة…';

      // ⭐ 1. إضافة إلى سلة SHEIN (إن كان الخيار مُفعّلاً)
      if (chk.checked) {
        clickSheinNativeAddToCart();
        confirmSheinDialog();
      }

      // ⭐ 2. إضافة إلى سلة يمن سيلو (بعد 1.5 ثانية)
      setTimeout(function () {
        callBridge('addToCart', product).then(function (r) {
          sending = false;
          fab.style.opacity = '1';
          var st = r && r.status ? r.status : 'error';
          if (st === 'ok') {
            main.textContent = 'تمت الإضافة ✓';
            toast('تمت الإضافة إلى سلتك ✓' +
                  (chk.checked ? ' + سلة SHEIN' : '') +
                  (r.cartCount ? ' (' + r.cartCount + ')' : ''));
            setTimeout(function () {
              main.textContent = '🛒 أضف إلى سلة سيلو';
            }, 2000);
          } else if (st === 'unauthenticated') {
            main.textContent = '🛒 أضف إلى سلة سيلو';
            toast('سجّل الدخول أولًا');
          } else {
            main.textContent = '🛒 أضف إلى سلة سيلو';
            toast((r && r.message) ? r.message : 'فشلت الإضافة');
          }
        });
      }, chk.checked ? 1500 : 100);
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
    blockSheinCartIcon();
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

  /* =========================================================
   * ⭐ [الحل B] استيراد سلة SHEIN كاملة
   * ========================================================= */
  (function () {
    if (window.__selooImportReady) return;
    window.__selooImportReady = true;

    var SELLO_CURRENCY = 'SAR';
    var SEND_INTERVAL_MS = 200;
    var IMPORT_FAB_ID = 'seloo-import-fab';

    function selooSend(action, payload) {
      try {
        if (window.flutter_inappwebview &&
            typeof window.flutter_inappwebview.callHandler === 'function') {
          window.flutter_inappwebview.callHandler(BRIDGE, {
            action: action,
            payload: payload
          });
          return true;
        }
        log('لا يوجد جسر callHandler');
      } catch (e) {
        log('فشل الإرسال', e);
      }
      return false;
    }

    function txt(el) {
      return (el && el.textContent ? el.textContent : '')
        .replace(/\s+/g, ' ')
        .trim();
    }

    function extractPrice(scope) {
      var els = scope.querySelectorAll('[class*="price"], [class*="Price"]');
      for (var i = 0; i < els.length; i++) {
        var t = txt(els[i]);
        var m = t.match(/[\d]+[.,]?[\d]*/);
        if (m) {
          var v = parseFloat(m[0].replace(/,/g, ''));
          if (!isNaN(v) && v >= 0.5 && v <= 100000) return v;
        }
      }
      return null;
    }

    function extractQty(scope) {
      var input = scope.querySelector(
        'input[type="number"], [class*="qty"] input, [class*="quantity"] input'
      );
      if (input) {
        var v = parseInt(input.value || input.getAttribute('value') || '1', 10);
        if (!isNaN(v) && v > 0) return v;
      }
      var m = txt(scope).match(/\b[x\u00d7]\s*(\d+)/i);
      return m ? parseInt(m[1], 10) : 1;
    }

    function extractGoodsId(scope, href) {
      var m = (href || '').match(/goods_id[=%\/]?(\d+)/i) ||
              (href || '').match(/-p-(\d+)/);
      if (m) return m[1];
      var link = scope
        ? scope.querySelector('a[href*="goods_id"], a[href*="-p-"]')
        : null;
      if (link) {
        var href2 = link.getAttribute('href') || '';
        var m2 = href2.match(/goods_id[=%\/]?(\d+)/i) ||
                 href2.match(/-p-(\d+)/);
        if (m2) return m2[1];
      }
      return null;
    }

    function extractImage(scope) {
      var img = scope ? scope.querySelector('img') : null;
      if (!img) return '';
      var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
      if (/^https?:\/\//i.test(src)) return src;
      if (src.indexOf('//') === 0) return 'https:' + src;
      return '';
    }

    function absoluteUrl(href) {
      if (!href) return null;
      if (/^https?:\/\//i.test(href)) return href;
      try { return new URL(href, location.origin).href; } catch (e) { return null; }
    }

    function extractCartItems() {
      var items = [];
      var seen = {};

      var wrappers = document.querySelectorAll(
        '[class*="cart-item"], [class*="cartItem"], [class*="CartItem"], ' +
        '[class*="cartItem___"], [class*="CART_ITEM"], [class*="checkout-item"]'
      );

      wrappers.forEach(function (w) {
        var link = w.querySelector('a[href*="goods_id"], a[href*="-p-"]');
        var href = link ? (link.getAttribute('href') || '') : '';
        var gid = extractGoodsId(w, href);
        if (!gid || seen[gid]) return;

        var nameEl = w.querySelector(
          '[class*="name"], [class*="Name"], [class*="title"], [class*="Title"]'
        );
        var name = txt(nameEl) || (link ? txt(link) : '') || '';

        var price = extractPrice(w);
        if (!name && price === null) return;

        seen[gid] = true;
        items.push({
          goodsId: gid,
          title: name,
          price: price,
          image: extractImage(w),
          quantity: extractQty(w),
          url: absoluteUrl(href)
        });
      });

      if (!items.length) {
        var links = document.querySelectorAll('a[href*="goods_id"], a[href*="-p-"]');
        links.forEach(function (a) {
          var gid = extractGoodsId(null, a.getAttribute('href') || '');
          if (!gid || seen[gid]) return;
          var scope = a.closest('[class*="item"], li, div');
          seen[gid] = true;
          items.push({
            goodsId: gid,
            title: txt(a),
            price: scope ? extractPrice(scope) : null,
            image: scope ? extractImage(scope) : '',
            quantity: scope ? extractQty(scope) : 1,
            url: a.href
          });
        });
      }
      return items;
    }
    window.selooExtractCart = extractCartItems;

    function toPayload(item) {
      var digits = String(item.goodsId || '').replace(/\D/g, '');

      var qty = parseInt(item.quantity, 10);
      if (isNaN(qty) || qty < 1) qty = 1;
      if (qty > 50) qty = 50;

      var priceOk = (typeof item.price === 'number' &&
                     isFinite(item.price) && item.price > 0);
      var price = priceOk ? item.price : 0.01;

      return {
        goodsId: digits,
        // ⭐ تم التصحيح: m.shein.com بدلاً من m.shein.com.sa
        productUrl: item.url || ('https://m.shein.com/ar/-p-' + digits + '.html'),
        title: item.title || ('منتج SHEIN #' + digits),
        imageUrl: item.image || '',
        sourcePrice: price,
        sourceCurrency: SELLO_CURRENCY,
        quantity: qty,
        color: '',
        size: '',
        options: {},
        sourceStore: 'SHEIN',
        sku: '',
        variantId: '',
        source: 'webview-cart'
      };
    }

    function isCartPage() {
      return location.pathname.toLowerCase().indexOf('cart') !== -1;
    }

    function injectImportFab() {
      if (!document.body) return;

      if (!isCartPage()) {
        var old = document.getElementById(IMPORT_FAB_ID);
        if (old) old.remove();
        return;
      }

      if (document.getElementById(IMPORT_FAB_ID)) return;

      var fab = document.createElement('div');
      fab.id = IMPORT_FAB_ID;
      fab.textContent = '📤 إرسال السلة إلى يمن سيلو';
      fab.setAttribute('style',
        'position:fixed;bottom:24px;left:16px;right:16px;z-index:2147483647;' +
        'background:#7c3aed;color:#fff;padding:14px 18px;border-radius:14px;' +
        'font-size:16px;font-weight:700;text-align:center;cursor:pointer;' +
        'box-shadow:0 6px 18px rgba(124,58,237,.5);' +
        'font-family:system-ui,sans-serif;direction:rtl;');

      fab.onclick = function () {
        fab.textContent = '⏳ جاري الفحص...';
        setTimeout(function () {
          var items = extractCartItems();
          if (!items.length) {
            fab.textContent = '⚠️ لم أجد منتجات — تأكد من تسجيل الدخول في SHEIN';
            setTimeout(function () {
              fab.textContent = '📤 إرسال السلة إلى يمن سيلو';
            }, 3500);
            return;
          }
          fab.textContent = '⏳ جاري إرسال ' + items.length + ' منتج...';

          var i = 0, sent = 0, noPrice = 0;
          function next() {
            if (i >= items.length) {
              selooSend('importComplete', {
                count: sent,
                total: items.length,
                noPrice: noPrice
              });
              fab.textContent = '✅ تم إرسال ' + sent + ' منتج';
              return;
            }
            var item = items[i];
            if (!(typeof item.price === 'number' && item.price > 0)) noPrice++;
            if (selooSend('addToCart', toPayload(item))) sent++;
            i++;
            setTimeout(next, SEND_INTERVAL_MS);
          }
          next();
        }, 1000);
      };

      document.body.appendChild(fab);
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function () {
        setTimeout(injectImportFab, 800);
      });
    } else {
      setTimeout(injectImportFab, 800);
    }

    var lastImportPath = location.pathname;
    setInterval(function () {
      if (location.pathname !== lastImportPath) {
        lastImportPath = location.pathname;
        setTimeout(injectImportFab, 1500);
      }
    }, 1500);
  })();
})();

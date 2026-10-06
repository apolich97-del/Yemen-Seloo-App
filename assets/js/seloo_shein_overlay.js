/**
 * Yemen Seloo — Overlay محسّن
 * - زر عائم بدل شريط سفلي (لا يغطي زر SHEIN)
 * - تفاعل مع تغيّر المسار فقط (لا كل DOM mutation)
 * - الضغط المطوّل = تشخيص
 */
(function () {
  'use strict';

  var CONFIG = {
    BRIDGE: 'selooBridge',
    FAB_ID: 'seloo-fab',
    TOAST_ID: 'seloo-toast',
    LABEL_ADD: 'أضف إلى سلة سيلو',
    LABEL_WORKING: 'جارٍ الإضافة…',
    LABEL_ADDED: 'تمت الإضافة ✓',
    TOAST_OK: 'تمت الإضافة إلى سلة سيلو ✓',
    TOAST_SHEIN_FAIL: 'تعذّرت الإضافة إلى SHEIN',
    TOAST_NO_BUTTON: 'لم أجد زر SHEIN — اضغط مطولًا للتشخيص',
    BRIDGE_TIMEOUT: 10000,
    SHEIN_CLICK_TIMEOUT: 6000,
    ROUTE_POLL: 2000,
    SETTLE_DELAY: 1200
  };

  var SHEIN_BUTTON_SELECTORS = [
    'button[class*="product-intro__add"]',
    'button[class*="add-to-cart"]',
    'button[class*="addToCart"]',
    'button[data-testid*="add-cart"]',
    'button[data-testid*="add-to-bag"]',
    '[role="button"][class*="add-to-cart"]',
    '[class*="product-intro__add-btn"] button',
    '[class*="product-intro__btn-add"]',
    '[class*="product-intro__add-cart"]',
    '[class*="add-bag"] button',
    'a[class*="add-to-cart"]'
  ];

  var SHEIN_CART_SELECTORS = [
    '[class*="header-cart"] [class*="badge"]',
    '[class*="header-cart"] [class*="num"]',
    '[class*="cart"] [class*="badge"]',
    '[data-testid*="cart-count"]'
  ];

  var PRODUCT_URL_PATTERNS = [/-p-(\d{5,})\.html/i];
  var LOG_PREFIX = '[seloo]';
  var barState = { sending: false };

  function log() {
    try { console.log.apply(console, [LOG_PREFIX].concat(Array.prototype.slice.call(arguments))); } catch (e) {}
  }
  function q(s) { try { return document.querySelector(s); } catch (e) { return null; } }
  function qa(s) { try { return Array.prototype.slice.call(document.querySelectorAll(s)); } catch (e) { return []; } }
  function isVisible(el) {
    if (!el) return false;
    try {
      var r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) return false;
      var st = window.getComputedStyle(el);
      if (st.display === 'none' || st.visibility === 'hidden' || parseFloat(st.opacity) < 0.1) return false;
      return true;
    } catch (e) { return false; }
  }
  function goodsIdFromUrl(url) {
    for (var i = 0; i < PRODUCT_URL_PATTERNS.length; i++) {
      var m = url.match(PRODUCT_URL_PATTERNS[i]);
      if (m) return m[1];
    }
    return null;
  }
  function text(sel) {
    var el = q(sel);
    if (!el) return null;
    var t = (el.textContent || '').trim();
    return t.length ? t : null;
  }
  function attr(sel, name) {
    var el = q(sel);
    return el ? (el.getAttribute(name) || '').trim() : null;
  }
  function parseMoney(raw) {
    if (!raw) return null;
    var cleaned = String(raw).replace(/[\u0660-\u0669]/g, function (d) {
      return String.fromCharCode(d.charCodeAt(0) - 0x0660 + 48);
    });
    var m = cleaned.replace(/[٬,\s]/g, '').match(/\d+(\.\d+)?/);
    if (!m) return null;
    var amount = parseFloat(m[0]);
    if (!isFinite(amount) || amount <= 0) return null;
    var cur = null;
    if (cleaned.indexOf('ر.س') !== -1 || cleaned.indexOf('SAR') !== -1) cur = 'SAR';
    else if (cleaned.indexOf('$') !== -1) cur = 'USD';
    else if (cleaned.indexOf('ر.ي') !== -1) cur = 'YER';
    if (!cur) {
      var code = cleaned.match(/\b([A-Z]{3})\b/);
      if (code) cur = code[1];
    }
    return { amount: amount, currency: cur };
  }
  function readSelectedColor() {
    var containers = qa('[class*="color"], [class*="Color"]');
    for (var i = 0; i < containers.length; i++) {
      var c = containers[i];
      var sel = c.querySelector('[class*="active"], [class*="selected"], [aria-checked="true"]');
      if (sel && isVisible(sel)) {
        var v = sel.getAttribute('title') || sel.getAttribute('aria-label') ||
                sel.getAttribute('data-name') || (sel.textContent || '').trim();
        if (v) return v;
      }
    }
    return '';
  }
  function readSelectedSize() {
    var containers = qa('[class*="size"], [class*="Size"]');
    for (var i = 0; i < containers.length; i++) {
      var c = containers[i];
      var sel = c.querySelector('[class*="active"], [class*="selected"], [aria-checked="true"]');
      if (sel && isVisible(sel)) {
        var v = sel.getAttribute('title') || sel.getAttribute('aria-label') ||
                sel.getAttribute('data-name') || (sel.textContent || '').trim();
        if (v) return v;
      }
    }
    return '';
  }
  function findSheinAddButton() {
    for (var i = 0; i < SHEIN_BUTTON_SELECTORS.length; i++) {
      var el = q(SHEIN_BUTTON_SELECTORS[i]);
      if (el && isVisible(el)) {
        log('زر SHEIN (selector):', SHEIN_BUTTON_SELECTORS[i]);
        return el;
      }
    }
    var allClickable = qa('button, [role="button"], a, div[class*="btn"], div[class*="Btn"]');
    for (var j = 0; j < allClickable.length; j++) {
      var b = allClickable[j];
      if (!isVisible(b)) continue;
      var t = (b.textContent || '').trim().toLowerCase();
      if (!t || t.length > 60) continue;
      if (t.indexOf('add to bag') !== -1 || t.indexOf('add to cart') !== -1 ||
          t.indexOf('add to basket') !== -1 || t.indexOf('أضف إلى السلة') !== -1 ||
          t.indexOf('أضف للسلة') !== -1 || t.indexOf('أضف إلى حقيبة') !== -1 ||
          t.indexOf('أضف للحقيبة') !== -1) {
        log('زر SHEIN (نص):', t);
        return b;
      }
    }
    return null;
  }
  function readSheinCartCount() {
    for (var i = 0; i < SHEIN_CART_SELECTORS.length; i++) {
      var el = q(SHEIN_CART_SELECTORS[i]);
      if (el) {
        var n = parseInt((el.textContent || '').replace(/[^0-9]/g, ''), 10);
        if (isFinite(n)) return n;
      }
    }
    return null;
  }
  function waitSheinConfirm(before, timeoutMs) {
    return new Promise(function (resolve) {
      var start = Date.now();
      var iv = setInterval(function () {
        var now = readSheinCartCount();
        if (before !== null && now !== null && now > before) {
          clearInterval(iv);
          resolve({ ok: true, newCount: now });
          return;
        }
        if (Date.now() - start > timeoutMs) {
          clearInterval(iv);
          resolve({ ok: false, reason: 'timeout' });
        }
      }, 300);
    });
  }
  function addToSheinCart() {
    var btn = findSheinAddButton();
    if (!btn) return Promise.resolve({ ok: false, reason: 'no_button' });
    var before = readSheinCartCount();
    try { btn.click(); } catch (e1) {
      try {
        var ev = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
        btn.dispatchEvent(ev);
      } catch (e2) {
        return Promise.resolve({ ok: false, reason: 'click_failed' });
      }
    }
    return waitSheinConfirm(before, CONFIG.SHEIN_CLICK_TIMEOUT);
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
        resolve({ status: 'timeout', message: 'انتهت المهلة' });
      }, CONFIG.BRIDGE_TIMEOUT);
      try {
        window.flutter_inappwebview
          .callHandler(CONFIG.BRIDGE, { action: action, payload: payload }, action)
          .then(function (r) {
            if (done) return;
            done = true;
            clearTimeout(tm);
            resolve(r && typeof r === 'object' ? r : { status: 'ok', message: '' });
          })
          .catch(function () {
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
  function collectProduct() {
    var goodsId = goodsIdFromUrl(location.href);
    if (!goodsId) return null;
    var title = text('h1') || attr('meta[property="og:title"]', 'content');
    var price = parseMoney(text('[class*="price"]')) ||
                parseMoney(attr('meta[property="product:price:amount"]', 'content'));
    if (!title || !price) return null;
    var imageUrl = attr('meta[property="og:image"]', 'content') || '';
    return {
      goodsId: String(goodsId),
      productUrl: location.href.split('#')[0],
      title: title,
      imageUrl: imageUrl,
      price: price.amount,
      currency: price.currency || 'SAR',
      color: readSelectedColor(),
      size: readSelectedSize(),
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
    s.textContent = [
      '#' + CONFIG.FAB_ID + '{position:fixed;bottom:100px;right:16px;z-index:2147483000;',
      'background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:14px 20px;',
      'font-size:15px;font-weight:700;font-family:inherit;direction:rtl;cursor:pointer;',
      'box-shadow:0 6px 20px rgba(124,58,237,.5);transition:transform .2s}',
      '#' + CONFIG.FAB_ID + ':active{transform:scale(.95)}',
      '#' + CONFIG.FAB_ID + '[disabled]{opacity:.6}',
      '#' + CONFIG.TOAST_ID + '{position:fixed;bottom:160px;left:50%;transform:translateX(-50%);',
      'z-index:2147483000;background:#111827;color:#fff;padding:12px 18px;border-radius:10px;',
      'font-size:13px;max-width:90vw;text-align:right;direction:rtl;white-space:pre-line;',
      'max-height:60vh;overflow-y:auto;line-height:1.5}'
    ].join('');
    (document.head || document.documentElement).appendChild(s);
  }
  function toast(msg) {
    var el = document.getElementById(CONFIG.TOAST_ID);
    if (!el) {
      el = document.createElement('div');
      el.id = CONFIG.TOAST_ID;
      document.body.appendChild(el);
    }
    el.textContent = msg;
    el.style.display = 'block';
    clearTimeout(el.__timer);
    el.__timer = setTimeout(function () { el.style.display = 'none'; }, 5000);
  }
  function diagnose() {
    var buttons = qa('button, [role="button"], a');
    var visible = buttons.filter(isVisible);
    var preview = visible.slice(0, 20).map(function (b) {
      var t = (b.textContent || '').trim().slice(0, 30);
      var c = (b.className || '').toString().slice(0, 40);
      return '• ' + t + '\n  ' + c;
    }).join('\n');
    toast('أزرار مرئية: ' + visible.length + '\n\n' + preview);
    log('أزرار مرئية:', visible);
  }
  function buildFab() {
    ensureStyle();
    var fab = document.getElementById(CONFIG.FAB_ID);
    if (!fab) {
      fab = document.createElement('button');
      fab.id = CONFIG.FAB_ID;
      fab.type = 'button';
      fab.textContent = CONFIG.LABEL_ADD;

      var pressTimer = null;
      var longPressed = false;

      function startPress() {
        longPressed = false;
        pressTimer = setTimeout(function () {
          longPressed = true;
          diagnose();
        }, 700);
      }
      function cancelPress() {
        if (pressTimer) { clearTimeout(pressTimer); pressTimer = null; }
      }

      fab.addEventListener('mousedown', startPress);
      fab.addEventListener('mouseup', cancelPress);
      fab.addEventListener('mouseleave', cancelPress);
      fab.addEventListener('touchstart', startPress);
      fab.addEventListener('touchend', cancelPress);
      fab.addEventListener('touchcancel', cancelPress);

      fab.addEventListener('click', async function () {
        if (longPressed) return;
        if (barState.sending) return;
        var product = collectProduct();
        if (!product) {
          toast('تعذّر قراءة المنتج');
          return;
        }
        var before = fab.textContent;
        barState.sending = true;
        fab.disabled = true;
        fab.textContent = CONFIG.LABEL_WORKING;

        var sheinRes = await addToSheinCart();
        if (!sheinRes.ok) {
          barState.sending = false;
          fab.disabled = false;
          fab.textContent = before;
          if (sheinRes.reason === 'no_button') {
            toast(CONFIG.TOAST_NO_BUTTON);
          } else if (sheinRes.reason === 'timeout') {
            toast(CONFIG.TOAST_SHEIN_FAIL + ' (انتهت المهلة)');
          } else {
            toast(CONFIG.TOAST_SHEIN_FAIL);
          }
          return;
        }

        var result = await callBridge('addToCart', product);
        barState.sending = false;
        fab.disabled = false;

        var st = result && result.status ? result.status : 'error';
        if (st === 'ok') {
          fab.textContent = CONFIG.LABEL_ADDED;
          toast(CONFIG.TOAST_OK + (result.cartCount ? ' (' + result.cartCount + ')' : ''));
          setTimeout(function () { fab.textContent = before; }, 2000);
        } else {
          fab.textContent = before;
          toast((result && result.message) ? result.message : CONFIG.TOAST_SHEIN_FAIL);
        }
      });

      document.body.appendChild(fab);
    }
  }
  function removeFab() {
    var fab = document.getElementById(CONFIG.FAB_ID);
    if (fab && fab.parentNode) fab.parentNode.removeChild(fab);
  }
  function sync() {
    var product = collectProduct();
    if (!product) { removeFab(); return; }
    buildFab();
  }
  function scheduleSync() {
    clearTimeout(scheduleSync.__timer);
    scheduleSync.__timer = setTimeout(sync, CONFIG.SETTLE_DELAY);
  }
  var lastUrl = location.href;
  setInterval(function () {
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      scheduleSync();
    }
  }, CONFIG.ROUTE_POLL);
  window.addEventListener('popstate', scheduleSync);
  window.addEventListener('hashchange', scheduleSync);
  window.__selooRefresh = function () { sync(); };
  window.__selooSetCartCount = function () {};
  window.__selooToast = function (m) { toast(m); };
  window.__selooDiagnose = function () { diagnose(); };
  function boot() {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', scheduleSync);
    } else {
      scheduleSync();
    }
  }
  boot();
})();

/**
 * Yemen Seloo — السكربت المحقون داخل صفحات SHEIN.
 * =====================================================================
 * الوظيفة:
 *   1) إظهار شريط «أضف إلى سلة سيلو» في صفحة المنتج داخل SHEIN.
 *   2) قراءة بيانات المنتج (Product ID, SKU, اللون, المقاس, الكمية, السعر, العملة, الصورة, العنوان).
 *   3) عند ضغط الزر: إضافة المنتج فعليًا إلى سلة SHEIN عبر زر SHEIN الأصلي.
 *   4) بعد نجاح SHEIN فقط: إرسال نفس المنتج إلى تطبيق Yemen Seloo عبر الجسر.
 *   5) إظهار رسالة موحّدة: «تمت الإضافة إلى سلة SHEIN وسلة سيلو ✓».
 */
(function () {
  'use strict';

  /* ==================== (1) الإعدادات ==================== */
  var CONFIG = {
    BRIDGE: 'selooBridge',
    BAR_ID: 'seloo-bar',
    TOAST_ID: 'seloo-toast',
    BAR_HEIGHT: 96,
    Z_INDEX: 2147483000,
    LABEL_ADD: 'أضف إلى سلة سيلو',
    LABEL_WORKING: 'جارٍ الإضافة…',
    LABEL_ADDED: 'في السلة ✓',
    TOAST_OK: 'تمت الإضافة إلى سلة SHEIN وسلة سيلو ✓',
    TOAST_SHEIN_FAIL: 'تعذّرت الإضافة إلى SHEIN: ',
    TOAST_NO_AUTH: 'سجّل الدخول أولًا لإضافة المنتجات',
    TOAST_NO_VARIANT: 'اختر اللون والمقاس أولًا',
    TOAST_NO_BUTTON: 'لم أجد زر الإضافة في SHEIN — حدّث الصفحة',
    BRIDGE_TIMEOUT: 10000,
    SHEIN_CLICK_TIMEOUT: 8000,
    CART_POLL_INTERVAL: 250,
    SETTLE_DELAY: 600,
    ROUTE_POLL: 500
  };

  var SELECTORS = {
    title: ['h1', 'div.product-intro__head h1',
      '[class*="product-intro__head"] h1', 'meta[property="og:title"]^content'],
    image: ['meta[property="og:image"]^content',
      'div.product-intro__main img^src', 'div[class*="gallery"] img^src',
      'img[src*="/images/goods/"]^src'],
    price: ['div.product-intro__price', '[class*="product-intro__price"]',
      'span[class*="price"]', 'div[class*="price__"] span',
      'meta[property="product:price:amount"]^content'],
    currency: ['meta[property="product:price:currency"]^content'],
    quantity: ['input[class*="quantity"]', '[class*="quantity"] input',
      'div[class*="quantity"] span[class*="value"]',
      '[class*="product-intro__quantity"] input']
  };

  var SHEIN_COLOR_SELECTORS = [
    '[class*="product-intro__color"] [aria-checked="true"]',
    '[class*="product-intro__color"] [class*="selected"]',
    '[class*="color-list"] [class*="active"]',
    '[class*="color-selector"] [class*="selected"]',
    '[class*="color"] [aria-checked="true"]',
    '[class*="color"] [class*="selected"]'
  ];

  var SHEIN_SIZE_SELECTORS = [
    '[class*="product-intro__size"] [aria-checked="true"]',
    '[class*="product-intro__size"] [class*="selected"]',
    '[class*="size-list"] [class*="active"]',
    '[class*="size-selector"] [class*="selected"]',
    '[class*="size"] [aria-checked="true"]',
    '[class*="size"] [class*="selected"]'
  ];

  var SHEIN_ADD_BUTTON_SELECTORS = [
    'button[class*="product-intro__add"]',
    'button[class*="add-to-cart"]',
    'button[class*="addToCart"]',
    'button[data-testid*="add-cart"]',
    '[role="button"][class*="add-to-cart"]',
    '[class*="product-intro__add-btn"] button',
    '[class*="product-intro__btn-add"]'
  ];

  var SHEIN_CART_BADGE_SELECTORS = [
    '[class*="header-cart"] [class*="badge"]',
    '[class*="header-cart"] [class*="num"]',
    '[class*="header-cart"] [class*="count"]',
    '[class*="cart-badge"]',
    '[data-testid*="cart-count"]',
    '[class*="cart"] [class*="badge"]'
  ];

  var SHEIN_TOAST_SELECTORS = [
    '[class*="toast"] [class*="success"]',
    '[class*="toast--success"]',
    '[class*="add-cart-success"]',
    '[class*="toast"]'
  ];

  var PRODUCT_URL_PATTERNS = [/-p-(\d{5,})\.html/i];
  var CURRENCY_SYMBOLS = { '$': 'USD', '￥': 'CNY', '¥': 'CNY', 'SAR': 'SAR', 'ر.س': 'SAR' };
  var LOG_PREFIX = '[seloo]';

  /* ==================== (2) أدوات ==================== */
  function log() {
    try {
      console.log.apply(console, [LOG_PREFIX].concat(Array.prototype.slice.call(arguments)));
    } catch (e) {}
  }
  function q(selector) {
    try { return document.querySelector(selector); } catch (e) { return null; }
  }
  function qa(selector) {
    try { return Array.prototype.slice.call(document.querySelectorAll(selector)); }
    catch (e) { return []; }
  }
  function text(selector) {
    var el = q(selector);
    if (!el) return null;
    var v = (el.textContent || '').trim();
    return v.length ? v : null;
  }
  function attr(selector, name) {
    var el = q(selector);
    if (!el) return null;
    var v = (el.getAttribute(name) || '').trim();
    return v.length ? v : null;
  }
  function pickFirst(list, reader) {
    for (var i = 0; i < list.length; i++) {
      var v = reader(list[i]);
      if (v) return v;
    }
    return null;
  }
  function readSpec(spec) {
    var parts = spec.split('^');
    return parts.length === 2 ? attr(parts[0], parts[1]) : text(parts[0]);
  }
  function isVisible(el) {
    if (!el) return false;
    try {
      var rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return false;
      var style = window.getComputedStyle(el);
      if (style.display === 'none' || style.visibility === 'hidden' ||
          style.opacity === '0') return false;
      if (el.disabled) return false;
      return true;
    } catch (e) { return false; }
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
    var currency = null;
    Object.keys(CURRENCY_SYMBOLS).forEach(function (sym) {
      if (!currency && cleaned.indexOf(sym) !== -1) currency = CURRENCY_SYMBOLS[sym];
    });
    if (!currency) {
      var code = cleaned.match(/\b([A-Z]{3})\b/);
      if (code) currency = code[1];
    }
    return { amount: amount, currency: currency };
  }
  function goodsIdFromUrl(url) {
    for (var i = 0; i < PRODUCT_URL_PATTERNS.length; i++) {
      var m = url.match(PRODUCT_URL_PATTERNS[i]);
      if (m) return m[1];
    }
    return null;
  }

  /* ==================== (3) استخراج المنتج ==================== */
  function fromJsonLd() {
    try {
      var nodes = document.querySelectorAll('script[type="application/ld+json"]');
      for (var i = 0; i < nodes.length; i++) {
        var parsed;
        try { parsed = JSON.parse(nodes[i].textContent || '{}'); } catch (e) { continue; }
        var candidates = Array.isArray(parsed) ? parsed : [parsed].concat(parsed['@graph'] || []);
        for (var j = 0; j < candidates.length; j++) {
          var node = candidates[j];
          if (!node || typeof node !== 'object') continue;
          var type = node['@type'];
          var isProduct = type === 'Product' ||
            (Array.isArray(type) && type.indexOf('Product') !== -1);
          if (!isProduct) continue;
          var offers = Array.isArray(node.offers) ? node.offers[0] : node.offers || {};
          var image = Array.isArray(node.image) ? node.image[0] : node.image;
          return {
            title: node.name || null,
            imageUrl: image || null,
            price: offers.price ? parseFloat(offers.price) : null,
            currency: offers.priceCurrency || null,
            sku: offers.sku || node.sku || null,
            source: 'jsonld'
          };
        }
      }
    } catch (e) { log('jsonld failed', e); }
    return null;
  }

  function fromSheinGlobals() {
    try {
      var g = window.gbCommonInfo || {};
      var goods = g.goodsInfo || g.goods || g.productInfo || {};
      var price = goods.salePrice || goods.price || g.salePrice || g.price;
      var id = goods.goods_id || goods.goodsId || g.goods_id || g.goodsId;
      var sku = goods.sku || goods.sku_code || goods.skuCode || g.sku;
      var variantId = goods.variant_id || goods.variantId || goods.goods_sn || null;
      if (!id && !price) return null;
      return {
        goodsId: id ? String(id) : null,
        title: goods.goods_name || goods.goodsName || null,
        imageUrl: goods.goods_img || goods.mainImage || null,
        price: price ? parseFloat(price) : null,
        currency: goods.currency_code || g.currency || null,
        sku: sku ? String(sku) : null,
        variantId: variantId ? String(variantId) : null,
        source: 'globals'
      };
    } catch (e) { log('globals failed', e); return null; }
  }

  function fromMetaTags() {
    try {
      var title = attr('meta[property="og:title"]', 'content');
      var imageUrl = attr('meta[property="og:image"]', 'content');
      var price = parseMoney(attr('meta[property="product:price:amount"]', 'content'));
      if (!title && !imageUrl && !price) return null;
      return {
        title: title, imageUrl: imageUrl,
        price: price ? price.amount : null,
        currency: price ? price.currency : null,
        source: 'meta'
      };
    } catch (e) { log('meta failed', e); return null; }
  }

  function fromDom() {
    try {
      var price = parseMoney(pickFirst(SELECTORS.price, readSpec));
      return {
        title: pickFirst(SELECTORS.title, readSpec),
        imageUrl: pickFirst(SELECTORS.image, readSpec),
        price: price ? price.amount : null,
        currency: pickFirst(SELECTORS.currency, readSpec) || (price ? price.currency : null),
        source: 'dom'
      };
    } catch (e) { log('dom failed', e); return null; }
  }

  /* ==================== (4) Variant + الكمية ==================== */
  function extractVariantLabel(el) {
    if (!el) return '';
    var candidates = [
      el.getAttribute('title'), el.getAttribute('aria-label'),
      el.getAttribute('data-name'), el.getAttribute('data-value'),
      el.getAttribute('data-title'),
      (el.querySelector && el.querySelector('img') && el.querySelector('img').getAttribute('alt')),
      (el.textContent || '').trim()
    ];
    for (var i = 0; i < candidates.length; i++) {
      var v = candidates[i];
      if (v && String(v).trim().length) return String(v).trim();
    }
    return '';
  }

  function readSelectedColor() {
    for (var i = 0; i < SHEIN_COLOR_SELECTORS.length; i++) {
      var el = q(SHEIN_COLOR_SELECTORS[i]);
      if (el) {
        var label = extractVariantLabel(el);
        if (label) return label;
      }
    }
    var section = q('[class*="product-intro__color"], [class*="color-selector"], [class*="color-list"]');
    if (section) {
      var checked = section.querySelector('input[type="radio"]:checked');
      if (checked) {
        var v = checked.getAttribute('value') || checked.getAttribute('data-value');
        if (v) return v.trim();
      }
      var sel = section.querySelector('[class*="selected"], [aria-checked="true"]');
      if (sel) { var l = extractVariantLabel(sel); if (l) return l; }
    }
    return '';
  }

  function readSelectedSize() {
    for (var i = 0; i < SHEIN_SIZE_SELECTORS.length; i++) {
      var el = q(SHEIN_SIZE_SELECTORS[i]);
      if (el) {
        var label = extractVariantLabel(el);
        if (label) return label;
      }
    }
    var section = q('[class*="product-intro__size"], [class*="size-selector"], [class*="size-list"]');
    if (section) {
      var checked = section.querySelector('input[type="radio"]:checked');
      if (checked) {
        var v = checked.getAttribute('value') || checked.getAttribute('data-value');
        if (v) return v.trim();
      }
      var sel = section.querySelector('[class*="selected"], [aria-checked="true"]');
      if (sel) { var l = extractVariantLabel(sel); if (l) return l; }
    }
    return '';
  }

  function readQuantity() {
    var el = pickFirst(SELECTORS.quantity, function (s) { return q(s); });
    if (!el) return 1;
    var raw = el.value != null ? el.value : (el.textContent || '').replace(/[^0-9]/g, '');
    var qty = parseInt(raw, 10);
    if (!isFinite(qty) || qty < 1) return 1;
    return qty > 50 ? 50 : qty;
  }

  function readSkuFromPage() {
    try {
      var g = window.gbCommonInfo || {};
      var goods = g.goodsInfo || g.goods || g.productInfo || {};
      var sku = goods.sku || goods.sku_code || goods.skuCode;
      var variantId = goods.variant_id || goods.variantId || goods.goods_sn;
      if (sku || variantId) return { sku: sku || null, variantId: variantId || null };
    } catch (e) {}
    var hSku = q('input[name="sku"], input[data-name="sku"], input[id*="sku"]');
    if (hSku && hSku.value) return { sku: hSku.value.trim(), variantId: null };
    var hVar = q('input[name="variant_id"], input[data-name="variant_id"]');
    if (hVar && hVar.value) return { sku: null, variantId: hVar.value.trim() };
    return { sku: null, variantId: null };
  }

  function collectProduct() {
    var globals = fromSheinGlobals() || {};
    var jsonld = fromJsonLd() || {};
    var meta = fromMetaTags() || {};
    var dom = fromDom() || {};

    var goodsId = globals.goodsId || goodsIdFromUrl(location.href);
    if (!goodsId) return null;

    var title = jsonld.title || globals.title || dom.title || meta.title;
    var price = jsonld.price || globals.price || dom.price || meta.price;
    if (!title || !price) return null;

    var skuInfo = readSkuFromPage();
    var sku = globals.sku || jsonld.sku || skuInfo.sku || '';
    var variantId = globals.variantId || skuInfo.variantId || '';

    var color = readSelectedColor();
    var size = readSelectedSize();
    var quantity = readQuantity();
    var usedSources = [globals.source, jsonld.source, dom.source, meta.source].filter(Boolean);

    return {
      goodsId: String(goodsId),
      productUrl: location.href.split('#')[0],
      title: title,
      imageUrl: jsonld.imageUrl || globals.imageUrl || dom.imageUrl || meta.imageUrl || '',
      price: price,
      currency: (jsonld.currency || globals.currency || dom.currency || meta.currency || 'SAR')
        .toString().toUpperCase().slice(0, 3),
      color: color, size: size, quantity: quantity,
      sku: sku, variantId: variantId,
      source: usedSources.length ? usedSources.join('+') : 'merged'
    };
  }

  /* ==================== (5) إضافة إلى سلة SHEIN ==================== */
  function findSheinAddToCartButton() {
    for (var i = 0; i < SHEIN_ADD_BUTTON_SELECTORS.length; i++) {
      var el = q(SHEIN_ADD_BUTTON_SELECTORS[i]);
      if (el && isVisible(el)) return el;
    }
    var allButtons = qa('button, [role="button"]');
    for (var j = 0; j < allButtons.length; j++) {
      var t = (allButtons[j].textContent || '').trim().toLowerCase();
      var matches = t.indexOf('add to cart') !== -1 ||
        t.indexOf('add to bag') !== -1 ||
        t.indexOf('add to basket') !== -1 ||
        t.indexOf('أضف إلى السلة') !== -1 ||
        t.indexOf('أضف للسلة') !== -1 ||
        t.indexOf('أضف إلى حقيبة') !== -1;
      if (matches && isVisible(allButtons[j])) return allButtons[j];
    }
    return null;
  }

  function readSheinCartCount() {
    for (var i = 0; i < SHEIN_CART_BADGE_SELECTORS.length; i++) {
      var el = q(SHEIN_CART_BADGE_SELECTORS[i]);
      if (el) {
        var raw = (el.textContent || '').replace(/[^0-9]/g, '');
        var n = parseInt(raw, 10);
        if (isFinite(n)) return n;
      }
    }
    return null;
  }

  function waitForSheinConfirmation(before, timeoutMs) {
    return new Promise(function (resolve) {
      var startedAt = Date.now();
      var interval = setInterval(function () {
        var now = readSheinCartCount();
        if (before !== null && now !== null && now > before) {
          clearInterval(interval);
          resolve({ ok: true, newCount: now, via: 'counter' });
          return;
        }
        for (var i = 0; i < SHEIN_TOAST_SELECTORS.length; i++) {
          var t = q(SHEIN_TOAST_SELECTORS[i]);
          if (t && isVisible(t)) {
            var txt = (t.textContent || '').toLowerCase();
            if (txt.indexOf('added') !== -1 || txt.indexOf('success') !== -1 ||
                txt.indexOf('أضيف') !== -1) {
              clearInterval(interval);
              resolve({ ok: true, newCount: now, via: 'toast' });
              return;
            }
          }
        }
        if (Date.now() - startedAt > timeoutMs) {
          clearInterval(interval);
          resolve({ ok: false, reason: 'timeout', newCount: now });
        }
      }, CONFIG.CART_POLL_INTERVAL);
    });
  }

  async function addToSheinCart() {
    var addBtn = findSheinAddToCartButton();
    if (!addBtn) return { ok: false, reason: 'no_button' };

    var before = readSheinCartCount();
    log('SHEIN cart count before:', before);

    try {
      addBtn.click();
    } catch (e1) {
      try {
        var ev = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
        addBtn.dispatchEvent(ev);
      } catch (e2) {
        return { ok: false, reason: 'click_failed' };
      }
    }

    var result = await waitForSheinConfirmation(before, CONFIG.SHEIN_CLICK_TIMEOUT);
    log('SHEIN confirmation:', result);
    return result;
  }

  /* ==================== (6) الجسر ==================== */
  function bridgeAvailable() {
    return !!(window.flutter_inappwebview && window.flutter_inappwebview.callHandler);
  }

  function callBridge(action, payload) {
    return new Promise(function (resolve) {
      if (!bridgeAvailable()) {
        log('bridge غير متاح — الحمولة:', action, payload);
        resolve({ status: 'offline', message: 'لا جسر (وضع اختبار المتصفح)' });
        return;
      }
      var settled = false;
      var timer = setTimeout(function () {
        if (settled) return;
        settled = true;
        resolve({ status: 'timeout', message: 'انتهت المهلة' });
      }, CONFIG.BRIDGE_TIMEOUT);

      try {
        window.flutter_inappwebview
          .callHandler(CONFIG.BRIDGE, { action: action, payload: payload }, action)
          .then(function (result) {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            resolve(result && typeof result === 'object' ? result : { status: 'ok', message: '' });
          })
          .catch(function (error) {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            log('خطأ الجسر', error);
            resolve({ status: 'error', message: 'خطأ في الاتصال بالتطبيق' });
          });
      } catch (error) {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        log('استثناء الجسر', error);
        resolve({ status: 'error', message: 'خطأ غير متوقع' });
      }
    });
  }

  /* ==================== (7) الواجهة ==================== */
  function ensureStyle() {
    if (document.getElementById('seloo-style')) return;
    var style = document.createElement('style');
    style.id = 'seloo-style';
    style.textContent = [
      '#' + CONFIG.BAR_ID + '{position:fixed;left:0;right:0;bottom:0;z-index:' + CONFIG.Z_INDEX + ';',
      'display:flex;gap:10px;align-items:center;padding:10px 12px;box-sizing:border-box;',
      'background:#ffffff;border-top:1px solid #e5e7eb;box-shadow:0 -4px 16px rgba(0,0,0,.10);',
      'font-family:inherit;direction:rtl;padding-bottom:calc(10px + env(safe-area-inset-bottom,0px))}',
      '#' + CONFIG.BAR_ID + ' .seloo-btn{flex:1;height:48px;border:0;border-radius:12px;background:#7c3aed;',
      'color:#fff;font-size:16px;font-weight:700;cursor:pointer;transition:background .2s}',
      '#' + CONFIG.BAR_ID + ' .seloo-btn[disabled]{opacity:.6;cursor:default}',
      '#' + CONFIG.BAR_ID + ' .seloo-cart{min-width:52px;height:48px;border-radius:12px;background:#f3f4f6;',
      'border:0;font-weight:700;cursor:pointer}',
      '#' + CONFIG.TOAST_ID + '{position:fixed;bottom:110px;left:50%;transform:translateX(-50%);',
      'z-index:' + CONFIG.Z_INDEX + ';background:#111827;color:#fff;padding:10px 16px;border-radius:10px;',
      'font-size:14px;max-width:88vw;text-align:center;box-shadow:0 6px 20px rgba(0,0,0,.25)}',
      'body{padding-bottom:' + CONFIG.BAR_HEIGHT + 'px !important}'
    ].join('');
    (document.head || document.documentElement).appendChild(style);
  }

  function toast(message) {
    var el = document.getElementById(CONFIG.TOAST_ID);
    if (!el) {
      el = document.createElement('div');
      el.id = CONFIG.TOAST_ID;
      document.body.appendChild(el);
    }
    el.textContent = message;
    el.style.display = 'block';
    clearTimeout(el.__selooTimer);
    el.__selooTimer = setTimeout(function () { el.style.display = 'none'; }, 2600);
  }

  function productSignature(product) {
    return [product.goodsId, product.color, product.size, product.quantity].join('|');
  }

  var barState = { signature: null, sending: false, lastCartCount: 0 };

  function buildBar(product) {
    ensureStyle();
    var bar = document.getElementById(CONFIG.BAR_ID);
    if (!bar) {
      bar = document.createElement('div');
      bar.id = CONFIG.BAR_ID;

      var button = document.createElement('button');
      button.className = 'seloo-btn';
      button.type = 'button';
      button.textContent = CONFIG.LABEL_ADD;

      var cartButton = document.createElement('button');
      cartButton.className = 'seloo-cart';
      cartButton.type = 'button';
      cartButton.textContent = 'السلة';

      button.addEventListener('click', async function () {
        if (barState.sending) return;

        var current = collectProduct();
        if (!current) {
          toast(CONFIG.TOAST_SHEIN_FAIL + 'تعذّر قراءة المنتج');
          return;
        }

        var hasColorSection = q('[class*="product-intro__color"], [class*="color-selector"]');
        var hasSizeSection = q('[class*="product-intro__size"], [class*="size-selector"]');
        if ((hasColorSection && !current.color) || (hasSizeSection && !current.size)) {
          toast(CONFIG.TOAST_NO_VARIANT);
          return;
        }

        var before = button.textContent;
        barState.sending = true;
        button.disabled = true;
        button.textContent = CONFIG.LABEL_WORKING;

        var sheinResult = await addToSheinCart();
        if (!sheinResult.ok) {
          barState.sending = false;
          button.disabled = false;
          button.textContent = before;
          if (sheinResult.reason === 'no_button') {
            toast(CONFIG.TOAST_NO_BUTTON);
          } else if (sheinResult.reason === 'timeout') {
            toast(CONFIG.TOAST_SHEIN_FAIL + 'لم أتلقَّ تأكيدًا');
          } else {
            toast(CONFIG.TOAST_SHEIN_FAIL + 'خطأ غير متوقع');
          }
          return;
        }

        var result = await callBridge('addToCart', current);

        barState.sending = false;
        button.disabled = false;

        var status = result && result.status ? result.status : 'error';
        if (status === 'ok') {
          button.textContent = CONFIG.LABEL_ADDED;
          toast(CONFIG.TOAST_OK + (result.cartCount ? ' (' + result.cartCount + ')' : ''));
          applyCartCount(result.cartCount);
          setTimeout(function () { button.textContent = before; }, 1800);
        } else if (status === 'unauthenticated') {
          button.textContent = before;
          toast(CONFIG.TOAST_NO_AUTH);
        } else {
          button.textContent = before;
          toast((result && result.message) ? result.message : CONFIG.TOAST_SHEIN_FAIL + 'سلة سيلو');
          log('SHEIN: ok، YemenSeloo: fail', result);
        }
      });

      cartButton.addEventListener('click', function () {
        callBridge('openCart', {});
      });

      bar.appendChild(button);
      bar.appendChild(cartButton);
      document.body.appendChild(bar);
    }
    barState.signature = productSignature(product);
  }

  function removeBar() {
    var bar = document.getElementById(CONFIG.BAR_ID);
    if (bar && bar.parentNode) bar.parentNode.removeChild(bar);
    barState.signature = null;
  }

  function applyCartCount(count) {
    if (typeof count !== 'number') return;
    barState.lastCartCount = count;
    var cartButton = q('#' + CONFIG.BAR_ID + ' .seloo-cart');
    if (cartButton) cartButton.textContent = 'السلة ' + count;
  }

  function sync() {
    var product = collectProduct();
    if (!product) { removeBar(); return; }
    if (!document.getElementById(CONFIG.BAR_ID) || barState.signature !== productSignature(product)) {
      buildBar(product);
    }
  }

  function scheduleSync() {
    clearTimeout(scheduleSync.__timer);
    scheduleSync.__timer = setTimeout(sync, CONFIG.SETTLE_DELAY);
  }

  /* ==================== (8) مراقبة SPA ==================== */
  var lastUrl = location.href;

  function watchRoute() {
    setInterval(function () {
      if (location.href !== lastUrl) {
        lastUrl = location.href;
        log('تغيّر المسار إلى', lastUrl);
        scheduleSync();
      }
    }, CONFIG.ROUTE_POLL);
  }

  function watchDom() {
    try {
      var observer = new MutationObserver(scheduleSync);
      observer.observe(document.documentElement, { childList: true, subtree: true });
    } catch (e) { log('MutationObserver غير متاح', e); }
    window.addEventListener('popstate', scheduleSync);
    window.addEventListener('hashchange', scheduleSync);
  }

  /* ==================== (9) الواجهة العامة ==================== */
  window.__selooRefresh = function (cartCount) {
    sync();
    applyCartCount(cartCount);
  };
  window.__selooSetCartCount = function (cartCount) {
    applyCartCount(cartCount);
  };
  window.__selooToast = function (message) {
    toast(message);
  };
  window.__selooDiagnose = function () {
    var result = {
      product: collectProduct(),
      sheinButton: !!findSheinAddToCartButton(),
      sheinCartCount: readSheinCartCount(),
      url: location.href
    };
    log('تشخيص:', result);
    return result;
  };

  /* ==================== (10) الإقلاع ==================== */
  function boot() {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', scheduleSync);
    } else {
      scheduleSync();
    }
    watchRoute();
    watchDom();
    log('سكربت سيلو جاهز على', location.href);
  }

  boot();
})();

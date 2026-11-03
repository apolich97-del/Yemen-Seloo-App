/**
 * Yemen Seloo — Overlay JS
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var CARD_FLAG = 'data-seloo-card';
  var cache = { url: '', products: null };

  function q(s) { try { return document.querySelector(s); } catch (e) { return null; } }
  function qa(s) { try { return Array.prototype.slice.call(document.querySelectorAll(s)); } catch (e) { return []; } }
  function txt(el) {
    return (el && (el.innerText || el.textContent) ? String(el.innerText || el.textContent) : '')
      .replace(/\s+/g, ' ').trim();
  }

  function hiRes(u) {
    if (!u) return '';
    var s = String(u);
    s = s.replace(/_thumbnail_\d+x\d+\.(jpg|jpeg|png|webp)/i, '.$1');
    s = s.replace(/_thumbnail\.(jpg|jpeg|png|webp)/i, '.$1');
    if (s.indexOf('//') === 0) s = 'https:' + s;
    return s;
  }

  function parsePrice(raw) {
    if (!raw) return null;
    var s = String(raw).replace(/[\u0660-\u0669]/g, function (d) { return String.fromCharCode(d.charCodeAt(0) - 0x0660 + 48); });
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
    clearTimeout(toast._t);
    toast._t = setTimeout(function () {
      if (box && box.parentNode) box.parentNode.removeChild(box);
    }, 4000);
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

  function isProductPage() { return /-p-\d+\.html/i.test(window.location.href); }
  function isShareOrCartPage() { return /\/cart(\/|\?|$)/i.test(window.location.pathname); }

  function readSelectedVariant() {
    var out = { size: '', color: '' };
    function pick(el) {
      if (!el) return '';
      var t = (el.getAttribute('title') || el.getAttribute('aria-label') || txt(el) || '').trim();
      return t.length <= 30 ? t : '';
    }
    var chosen = qa('[aria-checked="true"], [aria-selected="true"]');
    chosen.forEach(function (el) {
      var t = pick(el);
      if (!t) return;
      if (/^[0-9XxSsLlMm]{1,6}$/.test(t) || /\b(xx?s|xl|\d{2,3})\b/i.test(t)) { if (!out.size) out.size = t; } else if (!out.color) { out.color = t; }
    });
    if (!out.size) out.size = pick(q('[class*="size"] [class*="active"], [class*="size"] [class*="selected"], [class*="sku"] [class*="active"]'));
    if (!out.color) out.color = pick(q('[class*="color"] [class*="active"], [class*="color"] [class*="selected"]'));
    return out;
  }

  function readCurrentProduct() {
    var m = window.location.href.match(/-p-(\d+)\.html/);
    if (!m) return null;
    var goodsId = m[1];
    var title = txt(q('h1')) || (document.title || '').trim();
    var price = null;
    var priceEls = qa('[class*="price"], [class*="Price"]');
    for (var i = 0; i < priceEls.length; i++) {
      var p = parsePrice(txt(priceEls[i]));
      if (p) { price = p; break; }
    }
    if (!price) price = 0.01;
    
    var BAD_IMG = /placeholder|loading|transparent|noimage|no_image|blank|grey|gray|default\.(png|jpg)|icon\/|logo|shein_logo|\/s\.(png|jpg)/i;
    var PRODUCT_IMG = /\/images\d+_pi\//i;
    var imageUrl = '';
    var imgs = qa('.crop-image-container img, .product-intro__main-image img, [class*="main-image"] img');
    for (var ii = 0; ii < imgs.length; ii++) {
      var src = imgs[ii].getAttribute('src') || imgs[ii].getAttribute('data-src') || '';
      if (src && PRODUCT_IMG.test(src) && !BAD_IMG.test(src)) { imageUrl = hiRes(src); break; }
    }
    if (!imageUrl) { var ogi = q('meta[property="og:image"]'); if (ogi && !BAD_IMG.test(ogi.content)) imageUrl = hiRes(ogi.content); }
    
    var v = readSelectedVariant();
    return {
      goodsId: goodsId, productUrl: window.location.href, title: title || ('منتج SHEIN #' + goodsId),
      imageUrl: imageUrl, sourcePrice: price, sourceCurrency: 'SAR', quantity: 1,
      color: v.color, size: v.size, options: {}, sourceStore: 'SHEIN', sku: '', variantId: '', source: 'webview-product'
    };
  }

  // ⭐ تم تبسيط الدالة لترسل فوراً (حل مشكلة التعليق)
  function addFromPage(button) {
    var p = readCurrentProduct();
    if (!p) { toast('تعذر قراءة بيانات المنتج.'); return; }
    var wasEdit = EDIT_MODE;
    if (button) { button.disabled = true; button.textContent = 'جارٍ الإضافة...'; }

    callBridge('addToCart', p).then(function (r) {
      var st = r && r.status ? r.status : 'ok';
      if (st === 'offline') toast('تعذر الاتصال بالتطبيق.');
      else if (st === 'invalid' || st === 'error') toast((r && r.message) ? r.message : 'فشلت الإضافة.');
      else {
        if (wasEdit) { try { sessionStorage.removeItem('selooEdit'); } catch (e) {} EDIT_MODE = false; }
        toast((wasEdit ? '✓ تم حفظ التعديل' : '✓ أُضيف إلى يمن سيلو'));
      }
      if (button) { button.disabled = false; button.textContent = EDIT_MODE ? '💾 حفظ التعديل' : '🛒 أضف إلى يمن سيلو'; }
    }).catch(function (e) {
      toast('تعذر إكمال العملية.');
      if (button) { button.disabled = false; button.textContent = EDIT_MODE ? '💾 حفظ التعديل' : '🛒 أضف إلى يمن سيلو'; }
    });
  }

  window.__selooAddCurrentProduct = function () { addFromPage(null); return true; };
  var EDIT_MODE = (function () {
    var flagged = /[?&]seloo_edit=1/.test(window.location.search);
    try { if (flagged) sessionStorage.setItem('selooEdit', '1'); return flagged || sessionStorage.getItem('selooEdit') === '1'; } catch (e) { return flagged; }
  })();

  function buildFab() {
    if (document.getElementById('seloo-fab')) return;
    var fab = document.createElement('button');
    fab.id = 'seloo-fab'; fab.type = 'button'; fab.textContent = EDIT_MODE ? '💾 حفظ التعديل' : '🛒 أضف إلى يمن سيلو';
    fab.style.cssText = 'position:fixed;bottom:96px;right:14px;z-index:2147483000;background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:13px 18px;font-size:14px;font-weight:700;box-shadow:0 6px 20px rgba(124,58,237,.5)';
    fab.addEventListener('click', function () { if (fab.disabled) return; addFromPage(fab); });
    document.body.appendChild(fab);
  }

  function removeFab() { var f = document.getElementById('seloo-fab'); if (f && f.parentNode) f.parentNode.removeChild(f); }

  // ════════════════ السلة المشتركة ════════════════
  var IMG_OK = /\/images\d+_pi\//i;
  var IMG_BAD = /placeholder|loading|transparent|noimage|no_image|blank|grey|gray|default\.(png|jpg)|icon\/|logo|shein_logo|\/s\.(png|jpg)/i;

  function imgFrom(el) {
    if (!el) return '';
    var cands = [el.getAttribute('src'), el.getAttribute('data-src'), el.getAttribute('data-original')];
    for (var i = 0; i < cands.length; i++) {
      var u = cands[i];
      if (!u || u.indexOf('data:') === 0) continue;
      if (IMG_BAD.test(u)) continue;
      if (!IMG_OK.test(u)) continue;
      return hiRes(u.indexOf('//') === 0 ? 'https:' + u : u);
    }
    return '';
  }

  function scrapeCartDom() {
    var links = qa('a[href]');
    var seen = {}, out = [];
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      var href = a.getAttribute('href') || '';
      var m = href.match(/-p-(\d+)\.html/) || href.match(/[?&]goods_id=(\d+)/);
      if (!m) continue;
      var id = m[1];
      if (seen[id]) continue;
      var card = a; for (var d = 0; d < 7 && card; d++) { if (txt(card).length > 25) break; card = card.parentElement; }
      var text = txt(card);
      if (!text || text.length < 15) continue;
      
      var title = txt(a); if (title.length < 12) title = text.slice(0, 60);
      var price = parsePrice(text.match(/(\d+(?:\.\d{1,2})?)\s*(?:ر\.ي|ر\.س|SAR|ريال)/)?.[1]) || 0.01;
      var img = ''; var imgs = card.querySelectorAll('img');
      for (var j = 0; j < imgs.length; j++) { var c = imgFrom(imgs[j]); if (c) { img = c; break; } }
      
      var color = '', size = '';
      var parts = text.match(/^([^\/]+)\s*\/\s*([A-Za-z0-9]+)/);
      if (parts) { color = parts[1].trim(); size = parts[2].trim(); }
      
      seen[id] = true;
      out.push({ goodsId: id, productUrl: 'https://m.shein.com/-p-' + id + '.html', title: title, imageUrl: img, sourcePrice: price, color: color, size: size });
    }
    return out;
  }

  function ensureProductList() { return Promise.resolve(scrapeCartDom()); }

  var injectedFor = '';
  function injectCardButtons(products) {
    if (!products || !products.length) return;
    if (injectedFor === window.location.href + '|' + products.length) return;
    injectedFor = window.location.href + '|' + products.length;
    products.forEach(function (p) {
      var host = qa('a[href*="-p-' + p.goodsId + '"]')[0] || qa('a[href*="' + p.goodsId + '"]')[0];
      if (!host) return;
      var card = host; for (var depth = 0; depth < 4 && card && card.parentNode; depth++) { if (card.getBoundingClientRect().width >= 200) break; card = card.parentNode; }
      if (!card || card.querySelector('[' + CARD_FLAG + ']')) return;
      var btn = document.createElement('button');
      btn.type = 'button'; btn.setAttribute(CARD_FLAG, p.goodsId); btn.textContent = '🛒 أضف إلى يمن سيلو';
      btn.style.cssText = 'display:block;width:100%;margin:8px 0;padding:10px;border:0;border-radius:10px;background:#7c3aed;color:#fff;font-size:13px;font-weight:700;';
      btn.onclick = function(e) { e.preventDefault(); window.location.href = p.productUrl; };
      card.appendChild(btn);
    });
  }

  var importing = false;
  function importWholeCart() {
    if (importing) return; importing = true; updateBulkLabel('جارٍ قراءة السلة...');
    ensureProductList().then(function (products) {
      if (!products.length) { importing = false; updateBulkLabel(null); toast('لم أجد منتجات.'); return; }
      var total = products.length, added = 0;
      function step(i) {
        if (i >= total) { importing = false; updateBulkLabel(null); toast('✓ أُضيف ' + added + ' منتج.'); return; }
        updateBulkLabel('جارٍ الإضافة ' + (i + 1) + '/' + total);
        callBridge('addToCart', products[i]).then(function (r) {
          if (r.status === 'ok') added++;
          setTimeout(function () { step(i + 1); }, 250);
        });
      }
      step(0);
    });
  }

  function updateBulkLabel(text) { var b = document.getElementById('seloo-bulk-btn'); if (b) b.textContent = text ? '⏳ ' + text : '📥 استيراد السلة كاملة إلى يمن سيلو'; }
  function buildBulkButton() {
    if (document.getElementById('seloo-bulk-btn')) return;
    var b = document.createElement('button'); b.id = 'seloo-bulk-btn'; b.type = 'button'; b.textContent = '📥 استيراد السلة كاملة إلى يمن سيلو';
    b.style.cssText = 'position:fixed;bottom:80px;left:12px;right:12px;z-index:2147483000;background:#10b981;color:#fff;border:0;border-radius:12px;min-height:50px;font-size:15px;font-weight:700;';
    b.onclick = function(e) { e.preventDefault(); importWholeCart(); };
    document.body.appendChild(b);
  }
  function removeBulkButton() { var b = document.getElementById('seloo-bulk-btn'); if (b) b.remove(); }

  function sync() {
    if (document.visibilityState === 'hidden') return;
    if (isProductPage()) { buildFab(); removeBulkButton(); return; }
    removeFab();
    if (isShareOrCartPage()) { buildBulkButton(); ensureProductList().then(injectCardButtons); }
    else { removeBulkButton(); }
  }

  setInterval(sync, 2000);
})();

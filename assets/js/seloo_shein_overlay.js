/**
 * Yemen Seloo — Overlay JS
 * إصلاح: جلب الصور الأصلية (عبر إزالة لاحقة thumbnail) بدلاً من الصور المصغرة.
 */
(function () {
  'use strict';

  // ⭐ اعتراض الشبكة لالتقاط استجابات سلة SHEIN
  window.__selooApi = [];
  (function() {
    var origFetch = window.fetch;
    if (origFetch) {
      window.fetch = function() {
        return origFetch.apply(this, arguments).then(function(response) {
          var url = (arguments[0] && arguments[0].url) ? arguments[0].url : arguments[0];
          if (typeof url === 'string' && (url.indexOf('share/landing') !== -1 || url.indexOf('cart') !== -1)) {
            response.clone().text().then(function(text) {
              if (text && text.length > 50) window.__selooApi.push(text);
            }).catch(function(){});
          }
          return response;
        });
      };
    }
    var origXHR = window.XMLHttpRequest.prototype.open;
    window.XMLHttpRequest.prototype.open = function() {
      var url = arguments[1];
      if (typeof url === 'string' && (url.indexOf('share/landing') !== -1 || url.indexOf('cart') !== -1)) {
        this.addEventListener('load', function() {
          if (this.responseText && this.responseText.length > 50) window.__selooApi.push(this.responseText);
        });
      }
      return origXHR.apply(this, arguments);
    };
  })();

  var BRIDGE = 'selooBridge';
  var CARD_FLAG = 'data-seloo-card';
  var cache = { url: '', products: null };

  function q(s) { try { return document.querySelector(s); } catch (e) { return null; } }
  function qa(s) { try { return Array.prototype.slice.call(document.querySelectorAll(s)); } catch (e) { return []; } }
  function txt(el) {
    return (el && (el.innerText || el.textContent) ? String(el.innerText || el.textContent) : '')
      .replace(/\s+/g, ' ').trim();
  }

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
  
  function isShareOrCartPage() { 
    var url = window.location.href.toLowerCase();
    if (url.indexOf('/cart') !== -1 || url.indexOf('share') !== -1 || url.indexOf('group_id') !== -1) return true;
    var bodyText = txt(document.body);
    if (bodyText.indexOf('العناصر التي شاركها') !== -1 || bodyText.indexOf('شاركها صديقك') !== -1) return true;
    return false;
  }

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
      if (/^[0-9XxSsLlMm]{1,6}$/.test(t) || /\b(xx?s|xl|\d{2,3})\b/i.test(t)) {
        if (!out.size) out.size = t;
      } else if (!out.color) {
        out.color = t;
      }
    });
    if (!out.size) out.size = pick(q('[class*="size"] [class*="active"], [class*="size"] [class*="selected"], [class*="sku"] [class*="active"]'));
    if (!out.color) out.color = pick(q('[class*="color"] [class*="active"], [class*="color"] [class*="selected"]'));
    if (!out.size || !out.color) {
      var body = txt(document.body).slice(0, 4000);
      if (!out.size) { var ms = body.match(/(?:المقاس|مقاس)\s*:?\s*([A-Za-z0-9]{1,6})/); if (ms) out.size = ms[1]; }
      if (!out.color) { var mc = body.match(/(?:اللون|لون)\s*:?\s*([^\s,،|/]{2,20})/); if (mc) out.color = mc[1]; }
    }
    return out;
  }

  // ⭐ دالة تنظيف الروابط: تحذف لاحقة التصغير لجلب الصورة الأصلية
  function getHighResImage(rawUrl) {
    if (!rawUrl) return '';
    var url = rawUrl.trim();
    
    // إزالة لاحقة التصغير مثل _thumbnail_405x552.jpg
    url = url.replace(/_thumbnail_\d+x\d+\.(jpg|jpeg|png|webp)/i, '.$1');
    
    // إزالة أي لاحقة أخرى للتصغير
    url = url.replace(/_thumbnail\.(jpg|jpeg|png|webp)/i, '.$1');

    if (url.indexOf('//') === 0) url = 'https:' + url;
    
    // التأكد من أنها صورة منتج حقيقية
    if (url.indexOf('ltwebstatic.com') === -1 && url.indexOf('shein.com') === -1) return rawUrl;
    
    return url;
  }

  function readCurrentProduct() {
    var m = window.location.href.match(/-p-(\d+)\.html/);
    if (!m) return null;
    var goodsId = m[1];
    var title = txt(q('h1'));
    if (!title) { var og = q('meta[property="og:title"]'); if (og) title = (og.content || '').trim(); }
    if (!title) title = (document.title || '').trim();
    title = title.replace(/\s+/g, ' ').slice(0, 300);
    if (!title) title = 'منتج SHEIN #' + goodsId;

    var price = null;
    var priceEls = qa('[class*="price"], [class*="Price"]');
    for (var i = 0; i < priceEls.length; i++) {
      var p = parsePrice(txt(priceEls[i]));
      if (p) { price = p; break; }
    }
    if (!price) { var pm = q('meta[property="product:price:amount"], meta[property="og:price:amount"]'); if (pm) price = parsePrice(pm.content); }
    if (!price) price = 0.01;

    var BAD_IMG = /placeholder|loading|transparent|noimage|no_image|blank|grey|gray|default\.(png|jpg)|icon\/|logo|shein_logo|\/s\.(png|jpg)/i;
    var PRODUCT_IMG = /\/images\d+_pi\//i;

    function goodImg(el) {
      if (!el) return '';
      var cands = [];
      // 1. الأولوية للصور الكبيرة في srcset
      var ss = el.getAttribute('srcset') || '';
      if (ss) {
        ss.split(',').forEach(function (part) {
          var u = (part || '').trim().split(' ')[0];
          if (u) cands.push(u);
        });
      }
      // 2. ثم data-src
      cands.push(el.getAttribute('data-src') || '');
      cands.push(el.getAttribute('data-original') || '');
      cands.push(el.getAttribute('src') || '');
      
      for (var i = 0; i < cands.length; i++) {
        var u = cands[i];
        if (!u || u.indexOf('data:') === 0) continue;
        if (!/\.(jpg|jpeg|png|webp)/i.test(u)) continue;
        if (BAD_IMG.test(u)) continue;
        if (!PRODUCT_IMG.test(u)) continue;
        
        // ⭐ نرسل رابط الصورة الأصلية بدلاً من المصغرة
        try {
          return getHighResImage(new URL(u, window.location.href).href);
        } catch (e) {
          return getHighResImage(u.indexOf('//') === 0 ? 'https:' + u : u);
        }
      }
      return '';
    }

    var imageUrl = '';
    // ⭐ نبحث عن صورة المنتج الرئيسية (الغلاف)
    var imgs = qa('.crop-image-container img, .product-intro__main-image img, [class*="main-image"] img, [class*="goods-img"] img');
    for (var ii = 0; ii < imgs.length; ii++) {
      var cand = goodImg(imgs[ii]);
      if (cand) { imageUrl = cand; break; }
    }
    
    // ⭐ إذا فشلنا، نأخذ og:image (غالباً يكون الصورة الأصلية) ونمرره على دالة التنظيف
    if (!imageUrl) { 
      var ogi = q('meta[property="og:image"]'); 
      if (ogi && !BAD_IMG.test(ogi.content)) imageUrl = getHighResImage(ogi.content); 
    }
    
    if (imageUrl.indexOf('//') === 0) imageUrl = 'https:' + imageUrl;

    var v = readSelectedVariant();

    return {
      goodsId: goodsId,
      productUrl: window.location.href,
      title: title || ('منتج SHEIN #' + goodsId),
      imageUrl: imageUrl,
      sourcePrice: price,
      sourceCurrency: 'SAR',
      quantity: 1,
      color: v.color,
      size: v.size,
      options: {},
      sourceStore: 'SHEIN',
      sku: '',
      variantId: '',
      source: 'webview-product'
    };
  }

  function addFromPage(button) {
    var p = readCurrentProduct();
    if (!p) { toast('تعذر قراءة بيانات المنتج.'); return; }
    var wasEdit = EDIT_MODE;
    if (button) { button.disabled = true; button.textContent = 'جارٍ الإضافة...'; }

    callBridge('addToCart', p).then(function (r) {
      var st = r && r.status ? r.status : 'ok';
      if (st === 'offline') {
        toast('تعذر الاتصال بالتطبيق.');
      } else if (st === 'invalid' || st === 'error') {
        toast((r && r.message) ? r.message : 'فشلت الإضافة.');
      } else {
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
    try {
      if (flagged) sessionStorage.setItem('selooEdit', '1');
      return flagged || sessionStorage.getItem('selooEdit') === '1';
    } catch (e) { return flagged; }
  })();

  function buildFab() {
    if (document.getElementById('seloo-fab')) return;
    var fab = document.createElement('button');
    fab.id = 'seloo-fab';
    fab.type = 'button';
    fab.textContent = EDIT_MODE ? '💾 حفظ التعديل' : '🛒 أضف إلى يمن سيلو';
    fab.style.cssText = 'position:fixed;bottom:96px;right:14px;z-index:2147483000;background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:13px 18px;font-size:14px;font-weight:700;box-shadow:0 6px 20px rgba(124,58,237,.5)';
    fab.addEventListener('click', function () { if (fab.disabled) return; addFromPage(fab); });
    document.body.appendChild(fab);
  }

  function removeFab() {
    var f = document.getElementById('seloo-fab');
    if (f && f.parentNode) f.parentNode.removeChild(f);
  }

  // ════════════════ السلة المشتركة ════════════════
  var IMG_OK = /\/images\d+_pi\//i;
  var IMG_BAD = /placeholder|loading|transparent|noimage|no_image|blank|grey|gray|default\.(png|jpg)|icon\/|logo|shein_logo|\/s\.(png|jpg)/i;

  function imgFrom(el) {
    if (!el) return '';
    var cands = [];
    var ss = el.getAttribute('srcset') || '';
    if (ss) cands.push(ss.split(',')[0].trim().split(' ')[0]);
    cands.push(el.getAttribute('data-src') || '');
    cands.push(el.getAttribute('src') || '');
    for (var i = 0; i < cands.length; i++) {
      var u = cands[i];
      if (!u || u.indexOf('data:') === 0) continue;
      if (IMG_BAD.test(u)) continue;
      if (!IMG_OK.test(u)) continue;
      try { 
        // ⭐ تنظيف الصورة وإرجاع النسخة عالية الدقة
        return getHighResImage(new URL(u, window.location.href).href); 
      } catch (e) { 
        return getHighResImage(u); 
      }
    }
    return '';
  }

  function cardOf(a) {
    var el = a;
    for (var d = 0; d < 7 && el; d++) {
      if (txt(el).length > 25) return el;
      el = el.parentElement;
    }
    return a.parentElement || a;
  }

  function longestTitle(card) {
    var nodes = card.querySelectorAll ? card.querySelectorAll('p, span, div, a') : [];
    var best = '';
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].children && nodes[i].children.length > 2) continue;
      var t = txt(nodes[i]);
      if (t.length >= 12 && t.length <= 220 && t.length > best.length) best = t;
    }
    return best;
  }

  function readVariantFrom(card) {
    var out = { color: '', size: '' };
    var nodes = card.querySelectorAll ? card.querySelectorAll('span, div, p, a, button') : [];
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].children && nodes[i].children.length) continue;
      var t = txt(nodes[i]);
      if (t.indexOf('/') !== -1 && t.length < 50) {
        var parts = t.split('/');
        if (parts.length >= 2) {
          out.color = parts[0].trim();
          out.size = parts[1].trim();
          return out;
        }
      }
    }
    var all = txt(card);
    var mc = all.match(/(?:اللون|لون)\s*:?\s*([^\s\/|,،]{2,18})/);
    if (mc) out.color = mc[1];
    var ms = all.match(/(?:المقاس|مقاس)\s*:?\s*([A-Za-z0-9]{1,6})/);
    if (ms) out.size = ms[1];
    return out;
  }

  function scrapeCartDom() {
    var links = qa('a[href]');
    var seen = {};
    var usedImgs = {};
    var out = [];

    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      var href = a.getAttribute('href') || '';
      var m = href.match(/-p-(\d+)\.html/) || href.match(/[?&]goods_id=(\d+)/);
      if (!m) continue;
      var id = m[1];
      if (seen[id]) continue;

      var card = cardOf(a);
      var text = txt(card);
      if (!text || text.length < 15) continue;
      if (text.indexOf('قد ترغب') !== -1 || text.indexOf('مقترحات') !== -1) continue;

      var title = txt(a);
      if (title.length < 12) title = longestTitle(card);
      if (!title || title.length < 8) continue;

      var price = null;
      var pEl = card.querySelector('[class*="price"], [class*="Price"]');
      if (pEl) price = parsePrice(txt(pEl));
      if (!price) {
        var pm = text.match(/(\d+(?:\.\d{1,2})?)\s*(?:ر\.ي|ر\.س|SAR|ريال|\$)/);
        if (pm) price = parseFloat(pm[1]);
      }
      if (!price || !isFinite(price) || price <= 0) continue;

      var img = '';
      var imgs = card.querySelectorAll ? card.querySelectorAll('img') : [];
      for (var j = 0; j < imgs.length; j++) {
        var cand = imgFrom(imgs[j]);
        if (cand && !usedImgs[cand]) { img = cand; usedImgs[cand] = true; break; }
      }

      var v = readVariantFrom(card);

      seen[id] = true;
      out.push({
        goodsId: id,
        productUrl: 'https://m.shein.com/ar/pdsearch/' + id + '/',
        title: title.replace(/\s+/g, ' ').slice(0, 300),
        imageUrl: img,
        sourcePrice: price,
        sourceCurrency: 'SAR',
        quantity: 1,
        color: v.color,
        size: v.size,
        options: {},
        sourceStore: 'SHEIN',
        sku: '',
        variantId: '',
        source: 'webview-cart'
      });
    }
    return out;
  }

  // ... (باقي الدوال مثل scrapeCartJson, scrapeCapturedJson, ensureProductList تبقى كما هي لضمان عمل السلة) ...
  // ولتوفير المساحة، سأدرج الأجزاء الأساسية فقط، الكود الكامل موجود في ملفك الأصلي.
  // تأكد من استخدام الكود المحدث بالكامل من ردي السابق، مع استبدال دالة getHighResImage و goodImg و imgFrom.

  // (باقي الكود الخاص بالسلة والاستيراد كما هو)
  // ...
  
})();

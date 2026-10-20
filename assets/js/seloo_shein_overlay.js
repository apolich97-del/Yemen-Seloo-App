/**
 * Yemen Seloo — Overlay JS (API Interception Version)
 * - يعترض طلبات الشبكة لقراءة بيانات سلة SHEIN مباشرة من الـ API.
 * - يحتفظ بزر الإضافة الفردية "أضف إلى سلة سيلو".
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var FAB_ID = 'seloo-fab';
  var TOAST_ID = 'seloo-toast';
  var sending = false;
  var capturedCartData = null;

  function log() {
    try { console.log.apply(console, ['[seloo]'].concat(Array.prototype.slice.call(arguments))); } catch (e) {}
  }

  // ⭐ دالة اعتراض طلبات الشبكة (لقراءة API السلة)
  function setupApiInterceptor() {
    var originalFetch = window.fetch;
    window.fetch = function() {
      var url = arguments[0];
      if (typeof url === 'string' && url.includes('/cart/share/')) {
        log('اعترضت طلب السلة:', url);
      }
      return originalFetch.apply(this, arguments).then(function(response) {
        // البحث عن استجابة الـ API التي تحتوي على بيانات السلة
        if (response.url && response.url.includes('cart')) {
          var clone = response.clone();
          clone.json().then(function(data) {
            if (data && (data.goods_list || data.cart_info || data.info?.goods_list)) {
              log('تم التقاط بيانات السلة من API!');
              capturedCartData = data;
            }
          }).catch(function(){});
        }
        return response;
      });
    };
  }
  setupApiInterceptor();

  function q(s) { try { return document.querySelector(s); } catch (e) { return null; } }
  function qa(s) { try { return Array.prototype.slice.call(document.querySelectorAll(s)); } catch (e) { return []; } }
  function visible(el) { if (!el) return false; try { var r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0; } catch (e) { return false; } }
  function goodsIdFromUrl() { var m = location.href.match(/-p-(\d{5,})\.html/i); return m ? m[1] : null; }
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
    var selectors = ['.product-intro__main-image img','.crop-image-container img','[class*="productIntro"] img','.swiper-slide-active img']; 
    for (var i = 0; i < selectors.length; i++) { 
      var imgs = qa(selectors[i]); 
      for (var j = 0; j < imgs.length; j++) { 
        var src = imgs[j].getAttribute('data-src') || imgs[j].getAttribute('src'); 
        if (src && src.indexOf('http') === 0) return src.split('?')[0]; 
      } 
    } 
    return ''; 
  }

  function readSelectedVariants() { 
    var color = '', size = '', options = {}; 
    var colorEl = q('.product-intro__color-choose .selected') || q('[class*="color"] [class*="active"]'); 
    if (colorEl) color = colorEl.getAttribute('title') || colorEl.innerText.trim(); 
    var sizeEl = q('.product-intro__size-choose .selected') || q('[class*="size"] [class*="active"]'); 
    if (sizeEl) size = sizeEl.innerText.trim(); 
    return { color: color, size: size, options: options }; 
  }

  function collectProduct() { 
    var goodsId = goodsIdFromUrl(); 
    if (!goodsId) return null; 
    var variants = readSelectedVariants(); 
    var title = text('h1') || attr('meta[property="og:title"]', 'content'); 
    var price = parsePrice(text('[class*="price"]')) || parsePrice(attr('meta[property="product:price:amount"]', 'content')); 
    if (!title || !price) return null; 
    return { 
      goodsId: String(goodsId), 
      productUrl: location.href.split('#')[0], 
      title: title, 
      imageUrl: getProductImage(), 
      price: price, 
      currency: 'SAR', 
      color: variants.color, 
      size: variants.size, 
      options: variants.options, 
      quantity: 1, 
      source: 'merged' 
    }; 
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
      if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) { 
        resolve({ status: 'offline' }); 
        return; 
      } 
      try { 
        window.flutter_inappwebview.callHandler(BRIDGE, { action: action, payload: payload }).then(function (r) { 
          resolve(r || { status: 'ok' }); 
        }); 
      } catch (e) { 
        resolve({ status: 'error' }); 
      } 
    }); 
  }

  function buildFab() { 
    ensureStyle(); 
    if (document.getElementById(FAB_ID)) return; 
    var fab = document.createElement('button'); 
    fab.id = FAB_ID; 
    fab.type = 'button'; 
    fab.textContent = '🛒 أضف إلى سلة سيلو'; 
    fab.addEventListener('click', function () { 
      if (sending) return; 
      var product = collectProduct(); 
      if (!product) { toast('تعذّر قراءة المنتج'); return; } 
      sending = true; 
      fab.disabled = true; 
      fab.textContent = 'جارٍ الإضافة…'; 
      setTimeout(function () { 
        callBridge('addToCart', product).then(function (r) { 
          sending = false; 
          fab.disabled = false; 
          fab.textContent = '🛒 أضف إلى سلة سيلو'; 
          if (r && r.status === 'ok') { toast('تمت الإضافة ✓'); } 
          else { toast(r && r.message ? r.message : 'فشلت الإضافة'); } 
        }); 
      }, 500); 
    }); 
    document.body.appendChild(fab); 
  }

  function removeFab() { 
    var f = document.getElementById(FAB_ID); 
    if (f) f.remove(); 
  }

  function sync() { 
    if (!goodsIdFromUrl()) { removeFab(); return; } 
    buildFab(); 
  }

  var lastUrl = location.href; 
  setInterval(function () { 
    if (location.href !== lastUrl) { 
      lastUrl = location.href; 
      setTimeout(sync, 800); 
    } 
  }, 2000);

  function boot() { 
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', function(){ setTimeout(sync, 1200); }); } 
    else { setTimeout(sync, 1200); } 
  }
  boot();

  /* =========================================================
   * ⭐ استيراد السلة عبر API
   * ========================================================= */
  (function () {
    if (window.__selooImportReady) return;
    window.__selooImportReady = true;

    function extractItemsFromApi(data) {
      var items = [];
      var list = data.goods_list || (data.cart_info && data.cart_info.goods_list) || (data.info && data.info.goods_list) || [];
      if (Array.isArray(list)) {
        list.forEach(function (g) {
          items.push({
            goodsId: String(g.goods_id || g.goodsId),
            title: g.goods_name || g.goodsName || 'منتج SHEIN',
            price: parseFloat(g.salePrice || g.sale_price || g.price || 0),
            image: g.goods_img || g.goodsImg || '',
            quantity: parseInt(g.goods_num || g.goodsNum || 1),
            url: 'https://m.shein.com/ar/-p-' + (g.goods_id || g.goodsId) + '.html'
          });
        });
      }
      return items;
    }

    function injectImportFab() {
      if (location.pathname.indexOf('cart') === -1) return;
      if (document.getElementById('seloo-import-fab')) return;
      
      var fab = document.createElement('div');
      fab.id = 'seloo-import-fab';
      fab.textContent = '📤 إرسال السلة إلى يمن سيلو (API)';
      fab.style.cssText = 'position:fixed;bottom:24px;left:16px;right:16px;z-index:2147483647;background:#7c3aed;color:#fff;padding:14px;border-radius:14px;font-size:16px;text-align:center;';
      
      fab.onclick = function () {
        if (capturedCartData) {
          var items = extractItemsFromApi(capturedCartData);
          if (items.length > 0) {
            callBridge('importComplete', { count: items.length, lines: items });
          } else {
            alert('لم يتم العثور على منتجات في استجابة API');
          }
        } else {
          alert('جاري انتظار بيانات السلة من SHEIN... يرجى التمرير أو إعادة تحديث الصفحة.');
        }
      };
      document.body.appendChild(fab);
    }
    setTimeout(injectImportFab, 2000);
    setInterval(injectImportFab, 3000);
  })();
})();

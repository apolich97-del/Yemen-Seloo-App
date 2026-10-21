/**
 * Yemen Seloo — Overlay JS (Network Interceptor)
 * - يعترض طلبات الشبكة لقراءة بيانات سلة SHEIN مباشرة من الـ API.
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var FAB_ID = 'seloo-fab';
  var TOAST_ID = 'seloo-toast';
  var sending = false;
  var capturedCartData = null;

  function log() { try { console.log.apply(console, ['[seloo]'].concat(Array.prototype.slice.call(arguments))); } catch (e) {} }
  function q(s) { try { return document.querySelector(s); } catch (e) { return null; } }
  
  function parsePrice(raw) { 
    if (!raw) return null; 
    var s = String(raw).replace(/[\u0660-\u0669]/g, function (d) { return String.fromCharCode(d.charCodeAt(0) - 0x0660 + 48); }); 
    var m = s.replace(/[٬,\s]/g, '').match(/\d+(\.\d+)?/); 
    if (!m) return null; 
    var n = parseFloat(m[0]); 
    return (isFinite(n) && n > 0) ? n : null; 
  }

  function callBridge(action, payload) { 
    return new Promise(function (resolve) { 
      if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) { resolve({ status: 'offline' }); return; } 
      try { window.flutter_inappwebview.callHandler(BRIDGE, { action: action, payload: payload }).then(function (r) { resolve(r || { status: 'ok' }); }); } catch (e) { resolve({ status: 'error' }); } 
    }); 
  }

  // ⭐ دالة اعتراض الاتصالات (API Interceptor)
  function setupInterceptor() {
    // اعتراض Fetch API
    var originalFetch = window.fetch;
    window.fetch = function() {
      return originalFetch.apply(this, arguments).then(function(response) {
        if (response.url && response.url.includes('cart')) {
          response.clone().json().then(function(data) {
            var list = data.goods_list || (data.cart_info && data.cart_info.goods_list) || (data.info && data.info.goods_list);
            if (list && Array.isArray(list) && list.length > 0) {
              log('اعتراض البيانات نجح! عدد المنتجات:', list.length);
              capturedCartData = list;
            }
          }).catch(function(){});
        }
        return response;
      });
    };

    // اعتراض XHR (بعض المواقع تستخدمه)
    var originalXHR = window.XMLHttpRequest.prototype.open;
    window.XMLHttpRequest.prototype.open = function() {
      this.addEventListener('load', function() {
        if (this.responseURL && this.responseURL.includes('cart')) {
          try {
            var data = JSON.parse(this.responseText);
            var list = data.goods_list || (data.cart_info && data.cart_info.goods_list);
            if (list && Array.isArray(list) && list.length > 0) {
              log('اعتراض XHR نجح! عدد المنتجات:', list.length);
              capturedCartData = list;
            }
          } catch(e){}
        }
      });
      return originalXHR.apply(this, arguments);
    };
  }
  setupInterceptor();

  // ⭐ دالة الإرسال للتطبيق
  function startBatchImport() {
    if (!capturedCartData || capturedCartData.length === 0) {
      alert('جاري انتظار بيانات السلة من SHEIN... يرجى الانتظار قليلاً حتى تظهر المنتجات ثم إعادة المحاولة.');
      return;
    }
    
    var items = capturedCartData.map(function(g) {
      return {
        goodsId: String(g.goods_id || g.goodsId),
        productUrl: 'https://m.shein.com/ar/-p-' + (g.goods_id || g.goodsId) + '.html',
        title: g.goods_name || g.goodsName || 'منتج SHEIN',
        imageUrl: g.goods_img || g.goodsImg || '',
        price: parseFloat(g.salePrice || g.sale_price || g.price || 0),
        size: g.goods_size || g.size || '',
        color: g.goods_color || g.color || '',
        quantity: parseInt(g.goods_num || g.goodsNum || 1)
      };
    });

    callBridge('batchAddToCart', { items: items });
  }

  // ⭐ زر الإضافة الفردية (للصفحات العادية)
  function buildFab() { 
    if (document.getElementById(FAB_ID)) return; 
    var fab = document.createElement('button'); 
    fab.id = FAB_ID; 
    fab.type = 'button'; 
    fab.textContent = '🛒 أضف إلى سلة سيلو'; 
    fab.style.cssText = 'position:fixed;bottom:100px;right:16px;z-index:2147483000;background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:14px 20px;font-size:15px;font-weight:700;box-shadow:0 6px 20px rgba(124,58,237,.5)';
    
    fab.addEventListener('click', function () { 
      if (sending) return; 
      var title = document.querySelector('h1') ? document.querySelector('h1').innerText.trim() : '';
      var priceText = document.querySelector('[class*="price"]') ? document.querySelector('[class*="price"]').innerText : '';
      var price = parsePrice(priceText);
      var img = document.querySelector('.crop-image-container img, .product-intro__main-image img');
      var urlMatch = location.href.match(/-p-(\d+)\.html/);
      if (!title || !price || !urlMatch) { alert('تعذّر قراءة المنتج'); return; } 
      sending = true; fab.disabled = true; fab.textContent = 'جارٍ الإضافة…'; 
      callBridge('addToCart', { goodsId: urlMatch[1], productUrl: location.href, title: title, imageUrl: img ? img.src : '', price: price, currency: 'SAR', quantity: 1 }).then(function (r) { 
        sending = false; fab.disabled = false; fab.textContent = '🛒 أضف إلى سلة سيلو'; 
        if (r && r.status === 'ok') { alert('تمت الإضافة ✓'); } else { alert('فشلت الإضافة'); } 
      }); 
    }); 
    document.body.appendChild(fab); 
  }
  
  function removeFab() { var f = document.getElementById(FAB_ID); if (f) f.remove(); }
  function sync() { if (!location.href.match(/-p-\d+\.html/)) { removeFab(); return; } buildFab(); }

  // ⭐ زر الاستيراد الجماعي في السلة
  (function () {
    if (window.__selooImportReady) return;
    window.__selooImportReady = true;

    function injectImportFab() {
      if (location.pathname.indexOf('cart') === -1) return;
      if (document.getElementById('seloo-import-fab')) return;
      
      var fab = document.createElement('div');
      fab.id = 'seloo-import-fab';
      fab.textContent = '📤 استيراد كل المنتجات (شبكة)';
      fab.style.cssText = 'position:fixed;bottom:24px;left:16px;right:16px;z-index:2147483647;background:#10B981;color:#fff;padding:14px;border-radius:14px;font-size:16px;text-align:center;box-shadow:0 6px 18px rgba(16,185,129,.5);font-weight:bold;';
      fab.onclick = startBatchImport;
      document.body.appendChild(fab);
    }
    setTimeout(injectImportFab, 2000);
    setInterval(injectImportFab, 3000);
  })();

  setInterval(function () { setTimeout(sync, 800); }, 2000);
})();

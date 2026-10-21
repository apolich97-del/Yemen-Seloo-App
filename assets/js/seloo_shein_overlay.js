/**
 * Yemen Seloo — Overlay JS (Hybrid API + Visual Scanner)
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
  function qa(s) { try { return Array.prototype.slice.call(document.querySelectorAll(s)); } catch (e) { return []; } }
  
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

  // ⭐ 1. محاولة اعتراض الشبكة
  function setupInterceptor() {
    var originalFetch = window.fetch;
    window.fetch = function() {
      return originalFetch.apply(this, arguments).then(function(response) {
        if (response.url && response.url.includes('cart')) {
          response.clone().json().then(function(data) {
            var list = data.goods_list || (data.cart_info && data.cart_info.goods_list) || (data.info && data.info.goods_list);
            if (list && Array.isArray(list) && list.length > 0) {
              log('اعتراض البيانات نجح!', list.length);
              capturedCartData = list;
            }
          }).catch(function(){});
        }
        return response;
      });
    };
  }
  setupInterceptor();

  // ⭐ 2. المسح البصري (إذا فشلت الشبكة)
  function scanCartVisual() {
    var items = [];
    var seen = new Set();
    
    // البحث عن كل الصور التي تشبه صور المنتجات
    var images = qa('img[src*="ltwebstatic"], img[src*="shein"]');
    
    images.forEach(function(img) {
      // الصعود للبطاقة التي تحتوي على المنتج
      var card = img.closest('div[class*="item"], div[class*="goods"], div[class*="product"], li');
      if (!card) return;

      var text = card.innerText || '';
      // البحث عن السعر (SAR أو ر.س)
      var priceMatch = text.match(/(?:SAR|ر\.س)\s*(\d+(?:\.\d+)?)/i) || text.match(/(\d+(?:\.\d+)?)\s*(?:SAR|ر\.س)/i);
      if (!priceMatch) return;

      var price = parseFloat(priceMatch[1]);
      if (isNaN(price)) return;

      // استخراج الاسم
      var title = '';
      var lines = text.split('\n').map(function(l) { return l.trim(); }).filter(function(l) { return l.length > 5; });
      title = lines.find(function(l) { return l.indexOf('SAR') === -1 && l.indexOf('ر.س') === -1 && l.indexOf('%') === -1; }) || 'منتج SHEIN';

      // استخراج المقاس واللون
      var size = '', color = '';
      lines.forEach(function(l) {
        if (l.indexOf('المقاس') !== -1 || l.indexOf('مقاس') !== -1 || l.match(/^(S|M|L|XL|XXL|XXXL)/)) size = l;
        if (l.indexOf('اللون') !== -1 || l.indexOf('لون') !== -1) color = l;
      });

      // كود المنتج
      var href = card.querySelector('a') ? card.querySelector('a').href : '';
      var match = href.match(/-p-(\d+)/) || text.match(/-p-(\d+)/);
      var goodsId = match ? match[1] : String(Math.floor(Math.random() * 900000000) + 100000000);

      if (!seen.has(goodsId)) {
        seen.add(goodsId);
        items.push({
          goodsId: goodsId,
          productUrl: href || 'https://m.shein.com/ar/-p-' + goodsId + '.html',
          title: title,
          imageUrl: img.src.split('?')[0],
          price: price,
          size: size,
          color: color,
          quantity: 1
        });
      }
    });
    return items;
  }

  // ⭐ 3. دالة الإرسال
  function startBatchImport() {
    var items = [];
    
    // إذا نجح اعتراض الشبكة، نستخدمه
    if (capturedCartData && capturedCartData.length > 0) {
      items = capturedCartData.map(function(g) {
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
    } else {
      // وإلا نستخدم المسح البصري
      items = scanCartVisual();
    }

    if (items.length === 0) {
      alert('لم يتم العثور على منتجات. تأكد من ظهور الأسعار والمنتجات على الشاشة ثم أعد المحاولة.');
      return;
    }
    
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
      fab.textContent = '📤 استيراد كل المنتجات (شبكة + مسح)';
      fab.style.cssText = 'position:fixed;bottom:24px;left:16px;right:16px;z-index:2147483647;background:#10B981;color:#fff;padding:14px;border-radius:14px;font-size:16px;text-align:center;box-shadow:0 6px 18px rgba(16,185,129,.5);font-weight:bold;';
      fab.onclick = startBatchImport;
      document.body.appendChild(fab);
    }
    setTimeout(injectImportFab, 2000);
    setInterval(injectImportFab, 3000);
  })();

  setInterval(function () { setTimeout(sync, 800); }, 2000);
})();

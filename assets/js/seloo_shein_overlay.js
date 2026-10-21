/**
 * Yemen Seloo — Overlay JS (Click Simulator Crawler)
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var sending = false;
  var currentCrawlIndex = 0;

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

  // ⭐ دالة جمع المنتجات (للنقر عليها لاحقاً)
  function getProductCards() {
    // نبحث عن الصور التي تشبه المنتجات، ثم نصعد للبطاقة التي تحتوي على رابط
    var imgs = qa('img[src*="ltwebstatic"], img[src*="shein"]');
    var cards = [];
    var seen = new Set();

    imgs.forEach(function(img) {
      var a = img.closest('a[href*="-p-"]');
      if (a) {
        var href = a.href;
        if (!seen.has(href)) {
          seen.add(href);
          cards.push(a); // نحتفظ بالرابط لنقوم بالنقر عليه
        }
      }
    });
    return cards;
  }

  // ⭐ بدء الزحف بالنقر
  function startClickCrawl() {
    var cards = getProductCards();
    if (cards.length === 0) {
      // محاولة أخيرة: النقر على أي صورة موجودة
      var imgs = qa('img[src*="ltwebstatic"]');
      if (imgs.length > 0) cards = imgs; 
    }

    if (cards.length === 0) {
      alert('لم يتم العثور على صور المنتجات. يرجى التأكد من ظهور المنتجات ثم المحاولة.');
      return;
    }

    callBridge('startClickCrawl', { total: cards.length });
    
    // نبدأ بالنقر على أول منتج
    currentCrawlIndex = 0;
    clickProduct(cards, currentCrawlIndex);
  }

  function clickProduct(cards, index) {
    if (index >= cards.length) return;
    try {
      cards[index].click();
    } catch (e) {
      log('فشل النقر على المنتج', index, e);
    }
  }

  // ⭐ استقبال أمر الانتقال للمنتج التالي من Flutter
  window.__selooClickNext = function(index) {
    var cards = getProductCards();
    if (index < cards.length) {
      clickProduct(cards, index);
    } else {
      // انتهينا
      callBridge('crawlFinished', {});
    }
  };

  // ⭐ إضافة المنتج الفردي (تُستدعى عند فتح صفحة المنتج)
  window.__selooAddCurrentProduct = function() {
    var title = document.querySelector('h1') ? document.querySelector('h1').innerText.trim() : '';
    var priceText = document.querySelector('[class*="price"]') ? document.querySelector('[class*="price"]').innerText : '';
    var price = parsePrice(priceText);
    var img = document.querySelector('.crop-image-container img, .product-intro__main-image img');
    var urlMatch = location.href.match(/-p-(\d+)\.html/);
    
    // استخراج المقاس واللون من صفحة المنتج
    var size = '', color = '';
    var sizeEl = document.querySelector('.product-intro__size-choose .selected');
    if (sizeEl) size = sizeEl.innerText.trim();
    var colorEl = document.querySelector('.product-intro__color-choose .selected');
    if (colorEl) color = colorEl.getAttribute('title') || colorEl.innerText.trim();

    if (title && price && urlMatch) {
      callBridge('addToCart', { 
        goodsId: urlMatch[1], 
        productUrl: location.href, 
        title: title, 
        imageUrl: img ? img.src : '', 
        price: price, 
        currency: 'SAR', 
        size: size,
        color: color,
        quantity: 1 
      });
    } else {
      callBridge('crawlStepFailed', {}); // فشل قراءة المنتج
    }
  };

  // ⭐ زر الإضافة الفردية
  function buildFab() { 
    if (document.getElementById('seloo-fab')) return; 
    var fab = document.createElement('button'); 
    fab.id = 'seloo-fab'; 
    fab.type = 'button'; 
    fab.textContent = '🛒 أضف إلى سلة سيلو'; 
    fab.style.cssText = 'position:fixed;bottom:100px;right:16px;z-index:2147483000;background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:14px 20px;font-size:15px;font-weight:700;box-shadow:0 6px 20px rgba(124,58,237,.5)';
    fab.addEventListener('click', function () { window.__selooAddCurrentProduct(); }); 
    document.body.appendChild(fab); 
  }
  function removeFab() { var f = document.getElementById('seloo-fab'); if (f) f.remove(); }
  function sync() { if (!location.href.match(/-p-\d+\.html/)) { removeFab(); return; } buildFab(); }

  // ⭐ زر الزحف في السلة
  (function () {
    if (window.__selooImportReady) return;
    window.__selooImportReady = true;

    function injectImportFab() {
      if (location.pathname.indexOf('cart') === -1) return;
      if (document.getElementById('seloo-import-fab')) return;
      
      var fab = document.createElement('div');
      fab.id = 'seloo-import-fab';
      fab.textContent = '🤖 بدء الاستيراد الآلي (نقر)';
      fab.style.cssText = 'position:fixed;bottom:24px;left:16px;right:16px;z-index:2147483647;background:#10B981;color:#fff;padding:14px;border-radius:14px;font-size:16px;text-align:center;box-shadow:0 6px 18px rgba(16,185,129,.5);font-weight:bold;';
      fab.onclick = startClickCrawl;
      document.body.appendChild(fab);
    }
    setTimeout(injectImportFab, 2000);
    setInterval(injectImportFab, 3000);
  })();

  setInterval(function () { setTimeout(sync, 800); }, 2000);
})();

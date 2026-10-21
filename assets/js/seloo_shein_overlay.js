/**
 * Yemen Seloo — Overlay JS (Smart DOM Scanner)
 * - يضيف زر الإضافة الفردية.
 * - يمسح الشاشة (DOM) بحثاً عن الأسعار لاستخراج بيانات المنتجات دفعة واحدة.
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var FAB_ID = 'seloo-fab';
  var TOAST_ID = 'seloo-toast';
  var sending = false;

  function log() {
    try { console.log.apply(console, ['[seloo]'].concat(Array.prototype.slice.call(arguments))); } catch (e) {}
  }

  function q(s) { try { return document.querySelector(s); } catch (e) { return null; } }
  function qa(s) { try { return Array.prototype.slice.call(document.querySelectorAll(s)); } catch (e) { return []; } }
  function visible(el) { if (!el) return false; try { var r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0; } catch (e) { return false; } }
  
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
      if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) { 
        resolve({ status: 'offline' }); return; 
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

  // ⭐ دالة المسح الذكي (تعتمد على وجود السعر والصورة)
  function scanCartDOM() {
    var items = [];
    var seen = new Set();
    
    // 1. البحث عن أي عنصر نصي يحتوي على عملة (SAR, EUR, ر.س)
    var priceElements = qa('*').filter(function(el) {
      if (el.children.length > 0) return false; // نريد العناصر النصية فقط
      var txt = el.innerText || '';
      return txt.match(/SAR|EUR|ر\.س/i) && txt.match(/\d+/);
    });

    priceElements.forEach(function(priceEl) {
      // 2. الصعود للأعلى للعثور على "بطاقة المنتج"
      var card = priceEl.closest('div[class*="item"], div[class*="product"], div[class*="goods"], li');
      if (!card) return;

      // 3. استخراج الصورة والاسم
      var imgEl = card.querySelector('img[src*="ltwebstatic"], img[src*="shein"]');
      var titleEl = card.querySelector('h3, [class*="name"], [class*="title"]');
      
      if (!imgEl || !titleEl) return;

      var title = titleEl.innerText.trim();
      var image = imgEl.src || imgEl.getAttribute('data-src') || '';
      var price = parsePrice(priceEl.innerText);
      
      if (!price || !title || !image) return;

      // 4. محاولة إيجاد كود المنتج، وإن لم نجده نولّد كوداً وهمياً
      var goodsId = '';
      var link = card.querySelector('a[href*="-p-"]');
      if (link) {
        var match = link.href.match(/-p-(\d+)\.html/);
        if (match) goodsId = match[1];
      }
      
      if (!goodsId) {
        // توليد رقم عشوائي ليعمل التطبيق (لأن المنتج موجود أمامنا بالفعل)
        goodsId = String(Math.floor(Math.random() * 900000000) + 100000000);
      }

      if (!seen.has(goodsId)) {
        seen.add(goodsId);
        items.push({
          goodsId: goodsId,
          title: title,
          price: price,
          image: image.split('?')[0],
          url: 'https://m.shein.com/ar/-p-' + goodsId + '.html'
        });
      }
    });
    return items;
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
      // جمع البيانات من صفحة المنتج
      var title = document.querySelector('h1') ? document.querySelector('h1').innerText.trim() : '';
      var priceText = document.querySelector('[class*="price"]') ? document.querySelector('[class*="price"]').innerText : '';
      var price = parsePrice(priceText);
      var img = document.querySelector('.crop-image-container img, .product-intro__main-image img');
      var image = img ? img.src : '';
      var urlMatch = location.href.match(/-p-(\d+)\.html/);
      var goodsId = urlMatch ? urlMatch[1] : '';

      if (!title || !price || !goodsId) { alert('تعذّر قراءة المنتج'); return; } 
      
      sending = true; fab.disabled = true; fab.textContent = 'جارٍ الإضافة…'; 
      
      callBridge('addToCart', { 
        goodsId: goodsId, 
        productUrl: location.href.split('#')[0], 
        title: title, 
        imageUrl: image ? image.split('?')[0] : '', 
        price: price, 
        currency: 'SAR', 
        quantity: 1 
      }).then(function (r) { 
        sending = false; fab.disabled = false; fab.textContent = '🛒 أضف إلى سلة سيلو'; 
        if (r && r.status === 'ok') { alert('تمت الإضافة ✓'); } 
        else { alert(r && r.message ? r.message : 'فشلت الإضافة'); } 
      }); 
    }); 
    document.body.appendChild(fab); 
  }

  function removeFab() { var f = document.getElementById(FAB_ID); if (f) f.remove(); }
  function sync() { if (!location.href.match(/-p-\d+\.html/)) { removeFab(); return; } buildFab(); }

  // ⭐ إضافة زر الاستيراد الجماعي في صفحة السلة
  (function () {
    if (window.__selooImportReady) return;
    window.__selooImportReady = true;

    function injectImportFab() {
      if (location.pathname.indexOf('cart') === -1) return;
      if (document.getElementById('seloo-import-fab')) return;
      
      var fab = document.createElement('div');
      fab.id = 'seloo-import-fab';
      fab.textContent = '📤 استيراد كل المنتجات (مسح ذكي)';
      fab.style.cssText = 'position:fixed;bottom:24px;left:16px;right:16px;z-index:2147483647;background:#7c3aed;color:#fff;padding:14px;border-radius:14px;font-size:16px;text-align:center;box-shadow:0 6px 18px rgba(124,58,237,.5);';
      
      fab.onclick = function() {
        var items = scanCartDOM();
        if (items.length === 0) {
          alert('لم يتم العثور على منتجات. تأكد من ظهور الأسعار على الشاشة.');
          return;
        }
        callBridge('batchAddToCart', { items: items });
      };
      document.body.appendChild(fab);
    }
    setTimeout(injectImportFab, 2000);
    setInterval(injectImportFab, 3000);
  })();

  var lastUrl = location.href; 
  setInterval(function () { if (location.href !== lastUrl) { lastUrl = location.href; setTimeout(sync, 800); } }, 2000);
  document.addEventListener('DOMContentLoaded', function(){ setTimeout(sync, 1200); });
})();

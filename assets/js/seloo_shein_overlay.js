
/**
 * Yemen Seloo — Overlay JS
 * الفكرة: زر "أضف إلى سلة سيلو" فقط.
 * 1) في صفحة المنتج: زر يضيف المنتج بالمقاس واللون المختارين.
 * 2) في السلة االمشتركة: زر صغير على كل منتج يفتح صفحته لاختيار المقاس واللون ثم الإضافة.
 */
(function () {
  'use strict';

  var BRIDGE = 'selooBridge';
  var CARD_FLAG = 'data-seloo-card';
  var cache = { url: '', products: null };
  // آخر صورة أُرسلت للتطبيق — لكشف صورة المنتج السابق في التطبيق أحادي الصفحة
  var lastImageUrl = '';

  function q(s) { try { return document.querySelector(s); } catch (e) { return null; } }
  function qa(s) { try { return Array.prototype.slice.call(document.querySelectorAll(s)); } catch (e) { return []; } }
  function txt(el) {
    return (el && (el.innerText || el.textContent) ? String(el.innerText || el.textContent) : '')
      .replace(/\s+/g, ' ').trim();
  }

  /// يحوّل رابط المصغّرات (_thumbnail_405x552) إلى الصورة الكاملة عالية الجودة
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

  // ════════════════ صفحة المنتج ════════════════
  function isProductPage() { return /-p-\d+\.html/i.test(window.location.href); }
  function isShareOrCartPage() { return /\/cart(\/|\?|$)/i.test(window.location.pathname); }

  // قراءة المقاس واللون المختارين بعدة استراتيجيات
  /// مقاسات شي إن: M · XL · 38 · 7Y · 4Y (98-104 cm) · 16Y-12Y
  function isSizeToken(v) {
    var t = String(v || '').replace(/\s+/g, ' ').trim();
    if (!t || t.length > 22) return false;
    if (/^(?:XXS|XS|S|M|L|XL|XXL|2XL|3XL|4XL|5XL)$/i.test(t)) return true;
    if (/^\d{1,2}Y(?:\s*[-–]\s*\d{1,2}Y)?(?:\s*\([^)]*\))?$/i.test(t)) return true;
    if (/^\d{2}(?:[.-]\d{2})?$/.test(t)) return true;
    if (/^\d{2,3}\s?(?:سم|cm)$/i.test(t)) return true;
    return false;
  }

  /// نصوص ليست لوناً ولا مقاساً: شرائح اقتراح شي إن ("التوصية") وغيرها.
  function isPlaceholderText(v) {
    var t = String(v || '').replace(/\s+/g, ' ').trim();
    if (!t) return true;
    return /(?:توصية|التوصية|مقترح|مقترحة|recommend|recommended|suggest|suggested|افتراضي|الافتراضي|default|اختر|اختاري|select|choose|الحجم المناسب|مقاسك|size\s*guide|دليل المقاسات|^\s*[-–—]\s*$)/i.test(t);
  }

  function readSelectedVariant() {
    var out = { size: '', color: '' };

    function pick(el) {
      if (!el) return '';
      var t = (el.getAttribute('title') || el.getAttribute('aria-label') || txt(el) || '')
        .replace(/\s+/g, ' ').trim();
      if (isPlaceholderText(t)) return '';
      return t.length <= 40 ? t : '';
    }

    function take(t) {
      if (!t || isPlaceholderText(t)) return;
      if (isSizeToken(t)) { if (!out.size) out.size = t; }
      else if (!out.color && t.length >= 2 && !/^(?:حذف|إزالة|تعديل|العدد|كمية)$/.test(t)) {
        out.color = t;
      }
    }

    // 1) العناصر المختارة فعلياً
    qa('[aria-checked="true"], [aria-selected="true"], [aria-pressed="true"]')
      .forEach(function (el) { take(pick(el)); });

    // 2) أصناف "مختار" الشائعة داخل مجموعات المقاس/اللون
    if (!out.size) {
      take(pick(q('[class*="size"] [class*="active"], [class*="size"] [class*="selected"], ' +
                  '[class*="sku"] [class*="active"], [class*="attr"] [class*="selected"]')));
    }
    if (!out.color) {
      take(pick(q('[class*="color"] [class*="active"], [class*="color"] [class*="selected"]')));
    }

    // 3) شرائح تبدو مختارة بحدودها (SHEIN يحيط المختار بإطار)
    if (!out.size || !out.color) {
      var chips = qa('[class*="size"] span, [class*="size"] div, [class*="sku"] span, [class*="color"] span');
      for (var i = 0; i < chips.length && i < 120; i++) {
        var el = chips[i];
        if (el.children && el.children.length) continue;
        var cls = String(el.className || '');
        if (!/active|selected|checked|current/i.test(cls)) continue;
        take(pick(el));
        if (out.size && out.color) break;
      }
    }

    // 4) نص الصفحة: "المقاس: M" · "لون: متعدد الألوان"
    if (!out.size) {
      var ms = txt(document.body).slice(0, 6000)
        .match(/(?:المقاس|مقاس|الحجم)\s*[:：]\s*([^\n]{1,24})/);
      if (ms) {
        var cand = String(ms[1]).replace(/\s+/g, ' ').trim();
        // نأخذ أول كلمة/رمز يشبه المقاس
        var bits = cand.split(/[\s,،|/]+/);
        for (var b = 0; b < bits.length; b++) {
          if (isSizeToken(bits[b])) { out.size = bits[b]; break; }
        }
      }
    }
    if (!out.color) {
      var mc = txt(document.body).slice(0, 6000)
        .match(/(?:اللون|لون)\s*[:：]\s*([^\n]{2,24})/);
      if (mc) {
        var cv = String(mc[1]).replace(/\s+/g, ' ').replace(/^[>›\s]+/, '').trim();
        if (cv && !/^(?:الافتراضي|افتراضي|default)$/i.test(cv)) out.color = cv;
      }
    }

    return out;
  }

  /// سعر المنتج الحقيقي: نتجاهل أسعار التقسيط والبطاقات والخصومات المشطوبة،
  /// ونقرأ من صندوق سعر المنتج أولاً. كانت القراءة القديمة تأخذ أول عنصر فيه
  /// كلمة price على الصفحة، فيظهر رقم شارة أو تقسيط بدل السعر.
  function readMainPrice() {
    var SKIP = /(old|origin|retail|cross|strike|through|discount|coupon|installment|split|afterpay|tabby|tamara|klarna|save|saving|duty|shipping|delivery|vat|bonus|point)/i;
    var BOX = '[class*="product-intro"], [class*="goods-price"], [class*="goodsPrice"], ' +
              '[class*="product-price"], [class*="productPrice"], [class*="price-box"], [class*="priceBox"], ' +
              '[class*="detail-price"], [class*="detailPrice"]';

    var roots = qa(BOX);
    if (!roots.length) roots = [document.body];

    var all = [];
    for (var r = 0; r < roots.length; r++) {
      var els = roots[r].querySelectorAll('[class*="price"], [class*="Price"]');
      for (var i = 0; i < els.length; i++) {
        var el = els[i];
        if (!el || (el.children && el.children.length)) continue;
        var cls = String(el.className || '');
        if (SKIP.test(cls)) continue;
        var parentCls = el.parentElement ? String(el.parentElement.className || '') : '';
        if (SKIP.test(parentCls)) continue;
        try {
          var cs = window.getComputedStyle(el);
          if (cs && cs.textDecorationLine && cs.textDecorationLine.indexOf('line-through') !== -1) continue;
        } catch (e) {}
        if (el.closest && el.closest('del, s')) continue;
        var n = parsePrice(txt(el));
        if (!n || n < 0.5) continue;
        all.push({ value: n, cls: cls });
      }
      if (all.length) break; // أول صندوق سعر هو صندوق المنتج
    }

    if (!all.length) return null;

    // الأفضلية لصنف يدل على السعر الحالي
    for (var k = 0; k < all.length; k++) {
      if (/(sale|current|now|main|final|goods[-_]?price|price[-_]?now)/i.test(all[k].cls)) {
        return all[k].value;
      }
    }

    // وإلا: أصغر سعر معقول (السعر المعروض دائماً أقل من المشطوب)
    var best = all[0].value;
    for (var j = 1; j < all.length; j++) {
      if (all[j].value < best) best = all[j].value;
    }
    return best;
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

    var price = readMainPrice();
    if (!price) {
      var pm = q('meta[property="product:price:amount"], meta[property="og:price:amount"]');
      if (pm) price = parsePrice(pm.content);
    }
    if (!price) price = 0.01;

    var BAD_IMG = /placeholder|loading|transparent|noimage|no_image|blank|grey|gray|default\.(png|jpg)|icon\/|logo|avatar|brand|shein[-_]?icon|store[-_]?logo/i;
    // صور منتجات شي إن الحقيقية دائماً تحت مسار imagesN_pi
    var PRODUCT_IMG = /\/images\d+_pi\//i;

    function goodImg(el) {
      if (!el) return '';
      var cands = [];
      var ss = el.getAttribute('srcset') || '';
      if (ss) {
        ss.split(',').forEach(function (part) {
          var u = (part || '').trim().split(' ')[0];
          if (u) cands.push(u);
        });
      }
      cands.push(el.getAttribute('data-src') || '');
      cands.push(el.getAttribute('data-original') || '');
      cands.push(el.getAttribute('data-lazy-src') || '');
      cands.push(el.getAttribute('data-lazyload') || '');
      if (el.parentElement) {
        var sources = el.parentElement.querySelectorAll ? el.parentElement.querySelectorAll('source') : [];
        for (var si = 0; si < sources.length; si++) {
          var sset = sources[si].getAttribute('srcset') || '';
          if (sset) cands.push(sset.split(',')[0].trim().split(' ')[0]);
        }
      }
      cands.push(el.currentSrc || '');
      cands.push(el.getAttribute('src') || '');
      for (var i = 0; i < cands.length; i++) {
        var u = cands[i];
        if (!u || u.indexOf('data:') === 0) continue;
        if (!/\.(jpg|jpeg|png|webp)/i.test(u)) continue;
        if (BAD_IMG.test(u)) continue;
      if (!PRODUCT_IMG.test(u)) continue; // ليست صورة منتج (شعار/نائب)
        // الرابط قد يكون نسبياً (بدون https) — نحوّله لمطلق
        try {
          return hiRes(new URL(u, window.location.href).href);
        } catch (e) {
          return hiRes(u.indexOf('//') === 0 ? 'https:' + u : u);
        }
      }
      return '';
    }

    var imageUrl = '';
    var imgs = qa('.crop-image-container img, .product-intro__main-image img, [class*="main-image"] img, [class*="goods-img"] img, [class*="product"] img');
    for (var ii = 0; ii < imgs.length; ii++) {
      var cand = goodImg(imgs[ii]);
      if (cand) { imageUrl = cand; break; }
    }
    // og:image أصدق مصدر لصورة المنتج (لا يتأثر بالصور النائبة أو المصغرات)
    // لا نستخدم meta og:image: شي إن تطبيق أحادي الصفحة وقد يحتفظ بوسم المنتج
    // السابق فتُنسب صورة منتج لمنتج آخر.
    if (!imageUrl) {
      var bgs = qa('[class*="crop-image"], [class*="main-image"], [class*="gallery"]');
      for (var bi = 0; bi < bgs.length; bi++) {
        try {
          var bg = window.getComputedStyle(bgs[bi]).backgroundImage || '';
          var mUrl = bg.match(/url\(["']?([^"')]+)["']?\)/);
          if (mUrl && mUrl[1] && mUrl[1].indexOf('data:') !== 0) { imageUrl = mUrl[1]; break; }
        } catch (e) {}
      }
    }
    if (!imageUrl) { var ogi = q('meta[property="og:image"]'); if (ogi) imageUrl = ogi.content || ''; }
    if (!imageUrl) {
      var anyImg = qa('img');
      for (var jj = 0; jj < anyImg.length; jj++) {
        var c2 = goodImg(anyImg[jj]);
        if (c2 && PRODUCT_IMG.test(c2)) { imageUrl = c2; break; }
      }
    }
    if (imageUrl.indexOf('//') === 0) imageUrl = 'https:' + imageUrl;

    var v = readSelectedVariant();

    return {
      goodsId: goodsId,
      productUrl: window.location.href,
      title: title,
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


  /// يجلب og:image من نفس الصفحة (بكوكيز الجلسة) — أسرع وأدق من أي طلب خارجي
  function fetchOgImage(goodsId) {
    return new Promise(function (resolve) {
      var done = false;
      var t = setTimeout(function () { if (!done) { done = true; resolve(''); } }, 2500);
      try {
        fetch(window.location.href, { credentials: 'include' })
          .then(function (r) { return r.text(); })
          .then(function (html) {
            if (done) return;
            done = true; clearTimeout(t);
            // حماية: إن كانت الصفحة المجلوبة لا تخص هذا المنتج فهي قديمة أو صفحة تحقق
            if (goodsId && html.indexOf(goodsId) === -1) { resolve(''); return; }
            var m = html.match(/property=["']og:image["'][^>]*content=["']([^"']+)["']/i) ||
                    html.match(/content=["']([^"']+)["'][^>]*property=["']og:image["']/i);
            var u = m && m[1] ? m[1] : '';
            if (u && PRODUCT_IMG.test(u) && !BAD_IMG.test(u)) resolve(u);
            else resolve('');
          })
          .catch(function () { if (!done) { done = true; clearTimeout(t); resolve(''); } });
      } catch (e) {
        if (!done) { done = true; clearTimeout(t); resolve(''); }
      }
    });
  }

  /// يكشف صورة SHEIN النائبة (صندوق رمادي بشعار) عبر تحليل البكسلات
  function looksLikePlaceholder(url) {
    return new Promise(function (resolve) {
      var im = new Image();
      im.crossOrigin = 'anonymous';
      var settled = false;
      var t = setTimeout(function () {
        if (!settled) { settled = true; resolve(false); }
      }, 1800);

      im.onload = function () {
        if (settled) return;
        settled = true; clearTimeout(t);
        try {
          var c = document.createElement('canvas');
          c.width = 40; c.height = 40;
          var ctx = c.getContext('2d');
          ctx.drawImage(im, 0, 0, 40, 40);
          var d = ctx.getImageData(0, 0, 40, 40).data;
          var sum = 0, sum2 = 0, n = 0, grayLight = 0;
          for (var i = 0; i < d.length; i += 4) {
            var r = d[i], g = d[i + 1], b = d[i + 2];
            var lum = 0.299 * r + 0.587 * g + 0.114 * b;
            sum += lum; sum2 += lum * lum; n++;
            if (Math.abs(r - g) < 14 && Math.abs(g - b) < 14 && lum > 195) grayLight++;
          }
          var mean = sum / n;
          var variance = (sum2 / n) - (mean * mean);
          var grayRatio = grayLight / n;
          // تباين منخفض جداً أو أغلبها رمادي فاتح = صورة نائبة
          resolve(variance < 300 || grayRatio > 0.7);
        } catch (e) {
          resolve(false); // لا يمكن قراءة البكسلات (CORS) — لا نحكم
        }
      };
      im.onerror = function () {
        if (settled) return;
        settled = true; clearTimeout(t);
        resolve(false);
      };
      im.src = url;
    });
  }

  /// يتأكد أن رابط الصورة يعمل فعلاً وليس صورة SHEIN الرمادية الصغيرة
  function verifyImage(url) {
    return new Promise(function (resolve) {
      if (!url) { resolve(''); return; }
      var im = new Image();
      var done = false;
      var t = setTimeout(function () {
        if (!done) { done = true; resolve(url); }
      }, 2000);
      im.onload = function () {
        if (done) return;
        done = true; clearTimeout(t);
        var w = im.naturalWidth || 0;
        var h = im.naturalHeight || 0;
        if (w < 150 || h < 150) { resolve(''); return; }
        // الصور النائبة (شعار SHEIN الرمادي) ملفات صغيرة جداً — نقيس حجمها
        fetch(url, { credentials: 'omit' })
          .then(function (r) { return r.ok ? r.blob() : null; })
          .then(function (b) {
            if (!b) { resolve(url); return; }
            if (b.size < 8000) { resolve(''); return; }
            looksLikePlaceholder(url).then(function (isBad) {
              resolve(isBad ? '' : url);
            });
          })
          .catch(function () { resolve(url); });
      };
      im.onerror = function () {
        if (done) return;
        done = true; clearTimeout(t);
        resolve('');
      };
      im.src = url;
    });
  }

  function addFromPage(button) {
    var p = readCurrentProduct();
    if (!p) { toast('تعذر قراءة بيانات المنتج.'); return; }
    var wasEdit = EDIT_MODE;
    var label = EDIT_MODE ? '💾 حفظ التعديل' : '🛒 أضف إلى سلة سيلو';

    if (button) { button.disabled = true; button.textContent = 'جارٍ الإضافة...'; }

    // صورة الصفحة تُرسل فوراً؛ والتطبيق يستبدلها بالصورة الكبيرة الصحيحة
    // عبر معرّف المنتج. لا ننتظر أي طلب شبكة هنا حتى لا يتعلّق الزر.
    var domImg = p.imageUrl || '';
    if (domImg && domImg === lastImageUrl) domImg = '';
    p.imageUrl = domImg;

    // رابط الصفحة الحقيقي أدق من أي صيغة مُركّبة
    try {
      if (isProductPage()) p.productUrl = window.location.href.split('#')[0];
    } catch (e) {}

    var finished = false;
    function finish(message) {
      if (finished) return;
      finished = true;
      toast(message);
      if (button) { button.disabled = false; button.textContent = label; }
    }

    // شبكة أمان: لا يبقى الزر معطلاً أكثر من 12 ثانية
    var guard = setTimeout(function () { finish('انتهت المحاولة. أعد الضغط.'); }, 12000);

    callBridge('addToCart', p).then(function (r) {
      clearTimeout(guard);
      var st = r && r.status ? r.status : 'ok';
      if (st === 'offline') {
        finish('تعذر الاتصال بالتطبيق. حاول مجددًا.');
        return;
      }
      if (st === 'invalid' || st === 'error') {
        finish((r && r.message) ? r.message : 'فشلت الإضافة.');
        return;
      }
      var bits = [];
      if (p.size) bits.push('المقاس: ' + p.size);
      if (p.color) bits.push('اللون: ' + p.color);
      if (wasEdit) {
        try { sessionStorage.removeItem('selooEdit'); } catch (e) {}
        EDIT_MODE = false;
        label = '🛒 أضف إلى سلة سيلو';
      }
      if (p.imageUrl) lastImageUrl = p.imageUrl;
      finish((wasEdit ? '✓ تم حفظ التعديل' : '✓ أُضيف إلى سلة سيلو') + (bits.length ? ' — ' + bits.join(' · ') : ''));
    }).catch(function () {
      clearTimeout(guard);
      finish('تعذر إكمال العملية. حاول مجددًا.');
    });
  }

  window.__selooAddCurrentProduct = function () { addFromPage(null); return true; };

  // وضع التعديل يبقى محفوظاً طوال الجلسة (صفحة البحث ← صفحة المنتج)
  var EDIT_MODE = (function () {
    var flagged = /[?&]seloo_edit=1/.test(window.location.search);
    try {
      if (flagged) sessionStorage.setItem('selooEdit', '1');
      return flagged || sessionStorage.getItem('selooEdit') === '1';
    } catch (e) {
      return flagged;
    }
  })();

  function scrollToVariants() {
    try {
      var t = qa('[class*="product-intro__size"], [class*="size-attr"], [class*="sku"], [class*="goods-sku"]');
      if (t && t.length && t[0].scrollIntoView) {
        t[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    } catch (e) {}
  }

  function buildFab() {
    if (document.getElementById('seloo-fab')) return;
    var fab = document.createElement('button');
    fab.id = 'seloo-fab';
    fab.type = 'button';
    fab.textContent = EDIT_MODE ? '💾 حفظ التعديل' : '🛒 أضف إلى سلة سيلو';
    fab.style.cssText = 'position:fixed;bottom:96px;right:14px;z-index:2147483000;background:#7c3aed;color:#fff;border:0;border-radius:50px;padding:13px 18px;font-size:14px;font-weight:700;box-shadow:0 6px 20px rgba(124,58,237,.5)';
    fab.addEventListener('click', function () {
      if (fab.disabled) return;
      addFromPage(fab);
    });
    document.body.appendChild(fab);
  }

  function removeFab() {
    var f = document.getElementById('seloo-fab');
    if (f && f.parentNode) f.parentNode.removeChild(f);
  }

  // ════════════════ السلة المشتركة: زر لكل منتج ════════════════
  function readGroupId() {
    var hay = window.location.href + ' ' + (document.documentElement ? document.documentElement.innerHTML.slice(0, 200000) : '');
    var m = hay.match(/group_?[Ii]d[^0-9]{0,3}(\d{5,})/);
    if (m) return m[1];
    m = hay.match(/\/share\/(\d{5,})/);
    return m ? m[1] : null;
  }

  function mapProduct(it) {
    if (!it) return null;
    var id = String(it.goods_id || it.goodsId || '').trim();
    if (!/^\d+$/.test(id)) return null;
    var sale = (it.salePrice || {}).amount;
    var retail = (it.retailPrice || {}).amount;
    var price = parsePrice(sale) || parsePrice(retail) || 0.01;
    var title = String(it.goods_name || it.goodsName || ('منتج SHEIN #' + id)).trim().slice(0, 300);
    var img = String(it.goods_img || it.goodsImg || (it.goods_imgs && it.goods_imgs[0]) || '').trim();
    if (img.indexOf('//') === 0) img = 'https:' + img;
    if (img.indexOf('http') !== 0) img = '';
    var vvIt = variantOfNode(it);
    return {
      goodsId: id,
      productUrl: 'https://m.shein.com/ar/pdsearch/' + id + '/',
      title: title,
      imageUrl: hiRes(img),
      sourcePrice: price,
      color: vvIt.color,
      size: vvIt.size
    };
  }


  // ════════════════ استخراج السلة من الصفحة (السلة الشخصية) ════════════════
  var IMG_OK = /\/images\d+_pi\//i;
  var IMG_BAD = /placeholder|loading|transparent|noimage|no_image|blank|grey|gray|default\.(png|jpg)|icon\/|logo|avatar|brand|shein[-_]?icon|store[-_]?logo/i;

  function imgFrom(el) {
    if (!el) return '';
    var cands = [];
    var ss = el.getAttribute('srcset') || '';
    if (ss) cands.push(ss.split(',')[0].trim().split(' ')[0]);
    cands.push(el.getAttribute('data-src') || '');
    cands.push(el.getAttribute('data-original') || '');
    cands.push(el.getAttribute('data-lazy-src') || '');
    cands.push(el.currentSrc || '');
    cands.push(el.getAttribute('src') || '');
    for (var i = 0; i < cands.length; i++) {
      var u = cands[i];
      if (!u || u.indexOf('data:') === 0) continue;
      if (IMG_BAD.test(u)) continue;
      if (!IMG_OK.test(u)) continue;
      try { return new URL(u, window.location.href).href; } catch (e) { return u; }
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


  // ════════════ استخراج اللون والمقاس (أشكال SHEIN كلها) ════════════
  // SHEIN ترسل goodsAttr = "اللون/المقاس" (عناوين فقط بلا قيم) في كثير من
  // الردود، والقيم الحقيقية في saleAttr[].attr_value أو داخل البطاقة.
  var LABEL_RE = /^(?:اللون|لون|المقاس|مقاس|الحجم|حجم|القياس|color|colour|size|attr)$/i;

  /// تنظيف المفتاح: بلا حذف العناوين — العناوين هي ما نطابقه
  function normKey(v) {
    return String(v == null ? '' : v)
      .replace(/[\u064B-\u065F\u0670\u0640]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function cleanVal(v) {
    var t = String(v == null ? '' : v)
      .replace(/[\u064B-\u065F\u0670\u0640]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
    t = t.replace(/^[:\-\/|]+/, '').replace(/[:\-\/|]+$/, '').trim();
    return LABEL_RE.test(t) ? '' : t;
  }

  function isSizeLike(v) {
    var t = cleanVal(v);
    if (!t) return false;
    return /^(XXS|XS|S|M|L|XL|XXL|2XL|3XL|4XL|5XL)$/i.test(t) ||
           /^\d{2}(?:\.\d)?$/.test(t) ||
           /(?:سم|cm)$/i.test(t);
  }

  function variantFromAttrString(raw) {
    var out = { color: '', size: '' };
    var s = String(raw || '').trim();
    if (!s) return out;

    // 1) أزواج "مفتاح: قيمة" — Color:Blue;Size:M أو اللون:أزرق،المقاس:M
    var chunks = s.split(/[;،,]+/);
    for (var i = 0; i < chunks.length; i++) {
      var c = chunks[i];
      var at = c.indexOf(':');
      if (at < 1) continue;
      var k = normKey(c.slice(0, at));
      var v = cleanVal(c.slice(at + 1));
      if (!v) continue;
      if (/لون|color|colour/i.test(k)) out.color = out.color || v;
      else if (/مقاس|حجم|قياس|size/i.test(k)) out.size = out.size || v;
    }
    if (out.color && out.size) return out;

    // 2) "أزرق داكن/M" أو "M/أزرق داكن"
    var bits = s.split('/');
    for (var j = 0; j < bits.length; j++) {
      var b = cleanVal(bits[j]);
      if (!b) continue;
      if (!out.size && isSizeLike(b)) out.size = b;
      else if (!out.color && !isSizeLike(b)) out.color = b;
    }
    return out;
  }

  function variantOfNode(node) {
    var out = { color: '', size: '' };
    try {
      var arrs = [node.saleAttr, node.sale_attr, node.multiLevelSaleAttribute,
                  node.goods_attrs, node.attrs, node.sku_sale_attr, node.attributes];
      for (var i = 0; i < arrs.length; i++) {
        var arr = arrs[i];
        if (!arr || !arr.length) continue;
        for (var j = 0; j < arr.length; j++) {
          var it = arr[j] || {};
          var k = normKey(it.attr_name != null ? it.attr_name : (it.name != null ? it.name : it.attrName));
          var v = cleanVal(it.attr_value != null ? it.attr_value : (it.value != null ? it.value : it.attrValue));
          if (!v) continue;
          if (/لون|color|colour/i.test(k)) out.color = out.color || v;
          else if (/مقاس|حجم|قياس|size/i.test(k)) out.size = out.size || v;
        }
      }
    } catch (e) {}
    var str = variantFromAttrString(node.goodsAttr || node.goods_attr || '');
    if (!out.color) out.color = str.color;
    if (!out.size) out.size = str.size;
    return out;
  }

  /// يقرأ الأزواج من أي نص/HTML (يشمل JSON المخزّن داخل سمات البطاقة)
  function variantFromText(text) {
    var out = { color: '', size: '' };
    try {
      var re = /"attr_name"\s*:\s*"([^"]{1,40})"[\s\S]{0,160}?"attr_value"\s*:\s*"([^"]{1,80})"/g;
      var m;
      while ((m = re.exec(text))) {
        var k = normKey(m[1]);
        var v = cleanVal(m[2]);
        if (!v) continue;
        if (/لون|color|colour/i.test(k)) out.color = out.color || v;
        else if (/مقاس|حجم|قياس|size/i.test(k)) out.size = out.size || v;
      }
    } catch (e) {}
    if (out.color && out.size) return out;
    var gm = String(text).match(/"goodsAttr"\s*:\s*"([^"]{1,160})"/);
    var str = variantFromAttrString(gm ? gm[1] : '');
    if (!out.color) out.color = str.color;
    if (!out.size) out.size = str.size;
    return out;
  }

  /// يقرأ اللون والمقاس من عنصر مستقل داخل البطاقة (أدق من قراءة نص البطاقة كله)
  /// رابط المنتج: نُبقي رابط الصفحة الحقيقي إن وُجد داخل البطاقة.
  /// الرابط المُصنّع بلا slug (‎/-p-ID.html) يجعل SHEIN تعرض صفحة 404،
  /// فنستخدم البحث بالمعرّف وهو مسار صالح دائماً.
  function productUrlFor(card, id) {
    var fallback = 'https://m.shein.com/ar/pdsearch/' + id + '/';
    try {
      if (card) {
        var links = card.querySelectorAll ? card.querySelectorAll('a[href]') : [];
        for (var i = 0; i < links.length; i++) {
          var h = links[i].getAttribute('href') || '';
          if (h.indexOf(String(id)) === -1) continue;
          if (h.indexOf('/') === 0) h = 'https://m.shein.com' + h;
          if (h.indexOf('http') === 0) return h;
        }
        var attrs = ['data-url', 'data-href', 'data-link', 'data-goods-url'];
        for (var a = 0; a < attrs.length; a++) {
          var v = card.getAttribute ? (card.getAttribute(attrs[a]) || '') : '';
          if (!v || v.indexOf(String(id)) === -1) continue;
          if (v.indexOf('/') === 0) v = 'https://m.shein.com' + v;
          if (v.indexOf('http') === 0) return v;
        }
        var html = card.outerHTML || '';
        var m = html.match(new RegExp('(?:href|data-url)="([^"]*-p-' + id + '[^"]*)"'));
        if (m) {
          var u = m[1];
          if (u.indexOf('/') === 0) u = 'https://m.shein.com' + u;
          if (u.indexOf('http') === 0) return u;
        }
      }
    } catch (e) {}
    return fallback;
  }

  function readVariantFrom(card) {
    var out = { color: '', size: '' };

    // 1) أزواج attr_name/attr_value المخزّنة داخل البطاقة (الأدق)
    try {
      var fromHtml = variantFromText(card.innerHTML || '');
      if (fromHtml.color) out.color = fromHtml.color;
      if (fromHtml.size) out.size = fromHtml.size;
      if (out.color && out.size) return out;
    } catch (e) {}

    var SZ = '(XXS|XS|S|M|L|XL|XXL|2XL|3XL|\\d{2,3}\\s?(?:سم|cm))';
    var nodes = card.querySelectorAll ? card.querySelectorAll('span, div, p, a, button') : [];
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].children && nodes[i].children.length) continue;
      var t = txt(nodes[i]);
      if (!t || t.length > 40) continue;
      var m = t.match(new RegExp('^([^\\s\\/|,،]{2,18})\\s*\\/\\s*' + SZ + '$', 'i'));
      if (m) { out.color = m[1].trim(); out.size = m[2].trim(); return out; }
    }
    var all = txt(card);

    // 2) "اللون: أزرق داكن" — بشرط وجود نقطتين: كلمة "لون" داخل الوصف
    //    مثل "بلون أزرق بحري" ليست عنواناً، فلا تُقرأ منه قيمة مفردة.
    if (!out.color) {
      var mc = all.match(/(?:اللون|لون|color|colour)\s*[:：]\s*([^\n\/|,،]{2,24})/i);
      if (mc) out.color = cleanVal(mc[1]);
    }
    if (!out.size) {
      var ms = all.match(/(?:المقاس|مقاس|الحجم|حجم|size)\s*[:：]\s*([A-Za-z0-9]{1,8})/i);
      if (ms) { var cand = cleanVal(ms[1]); if (isSizeLike(cand)) out.size = cand; }
    }

    // 2.5) شرائح "العنوان ثم القيمة" كعنصرين متجاورين (شكل SHEIN الشائع)
    try {
      var pairNodes = card.querySelectorAll ? card.querySelectorAll('span,div,p,i,em,b') : [];
      for (var q = 0; q < pairNodes.length - 1; q++) {
        var kn = normKey(txt(pairNodes[q]));
        if (!/^(?:اللون|لون|color|colour|المقاس|مقاس|الحجم|حجم|size)$/i.test(kn)) continue;
        var vn = cleanVal(txt(pairNodes[q + 1]));
        if (!vn) continue;
        if (/لون|color|colour/i.test(kn) && !out.color) out.color = vn;
        else if (/مقاس|حجم|size/i.test(kn) && !out.size && isSizeLike(vn)) out.size = vn;
      }
    } catch (e) {}

    // 2.7) لون من شرائح القيم المفردة (بلا عنوان) — آخر مرشّح معقول
    if (!out.color) {
      var vals = card.querySelectorAll ? card.querySelectorAll('span,i,em,b') : [];
      for (var z = 0; z < vals.length; z++) {
        if (vals[z].children && vals[z].children.length) continue;
        var vt = cleanVal(txt(vals[z]));
        if (!vt || vt.length < 2 || vt.length > 24) continue;
        if (/\d/.test(vt)) continue;
        if (/حذف|إزالة|remove|delete|تعديل|edit/i.test(vt)) continue;
        if (isSizeLike(vt)) continue;
        out.color = vt;
        break;
      }
    }

    // 3) مقاس وحده داخل عنصر قصير (شرائح SHEIN تعرض المقاس كوسم مستقل)
    if (!out.size) {
      var SZ2 = /^(XXS|XS|S|M|L|XL|XXL|2XL|3XL|4XL|5XL|\d{2}(?:\.\d)?)$/i;
      var chips = card.querySelectorAll ? card.querySelectorAll('span,i,b,em,button') : [];
      for (var k = 0; k < chips.length; k++) {
        if (chips[k].children && chips[k].children.length) continue;
        var ct = cleanVal(txt(chips[k]));
        if (ct && ct.length <= 5 && SZ2.test(ct)) { out.size = ct.toUpperCase(); break; }
      }
    }
    return out;
  }


  // ════════════════ قراءة بيانات السلة من JSON المضمّن في الصفحة ════════════════
  function pickStr(src, keys) {
    for (var i = 0; i < keys.length; i++) {
      var m = src.match(new RegExp('"' + keys[i] + '"\\s*:\\s*"([^"]{2,300})"'));
      if (m) {
        var v = m[1].replace(/\\u002F/g, '/').replace(/\\\//g, '/').trim();
        if (v) return v;
      }
    }
    return '';
  }

  function pickPrice(src) {
    var m = src.match(/"salePrice"\s*:\s*\{[^}]*?"amount"\s*:\s*"?([\d.]+)/);
    if (m) { var a = parseFloat(m[1]); if (a > 0) return a; }
    m = src.match(/"price"\s*:\s*\{[^}]*?"amount"\s*:\s*"?([\d.]+)/);
    if (m) { var b = parseFloat(m[1]); if (b > 0) return b; }
    m = src.match(/"retailPrice"\s*:\s*\{[^}]*?"amount"\s*:\s*"?([\d.]+)/);
    if (m) { var c = parseFloat(m[1]); if (c > 0) return c; }
    return 0;
  }

  function absImage(u) {
    if (!u) return '';
    var x = u.trim();
    if (x.indexOf('//') === 0) x = 'https:' + x;
    if (IMG_BAD.test(x)) return '';
    if (x.indexOf('http') !== 0) {
      var h = x.indexOf('ltwebstatic.com');
      if (h >= 0) x = 'https://img.ltwebstatic.com' + x.substring(h + 15);
      else if (x.charAt(0) === '/') x = 'https://img.ltwebstatic.com' + x;
      else return '';
    }
    return IMG_OK.test(x) ? x : '';
  }

  /// يستخرج المنتجات من بيانات الصفحة المضمّنة (لا يعتمد على شكل البطاقات)
  function scrapeCartJson() {
    var scripts = qa('script');
    var out = [];
    var seen = {};
    for (var i = 0; i < scripts.length; i++) {
      var raw = scripts[i].textContent || '';
      if (raw.length < 40) continue;
      if (raw.indexOf('goods_id') === -1 && raw.indexOf('goodsId') === -1) continue;

      // لا نقرأ إلا ما بعد قسم سلة حقيقي — يمنع منتجات المقترحات
      var marks = ['cartList', 'cart_list', 'normalProducts', 'normal_products', 'goodsList', 'goods_list'];
      var startAt = -1;
      for (var mi = 0; mi < marks.length; mi++) {
        var pos = raw.indexOf(marks[mi]);
        if (pos !== -1 && (startAt === -1 || pos < startAt)) startAt = pos;
      }
      if (startAt === -1) continue;
      var src = raw.slice(startAt);

      // نقطع عند أول قسم مقترحات/مشابهة، فلا تدخل منتجاتها في السلة
      var cut = src.search(/"(?:recommend|similar|guess|likeYou|history|browse|recent|suggest)[A-Za-z_]*"\s*:/i);
      if (cut > 0) src = src.slice(0, cut);

      var re = /"(?:goods_id|goodsId)"\s*:\s*"?(\d{6,})"?/g;
      var m;
      while ((m = re.exec(src))) {
        var id = m[1];
        if (seen[id]) continue;
        // نافذة للأمام فقط، تنتهي عند بداية المنتج التالي — تمنع قراءة بيانات منتج آخر
        var after = m.index + 8;
        var nextIdx = src.indexOf('"goods_id"', after);
        if (nextIdx === -1) nextIdx = src.indexOf('"goodsId"', after);
        var end = Math.min(src.length, m.index + 2500);
        if (nextIdx !== -1 && nextIdx < end) end = nextIdx;
        var win = src.slice(m.index, end);

        var title = pickStr(win, ['goods_name', 'goodsName', 'product_name', 'title']);
        var img = absImage(pickStr(win, ['goods_img', 'goodsImg', 'goods_image', 'main_image', 'product_img']));
        var price = pickPrice(win);
        if (!price) price = parsePrice(pickStr(win, ['price', 'salePrice']));
        var attrRaw = pickStr(win, ['goodsAttr', 'goods_attr', 'attr_value']);
        if (!title && !img) continue;
        if (!price || price <= 0) continue;

        var vvWin = (function () {
          var fromPairs = variantFromText(win);
          if (!fromPairs.color || !fromPairs.size) {
            var fromAttr = variantFromAttrString(attrRaw);
            if (!fromPairs.color) fromPairs.color = fromAttr.color;
            if (!fromPairs.size) fromPairs.size = fromAttr.size;
          }
          return fromPairs;
        })();
        var qm = win.match(/"(?:goods_num|goodsNum|cart_num|cartNum|num|quantity|qty)"\s*:\s*"?(\d{1,2})"?/);
        var qty = qm ? Math.min(50, Math.max(1, parseInt(qm[1], 10))) : 1;
        seen[id] = true;
        out.push({
          goodsId: id,
          productUrl: 'https://m.shein.com/ar/pdsearch/' + id + '/',
          title: (title || ('منتج SHEIN #' + id)).replace(/\s+/g, ' ').slice(0, 300),
          imageUrl: img,
          sourcePrice: price,
          sourceCurrency: 'SAR',
          quantity: qty,
          color: vvWin.color,
          size: vvWin.size,
          options: {},
          sourceStore: 'SHEIN',
          sku: '',
          variantId: '',
          source: 'webview-cart'
        });
      }
    }
    return out;
  }

  /// يقرأ منتجات السلة المعروضة على الشاشة (تعمل بلا معرّف سلة مشتركة)
  /// سلة SHEIN الحديثة تبني البطاقات من div بلا href.
  /// هنا نلتقط أي بطاقة تحمل زر حذف/تحديد ثم نستخرج المعرّف من داخل HTML البطاقة.
  function scrapeCartCards() {
    var out = [];
    var seen = {};
    var marks = qa('[class*="delete"],[class*="Delete"],[class*="remove"],[class*="trash"],[aria-label*="حذف"],[aria-label*="delete"],[class*="checkbox"],[class*="j-checkbox"]');
    for (var m = 0; m < marks.length && out.length < 60; m++) {
      var card = marks[m];
      for (var up = 0; up < 6 && card && card.parentNode; up++) {
        var t = txt(card);
        if (t && t.length > 25 && /(?:SAR|ر\.س|ريال|\$)/.test(t)) break;
        card = card.parentNode;
      }
      if (!card || !card.innerHTML) continue;

      // outerHTML ليشمل سمات البطاقة نفسها (data-goods-id قد تكون عليها)
      var html = card.outerHTML || card.innerHTML || '';
      var idm = html.match(/-p-(\d{5,})\.html/) ||
                html.match(/[?&]goods_id=(\d{5,})/) ||
                html.match(/"goodsId"\s*:\s*"?(\d{5,})/) ||
                html.match(/goods_id["'\s:=]+(\d{5,})/) ||
                html.match(/data-(?:id|goods-id)="(\d{5,})"/);
      if (!idm) continue;
      var id = idm[1];
      if (seen[id]) continue;

      var text = txt(card).replace(/\s+/g, ' ').slice(0, 400);
      var price = pickLowestPrice(text);
      if (!price || !isFinite(price)) continue;

      var img = '';
      var imgs = card.querySelectorAll ? card.querySelectorAll('img') : [];
      for (var j = 0; j < imgs.length; j++) {
        var c = hiRes(imgFrom(imgs[j]));
        if (c) { img = c; break; }
      }

      var title = longestTitle(card);
      if (!title || title.length < 8) title = text.slice(0, 120);
      var v = readVariantFrom(card);

      seen[id] = true;
      out.push({
        goodsId: id,
        productUrl: productUrlFor(card, id),
        title: title.replace(/\s+/g, ' ').slice(0, 300),
        imageUrl: img,
        sourcePrice: price,
        sourceCurrency: 'SAR',
        quantity: qtyFromText(text),
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

      var title = txt(a);
      if (title.length < 12) title = longestTitle(card);
      if (!title || title.length < 8) continue;

      // السعر: نفضّل عنصر السعر ثم أي رقم بجانب رمز عملة
      // علامة أن البطاقة سطر سلة فعلي وليست منتجاً مقترحاً
      var cartMark = card.querySelector(
        '[class*="delete"],[class*="Delete"],[class*="remove"],[class*="Remove"],' +
        '[class*="trash"],[class*="checkbox"],[class*="check-box"],[class*="stepper"],' +
        '[class*="quantity"],[class*="counter"],[aria-label*="حذف"],[aria-label*="delete"]'
      );
      if (!cartMark) continue;

      var price = null;
      var pEl = card.querySelector('[class*="price"], [class*="Price"]');
      if (pEl) price = pickLowestPrice(txt(pEl));
      if (!price) price = pickLowestPrice(text);
      if (!price || !isFinite(price) || price <= 0) continue;

      var img = '';
      var imgs = card.querySelectorAll ? card.querySelectorAll('img') : [];
      for (var j = 0; j < imgs.length; j++) {
        var cand = hiRes(imgFrom(imgs[j]));
        if (cand && !usedImgs[cand]) { img = cand; usedImgs[cand] = true; break; }
      }

      // المقاس واللون: نبحث عن عنصر صغير نصه "بني / L" بدقة
      var v = readVariantFrom(card);
      var color = v.color, size = v.size;

      seen[id] = true;
      out.push({
        goodsId: id,
        productUrl: productUrlFor(card, id),
        title: title.replace(/\s+/g, ' ').slice(0, 300),
        imageUrl: img,
        sourcePrice: price,
        sourceCurrency: 'SAR',
        quantity: qtyFromText(text),
        color: color,
        size: size,
        options: {},
        sourceStore: 'SHEIN',
        sku: '',
        variantId: '',
        source: 'webview-cart'
      });
    }
    return out;
  }

  function fetchPageCart() {
    var gid = readGroupId();
    if (!gid) return Promise.resolve([]);
    var origins = [window.location.origin, 'https://m.shein.com'];
    var i = 0;

    function attempt() {
      if (i >= origins.length) return Promise.resolve([]);
      var url = origins[i++] + '/ar/bff-api/order/cart/share/landing?_ver=1.1.8&_lang=ar';
      return fetch(url, {
        method: 'POST',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
          'AppCurrency': 'SAR',
          'AppLanguage': 'ar'
        },
        body: JSON.stringify({ groupId: gid, localCountry: 'SA', userLocalSizeCountry: '' })
      }).then(function (r) { return r.json(); }).then(function (data) {
        var info = data && data.info;
        var list = info && info.normalProducts;
        if (!list || !list.length) return attempt();
        return list.map(mapProduct).filter(Boolean);
      }).catch(function () { return attempt(); });
    }
    return attempt();
  }

  // ════════════════ التقاط بيانات الشبكة (استجابة سلة SHEIN نفسها) ════════════════
  function numOf(v) {
    if (v === null || v === undefined) return 0;
    if (typeof v === 'number') return isFinite(v) ? v : 0;
    if (typeof v === 'string') {
      var n = parseFloat(v.replace(/[^\d.]/g, ''));
      return isFinite(n) ? n : 0;
    }
    if (typeof v === 'object') {
      var ks = ['amount', 'value', 'price', 'usdAmount', 'rawAmount'];
      for (var i = 0; i < ks.length; i++) {
        var n2 = numOf(v[ks[i]]);
        if (n2 > 0) return n2;
      }
    }
    return 0;
  }

  function deepPrice(node) {
    var ks = ['salePrice', 'sale_price', 'price', 'skuPrice', 'sku_price', 'retailPrice', 'retail_price', 'nowPrice'];
    for (var i = 0; i < ks.length; i++) {
      if (node[ks[i]] !== undefined) {
        var n = numOf(node[ks[i]]);
        if (n > 0) return n;
      }
    }
    return 0;
  }

  /// كمية السطر داخل السلة (1..50). بعض الحقول تُسمّى goods_num أو num
  function pickQty(node) {
    var ks = ['goods_num', 'goodsNum', 'cart_num', 'cartNum', 'num', 'quantity', 'qty', 'skuQty', 'sku_qty', 'buyNum', 'buy_num', 'count'];
    for (var i = 0; i < ks.length; i++) {
      if (node[ks[i]] !== undefined) {
        var n = numOf(node[ks[i]]);
        if (n >= 1) return Math.min(50, Math.max(1, Math.round(n)));
      }
    }
    return 1;
  }

  /// كمية من نص البطاقة: نمط "‎- 2 +"
  /// كل الأسعار في نص واحد. SHEIN تعرض السعر قبل الخصم مشطوباً بجانب
  /// السعر الفعلي، فنأخذ الأقل — وإلا وصل السعر القديم إلى السلة.
  var SAVING_CTA = /(?:وفّر|وفر|توفير|خصم|كوبون|قسيمة|save|saving|off\b|discount|coupon)/i;

  function priceCandidates(text) {
    var out = [];
    var re = /(\d+(?:[.,]\d{1,2})?)\s*(?:ر\.س|SAR|ر\.ي|ريال|\$)|(?:SAR|ر\.س|ر\.ي|\$)\s*(\d+(?:[.,]\d{1,2})?)/gi;
    var m;
    var src = String(text == null ? '' : text);
    while ((m = re.exec(src))) {
      // "وفّر 2.10 ر.س" مبلغ توفير لا سعر
      var ctx = src.slice(Math.max(0, m.index - 20), m.index);
      if (SAVING_CTA.test(ctx)) continue;
      var v = parseFloat(String(m[1] || m[2] || '').replace(',', '.'));
      if (v > 0 && isFinite(v)) out.push(v);
    }
    return out;
  }

  function pickLowestPrice(text) {
    var a = priceCandidates(text);
    if (!a.length) return 0;
    var min = a[0];
    for (var i = 1; i < a.length; i++) if (a[i] < min) min = a[i];
    return min;
  }

  function qtyFromText(t) {
    if (!t) return 1;
    var m = String(t).match(/[-−]\s*(\d{1,2})\s*\+/);
    if (m) {
      var n = parseInt(m[1], 10);
      if (n >= 1) return Math.min(50, n);
    }
    return 1;
  }

  function normImg(u) {
    var s = String(u || '').trim();
    if (!s) return '';
    if (s.indexOf('//') === 0) s = 'https:' + s;
    if (s.indexOf('http') !== 0) return '';
    if (!/\.(jpg|jpeg|png|webp)/i.test(s)) return '';
    if (/placeholder|loading|transparent|noimage|no_image|blank|grey|gray|icon\/|logo|avatar|brand/i.test(s)) return '';
    return hiRes(s);
  }

  /// يقرأ ما التقطه الخطّاف من استجابات الشبكة (بيانات سلة SHEIN الحقيقية)
  // مفاتيح أقسام ليست سلة: منتجات مقترحة أو مشابهة أو شوهدت حديثاً
  var NOT_CART = /recommend|similar|guess|like|interest|history|browse|recent|suggest|ranking|feed|discover/i;
  // مفاتيح السلة الفعلية
  var IS_CART = /cart|goodslist|goods_list|productlist|product_list|normalproducts|normal_products|sku|orderitem/i;

  function scrapeCapturedJson() {
    var out = [];
    var seen = {};
    var store = window.__selooApi || [];

    function walk(node, depth, path) {
      if (!node || depth > 14 || out.length > 120) return;
      var pth = path || '';
      if (Array.isArray(node)) {
        for (var i = 0; i < node.length; i++) walk(node[i], depth + 1, pth);
        return;
      }
      if (typeof node !== 'object') return;

      var id = node.goods_id || node.goodsId || node.goods_sn || node.productId;
      var sid = id === null || id === undefined ? '' : String(id);
      // نأخذ فقط ما يقع تحت قسم سلة حقيقي، ونتجاهل المقترحات وما شابهها
      var inCart = IS_CART.test(pth) && !NOT_CART.test(pth);
      if (/^\d{5,}$/.test(sid) && !seen[sid] && inCart) {
        var title = node.goods_name || node.goodsName || node.title || '';
        var price = deepPrice(node);
        if (title && price > 0) {
          seen[sid] = true;
          var vvNode = variantOfNode(node);
          out.push({
            goodsId: sid,
            productUrl: 'https://m.shein.com/ar/pdsearch/' + sid + '/',
            title: String(title).replace(/\s+/g, ' ').slice(0, 300),
            imageUrl: normImg(node.goods_img || node.goodsImg || (node.goods_imgs && node.goods_imgs[0]) || node.image || node.main_image),
            sourcePrice: price,
            sourceCurrency: 'SAR',
            quantity: pickQty(node),
            color: vvNode.color,
            size: vvNode.size,
            options: {},
            sourceStore: 'SHEIN',
            sku: '',
            variantId: '',
            source: 'webview-cart'
          });
        }
      }

      for (var k in node) {
        if (Object.prototype.hasOwnProperty.call(node, k)) walk(node[k], depth + 1, pth + '/' + k);
      }
    }

    for (var s = 0; s < store.length; s++) {
      var json;
      try { json = JSON.parse(store[s]); } catch (e) { continue; }
      walk(json, 0, '');
    }
    return out;
  }

  /// يعيد طلب واجهات الشبكة التي استدعتها الصفحة (بكوكيز الجلسة) لالتقاط بيانات السلة
  function refetchCartApis() {
    // أولاً: الروابط التي جمعها التطبيق نفسه من طبقة الشبكة (أدق مصدر)
    var dartUrls = [];
    try { dartUrls = (window.__selooUrls || []).slice(0, 12); } catch (e) {}
    var urls = dartUrls.slice(0);
    try {
      var res = performance.getEntriesByType('resource') || [];
      for (var i = 0; i < res.length; i++) {
        var u = res[i].name || '';
        if (!u) continue;
        if (!/bff-api|\/cart|order|cartlist|goods/i.test(u)) continue;
        if (urls.indexOf(u) !== -1) continue;
        urls.push(u);
      }
    } catch (e) {}
    if (!urls.length) return Promise.resolve([]);
    urls = urls.slice(-6);
    var tasks = urls.map(function (u) {
      return fetch(u, { credentials: 'include' })
        .then(function (r) { return r.text(); })
        .then(function (t) {
          if (!t) return '';
          if (t.indexOf('goods_id') === -1 && t.indexOf('goodsId') === -1) return '';
          return t;
        })
        .catch(function () { return ''; });
    });
    return Promise.all(tasks).then(function (texts) {
      var keep = texts.filter(function (t) { return !!t; });
      if (keep.length) {
        window.__selooApi = (window.__selooApi || []).concat(keep).slice(-10);
      }
      return keep;
    });
  }

  function ensureProductList() {
    if (cache.products && cache.url === window.location.href) return Promise.resolve(cache.products);

    // 1) بيانات الشبكة (أدق مصدر: استجابة سلة SHEIN نفسها)
    var netList = scrapeCapturedJson();
    // 2) السلة المعروضة على الشاشة (روابط، ثم بطاقات بلا روابط)
    var domList = scrapeCartDom();
    var cardList = scrapeCartCards();
    if (cardList.length) {
      var seenDom = {};
      var k;
      for (k = 0; k < domList.length; k++) seenDom[domList[k].goodsId] = true;
      for (k = 0; k < cardList.length; k++) {
        if (!seenDom[cardList[k].goodsId]) domList.push(cardList[k]);
      }
    }
    // 3) بيانات الصفحة المضمّنة — تكمّل ما فات البطاقات
    var jsonList = netList.length ? [] : scrapeCartJson();

    var merged = [];
    var byId = {};
    var i;
    for (i = 0; i < netList.length; i++) { byId[netList[i].goodsId] = netList[i]; merged.push(netList[i]); }
    for (i = 0; i < domList.length; i++) {
      if (byId[domList[i].goodsId]) continue;
      byId[domList[i].goodsId] = domList[i]; merged.push(domList[i]);
    }
    for (i = 0; i < jsonList.length; i++) {
      var it = jsonList[i];
      if (byId[it.goodsId]) {
        // نكمّل الناقص في بطاقة DOM من بيانات الصفحة
        if (!byId[it.goodsId].imageUrl && it.imageUrl) byId[it.goodsId].imageUrl = it.imageUrl;
        continue;
      }
      byId[it.goodsId] = it;
      merged.push(it);
    }
    if (merged.length) {
      cache.products = merged;
      cache.url = window.location.href;
      return Promise.resolve(merged);
    }

    // 4) إعادة طلب واجهات السلة من الشبكة ثم إعادة القراءة
    return refetchCartApis().then(function (kept) {
      if (!kept.length) return [];
      var again = scrapeCapturedJson();
      if (again.length) {
        cache.products = again;
        cache.url = window.location.href;
      }
      return again;
    }).then(function (list) {
      if (list && list.length) return list;
      return fetchPageCart().then(function (fallback) {
        cache.products = fallback;
        cache.url = window.location.href;
        return fallback;
      });
    });

  }

  // إيجاد أصغر عنصر يحتوي نص المنتج
  function findByText(needle) {
    if (!needle || needle.length < 6) return null;
    var probe = needle.slice(0, 14);
    var els = qa('a, [class*="card"], [class*="item"], [class*="goods"], li');
    var best = null;
    for (var i = 0; i < els.length; i++) {
      var t = txt(els[i]);
      if (t.indexOf(probe) === -1) continue;
      if (!best || t.length < txt(best).length) best = els[i];
    }
    return best;
  }

  function findByImage(product) {
    if (!product.imageUrl) return null;
    var name = product.imageUrl.split('/').pop().split('?')[0];
    if (!name || name.length < 8) return null;
    var imgs = qa('img');
    for (var i = 0; i < imgs.length; i++) {
      var src = imgs[i].getAttribute('src') || imgs[i].getAttribute('data-src') || '';
      if (src.indexOf(name) !== -1) return imgs[i];
    }
    return null;
  }

  var injectedFor = '';
  function injectCardButtons(products) {
    if (!products || !products.length) return;
    if (injectedFor === window.location.href + '|' + products.length) return;
    injectedFor = window.location.href + '|' + products.length;
    products.forEach(function (p) {
      var host = findByText(p.title) || findByImage(p);
      if (!host) return;

      // نصعد حتى حاوية بصرية معقولة
      var card = host;
      for (var depth = 0; depth < 4 && card && card.parentNode; depth++) {
        var r = card.getBoundingClientRect ? card.getBoundingClientRect() : { width: 0, height: 0 };
        if (r.width >= 200 && r.height >= 90) break;
        card = card.parentNode;
      }
      if (!card || !card.appendChild) return;
      // زر واحد فقط لكل بطاقة، مهما تكررت المنتجات المطابقة
      if (card.querySelector && card.querySelector('[' + CARD_FLAG + ']')) return;

      var btn = document.createElement('button');
      btn.type = 'button';
      btn.setAttribute(CARD_FLAG, p.goodsId);
      btn.textContent = '🛒 أضف إلى سلة سيلو';
      btn.style.cssText = 'display:block;width:100%;margin:8px 0 4px;padding:10px;border:0;border-radius:10px;background:#7c3aed;color:#fff;font-size:13px;font-weight:700;font-family:inherit';
      btn.addEventListener('click', function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        window.location.href = p.productUrl;
      });
      card.appendChild(btn);
    });
  }

  // ════════════════ المزامنة ════════════════
  // ═══ استيراد السلة كاملة (يمر بنفس مسار الإضافة الفردية) ═══
  var importing = false;

  function importWholeCart() {
    if (importing) return;
    importing = true;
    updateBulkLabel('جارٍ قراءة السلة...');

    ensureProductList().then(function (products) {
      if (!products || !products.length) {
        importing = false;
        updateBulkLabel(null);
        var nNet = 0, nLinks = 0, nCards = 0, nJson = 0;
        try { nNet = scrapeCapturedJson().length; } catch (e) {}
        try { nLinks = scrapeCartDom().length; } catch (e) {}
        try { nCards = scrapeCartCards().length; } catch (e) {}
        try { nJson = scrapeCartJson().length; } catch (e) {}
        toast('لم أجد منتجات — شبكة:' + nNet + ' · روابط:' + nLinks +
              ' · بطاقات:' + nCards + ' · مضمّن:' + nJson);
        return;
      }

      var total = products.length;
      var added = 0;
      var failed = 0;

      function step(i) {
        if (i >= total) {
          importing = false;
          updateBulkLabel(null);
          toast('✓ اكتمل: أُضيف ' + added + ' من ' + total + ' منتج إلى سلة يمن سيلو'
            + (failed ? ' — تعذر ' + failed : ''));
          return;
        }
        updateBulkLabel('جارٍ الإضافة ' + (i + 1) + '/' + total);
        callBridge('addToCart', products[i]).then(function (r) {
          var st = r && r.status ? r.status : 'ok';
          if (st === 'ok' || st === 'success') { added++; } else { failed++; }
          setTimeout(function () { step(i + 1); }, 250);
        });
      }
      step(0);
    }).catch(function () {
      importing = false;
      updateBulkLabel(null);
      toast('تعذر قراءة السلة — أعد المحاولة بعد تحميل الصفحة.');
    });
  }

  function updateBulkLabel(text) {
    var b = document.getElementById('seloo-bulk-btn');
    if (!b) return;
    b.textContent = text ? '⏳ ' + text : '📥 استيراد السلة كاملة إلى سيلو';
  }

  function buildBulkButton() {
    if (document.getElementById('seloo-bulk-btn')) return;
    var b = document.createElement('button');
    b.id = 'seloo-bulk-btn';
    b.type = 'button';
    b.textContent = '📥 استيراد السلة كاملة إلى سيلو';
    b.style.cssText = 'position:fixed;bottom:16px;left:12px;right:12px;z-index:2147483000;background:#10b981;color:#fff;border:0;border-radius:12px;min-height:50px;font-size:15px;font-weight:700;box-shadow:0 4px 16px rgba(0,0,0,.25);cursor:pointer';
    b.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      importWholeCart();
    });
    document.body.appendChild(b);
  }

  function removeBulkButton() {
    var b = document.getElementById('seloo-bulk-btn');
    if (b && b.parentNode) b.parentNode.removeChild(b);
  }

  function sync() {
    if (document.visibilityState === 'hidden') return;
    if (isProductPage()) {
      buildFab();
      removeBulkButton();
      if (EDIT_MODE && !window.__selooScrolled) {
        window.__selooScrolled = true;
        setTimeout(scrollToVariants, 900);
      }
      return;
    }
    removeFab();
    if (isShareOrCartPage()) {
      buildBulkButton();
      ensureProductList().then(function (list) { injectCardButtons(list); });
    } else {
      removeBulkButton();
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { setTimeout(sync, 800); });
  } else {
    setTimeout(sync, 800);
  }
  setInterval(sync, 6000);
})();

/**
 * Yemen Seloo — Overlay JS
 * الفكرة: زر "أضف إلى سلة سيلو" فقط.
 * 1) في صفحة المنتج: زر يضيف المنتج بالمقاس واللون المختارين.
 * 2) في السلة المشتركة: زر صغير على كل منتج يفتح صفحته لاختيار المقاس واللون ثم الإضافة.
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
  function readSelectedVariant() {
    var out = { size: '', color: '' };

    function pick(el) {
      if (!el) return '';
      var t = (el.getAttribute('title') || el.getAttribute('aria-label') || txt(el) || '').trim();
      return t.length <= 30 ? t : '';
    }

    // 1) عناصر عليها aria-checked / aria-selected
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

    // 2) أصناف مختارة شائعة
    if (!out.size) {
      out.size = pick(q('[class*="size"] [class*="active"], [class*="size"] [class*="selected"], [class*="sku"] [class*="active"]'));
    }
    if (!out.color) {
      out.color = pick(q('[class*="color"] [class*="active"], [class*="color"] [class*="selected"]'));
    }

    // 3) نص شريط الاختيار: "المقاس: M" / "اللون: الأسود"
    if (!out.size || !out.color) {
      var body = txt(document.body).slice(0, 4000);
      if (!out.size) {
        var ms = body.match(/(?:المقاس|مقاس)\s*:?\s*([A-Za-z0-9]{1,6})/);
        if (ms) out.size = ms[1];
      }
      if (!out.color) {
        var mc = body.match(/(?:اللون|لون)\s*:?\s*([^\s,،|/]{2,20})/);
        if (mc) out.color = mc[1];
      }
    }

    return out;
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
    if (!price) {
      var pm = q('meta[property="product:price:amount"], meta[property="og:price:amount"]');
      if (pm) price = parsePrice(pm.content);
    }
    if (!price) price = 0.01;

    var BAD_IMG = /placeholder|loading|transparent|noimage|no_image|blank|grey|gray|default\.(png|jpg)|icon\//i;

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
        // الرابط قد يكون نسبياً (بدون https) — نحوّله لمطلق
        try {
          return new URL(u, window.location.href).href;
        } catch (e) {
          return u.indexOf('//') === 0 ? 'https:' + u : u;
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
    var ogFirst = q('meta[property="og:image"]');
    if (ogFirst && ogFirst.content && !BAD_IMG.test(ogFirst.content)) {
      imageUrl = ogFirst.content;
    }
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
        if (c2 && c2.indexOf('ltwebstatic') !== -1) { imageUrl = c2; break; }
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
    if (button) { button.disabled = true; button.textContent = 'جارٍ الإضافة...'; }

    var ogBackup = (function () { var m = q('meta[property="og:image"]'); return m && m.content ? m.content : ''; })();

    verifyImage(p.imageUrl).then(function (okUrl) {
      if (okUrl) { p.imageUrl = okUrl; return; }
      // الرابط الأول لم يصلح: نجرّب og:image ثم نُرسل بلا صورة (يحتفظ السطر بصورته)
      return verifyImage(ogBackup).then(function (alt) { p.imageUrl = alt || ''; });
    }).then(function () {
      return callBridge('addToCart', p);
    }).then(function (r) {
      var st = r && r.status ? r.status : 'ok';
      if (st === 'offline') {
        toast('تعذر الاتصال بالتطبيق. حاول مجددًا.');
      } else if (st === 'invalid' || st === 'error') {
        toast((r && r.message) ? r.message : 'فشلت الإضافة.');
      } else {
        var bits = [];
        if (p.size) bits.push('المقاس: ' + p.size);
        if (p.color) bits.push('اللون: ' + p.color);
        bits.push(p.imageUrl ? 'صورة ✓' : 'بلا صورة ✗');
        if (wasEdit) {
          try { sessionStorage.removeItem('selooEdit'); } catch (e) {}
          EDIT_MODE = false;
        }
        toast((wasEdit ? '✓ تم حفظ التعديل' : '✓ أُضيف إلى سلة سيلو') + ' — ' + bits.join(' · '));
      }
      if (button) { button.disabled = false; button.textContent = EDIT_MODE ? '💾 حفظ التعديل' : '🛒 أضف إلى سلة سيلو'; }
    }).catch(function (e) {
      toast('تعذر إكمال العملية. حاول مجددًا.');
      if (button) { button.disabled = false; button.textContent = EDIT_MODE ? '💾 حفظ التعديل' : '🛒 أضف إلى سلة سيلو'; }
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
    var attrs = String(it.goodsAttr || '').split('/');
    return {
      goodsId: id,
      productUrl: 'https://m.shein.com/-p-' + id + '.html',
      title: title,
      imageUrl: img,
      sourcePrice: price,
      color: (attrs[0] || '').trim(),
      size: (attrs[1] || '').trim()
    };
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

  function ensureProductList() {
    if (cache.products && cache.url === window.location.href) return Promise.resolve(cache.products);
    return fetchPageCart().then(function (list) {
      cache.products = list;
      cache.url = window.location.href;
      return list;
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
      if (card.querySelector && card.querySelector('[' + CARD_FLAG + '="' + p.goodsId + '"]')) return;

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
        toast('لم أجد منتجات في السلة — افتحها وانتظر تحميلها.');
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
  setInterval(sync, 4000);
})();

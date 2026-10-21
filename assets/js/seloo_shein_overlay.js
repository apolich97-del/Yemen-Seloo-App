
(function () {
  'use strict';

  const BUTTON_ID = 'seloo-shein-add-button';
  const STYLE_ID = 'seloo-shein-overlay-style';

  // يعمل على صفحات المنتجات فقط، وليس الرئيسية أو نتائج البحث.
  function isProductPage() {
    return /-p-\d+\.html/i.test(window.location.pathname);
  }

  function getProductData() {
    const data = {
      url: window.location.href,
      title: document.title || '',
      goodsId: '',
      image: '',
      price: '',
      currency: 'SAR'
    };

    // استخراج معرّف المنتج من الرابط.
    const idMatch = window.location.pathname.match(/-p-(\d+)\.html/i);

    if (idMatch) {
      data.goodsId = idMatch[1];
    }

    // محاولة قراءة بيانات المنتج من JSON-LD.
    const scripts = document.querySelectorAll(
      'script[type="application/ld+json"]'
    );

    for (const script of scripts) {
      try {
        const parsed = JSON.parse(script.textContent || '{}');
        const objects = Array.isArray(parsed) ? parsed : [parsed];

        for (const obj of objects) {
          if (!obj || typeof obj !== 'object') continue;

          const product = obj['@type'] === 'Product'
            ? obj
            : Array.isArray(obj['@graph'])
              ? obj['@graph'].find(
                  item => item && item['@type'] === 'Product'
                )
              : null;

          if (!product) continue;

          if (product.name) {
            data.title = String(product.name).slice(0, 300);
          }

          if (product.image) {
            const image = Array.isArray(product.image)
              ? product.image[0]
              : product.image;

            if (typeof image === 'string') {
              data.image = image;
            } else if (image && image.url) {
              data.image = image.url;
            }
          }

          const offers = product.offers;
          const offer = Array.isArray(offers) ? offers[0] : offers;

          if (offer && offer.price != null) {
            data.price = String(offer.price);
          }

          if (offer && offer.priceCurrency) {
            data.currency = String(offer.priceCurrency);
          }

          break;
        }
      } catch (_) {
        // تجاهل بيانات JSON-LD غير الصالحة.
      }

      if (data.image || data.price) break;
    }

    // بدائل لاستخراج الصورة والسعر من عناصر الصفحة.
    if (!data.image) {
      const imageElement = document.querySelector(
        'meta[property="og:image"], meta[name="twitter:image"]'
      );

      if (imageElement) {
        data.image = imageElement.content || '';
      }
    }

    if (!data.price) {
      const priceElement = document.querySelector(
        'meta[property="product:price:amount"]'
      );

      if (priceElement) {
        data.price = priceElement.content || '';
      }
    }

    return data;
  }

  function addStyles() {
    if (document.getElementById(STYLE_ID)) return;

    const style = document.createElement('style');
    style.id = STYLE_ID;

    style.textContent = `
      #${BUTTON_ID} {
        position: fixed;
        left: 12px;
        right: 12px;
        bottom: 18px;
        z-index: 2147483647;
        width: calc(100% - 24px);
        min-height: 52px;
        border: 0;
        border-radius: 12px;
        background: #5a16ab;
        color: #ffffff;
        font-size: 16px;
        font-weight: 700;
        font-family: inherit;
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.25);
        cursor: pointer;
      }

      #${BUTTON_ID}:disabled {
        opacity: 0.7;
        cursor: wait;
      }
    `;

    (document.head || document.documentElement).appendChild(style);
  }

  function showMessage(message) {
    let box = document.getElementById('seloo-shein-message');

    if (!box) {
      box = document.createElement('div');
      box.id = 'seloo-shein-message';

      Object.assign(box.style, {
        position: 'fixed',
        top: '16px',
        left: '12px',
        right: '12px',
        zIndex: '2147483647',
        padding: '12px',
        borderRadius: '10px',
        background: '#ffffff',
        color: '#333333',
        fontSize: '14px',
        textAlign: 'center',
        boxShadow: '0 3px 14px rgba(0,0,0,.2)'
      });

      document.documentElement.appendChild(box);
    }

    box.textContent = message;

    window.setTimeout(function () {
      if (box && box.parentNode) {
        box.parentNode.removeChild(box);
      }
    }, 3500);
  }

  function addButton() {
    if (!isProductPage()) return;
    if (document.getElementById(BUTTON_ID)) return;

    addStyles();

    const button = document.createElement('button');
    button.id = BUTTON_ID;
    button.type = 'button';
    button.textContent = '🛒 أضف إلى سلة سيلو';

    button.addEventListener('click', function () {
      if (button.disabled) return;

      const product = getProductData();

      if (!product.goodsId) {
        showMessage('تعذر تحديد رقم المنتج.');
        return;
      }

      if (
        !window.selooBridge ||
        typeof window.selooBridge.postMessage !== 'function'
      ) {
        showMessage('تعذر الاتصال بالتطبيق. حاول مجددًا.');
        return;
      }

      button.disabled = true;
      button.textContent = 'جارٍ إرسال المنتج...';

      try {
        window.selooBridge.postMessage(
          JSON.stringify({
            action: 'addToCart',
            payload: product
          })
        );

        showMessage('تم إرسال طلب إضافة المنتج إلى يمن سيلو.');
      } catch (_) {
        showMessage('تعذر إرسال المنتج إلى التطبيق.');
      }

      window.setTimeout(function () {
        button.disabled = false;
        button.textContent = '🛒 أضف إلى سلة سيلو';
      }, 1800);
    });

    document.body.appendChild(button);
  }

  function initialize() {
    if (!isProductPage()) return;
    addButton();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize);
  } else {
    initialize();
  }

  // بعض صفحات SHEIN تُحمّل تفاصيل المنتج بعد فتح الصفحة.
  let attempts = 0;

  const poll = window.setInterval(function () {
    attempts++;

    if (isProductPage()) {
      addButton();
    }

    if (document.getElementById(BUTTON_ID) || attempts >= 20) {
      window.clearInterval(poll);
    }
  }, 500);
})();

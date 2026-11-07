import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../core/config/seloo_config.dart';
import '../../cart/application/cart_counter.dart';
import '../../home/presentation/main_tab_controller.dart';
import '../data/shein_link_resolver.dart';
import 'shein_bridge_controller.dart';

class SheinWebScreen extends StatefulWidget {
  const SheinWebScreen({super.key});

  @override
  State<SheinWebScreen> createState() => _SheinWebScreenState();
}

class _SheinWebScreenState extends State<SheinWebScreen> {
  final CartCounter _cartCounter = Get.find<CartCounter>();
  final SheinBridgeController _bridgeController = SheinBridgeController();

  InAppWebViewController? _webViewController;
  String? _shareCartUrl;
  String? _editUrl;
  String? _editingLineId;
  double _progress = 0;
  bool _isLoading = true;
  bool _resolvingLink = false;

  // ⭐ متغيرات التحكم في الزحف
  bool _isCrawling = false;
  int _currentCrawlIndex = 0;
  int _totalCrawlItems = 0;
  int _addedCount = 0;

  /// يحوّل أي رابط وارد (sheinlink:// أو رابط مشاركة) إلى صفحة سلة صالحة
  static String? _shareUrlFrom(Object? raw) {
    final String s = (raw ?? '').toString().trim();
    if (s.isEmpty) return null;

    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    final String lower = s.toLowerCase();
    if (lower.startsWith('sheinlink') || s.contains('group_id')) {
      final RegExpMatch? dataMatch = RegExp(r'data=([^&\s]+)').firstMatch(s);
      if (dataMatch != null) {
        try {
          final String decoded = Uri.decodeComponent(dataMatch.group(1)!);
          final Object? obj = jsonDecode(decoded);
          if (obj is Map && obj['group_id'] != null) {
            final Object? shc = obj['shc'];
            return 'https://m.shein.com/ar/cart/share/landing'
                '?group_id=${obj['group_id']}'
                '${shc != null ? '&shc=$shc' : ''}';
          }
        } catch (_) {}
      }

      final RegExpMatch? gid = RegExp(
        r'group_?id[^0-9]{0,3}(\d{5,})',
        caseSensitive: false,
      ).firstMatch(s);
      if (gid != null) {
        return 'https://m.shein.com/ar/cart/share/landing?group_id=${gid.group(1)}';
      }
    }

    return null;
  }


  /// خطّاف يُحقن قبل تحميل الصفحة: يسجّل استجابات السلة من SHEIN نفسها،
  /// لأن بيانات السلة لا تكون دائماً في الصفحة ولا في بطاقات ثابتة.
  /// روابط استجابات قد تحمل بيانات السلة
  final List<String> _netUrls = <String>[];

  /// صفحة 404 من SHEIN: نجرّب مسار البحث بالمعرّف مرة واحدة فقط
  bool _recovered404 = false;
  static final RegExp _netUrlRe = RegExp(
    r'cart|order|bff-api|goods|product',
    caseSensitive: false,
  );

  static const String _apiHook = r"""
(function () {
  if (window.__selooHooked) return;
  window.__selooHooked = true;
  window.__selooApi = [];
  function keep(u, t) {
    try {
      if (!t || typeof t !== 'string') return;
      if (t.length > 500000) return;
      var looksCart = /cart|order|bff-api|product|goods/i.test(String(u));
      var hasGoods = t.indexOf('goods_id') !== -1 || t.indexOf('goodsId') !== -1;
      if (!looksCart && !hasGoods) return;
      if (!hasGoods) return;
      window.__selooApi.push(t);
      if (window.__selooApi.length > 8) window.__selooApi.shift();
      try {
        window.__selooUrls = window.__selooUrls || [];
        var uu = String(u);
        if (uu && window.__selooUrls.indexOf(uu) === -1) {
          window.__selooUrls.push(uu);
          if (window.__selooUrls.length > 12) window.__selooUrls.shift();
        }
      } catch (e) {}
    } catch (e) {}
  }
  var of = window.fetch;
  if (of) {
    window.fetch = function () {
      var a = arguments[0];
      var u = (a && a.url) ? a.url : String(a || '');
      return of.apply(this, arguments).then(function (r) {
        try {
          if (r && r.clone) { r.clone().text().then(function (t) { keep(u, t); }).catch(function () {}); }
        } catch (e) {}
        return r;
      });
    };
  }
  var oo = XMLHttpRequest.prototype.open;
  var os = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) {
    this.__selooUrl = u;
    return oo.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    var x = this;
    try {
      x.addEventListener('load', function () { keep(x.__selooUrl || '', x.responseText); });
    } catch (e) {}
    return os.apply(this, arguments);
  };
})();
""";

  /// يكشف صفحة "لا يمكننا العثور على الصفحة" وينتقل إلى مسار البحث بالمعرّف.
  Future<void> _recoverFrom404(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (_recovered404) return;
    try {
      final Object? isMissing = await controller.evaluateJavascript(source: '''
(function () {
  try {
    var t = (document.body && document.body.innerText) || '';
    return t.indexOf('لا يمكننا العثور على الصفحة') > -1 || /Oops/i.test(t);
  } catch (e) { return false; }
})();
''');
      if (isMissing != true) return;

      final String source = '${url ?? ''} ${_editUrl ?? ''} $_initialUrl';
      final RegExpMatch? m = RegExp(
        r'-p-(\d{6,})|goods_id=(\d{6,})|pdsearch/(\d{6,})',
      ).firstMatch(source);
      final String id = m?.group(1) ?? m?.group(2) ?? m?.group(3) ?? '';
      if (id.isEmpty) return;

      _recovered404 = true;
      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri('https://m.shein.com/ar/pdsearch/$id/'),
        ),
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      _shareCartUrl = _shareUrlFrom(args['shareCartUrl']);
      _editUrl = _shareUrlFrom(args['editUrl']);
      _editingLineId = args['editLineId'] as String?;

      // أي حقل آخر قد يحمل رابط sheinlink من نظام المشاركة
      if (_shareCartUrl == null) {
        for (final Object? v in args.values) {
          final String raw = (v ?? '').toString();
          if (raw.isEmpty) continue;
          if (raw.startsWith('http://') || raw.startsWith('https://')) {
            continue;
          }
          final String? cand = _shareUrlFrom(raw);
          if (cand != null) {
            _shareCartUrl = cand;
            break;
          }
        }
      }
    }

    if (_shareCartUrl != null && _shareCartUrl!.isNotEmpty) {
      if (_needsResolution(_shareCartUrl)) {
        _resolveIncoming(_shareCartUrl!);
      } else {
        try {
          GetStorage().write('seloo_last_share_url', _shareCartUrl);
        } catch (_) {}
      }
    }
  }

  /// رابط onelink أو أي رابط بلا معرّف سلة يحتاج قراءة قبل الفتح
  static bool _needsResolution(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.contains('onelink.shein.com')) return true;
    return SheinLinkResolver.groupIdIn(url) == null &&
        !url.contains('-p-') &&
        url.contains('cart');
  }

  Future<void> _resolveIncoming(String raw) async {
    _resolvingLink = true;
    final String? resolved = await SheinLinkResolver.resolve(raw);
    if (!mounted) return;
    setState(() {
      _resolvingLink = false;
      if (resolved != null) _shareCartUrl = resolved;
    });
    if (resolved != null) {
      try {
        GetStorage().write('seloo_last_share_url', resolved);
      } catch (_) {}
    }
  }

  String get _initialUrl =>
      _editUrl ?? _shareCartUrl ?? SheinWebConfig.homeAr;

  InAppWebViewSettings _buildSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      domStorageEnabled: true,
      cacheEnabled: true,
      useHybridComposition: true,
      applicationNameForUserAgent: 'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    );
  }

  void _nextCrawlStep() {
    if (_currentCrawlIndex >= _totalCrawlItems) {
      // انتهى الزحف
      setState(() => _isCrawling = false);
      Get.back();
      Get.snackbar('✅ اكتمل الاستيراد', 'تمت إضافة $_addedCount منتج', backgroundColor: Colors.green, colorText: Colors.white);
      try { Get.find<MainTabController>().goToCart(); } catch (_) {}
      return;
    }

    _currentCrawlIndex++;
    // نعود للخلف (لصفحة السلة) ثم ننقر على المنتج التالي
    _webViewController?.goBack();
    Future.delayed(const Duration(seconds: 2), () {
      _webViewController?.evaluateJavascript(source: 'window.__selooClickNext($_currentCrawlIndex);');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isCrawling ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
        title: Text(_isCrawling ? 'جاري الاستيراد ($_currentCrawlIndex/$_totalCrawlItems)' : 'استيراد السلة', style: const TextStyle(fontSize: 16)),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث الصفحة',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _webViewController?.reload();
            },
          ),
        ],
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (_isCrawling) {
              setState(() => _isCrawling = false);
              return;
            }
            // داخل متصفح شي إن: رجوع خطوة، وإن لم يوجد تاريخ نعود للتطبيق
            bool wentBack = false;
            try {
              final InAppWebViewController? c = _webViewController;
              if (c != null && await c.canGoBack()) {
                await c.goBack();
                wentBack = true;
              }
            } catch (_) {}
            if (!wentBack) Get.back();
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          if (_isLoading && _progress < 1)
            LinearProgressIndicator(value: _progress, color: const Color(0xFF7C3AED), minHeight: 3),
          if (_resolvingLink)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(color: Color(0xFF7C3AED)),
                    SizedBox(height: 14),
                    Text('جارٍ قراءة رابط السلة من شي إن…'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF7C3AED),
                onRefresh: () async {
                  await _webViewController?.reload();
                  await Future<void>.delayed(const Duration(milliseconds: 600));
                },
                child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_initialUrl), headers: <String, String>{'Accept-Language': 'ar,ar-SA;q=0.9,en;q=0.5'}),
              initialSettings: _buildSettings(),
              initialUserScripts: UnmodifiableListView<UserScript>(<UserScript>[
                UserScript(
                  source: _apiHook,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              onWebViewCreated: (controller) async {
                _webViewController = controller;
                _bridgeController.editingLineId = _editingLineId;
                await _bridgeController.attach(controller);

                // ⭐ ربط أوامر الزحف
                _bridgeController.onStartClickCrawl = (total) {
                  setState(() {
                    _isCrawling = true;
                    _totalCrawlItems = total;
                    _currentCrawlIndex = 0;
                  });
                };
                _bridgeController.onCrawlStepFailed = () {
                  _nextCrawlStep();
                };
              },
              shouldInterceptRequest: (controller, request) async {
                try {
                  final String u = request.url.toString();
                  if (u.startsWith('http') &&
                      _netUrlRe.hasMatch(u) &&
                      !_netUrls.contains(u)) {
                    _netUrls.add(u);
                    if (_netUrls.length > 12) _netUrls.removeAt(0);
                  }
                } catch (_) {}
                return null;
              },
              onLoadStart: (c, u) { setState(() { _isLoading = true; _progress = 0; }); },
              onLoadStop: (controller, url) async {
                setState(() { _isLoading = false; _progress = 1; });
                // نمرّر روابط واجهات السلة التي رصدناها إلى الصفحة
                if (_netUrls.isNotEmpty) {
                  final String list = _netUrls
                      .map((String e) => '"${e.replaceAll('"', '')}"')
                      .join(',');
                  await controller.evaluateJavascript(
                    source: 'window.__selooUrls = [$list];',
                  );
                }
                final script = await _bridgeController.loadOverlayScript();
                await controller.evaluateJavascript(source: script);

                // شي إن تعرض 404 لرابط منتج بلا slug — ننتقل للبحث بالمعرّف
                await _recoverFrom404(controller, url);

                // ⭐ إذا كنا في صفحة منتج أثناء الزحف، نضيفه
                if (_isCrawling && url.toString().contains('-p-')) {
                  await controller.evaluateJavascript(source: 'setTimeout(function() { if(window.__selooAddCurrentProduct) window.__selooAddCurrentProduct(); }, 1500);');
                  
                  // ⭐ نعتمد على الـ Bridge لإخبارنا بالنجاح، لكن للتبسيط ننتقل بعد 3 ثوانٍ
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted && _isCrawling) {
                      _addedCount++;
                      _nextCrawlStep();
                    }
                  });
                }
              },
              onUpdateVisitedHistory: (controller, url, isReload) => setState(() {}),
              // أي رابط sheinlink:// أو مخطط غير http يُحوّل لصفحة السلة بدل رسالة الخطأ
              shouldOverrideUrlLoading: (controller, action) async {
                final String target =
                    action.request.url?.toString() ?? '';
                if (target.isEmpty) return NavigationActionPolicy.ALLOW;
                final bool webUrl =
                    target.startsWith('http://') || target.startsWith('https://');
                if (webUrl) return NavigationActionPolicy.ALLOW;

                if (target.contains('onelink.shein.com')) {
                  final String? resolved =
                      await SheinLinkResolver.resolve(target);
                  if (resolved != null) {
                    await controller.loadUrl(
                      urlRequest: URLRequest(url: WebUri(resolved)),
                    );
                  }
                  return NavigationActionPolicy.CANCEL;
                }

                final String? fixed = _shareUrlFrom(target);
                if (fixed != null) {
                  await controller.loadUrl(
                    urlRequest: URLRequest(url: WebUri(fixed)),
                  );
                }
                return NavigationActionPolicy.CANCEL;
              },
              onProgressChanged: (c, p) { setState(() => _progress = p / 100); },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/seloo_config.dart';
import '../../cart/application/cart_counter.dart';
import 'shein_bridge_controller.dart';

class SheinWebScreen extends StatefulWidget {
  const SheinWebScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  State<SheinWebScreen> createState() => _SheinWebScreenState();
}

class _SheinWebScreenState extends State<SheinWebScreen> {
  final SheinBridgeController _bridge = SheinBridgeController();
  final GlobalKey _webViewKey = GlobalKey();

  InAppWebViewController? _controller;
  StreamSubscription<int>? _cartSubscription;
  String? _overlayScript;

  bool _loading = true;
  double _progress = 0;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadOverlayScript();
    _listenToCart();
  }

  Future<void> _loadOverlayScript() async {
    try {
      final String source = await _bridge.loadOverlayScript();
      if (!mounted) return;
      setState(() => _overlayScript = source);
    } catch (e) {
      debugPrint('[Seloo] فشل تحميل السكربت: $e');
      if (!mounted) return;
      setState(() => _overlayScript = '');
    }
  }

  void _listenToCart() {
    try {
      final CartCounter cart = Get.find<CartCounter>();
      _cartSubscription = cart.stream.listen((int value) {
        if (!mounted) return;
        setState(() => _cartCount = value);
        _bridge.pushCartCountToPage();
      });
    } catch (e) {
      debugPrint('[Seloo] CartCounter غير مسجل: $e');
    }
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openExternally(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('تعذّر فتح الرابط: $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        titleSpacing: 12,
        title: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.shopping_bag,
                    color: Color(0xFF7C3AED),
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'يمن سيلو',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'سلة سيلو',
            onPressed: () => Get.toNamed('/cartScreen'),
            icon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          IconButton(
            tooltip: 'إعادة التحميل',
            onPressed: () async => _controller?.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_loading)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              color: const Color(0xFF7C3AED),
            ),
          Expanded(
            child: _overlayScript == null
                ? const Center(child: CircularProgressIndicator())
                : InAppWebView(
                    key: _webViewKey,
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.initialUrl ?? SheinWebConfig.homeAr),
                    ),
                    initialSettings: InAppWebViewSettings(
                      // ⭐ تخزين محلي للجلسة والكوكيز
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      useShouldOverrideUrlLoading: true,

                      // ⭐⭐ الحل الرئيسي للبطء: تعطيل اعتراض الطلبات
                      useShouldInterceptRequest: false,

                      allowsInlineMediaPlayback: true,
                      mediaPlaybackRequiresUserGesture: true,
                      transparentBackground: false,
                      applicationNameForUserAgent: 'YemenSelooApp/1.0',

                      // ⭐ تحسينات إضافية للسرعة
                      cacheEnabled: true,
                      clearCache: false,
                      javaScriptEnabled: true,
                      supportZoom: false,
                      disableVerticalScroll: false,
                      disableHorizontalScroll: false,
                    ),
                    initialUserScripts:
                        UnmodifiableListView<UserScript>(<UserScript>[
                      UserScript(
                        source: _overlayScript!,
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                      ),
                    ]),
                    onWebViewCreated:
                        (InAppWebViewController controller) async {
                      _controller = controller;
                      await _bridge.attach(controller);
                    },
                    onLoadStart: (InAppWebViewController _, WebUri? url) {
                      if (!mounted) return;
                      setState(() => _loading = true);
                    },
                    onLoadStop:
                        (InAppWebViewController controller, WebUri? url) async {
                      if (!mounted) return;
                      setState(() => _loading = false);
                      try {
                        final int count = Get.find<CartCounter>().count;
                        await controller.evaluateJavascript(
                          source:
                              'window.__selooRefresh && window.__selooRefresh($count);',
                        );
                      } catch (e) {
                        debugPrint('[Seloo] evaluateJavascript: $e');
                      }
                    },
                    onProgressChanged:
                        (InAppWebViewController _, int progress) {
                      if (!mounted) return;
                      setState(() => _progress = progress / 100);
                    },
                    onReceivedError: (
                      InAppWebViewController _,
                      WebResourceRequest request,
                      WebResourceError error,
                    ) {
                      debugPrint(
                          '[Seloo] خطأ تحميل ${request.url}: ${error.description}');
                    },
                    shouldOverrideUrlLoading: (
                      InAppWebViewController _,
                      NavigationAction action,
                    ) async {
                      final WebUri? target = action.request.url;
                      if (target == null) return NavigationActionPolicy.ALLOW;
                      final Uri uri = Uri.parse(target.toString());

                      if (SheinNavigationPolicy.isExternalRedirect(uri)) {
                        await _openExternally(uri);
                        return NavigationActionPolicy.CANCEL;
                      }
                      if (uri.scheme.startsWith('http') &&
                          !SheinNavigationPolicy.isInternal(uri)) {
                        await _openExternally(uri);
                        return NavigationActionPolicy.CANCEL;
                      }
                      return SheinNavigationPolicy.decide(uri);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _SelooCartBar(count: _cartCount),
    );
  }
}

class _SelooCartBar extends StatelessWidget {
  const _SelooCartBar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const <BoxShadow>[
            BoxShadow(blurRadius: 8, color: Color(0x22000000)),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.shopping_bag_outlined, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Text(
              count > 0 ? 'في سلة سيلو: $count منتج' : 'سلة سيلو فارغة',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              onPressed: count > 0 ? () => Get.toNamed('/cartScreen') : null,
              child: const Text('إتمام الطلب'),
            ),
          ],
        ),
      ),
    );
  }
}

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

  // ⭐ حالة التعديل
  String? _editLineId;
  String? _editUrl;

  bool _loading = true;
  double _progress = 0;
  int _cartCount = 0;

  bool get _isEditing => _editLineId != null;

  @override
  void initState() {
    super.initState();

    // ⭐ اقرأ arguments من Get
    final Object? args = Get.arguments;
    if (args is Map) {
      final Object? editLineId = args['editLineId'];
      final Object? editUrl = args['editUrl'];
      if (editLineId is String && editLineId.isNotEmpty) {
        _editLineId = editLineId;
      }
      if (editUrl is String && editUrl.isNotEmpty) {
        _editUrl = editUrl;
      }
    }

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

    // ⭐ امسح حالة التعديل إذا خرج المستخدم قبل الإتمام
    try {
      final CartCounter cart = Get.find<CartCounter>();
      if (cart.isEditing) cart.clearEditing();
    } catch (_) {}

    super.dispose();
  }

  Future<void> _openExternally(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('تعذّر فتح الرابط: $uri');
    }
  }

  void _cancelEdit() {
    try {
      Get.find<CartCounter>().clearEditing();
    } catch (_) {}
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final Color barColor =
        _isEditing ? const Color(0xFFEA580C) : const Color(0xFF7C3AED);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: barColor,
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
            Text(
              _isEditing ? 'تعديل المنتج' : 'يمن سيلو',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: <Widget>[
          if (_isEditing)
            IconButton(
              tooltip: 'إلغاء التعديل',
              onPressed: _cancelEdit,
              icon: const Icon(Icons.close),
            ),
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
              color: barColor,
            ),
          Expanded(
            child: _overlayScript == null
                ? const Center(child: CircularProgressIndicator())
                : InAppWebView(
                    key: _webViewKey,
                    initialUrlRequest: URLRequest(
                      url: WebUri(
                        _editUrl ??
                            widget.initialUrl ??
                            SheinWebConfig.homeAr,
                      ),
                    ),
                    initialSettings: InAppWebViewSettings(
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      useShouldOverrideUrlLoading: true,
                      useShouldInterceptRequest: false,
                      allowsInlineMediaPlayback: true,
                      mediaPlaybackRequiresUserGesture: true,
                      transparentBackground: false,
                      applicationNameForUserAgent: 'YemenSelooApp/1.0',
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
                      InAppWebViewController controller,
                      WebResourceRequest request,
                      WebResourceError error,
                    ) {
                      debugPrint(
                          '[Seloo] خطأ تحميل ${request.url}: ${error.description}');

                      // ⭐ إذا فشل التحميل الرئيسي
                      final bool isMain = request.isForMainFrame ?? false;
                      if (isMain && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'تعذّر تحميل الصفحة: ${error.description}'),
                            action: SnackBarAction(
                              label: 'إعادة',
                              onPressed: () => controller.reload(),
                            ),
                          ),
                        );
                      }
                    },
                    shouldOverrideUrlLoading: (
                      InAppWebViewController _,
                      NavigationAction action,
                    ) async {
                      final WebUri? target = action.request.url;
                      if (target == null) return NavigationActionPolicy.ALLOW;
                      final Uri uri = Uri.parse(target.toString());

                      // ⭐ منع تسجيل الدخول إلى SHEIN / Google / Apple
                      if (SheinWebConfig.loginHosts
                          .any((String h) => uri.host.endsWith(h))) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'التصفح داخل يمن سيلو لا يحتاج إلى حساب SHEIN.'),
                            ),
                          );
                        }
                        return NavigationActionPolicy.CANCEL;
                      }

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

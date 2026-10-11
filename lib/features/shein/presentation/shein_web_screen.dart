import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import '../../../core/config/seloo_config.dart';
import '../../cart/application/cart_counter.dart';
import 'shein_bridge_controller.dart';

/// شاشة SHEIN داخل WebView (flutter_inappwebview).
/// ⚠️ لا تحتوي Scaffold/AppBar — لأنها تُعرض داخل MainShell.
/// ✅ تُضيف AppBar برتقالي فقط في وضع التعديل.
class SheinWebScreen extends StatefulWidget {
  const SheinWebScreen({super.key});

  @override
  State<SheinWebScreen> createState() => _SheinWebScreenState();
}

class _SheinWebScreenState extends State<SheinWebScreen> {
  final CartCounter _cartCounter = Get.find<CartCounter>();
  final SheinBridgeController _bridgeController = SheinBridgeController();

  InAppWebViewController? _webViewController;
  String? _editLineId;
  String? _editUrl;
  double _progress = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final dynamic args = Get.arguments;
    if (args is Map) {
      _editLineId = args['editLineId'] as String?;
      _editUrl = args['editUrl'] as String?;
      if (_editUrl == null && args['openUrl'] is String) {
        _editUrl = args['openUrl'] as String?;
      }
    }

    if (_editLineId != null) {
      _cartCounter.editingLineId.value = _editLineId!;
    }
  }

  @override
  void dispose() {
    _cartCounter.clearEditing();
    super.dispose();
  }

  String get _initialUrl => _editUrl ?? SheinWebConfig.homeAr;

  InAppWebViewSettings _buildSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      cacheEnabled: true,
      clearCache: false,
      useHybridComposition: true,
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
      applicationNameForUserAgent:
          'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      supportMultipleWindows: false,
      javaScriptCanOpenWindowsAutomatically: false,
      supportZoom: false,
      builtInZoomControls: false,
      displayZoomControls: false,
      useWideViewPort: true,
      loadWithOverviewMode: true,
      transparentBackground: false,
    );
  }

  Future<void> _injectScripts(InAppWebViewController controller) async {
    try {
      final String editId = _cartCounter.editingLineId.value ?? '';
      await controller.evaluateJavascript(
        source: 'window.__SELOO_EDITING_LINE_ID__ = "$editId";',
      );
      final String script = await _bridgeController.loadOverlayScript();
      await controller.evaluateJavascript(source: script);
    } catch (e) {
      debugPrint('[Seloo] فشل حقن السكربت: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = _editLineId != null;

    return Column(
      children: <Widget>[
        // ⭐ AppBar صغير — يظهر فقط في وضع التعديل
        if (isEditing)
          Container(
            color: const Color(0xFFF97316),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.edit, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'وضع التعديل',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _cartCounter.clearEditing();
                    // العودة إلى تبويب السلة
                    Get.back();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('إلغاء'),
                ),
              ],
            ),
          ),
        // شريط التحميل
        if (_isLoading && _progress < 1)
          LinearProgressIndicator(
            value: _progress,
            color: const Color(0xFF7C3AED),
            backgroundColor: Colors.transparent,
            minHeight: 3,
          ),
        // WebView
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(_initialUrl),
              headers: <String, String>{
                'Accept-Language': 'ar,ar-SA;q=0.9,en;q=0.5',
              },
            ),
            initialSettings: _buildSettings(),
            onWebViewCreated: (InAppWebViewController controller) async {
              _webViewController = controller;
              await _bridgeController.attach(controller);
            },
            onLoadStart: (controller, url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _progress = 0;
                });
              }
            },
            onLoadStop: (controller, url) async {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _progress = 1;
                });
              }
              await _injectScripts(controller);
            },
            onProgressChanged: (controller, progress) {
              if (mounted) {
                setState(() => _progress = progress / 100);
              }
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame ?? false) {
                if (mounted) setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('فشل تحميل الصفحة: ${error.description}'),
                  ),
                );
              }
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final WebUri? webUri = action.request.url;
              if (webUri == null) return NavigationActionPolicy.ALLOW;
              final Uri uri = Uri.parse(webUri.toString());
              return SheinNavigationPolicy.decide(uri);
            },
          ),
        ),
      ],
    );
  }
}

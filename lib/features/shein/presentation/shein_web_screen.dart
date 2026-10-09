import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/shein_bridge_controller.dart';
import '../../cart/application/cart_counter.dart';

/// شاشة SHEIN داخل WebView.
/// - تدعم وضع التعديل (editLineId + editUrl).
/// - تفرض اللغة العربية عبر Accept-Language.
/// - تستخدم User-Agent للهاتف لتسريع التصفح.
class SheinWebScreen extends StatefulWidget {
  const SheinWebScreen({super.key});

  @override
  State<SheinWebScreen> createState() => _SheinWebScreenState();
}

class _SheinWebScreenState extends State<SheinWebScreen> {
  late final WebViewController _controller;
  final CartCounter _cartCounter = Get.find<CartCounter>();
  final SheinBridgeController _bridgeController =
      Get.find<SheinBridgeController>();

  String? _editLineId;
  String? _editUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // ⭐ استقبال arguments (تعديل أو فتح منتج)
    final Map<String, dynamic>? args =
        Get.arguments is Map ? Map<String, dynamic>.from(Get.arguments as Map) : null;

    if (args != null) {
      _editLineId = args['editLineId'] as String?;
      _editUrl = args['editUrl'] as String?;

      // ⭐ دعم فتح رابط منتج من السلة (بدون تعديل)
      if (_editUrl == null && args['openUrl'] is String) {
        _editUrl = args['openUrl'] as String?;
      }
    }

    if (_editLineId != null) {
      _cartCounter.editingLineId.value = _editLineId!;
    }

    // ⭐ الرابط الافتراضي: النسخة العربية
    final String initialUrl = _editUrl ?? 'https://ar.shein.com/';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // ⭐ User-Agent للهاتف (يحمّل نسخة أخف وأسرع)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            // ⭐ حقن السكربت (seloo_shein_overlay.js)
            _bridgeController.injectJavaScript(_controller, url);
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            if (error.isForMainFrame == true) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('فشل تحميل الصفحة: ${error.description}'),
                ),
              );
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // ⭐ منع فتح روابط خارجية داخل WebView
            final String url = request.url;
            if (url.startsWith('https://www.shein.com') ||
                url.startsWith('https://ar.shein.com') ||
                url.startsWith('https://m.shein.com') ||
                url.startsWith('https://sa.shein.com') ||
                url.startsWith('https://ar.shein.com.sa') ||
                url.startsWith('https://www.shein.com.sa') ||
                url.contains('shein.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(initialUrl),
        // ⭐ فرض اللغة العربية على كل الطلبات
        headers: <String, String>{
          'Accept-Language': 'ar,ar-SA;q=0.9,ar-EG;q=0.8,en;q=0.5',
        },
      );
  }

  @override
  void dispose() {
    // ⭐ تنظيف حالة التعديل عند مغادرة الشاشة
    _cartCounter.clearEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = _editLineId != null;

    return Scaffold(
      appBar: AppBar(
        // ⭐ لون برتقالي في وضع التعديل، بنفسجي عادي
        backgroundColor:
            isEditing ? const Color(0xFFF97316) : const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        elevation: 2,
        title: Text(
          isEditing ? 'تعديل المنتج' : 'تصفح SHEIN',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          // ⭐ زر إلغاء التعديل
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'إلغاء التعديل',
              onPressed: () {
                _cartCounter.clearEditing();
                Get.back();
              },
            ),
          // ⭐ زر تحديث الصفحة
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              setState(() => _isLoading = true);
              _controller.reload();
            },
          ),
          // ⭐ زر الصفحة الرئيسية
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'الرئيسية',
            onPressed: () {
              _controller.loadRequest(
                Uri.parse('https://ar.shein.com/'),
                headers: <String, String>{
                  'Accept-Language': 'ar,ar-SA;q=0.9,en;q=0.5',
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: _controller),
          // ⭐ شريط تحميل رقيق أعلى الشاشة
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                color: Color(0xFF7C3AED),
                backgroundColor: Colors.transparent,
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }
}

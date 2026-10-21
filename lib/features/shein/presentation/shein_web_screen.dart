import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import '../../../core/config/seloo_config.dart';
import '../../cart/application/cart_counter.dart';
import '../../home/presentation/main_tab_controller.dart';
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
  double _progress = 0;
  bool _isLoading = true;

  // ⭐ متغيرات التحكم في الزحف
  bool _isCrawling = false;
  int _currentCrawlIndex = 0;
  int _totalCrawlItems = 0;
  int _addedCount = 0;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      _shareCartUrl = args['shareCartUrl'] as String?;
    }
  }

  String get _initialUrl => _shareCartUrl ?? SheinWebConfig.homeAr;

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
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () {
          if (_isCrawling) {
            setState(() => _isCrawling = false);
          } else {
            Get.back();
          }
        }),
      ),
      body: Column(
        children: <Widget>[
          if (_isLoading && _progress < 1)
            LinearProgressIndicator(value: _progress, color: const Color(0xFF7C3AED), minHeight: 3),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_initialUrl), headers: <String, String>{'Accept-Language': 'ar,ar-SA;q=0.9,en;q=0.5'}),
              initialSettings: _buildSettings(),
              onWebViewCreated: (controller) async {
                _webViewController = controller;
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
              onLoadStart: (c, u) { setState(() { _isLoading = true; _progress = 0; }); },
              onLoadStop: (controller, url) async {
                setState(() { _isLoading = false; _progress = 1; });
                final script = await _bridgeController.loadOverlayScript();
                await controller.evaluateJavascript(source: script);

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
              onProgressChanged: (c, p) { setState(() => _progress = p / 100); },
            ),
          ),
        ],
      ),
    );
  }
}

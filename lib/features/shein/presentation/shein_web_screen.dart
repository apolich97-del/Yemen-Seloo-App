import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import '../../../core/config/seloo_config.dart';
import '../../cart/application/cart_counter.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        title: const Text('استيراد السلة', style: TextStyle(fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
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
              },
              onLoadStart: (c, u) { setState(() { _isLoading = true; _progress = 0; }); },
              onLoadStop: (controller, url) async {
                setState(() { _isLoading = false; _progress = 1; });
                final script = await _bridgeController.loadOverlayScript();
                await controller.evaluateJavascript(source: script);
              },
              onProgressChanged: (c, p) { setState(() => _progress = p / 100); },
            ),
          ),
        ],
      ),
    );
  }
}

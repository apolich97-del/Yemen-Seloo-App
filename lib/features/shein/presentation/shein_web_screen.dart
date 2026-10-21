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
  String? _editLineId;
  String? _editUrl;
  String? _shareCartUrl;
  double _progress = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) {
      _editLineId = args['editLineId'] as String?;
      _editUrl = args['editUrl'] as String?;
      _shareCartUrl = args['shareCartUrl'] as String?;
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

  String get _initialUrl {
    if (_shareCartUrl != null && _shareCartUrl!.isNotEmpty) return _shareCartUrl!;
    return _editUrl ?? SheinWebConfig.homeAr;
  }

  InAppWebViewSettings _buildSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      cacheEnabled: true,
      useHybridComposition: true,
      mediaPlaybackRequiresUserGesture: false,
      applicationNameForUserAgent: 'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    );
  }

  Future<void> _injectScripts(InAppWebViewController controller) async {
    try {
      final String script = await _bridgeController.loadOverlayScript();
      await controller.evaluateJavascript(source: script);
    } catch (e) {
      debugPrint('[Seloo] فشل حقن السكربت: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isImportingCart = _shareCartUrl != null;

    return Column(
      children: <Widget>[
        if (isImportingCart)
          Container(
            color: const Color(0xFF7C3AED),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.download, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('جاري استيراد السلة...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () { _cartCounter.clearEditing(); Get.back(); }, 
                  style: TextButton.styleFrom(foregroundColor: Colors.white), 
                  icon: const Icon(Icons.close, size: 18), 
                  label: const Text('إلغاء')
                ),
              ],
            ),
          ),
        if (_isLoading && _progress < 1)
          LinearProgressIndicator(value: _progress, color: const Color(0xFF7C3AED), backgroundColor: Colors.transparent, minHeight: 3),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_initialUrl), headers: <String, String>{'Accept-Language': 'ar,ar-SA;q=0.9,en;q=0.5'}),
            initialSettings: _buildSettings(),
            onWebViewCreated: (controller) async { 
              _webViewController = controller; 
              await _bridgeController.attach(controller); 
            },
            onLoadStart: (controller, url) { if (mounted) setState(() { _isLoading = true; _progress = 0; }); },
            onLoadStop: (controller, url) async { if (mounted) setState(() { _isLoading = false; _progress = 1; }); await _injectScripts(controller); },
            onProgressChanged: (controller, progress) { if (mounted) setState(() => _progress = progress / 100); },
          ),
        ),
      ],
    );
  }
}

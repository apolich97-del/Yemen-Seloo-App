import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/seloo_config.dart';
import '../../shein/application/shein_cart_importer.dart';
import '../application/cart_counter.dart';
import '../data/seloo_cart_link.dart';
import '../domain/cart_item.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleLight = Color(0xFFFAF7FF);
const Color _border = Color(0xFFE9D5FF);
const Color _green = Color(0xFF25D366);
const Color _orange = Color(0xFFF97316);

const String _primaryWhatsApp = '967770518757';
const String _primaryPhone = '770518757';
const String _backupWhatsApp = '967737383637';
const String _backupPhone = '737383637';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartCounter _cart = Get.find<CartCounter>();
  final TextEditingController _shareCartController =
      TextEditingController();

  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _cart.refreshQuote();
  }

  @override
  void dispose() {
    _shareCartController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    final String? error = await action();
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  // Ø§Ø³ØªÙŠØ±Ø§Ø¯ Ø³Ù„Ø© SHEIN Ø§Ù„Ù…Ø´ØªØ±ÙƒØ© Ø¹Ø¨Ø± ÙˆØ§Ø¬Ù‡Ø© Ø§Ù„Ù…Ø³ØªÙˆØ±Ø¯ Ø§Ù„Ø­Ø§Ù„ÙŠØ©.
  bool _refreshing = false;

  /// Ø¥Ø¹Ø§Ø¯Ø© Ù‚Ø±Ø§Ø¡Ø© Ø§Ù„Ø³Ù„Ø© Ù…Ù† Ø§Ù„ØªØ®Ø²ÙŠÙ† ÙˆØ¥Ø¹Ø§Ø¯Ø© Ø­Ø³Ø§Ø¨ Ø§Ù„Ø£Ø³Ø¹Ø§Ø±
  Future<void> _refreshCart() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _cart.onItemAdded();
      await _cart.refreshQuote();
      _snack('ØªÙ… ØªØ­Ø¯ÙŠØ« Ø§Ù„Ø³Ù„Ø©');
    } catch (_) {
      _snack('ØªØ¹Ø°Ù‘Ø± ØªØ­Ø¯ÙŠØ« Ø§Ù„Ø³Ù„Ø©');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _importSharedCart() async {
    if (_importing) return;

    final String text = _shareCartController.text.trim();

    if (text.isEmpty) {
      _snack('Ø§Ù„ØµÙ‚ Ø±Ø§Ø¨Ø· Ø§Ù„Ø³Ù„Ø© Ø§Ù„Ù…Ø´ØªØ±ÙƒØ© Ø£ÙˆÙ„Ø§Ù‹');
      return;
    }

    setState(() => _importing = true);

    try {
      final SheinCartImportResult result =
          await SheinCartImporter().importSharedCart(text);

      if (!mounted) return;

      setState(() => _importing = false);

      if (!result.success) {
        _snack([result.me](https://result.me)ssage);
        // Ø§Ù„Ù…Ø³Ø§Ø± Ø§Ù„Ù…Ø¶Ù…ÙˆÙ†: ÙØªØ­ Ø§Ù„Ø±Ø§Ø¨Ø· Ø¯Ø§Ø®Ù„ Ù…ØªØµÙØ­ Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ (Ø²Ø± Ø§Ù„Ø²Ø­Ù Ø§Ù„Ø£Ø®Ø¶Ø±)
        await Get.toNamed('/shein', arguments: {'shareCartUrl': text});
        return;
      }

      // Ù†Ø­ÙØ¸ Ø±Ø§Ø¨Ø· Ø§Ù„Ø³Ù„Ø© Ø§Ù„Ù…Ø´ØªØ±Ùƒ Ù„ØªÙØ±ÙÙŽÙ‚ Ø¨Ù‡ Ø±Ø³Ø§Ù„Ø© ÙˆØ§ØªØ³Ø§Ø¨ Ù„Ø§Ø­Ù‚Ø§Ù‹
      try {
        GetStorage().write('seloo_last_share_url', text);
        // Ù†Ø­ÙØ¸ Ø£Ø³Ø·Ø± Ù‡Ø°Ù‡ Ø§Ù„Ø³Ù„Ø© Ù„ÙŠÙØ±ÙÙŽÙ‚ Ø§Ù„Ø±Ø§Ø¨Ø· ÙÙ‚Ø· Ø¥Ù† Ø·Ø§Ø¨Ù‚ Ù…Ø­ØªÙˆÙ‰ Ø§Ù„Ø³Ù„Ø© Ø§Ù„Ø­Ø§Ù„ÙŠ
        final List<String> ids =
            _cart.items.map((CartItem e) => e.lineId).toList();
        GetStorage().write('seloo_share_link_lines', jsonEncode(ids));
      } catch (_) {}

      _shareCartController.clear();
      await _cart.refreshQuote();

      _snack([result.me](https://result.me)ssage);
    } catch (_) {
      if (!mounted) return;

      setState(() => _importing = false);
      _snack(
        'ÙØ´Ù„ Ø§Ø³ØªÙŠØ±Ø§Ø¯ Ø§Ù„Ø³Ù„Ø©. ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ø±Ø§Ø¨Ø· ÙˆØ§Ù„Ø§ØªØµØ§Ù„ Ø«Ù… Ø£Ø¹Ø¯ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø©.',
      );
    }
  }

  Future<void> _shareCartToWhatsApp() async {
    if (_cart.items.isEmpty) {
      _snack('Ø§Ù„Ø³Ù„Ø© ÙØ§Ø±ØºØ©');
      return;
    }

    await _cart.refreshQuote();
    final CartQuote? q = _cart.quote.value;

    if (q == null) {
      _snack('ØªØ¹Ø°Ù‘Ø± Ø­Ø³Ø§Ø¨ Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠØŒ Ø­Ø§ÙˆÙ„ Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.');
      return;
    }

    final String message = _buildWhatsAppMessage(
      q: q,
      includeCommission: false,
    );

    await _sendWhatsApp(message);
  }

  Future<void> _shareCartWithCommission() async {
    if (_cart.items.isEmpty) {
      _snack('Ø§Ù„Ø³Ù„Ø© ÙØ§Ø±ØºØ©');
      return;
    }

    if (!_cart.hasCommission) {
      _snack('Ø£Ø¯Ø®Ù„ Ù…Ø¨Ù„Øº Ø§Ù„Ø¹Ù…ÙˆÙ„Ø© Ø£ÙˆÙ„Ø§Ù‹');
      return;
    }

    await _cart.refreshQuote();
    final CartQuote? q = _cart.quote.value;

    if (q == null) {
      _snack('ØªØ¹Ø°Ù‘Ø± Ø­Ø³Ø§Ø¨ Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final double commissionSar = _cart.commissionTotalSar;
        final double commissionYer = _cart.commissionTotalYer;
        final double rate = q.exchangeRate;
        final double totalSar =
            (q.grandTotalLocal / rate) + commissionSar;
        final double totalYer =
            q.grandTotalLocal + commissionYer;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('âš ï¸ ØªØ£ÙƒÙŠØ¯ Ù…Ø´Ø§Ø±ÙƒØ© Ø§Ù„Ø¹Ù…ÙˆÙ„Ø©'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Ø³ÙŠØªÙ… Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø³Ù„Ø© Ù…Ø¹ Ø§Ù„Ø¹Ù…ÙˆÙ„Ø© Ù„Ù„Ø´Ø±ÙƒØ©ØŒ ÙˆØ³ÙŠØ¯ÙØ¹ Ø§Ù„Ø¹Ù…ÙŠÙ„:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _summaryRow(
                    'ðŸ’µ Ù‚ÙŠÙ…Ø© Ø§Ù„Ø³Ù„Ø©',
                    '${(q.itemsSubtotalLocal / rate).toStringAsFixed(2)} SAR',
                  ),
                  _summaryRow(
                    'ðŸ› ï¸ Ø±Ø³ÙˆÙ… Ø§Ù„Ø®Ø¯Ù…Ø©',
                    '${(q.serviceFeeLocal / rate).toStringAsFixed(2)} SAR',
                  ),
                  _summaryRow(
                    'ðŸšš Ø§Ù„Ø´Ø­Ù†',
                    '${(q.shippingLocal / rate).toStringAsFixed(2)} SAR',
                  ),
                  _summaryRow(
                    'ðŸŽ Ø§Ù„Ø¹Ù…ÙˆÙ„Ø© (${_cart.commissionPerPiece.value.toStringAsFixed(2)} Ã— ${_cart.items.length})',
                    '${commissionSar.toStringAsFixed(2)} SAR',
                  ),
                  const Divider(height: 20),
                  _summaryRow(
                    'ðŸ’° Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø·Ù„ÙˆØ¨',
                    '${totalSar.toStringAsFixed(2)} SAR',
                    emphasize: true,
                  ),
                  _summaryRow(
                    'ðŸ‡¾ðŸ‡ª Ø¨Ø§Ù„Ø±ÙŠØ§Ù„ Ø§Ù„ÙŠÙ…Ù†ÙŠ',
                    '${totalYer.toStringAsFixed(0)} Ø±ÙŠØ§Ù„',
                    emphasize: true,
                  ),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _purpleLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'ðŸŽ *Ø§Ù„Ù…Ø³ØªØ­Ù‚ Ù„Ùƒ* (Ø¨Ø¹Ø¯ Ø®ØµÙ… Ù‚ÙŠÙ…Ø© Ø§Ù„Ø³Ù„Ø©):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _purple,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ø§Ù„Ø¹Ù…ÙˆÙ„Ø© = ${commissionYer.toStringAsFixed(0)} Ø±ÙŠØ§Ù„ ÙŠÙ…Ù†ÙŠ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _purple,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '(${commissionSar.toStringAsFixed(2)} SAR Ã— $rate)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Ø¥Ù„ØºØ§Ø¡',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                ),
                child: const Text('Ù…ÙˆØ§ÙÙ‚ âœ“'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    _[cart.app](https://cart.app)roveCommission();

    final String message = _buildWhatsAppMessage(
      q: q,
      includeCommission: true,
    );

    await _sendWhatsApp(message);
  }

  String _buildWhatsAppMessage({
    required CartQuote q,
    required bool includeCommission,
  }) {
    final StringBuffer b = StringBuffer();

    b.writeln('ðŸ›ï¸ *Ø·Ù„Ø¨ Ø¬Ø¯ÙŠØ¯ Ù…Ù† ÙŠÙ…Ù† Ø³ÙŠÙ„Ùˆ*');
    b.writeln('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');
    b.writeln('');

    for (int i = 0; i < _cart.items.length; i++) {
      final CartItem item = _cart.items[i];

      b.writeln('${i + 1}. ${item.title}');

      if (item.color.isNotEmpty) {
        b.writeln('   Ø§Ù„Ù„ÙˆÙ†: ${item.color}');
      }

      if (item.size.isNotEmpty) {
        b.writeln('   Ø§Ù„Ù…Ù‚Ø§Ø³: ${item.size}');
      }

      if (item.options.isNotEmpty) {
        item.options.forEach((String k, String v) {
          b.writeln('   $k: $v');
        });
      }

      b.writeln('   Ø§Ù„ÙƒÙ…ÙŠØ©: ${item.quantity}');
      b.writeln(
        '   Ø§Ù„Ø³Ø¹Ø±: ${item.sourcePrice.toStringAsFixed(2)} SAR',
      );

      if (item.goodsId.isNotEmpty) {
        // Ø´ÙŠ Ø¥Ù† ØªØ­Ø¬Ø¨ Ø§Ù„ÙØªØ­ Ø§Ù„Ù…Ø¨Ø§Ø´Ø± Ù„ØµÙØ­Ø§Øª Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª Ù…Ù† Ø®Ø§Ø±Ø¬ Ø¬Ù„Ø³Ø© Ø§Ù„Ù…ØªØµÙØ­ØŒ
        // ÙÙŠÙØ±Ø³ÙŽÙ„ Ø±Ù…Ø² Ø§Ù„Ù…Ù†ØªØ¬ Ù†ØµÙ‹Ù‘Ø§ Ø¨Ø¯Ù„ Ø±Ø§Ø¨Ø· Ù„Ø§ ÙŠØ¹Ù…Ù„.
        b.writeln('   ðŸ†” Ø±Ù…Ø² Ø§Ù„Ù…Ù†ØªØ¬: ${item.goodsId}');
        b.writeln('   ðŸ”— https://m.shein.com/ar/pdsearch/${item.goodsId}/');
      } else if (item.sourceUrl.isNotEmpty) {
        b.writeln('   Ø§Ù„Ø±Ø§Ø¨Ø·: ${item.sourceUrl}');
      }

      b.writeln('');
    }

    b.writeln('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');
    b.writeln('ðŸ“¦ Ø¹Ø¯Ø¯ Ø§Ù„Ø£Ø³Ø·Ø±: ${q.linesCount}');
    b.writeln('ðŸ”¢ Ø¹Ø¯Ø¯ Ø§Ù„Ù‚Ø·Ø¹: ${q.unitsCount}');
    b.writeln('');

    final double rate = q.exchangeRate;
    final double subtotalSar = q.itemsSubtotalLocal / rate;
    final double serviceFeeSar = q.serviceFeeLocal / rate;
    final double shippingSar = q.shippingLocal / rate;

    b.writeln(
      'ðŸ’µ Ù‚ÙŠÙ…Ø© Ø§Ù„Ø³Ù„Ø©: ${subtotalSar.toStringAsFixed(2)} SAR',
    );
    b.writeln(
      'ðŸ› ï¸ Ø±Ø³ÙˆÙ… Ø§Ù„Ø®Ø¯Ù…Ø©: ${serviceFeeSar.toStringAsFixed(2)} SAR',
    );
    b.writeln(
      'ðŸšš Ø§Ù„Ø´Ø­Ù†: ${shippingSar.toStringAsFixed(2)} SAR',
    );

    if (includeCommission) {
      final double commissionSar = _cart.commissionTotalSar;
      final double commissionYer = _cart.commissionTotalYer;

      final double totalSar =
          subtotalSar + serviceFeeSar + shippingSar + commissionSar;

      final double totalYer = q.grandTotalLocal + commissionYer;

      b.writeln(
        'ðŸŽ Ø¹Ù…ÙˆÙ„Ø© Ø§Ù„Ù…Ù†Ø¯ÙˆØ¨: ${commissionSar.toStringAsFixed(2)} SAR',
      );
      b.writeln('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');
      b.writeln(
        'ðŸ’° Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø·Ù„ÙˆØ¨: ${totalSar.toStringAsFixed(2)} SAR',
      );
      b.writeln(
        'ðŸ‡¾ðŸ‡ª Ø¨Ø§Ù„Ø±ÙŠØ§Ù„ Ø§Ù„ÙŠÙ…Ù†ÙŠ: ${totalYer.toStringAsFixed(0)} Ø±ÙŠØ§Ù„',
      );
      b.writeln('ðŸ“Š Ø³Ø¹Ø± Ø§Ù„ØµØ±Ù: ${rate.toStringAsFixed(0)}');

      final String regionName =
          _cart.region.value == 'south' ? 'Ø§Ù„Ø¬Ù†ÙˆØ¨' : 'Ø§Ù„Ø´Ù…Ø§Ù„';

      b.writeln('ðŸ“ Ø§Ù„Ù…Ù†Ø·Ù‚Ø©: $regionName');
      b.writeln('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');
      b.writeln('ðŸŽ *Ø§Ù„Ù…Ø³ØªØ­Ù‚ Ù„Ù„Ù…Ù†Ø¯ÙˆØ¨* (Ø¨Ø¹Ø¯ Ø®ØµÙ… Ù‚ÙŠÙ…Ø© Ø§Ù„Ø³Ù„Ø©):');
      b.writeln(
        '   Ø§Ù„Ø¹Ù…ÙˆÙ„Ø© = *${commissionYer.toStringAsFixed(0)} Ø±ÙŠØ§Ù„ ÙŠÙ…Ù†ÙŠ*',
      );
    } else {
      b.writeln('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');
      b.writeln(
        'ðŸ’° Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ: ${(subtotalSar + serviceFeeSar + shippingSar).toStringAsFixed(2)} SAR',
      );
      b.writeln(
        'ðŸ‡¾ðŸ‡ª Ø¨Ø§Ù„Ø±ÙŠØ§Ù„ Ø§Ù„ÙŠÙ…Ù†ÙŠ: ${q.grandTotalLocal.toStringAsFixed(0)} Ø±ÙŠØ§Ù„',
      );
      b.writeln('ðŸ“Š Ø³Ø¹Ø± Ø§Ù„ØµØ±Ù: ${rate.toStringAsFixed(0)}');

      final String regionName =
          _cart.region.value == 'south' ? 'Ø§Ù„Ø¬Ù†ÙˆØ¨' : 'Ø§Ù„Ø´Ù…Ø§Ù„';

      b.writeln('ðŸ“ Ø§Ù„Ù…Ù†Ø·Ù‚Ø©: $regionName');
    }

    b.writeln('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');

    // Ø±Ø§Ø¨Ø· Ø§Ù„Ø³Ù„Ø© ÙƒÙ…Ø§ ÙˆØµÙ„Øª Ù…Ù† Ø´ÙŠ Ø¥Ù† (ÙŠÙÙØªØ­ ÙƒØ§Ù…Ù„Ø§Ù‹ Ø¨Ø¯Ù„ Ø±ÙˆØ§Ø¨Ø· Ù…ØªÙØ±Ù‚Ø©)
    try {
      final String? cartLink =
          GetStorage().read<String>('seloo_last_share_url');
      if (cartLink != null && cartLink.trim().isNotEmpty && _cartMatchesLink()) {
        b.writeln('ðŸ›’ Ø±Ø§Ø¨Ø· Ø§Ù„Ø³Ù„Ø© ÙƒØ§Ù…Ù„Ø© ÙÙŠ Ø´ÙŠ Ø¥Ù†:');
        b.writeln(cartLink.trim());
        b.writeln('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');
      }
    } catch (_) {}

    // Ø±Ø§Ø¨Ø· Ø³Ù„Ø© ÙŠÙ…Ù† Ø³ÙŠÙ„Ùˆ Ø§Ù„ÙƒØ§Ù…Ù„Ø© (ÙƒÙ„ Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª ÙÙŠ Ø±Ø§Ø¨Ø· ÙˆØ§Ø­Ø¯)
    try {
      if (_cart.items.isNotEmpty) {
        b.writeln('ðŸ›’ *Ø³Ù„Ø© ÙƒØ§Ù…Ù„Ø© â€” ÙƒÙ„ Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª ÙÙŠ Ø±Ø§Ø¨Ø· ÙˆØ§Ø­Ø¯:*');
        b.writeln(SelooCartLink.webLink(_cart.items));
        b.writeln('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”');
      }
    } catch (_) {}

    b.writeln('ðŸ“ž Ù„Ù„ØªÙˆØ§ØµÙ„: $_primaryPhone');
    b.writeln('ðŸ“ž Ø§Ù„Ø¨Ø¯ÙŠÙ„: $_backupPhone');
    b.writeln('');
    b.writeln('Ø®Ø¯Ù…ØªÙƒÙ… ØºØ§ÙŠØªÙ†Ø§ ÙˆØ«Ù‚ØªÙƒÙ… Ù‡Ø¯ÙÙ†Ø§');

    return b.toString();
  }

  /// Ù‡Ù„ Ø§Ù„Ø³Ù„Ø© Ø§Ù„Ø­Ø§Ù„ÙŠØ© Ù‡ÙŠ Ù†ÙØ³ Ø§Ù„Ø³Ù„Ø© Ø§Ù„Ù…Ø³ØªÙˆØ±Ø¯Ø© Ù…Ù† Ø§Ù„Ø±Ø§Ø¨Ø·ØŸ (ÙˆØ¥Ù„Ø§ ÙØ§Ù„Ø±Ø§Ø¨Ø· Ù…Ø¶Ù„ÙÙ‘Ù„)
  bool _cartMatchesLink() {
    try {
      final String? raw = GetStorage().read<String>('seloo_share_link_lines');
      if (raw == null || raw.isEmpty) return false;
      final Object? parsed = jsonDecode(raw);
      if (parsed is! List) return false;
      final Set<String> saved = parsed.map((Object? e) => '$e').toSet();
      if (saved.isEmpty) return false;
      // ÙƒÙ„ Ø³Ø·Ø± ÙÙŠ Ø§Ù„Ø³Ù„Ø© ÙŠØ¬Ø¨ Ø£Ù† ÙŠÙƒÙˆÙ† Ù…Ù† ØªÙ„Ùƒ Ø§Ù„Ø³Ù„Ø© Ø§Ù„Ù…Ø³ØªÙˆØ±Ø¯Ø©
      return _cart.items.every((CartItem e) => saved.contains(e.lineId));
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendWhatsApp(String message) async {
    final Uri url = Uri.parse(
      'https://wa.me/$_primaryWhatsApp?text=${Uri.encodeComponent(message)}',
    );

    try {
      final bool ok = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!ok) _snack('ØªØ¹Ø°Ù‘Ø± ÙØªØ­ Ø§Ù„ÙˆØ§ØªØ³Ø§Ø¨');
    } catch (e) {
      _snack('ØªØ¹Ø°Ù‘Ø± ÙØªØ­ Ø§Ù„ÙˆØ§ØªØ³Ø§Ø¨: $e');
    }
  }

  Future<void> _openCommissionCalculator() async {
    if (_cart.items.isEmpty) {
      _snack('Ø§Ù„Ø³Ù„Ø© ÙØ§Ø±ØºØ©');
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: _cart.commissionPerPiece.value > 0
          ? _cart.commissionPerPiece.value.toStringAsFixed(2)
          : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (BuildContext ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (BuildContext ctx, StateSetter setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.calculate, color: _purple, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'ðŸ§® Ø¢Ù„Ø© Ø­Ø³Ø§Ø¨ Ø¹Ù…ÙˆÙ„Ø© Ø§Ù„Ù…Ù†Ø¯ÙˆØ¨',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: _purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Ù…Ø¨Ù„Øº Ø§Ù„Ø¹Ù…ÙˆÙ„Ø© Ù„ÙƒÙ„ Ù‚Ø·Ø¹Ø©',
                        hintText: 'Ù…Ø«Ø§Ù„: 5.00',
                        prefixIcon: const Icon(
                          Icons.attach_money,
                          color: _purple,
                        ),
                        suffixText: 'SAR',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _purple,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (String v) {
                        final double value = double.tryParse(v) ?? 0;

                                                _cart.setCommission(value);
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _purpleLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Obx(() {
                        final double perPiece =
                            _cart.commissionPerPiece.value;
                        final double totalSar = _cart.commissionTotalSar;
                        final double totalYer = _cart.commissionTotalYer;
                        final int count = _cart.items.length;

                        final double rate = totalSar > 0
                            ? totalYer / totalSar
                            : _cart.quote.value?.exchangeRate ?? 140;

                        return Column(
                          children: <Widget>[
                            _summaryRow('ðŸ“¦ Ø¹Ø¯Ø¯ Ø§Ù„Ù‚Ø·Ø¹', '$count'),
                            const SizedBox(height: 6),
                            _summaryRow(
                              'ðŸŽ Ø§Ù„Ø¹Ù…ÙˆÙ„Ø© Ù„ÙƒÙ„ Ù‚Ø·Ø¹Ø©',
                              '${perPiece.toStringAsFixed(2)} SAR',
                            ),
                            const Divider(height: 16),
                            _summaryRow(
                              'ðŸ’° Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø¹Ù…ÙˆÙ„Ø©',
                              '${totalSar.toStringAsFixed(2)} SAR',
                              emphasize: true,
                            ),
                            const SizedBox(height: 6),
                            _summaryRow(
                              'ðŸ‡¾ðŸ‡ª Ø¨Ø§Ù„Ø±ÙŠØ§Ù„ Ø§Ù„ÙŠÙ…Ù†ÙŠ',
                              '${totalYer.toStringAsFixed(0)} Ø±ÙŠØ§Ù„',
                              emphasize: true,
                            ),
                            const SizedBox(height: 6),
                            _summaryRow(
                              'ðŸ“Š Ø³Ø¹Ø± Ø§Ù„ØµØ±Ù',
                              rate.toStringAsFixed(0),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Obx(() {
                      final bool hasCom = _cart.hasCommission;

                      return Column(
                        children: <Widget>[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: hasCom
                                  ? () async {
                                      Navigator.of(ctx).pop();
                                      await _shareCartWithCommission();
                                    }
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.share),
                              label: const Text(
                                'Ù…Ø´Ø§Ø±ÙƒØ© Ù…Ø¹ Ø§Ù„Ø´Ø±ÙƒØ©',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _shareCartToWhatsApp();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _purple,
                                side: const BorderSide(color: _purple),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.share),
                              label: const Text(
                                'Ù…Ø´Ø§Ø±ÙƒØ© Ø¹Ø§Ø¯ÙŠØ© (Ø¨Ø¯ÙˆÙ† Ø¹Ù…ÙˆÙ„Ø©)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Ø¥ØºÙ„Ø§Ù‚'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    controller.dispose();
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? _purple : const Color(0xFF374151),
              fontWeight:
                  emphasize ? FontWeight.w900 : FontWeight.w500,
              fontSize: emphasize ? 14 : 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? _purple : const Color(0xFF374151),
            fontWeight:
                emphasize ? FontWeight.w900 : FontWeight.w600,
            fontSize: emphasize ? 14 : 13,
          ),
        ),
      ],
    );
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildImportSheinCartButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _orange.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.download_outlined, color: _orange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Ø§Ø³ØªÙŠØ±Ø§Ø¯ Ø³Ù„Ø© Ø´ÙŠ Ø§Ù†',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ø§Ù„ØµÙ‚ Ø±Ø§Ø¨Ø· Ø§Ù„Ø³Ù„Ø© Ø§Ù„Ù…Ø´ØªØ±ÙƒØ© Ù…Ù† Ø´ÙŠ Ø¥Ù† (Ø£Ùˆ Ù†Øµ Ø§Ù„Ù…Ø´Ø§Ø±ÙƒØ© Ø§Ù„ÙƒØ§Ù…Ù„):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _shareCartController,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'https://m.shein.com/ar/cart/share/landing?...',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _importing ? null : _importSharedCart,
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                ),
                child: _importing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Ø¨Ø¯Ø¡ Ø§Ù„Ø§Ø³ØªÙŠØ±Ø§Ø¯',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Obx(() {
            if (_cart.items.isEmpty) {
              return Column(
                children: <Widget>[
                  _Header(count: _cart.items.length, onRefresh: _refreshCart),
                  const SizedBox(height: 8),
                  _buildImportSheinCartButton(),
                  const Expanded(child: _EmptyCart()),
                ],
              );
            }

            return Column(
              children: <Widget>[
                _Header(count: _cart.items.length, onRefresh: _refreshCart),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    children: <Widget>[
                      const Text(
                        'Ø³Ù„Ø© Ø§Ù„ØªØ³ÙˆÙ‚',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ø§Ø®ØªØ± Ù…Ù†Ø·Ù‚Ø© Ø§Ù„ØªØ³Ø¹ÙŠØ±ØŒ Ø«Ù… Ø´Ø§Ø±Ùƒ Ø³Ù„ØªÙƒ Ø£Ùˆ Ø£ÙƒÙ‘Ø¯ Ø·Ù„Ø¨Ùƒ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildImportSheinCartButton(),
                      const SizedBox(height: 10),
                      ..._cart.items.map(
                        (CartItem item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CartLineTile(
                            item: item,
                            onQuantity: (int v) =>
                                _run(() => _cart.updateQuantity(item, v)),
                            onRemove: () => _run(() => _cart.remove(item)),
                            onEdit: () => _cart.startEditing(item),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RegionSelector(cart: _cart),
                      const SizedBox(height: 10),
                      _QuoteSummary(cart: _cart),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openCommissionCalculator,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _purple,
                            side: const BorderSide(
                              color: _purple,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.calculate, size: 20),
                          label: const Text(
                            'ðŸ§® Ø¢Ù„Ø© Ø­Ø³Ø§Ø¨ Ø¹Ù…ÙˆÙ„Ø© Ø§Ù„Ù…Ù†Ø¯ÙˆØ¨',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _shareCartToWhatsApp,
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.share),
                          label: const Text(
                            'Ù…Ø´Ø§Ø±ÙƒØ© Ø§Ù„Ø³Ù„Ø© Ø¹Ø¨Ø± ÙˆØ§ØªØ³Ø§Ø¨',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CheckoutButton(cart: _cart),
                      const SizedBox(height: 8),
                      Text(
                        SelooConfig.priceDisclaimer,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ContactBox(),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// Header
class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onRefresh});

  final int count;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _purpleLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: _purple,
                  size: 22,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'ØªØ­Ø¯ÙŠØ« Ø§Ù„Ø³Ù„Ø©',
            icon: const Icon(Icons.refresh, color: _purple, size: 22),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const <Widget>[
              Text(
                'ÙŠÙ…Ù† Ø³ÙŠÙ„Ùˆ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: _purple,
                ),
              ),
              Text(
                'YEMEN SELOO',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 2,
                  color: _purple,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _purpleLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.storefront,
              color: _purple,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// Cart line
class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.item,
    required this.onQuantity,
    required this.onRemove,
    required this.onEdit,
  });

  final CartItem item;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  /// Ø¶ØºØ·Ø© Ø·ÙˆÙŠÙ„Ø© Ø¹Ù„Ù‰ Ø§Ù„ØµÙˆØ±Ø© ØªÙƒØ´Ù Ø±Ø§Ø¨Ø·Ù‡Ø§ â€” Ù„Ù„ØªØ´Ø®ÙŠØµ ÙÙ‚Ø·
  void _showImageDebug(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('Ø±Ø§Ø¨Ø· ØµÙˆØ±Ø© Ø§Ù„Ù…Ù†ØªØ¬'),
          content: SingleChildScrollView(
            child: SelectableText(
              item.imageUrl.isEmpty ? '(ÙØ§Ø±Øº)' : item.imageUrl,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ø¥ØºÙ„Ø§Ù‚'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1.2),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GestureDetector(
                onTap: onEdit,
                onLongPress: () => _showImageDebug(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: _ProductImage(url: item.imageUrl),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: onRemove,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'SAR ${item.sourcePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Color(0xFF1F2937),
                        height: 1.4,
                      ),
                    ),
                    if (item.color.isNotEmpty || item.size.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            if (item.color.isNotEmpty)
                              _InfoChip(
                                label: 'Ø§Ù„Ù„ÙˆÙ†',
                                value: item.color,
                                color: _purple,
                              ),
                            if (item.size.isNotEmpty)
                              _InfoChip(
                                label: 'Ø§Ù„Ù…Ù‚Ø§Ø³',
                                value: item.size,
                                color: _orange,
                              ),
                          ],
                        ),
                      ),
                    if (item.options.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: item.options.entries
                              .map(
                                (MapEntry<String, String> e) => _InfoChip(
                                  label: e.key,
                                  value: e.value,
                                  color: const Color(0xFF10B981),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _QuantityButton(
                icon: Icons.remove,
                enabled: item.quantity > 1,
                onTap: () => onQuantity(item.quantity - 1),
              ),
              const SizedBox(width: 12),
              Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              _QuantityButton(
                icon: Icons.add,
                enabled:
                    item.quantity < SelooConfig.maxQuantityPerLine,
                onTap: () => onQuantity(item.quantity + 1),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: _orange,
                  size: 20,
                ),
                tooltip: 'ØªØ¹Ø¯ÙŠÙ„',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  /// ÙŠØµÙ„Ø­ Ø§Ù„Ø±ÙˆØ§Ø¨Ø· Ø§Ù„Ù‚Ø¯ÙŠÙ…Ø© Ø§Ù„Ù…Ø®Ø²Ù‘Ù†Ø© Ø¨ØµÙŠØºØ© Ù†Ø³Ø¨ÙŠØ© (Ø¨Ù„Ø§ https) ÙÙ„Ø§ ØªØ¸Ù‡Ø± ØµÙˆØ±ØªÙ‡Ø§
  static String _absolute(String raw) {
    String u = raw.trim().replaceAll(' ', '');
    if (u.isEmpty) return '';

    // Ù„Ùˆ ØªÙƒØ±Ù‘Ø± Ø§Ù„Ù…Ø®Ø·Ø· Ø£Ùˆ Ø§Ù„Ø¯ÙˆÙ…ÙŠÙ† Ø¯Ø§Ø®Ù„ Ø§Ù„Ø±Ø§Ø¨Ø· Ù†Ø£Ø®Ø° Ø¢Ø®Ø± Ø¬Ø²Ø¡ Ø³Ù„ÙŠÙ…
    final int lastScheme = u.lastIndexOf('http');
    if (lastScheme > 0) u = u.substring(lastScheme);

    if (u.startsWith('//')) u = 'https:$u';
    if (!u.startsWith('http')) {
      u = u.startsWith('/')
          ? 'https://img.ltwebstatic.com$u'
          : 'https://img.ltwebstatic.com/$u';
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final String src = _absolute(url);
    if (src.isEmpty) return _placeholder();

    return CachedNetworkImage(
      imageUrl: src,
      fit: BoxFit.cover,
      // Ø´ÙŠ Ø¥Ù† ØªØ±ÙØ¶ Ø¨Ø¹Ø¶ Ø§Ù„ØµÙˆØ± Ø¨Ù„Ø§ Ù‡ÙˆÙŠØ© Ù…ØªØµÙØ­/Ù…Ø±Ø¬Ø¹ â€” Ù†Ø±Ø³Ù„Ù‡Ø§ ÙƒÙ…Ø§ ÙŠÙØ¹Ù„ Ø§Ù„ÙˆÙŠØ¨
      httpHeaders: const <String, String>{
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-G991B) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://m.shein.com/',
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      },
      placeholder: (_, __) => Container(
        color: _purpleLight,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _purple,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        color: _purpleLight,
        child: const Icon(
          Icons.image_outlined,
          color: _purple,
          size: 32,
        ),
      );
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

    @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? _purpleLight : const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? _purple : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}

class _RegionSelector extends StatelessWidget {
  const _RegionSelector({required this.cart});

  final CartCounter cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String current = cart.region.value;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.public, color: _purple, size: 18),
                SizedBox(width: 6),
                Text(
                  'Ù…Ù†Ø·Ù‚Ø© Ø§Ù„ØªØ³Ø¹ÙŠØ±',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _purple,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _RegionButton(
                    label: 'Ø§Ù„Ø´Ù…Ø§Ù„ Â· 140',
                    active: current == 'north',
                    onTap: () => cart.setRegion('north'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RegionButton(
                    label: 'Ø§Ù„Ø¬Ù†ÙˆØ¨ Â· 413',
                    active: current == 'south',
                    onTap: () => cart.setRegion('south'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _RegionButton extends StatelessWidget {
  const _RegionButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? _purple : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _purple : _border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : _purple,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({required this.cart});

  final CartCounter cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final CartQuote? q = cart.quote.value;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: q == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(color: _purple),
              )
            : Column(
                children: <Widget>[
                  _row('ðŸ“¦ Ø¹Ø¯Ø¯ Ø§Ù„Ø£Ø³Ø·Ø±', '${q.linesCount}'),
                  const SizedBox(height: 8),
                  _row('ðŸ”¢ Ø¹Ø¯Ø¯ Ø§Ù„Ù‚Ø·Ø¹', '${q.unitsCount}'),
                  const Divider(height: 20),
                  _row(
                    'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª',
                    'SAR ${(q.itemsSubtotalLocal / q.exchangeRate).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'Ø±Ø³ÙˆÙ… Ø§Ù„Ø®Ø¯Ù…Ø©',
                    'SAR ${(q.serviceFeeLocal / q.exchangeRate).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'Ø§Ù„Ø´Ø­Ù†',
                    'SAR ${(q.shippingLocal / q.exchangeRate).toStringAsFixed(2)}',
                  ),
                  const Divider(height: 20),
                  _row(
                    'Ø³Ø¹Ø± Ø§Ù„ØµØ±Ù',
                    'YER / SAR ${q.exchangeRate.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _row(
                    'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø¨Ø§Ù„Ø±ÙŠØ§Ù„ Ø§Ù„ÙŠÙ…Ù†ÙŠ',
                    '${q.grandTotalLocal.toStringAsFixed(0)} Ø±.ÙŠ',
                    emphasize: true,
                  ),
                ],
              ),
      );
    });
  }

  Widget _row(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? _purple : const Color(0xFF374151),
              fontWeight:
                  emphasize ? FontWeight.w900 : FontWeight.w500,
              fontSize: emphasize ? 15 : 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize ? _purple : const Color(0xFF374151),
            fontWeight:
                emphasize ? FontWeight.w900 : FontWeight.w600,
            fontSize: emphasize ? 15 : 13,
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({required this.cart});

  final CartCounter cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool enabled =
          cart.quote.value != null && cart.items.isNotEmpty;

      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed:
              enabled ? () => Get.toNamed('/checkoutScreen') : null,
          style: FilledButton.styleFrom(
            backgroundColor: _purple,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Ø§Ù„Ø§Ù†ØªÙ‚Ø§Ù„ Ù„ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø·Ù„Ø¨',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      );
    });
  }
}

class _ContactBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _purpleLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: <Widget>[
          Text(
            'ðŸ“ž Ù„Ù„ØªÙˆØ§ØµÙ„ Ù…Ø¹Ù†Ø§',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _purple,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Ø§Ù„Ø£Ø³Ø§Ø³ÙŠ: $_primaryPhone',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Ø§Ù„Ø¨Ø¯ÙŠÙ„: $_backupPhone',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: _purple,
          ),
          const SizedBox(height: 12),
          const Text('Ø³Ù„ØªÙƒ ÙØ§Ø±ØºØ©. ØªØµÙÙ‘Ø­ SHEIN ÙˆØ£Ø¶Ù Ù…Ø§ ÙŠØ¹Ø¬Ø¨Ùƒ.'),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () => Get.offNamed('/shein'),
            child: const Text('ØªØµÙÙ‘Ø­ SHEIN'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:location/location.dart' as geo;

import '../../../core/config/seloo_config.dart';
import '../../cart/application/cart_counter.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../../cart/domain/cart_item.dart';
import '../../shein/domain/shein_draft.dart';

/// شاشة إتمام الطلب: تجمع بيانات التوصيل ثم تُنشئ الطلب على الخادم.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SelooCartService _service = SelooCartService();
  final CartCounter _cart = Get.find<CartCounter>();

  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _city = TextEditingController();

  double? _lat;
  double? _lng;
  bool _sending = false;
  bool _locating = false;

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final geo.Location location = geo.Location();
      if (!await location.serviceEnabled() && !await location.requestService()) {
        throw StateError('خدمة الموقع معطّلة');
      }
      geo.PermissionStatus status = await location.hasPermission();
      if (status == geo.PermissionStatus.denied) {
        status = await location.requestPermission();
      }
      if (status != geo.PermissionStatus.granted) {
        throw StateError('لم يُمنح إذن الموقع');
      }
      final geo.LocationData data = await location.getLocation();
      if (!mounted) return;
      setState(() {
        _lat = data.latitude;
        _lng = data.longitude;
      });
      _snack('تم تحديد موقعك');
    } catch (error) {
      _snack('تعذّر تحديد الموقع: $error');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_lat == null || _lng == null) {
      _snack('حدّد موقع التوصيل أولًا');
      return;
    }

    setState(() => _sending = true);
    try {
      final BridgeResult result = await _service.submitOrder(
        contactPhone: _phone.text.trim(),
        addressLine: _address.text.trim(),
        city: _city.text.trim(),
        lat: _lat!,
        lng: _lng!,
      );
      if (!mounted) return;

      if (result.isOk) {
        final String orderId = result.orderId ?? '';
        await Get.dialog<void>(
          AlertDialog(
            title: const Text('تم إنشاء الطلب'),
            content: Text(
              'رقم الطلب: $orderId\n'
              'يرجى إتمام الدفع عبر إحدى قنوات يمن سيلو.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Get.back<void>(),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        );
        _cart.quote.value = null;
        Get.offAllNamed('/shein');
      } else {
        _snack(result.message);
      }
    } catch (error) {
      _snack('تعذّر إنشاء الطلب: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        title: const Text('إتمام الطلب'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم التواصل',
                hintText: '+967xxxxxxxxx',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone, color: Color(0xFF7C3AED)),
              ),
              validator: (String? value) {
                final String v = (value ?? '').trim();
                if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(v)) {
                  return 'رقم هاتف غير صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'المدينة',
                border: OutlineInputBorder(),
                prefixIcon:
                    Icon(Icons.location_city, color: Color(0xFF7C3AED)),
              ),
              validator: (String? value) =>
                  (value ?? '').trim().length < 2 ? 'المدينة مطلوبة' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'العنوان بالتفصيل',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home_outlined, color: Color(0xFF7C3AED)),
              ),
              validator: (String? value) =>
                  (value ?? '').trim().length < 5 ? 'العنوان مطلوب' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _lat == null
                    ? 'تحديد موقع التوصيل'
                    : 'الموقع: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
              ),
            ),
            const SizedBox(height: 20),
            _Summary(cart: _cart),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: const Text('تأكيد الطلب',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            const _PolicyNotes(),
          ],
        ),
      ),
    );
  }
}

class _PolicyNotes extends StatelessWidget {
  const _PolicyNotes();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.info_outline, color: Color(0xFF7C3AED), size: 20),
              SizedBox(width: 6),
              Text('ملاحظات مهمة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
            ],
          ),
          const SizedBox(height: 8),
          _bullet(SelooConfig.priceDisclaimer),
          _bullet(SelooConfig.paymentNote),
          _bullet(SelooConfig.shippingEstimate),
          _bullet(SelooConfig.damagePolicy),
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('•  ', style: TextStyle(color: Color(0xFF7C3AED))),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 12.5, height: 1.5))),
          ],
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.cart});

  final CartCounter cart;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final CartQuote? quote = cart.quote.value;
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: quote == null
              ? Row(
                  children: <Widget>[
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF7C3AED))),
                    const SizedBox(width: 12),
                    Text('جارٍ حساب الإجمالي… (${cart.items.length} منتجًا)'),
                  ],
                )
              : Column(
                  children: <Widget>[
                    Text('${quote.linesCount} منتجًا • ${quote.unitsCount} وحدة'),
                    const Divider(),
                    Text(
                      'الإجمالي: ${quote.grandTotalLocal.toStringAsFixed(0)} ر.ي',
                      style: const TextStyle(
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }
}

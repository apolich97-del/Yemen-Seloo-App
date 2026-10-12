import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:location/location.dart' as geo;

import '../../../core/config/seloo_config.dart';
import '../../cart/application/cart_counter.dart';
import '../../cart/data/seloo_cart_service.dart';
import '../../cart/domain/cart_item.dart';

/// شاشة إتمام الطلب: تجمع بيانات التوصيل ثم تُنشئ الطلب.
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
      if (!await location.serviceEnabled() &&
          !await location.requestService()) {
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
      // ⭐ إرسال بيانات التسعير والعمولة
      final BridgeResult result = await _service.submitOrder(
        contactPhone: _phone.text.trim(),
        addressLine: _address.text.trim(),
        city: _city.text.trim(),
        lat: _lat!,
        lng: _lng!,
        region: _cart.region.value,
        commissionPerPiece: _cart.commissionPerPiece.value,
        commissionApproved: _cart.commissionApproved.value,
      );
      if (!mounted) return;

      if (result.isOk) {
        final String orderId = result.orderId ?? '';
        final bool hasCommission =
            _cart.commissionApproved.value && _cart.hasCommission;
        final double commissionYer =
            hasCommission ? _cart.commissionTotalYer : 0.0;

        await Get.dialog<void>(
          Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('تم إنشاء الطلب'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('رقم الطلب: $orderId'),
                  const SizedBox(height: 8),
                  const Text(
                    'يرجى إتمام الدفع عبر إحدى قنوات يمن سيلو.',
                    style: TextStyle(fontSize: 13),
                  ),
                  if (hasCommission) ...<Widget>[
                    const Divider(height: 20),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '🎁 *المستحق لك* (عمولة المندوب):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${commissionYer.toStringAsFixed(0)} ريال يمني',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7C3AED),
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            '(بعد خصم قيمة السلة)',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Get.back<void>(),
                  child: const Text('حسنًا'),
                ),
              ],
            ),
          ),
        );

        // مسح حالة العمولة بعد نجاح الطلب
        _cart.unapproveCommission();
        _cart.quote.value = null;
        Get.offAllNamed('/main');
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
      final bool hasCommission =
          cart.commissionApproved.value && cart.hasCommission;

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
                    const Divider(height: 16),

                    // ⭐ العمولة إن وُجدت
                    if (hasCommission) ...<Widget>[
                      Row(
                        children: <Widget>[
                          const Text('🎁 عمولة المندوب:',
                              style: TextStyle(fontSize: 13)),
                          const Spacer(),
                          Text(
                            '${cart.commissionTotalSar.toStringAsFixed(2)} SAR',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const Text('🇾🇪 بالريال اليمني:',
                              style: TextStyle(fontSize: 13)),
                          const Spacer(),
                          Text(
                            '${cart.commissionTotalYer.toStringAsFixed(0)} ريال',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                    ],

                    // الإجمالي
                    Text(
                      'الإجمالي: ${(quote.grandTotalLocal + (hasCommission ? cart.commissionTotalYer : 0)).toStringAsFixed(0)} ر.ي',
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

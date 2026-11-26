import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';

/// خريطة مسار تفاعلية للشحنة: الصين 🇨🇳 ← الإمارات 🇦🇪 ← الجمارك السعودية 🇸🇦 ← اليمن 🇾🇪 ← مدينة العميل.
class InteractiveRouteMap extends StatefulWidget {
  final Order order;
  const InteractiveRouteMap({super.key, required this.order});

  @override
  State<InteractiveRouteMap> createState() => _InteractiveRouteMapState();
}

class _InteractiveRouteMapState extends State<InteractiveRouteMap> {
  int? _selectedIdx;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final m = o.milestone;
    final activeIdx = _selectedIdx ?? m.stepIndex;
    final steps = ShippingMilestone.values;
    final current = steps[activeIdx.clamp(0, steps.length - 1)];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: T.dark
              ? const [Color(0xFF181132), Color(0xFF100B22)]
              : const [Color(0xFFF6F2FF), Color(0xFFFFFFFF)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: T.primary.withOpacity(.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.public, size: 18, color: T.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مسار الشحنة التفاعلي',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: T.text),
                    ),
                    Text(
                      'الصين ← الإمارات ← السعودية ← ${o.shippingGovernorate.isNotEmpty ? o.shippingGovernorate : o.address.city}',
                      style: TextStyle(fontSize: 10.5, color: T.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: T.primary.withOpacity(.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(m.progress * 100).round()}%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: T.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 118,
            child: CustomPaint(
              painter: _RouteMapPainter(
                currentStep: m.stepIndex,
                selectedStep: activeIdx,
                primary: T.primary,
                accent: T.accent,
                border: T.border,
                isDark: T.dark,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(steps.length, (i) {
                  final s = steps[i];
                  final reached = i <= m.stepIndex;
                  final selected = i == activeIdx;
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedIdx = i),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(s.emoji, style: TextStyle(fontSize: selected ? 18 : 14)),
                            const SizedBox(height: 2),
                            Text(
                              s.shortAr,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.2,
                                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                                color: reached ? T.primary : T.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.border),
            ),
            child: Row(
              children: [
                Text(current.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.labelAr,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: T.text)),
                      if (o.shippingStageNote.isNotEmpty && current == m)
                        Text(o.shippingStageNote, style: TextStyle(fontSize: 10.5, color: T.muted)),
                      if (o.trackingNo.isNotEmpty)
                        Text('رقم التتبع: ${o.trackingNo}',
                            style: TextStyle(fontSize: 10.5, color: T.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (o.trackingUrl.isNotEmpty || o.trackingImageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (o.trackingUrl.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(o.trackingUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 15),
                      label: const Text('فتح رابط التتبع', style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
                if (o.trackingUrl.isNotEmpty && o.trackingImageUrl.isNotEmpty)
                  const SizedBox(width: 8),
                if (o.trackingImageUrl.isNotEmpty)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBar(
                                title: const Text('صورة التتبع'),
                                automaticallyImplyLeading: false,
                                actions: [
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                              InteractiveViewer(
                                child: Image.network(o.trackingImageUrl, fit: BoxFit.contain),
                              ),
                            ],
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.image_outlined, size: 15),
                      label: const Text('صورة التتبع', style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  final int currentStep;
  final int selectedStep;
  final Color primary;
  final Color accent;
  final Color border;
  final bool isDark;

  _RouteMapPainter({
    required this.currentStep,
    required this.selectedStep,
    required this.primary,
    required this.accent,
    required this.border,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const count = 7;
    final yBase = size.height * 0.34;
    final points = List<Offset>.generate(count, (i) {
      final x = (size.width / count) * (i + 0.5);
      final dy = (i % 2 == 0) ? -10.0 : 10.0;
      return Offset(x, yBase + dy);
    });

    final bgLine = Paint()
      ..color = border
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], bgLine);
    }

    final activeLine = Paint()
      ..color = primary
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < currentStep && i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], activeLine);
    }

    for (int i = 0; i < points.length; i++) {
      final reached = i <= currentStep;
      final isSel = i == selectedStep;
      if (isSel) {
        canvas.drawCircle(
          points[i],
          11,
          Paint()..color = accent.withOpacity(.28),
        );
      }
      canvas.drawCircle(
        points[i],
        isSel ? 7 : 5.5,
        Paint()..color = reached ? primary : (isDark ? const Color(0xFF2D2354) : Colors.white),
      );
      canvas.drawCircle(
        points[i],
        isSel ? 7 : 5.5,
        Paint()
          ..color = reached ? accent : border
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 2 : 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.currentStep != currentStep || oldDelegate.selectedStep != selectedStep;
}

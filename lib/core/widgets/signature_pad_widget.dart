import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/app_theme.dart';

/// لوحة توقيع إلكتروني بالإصبع — تصدّر صورة PNG شفافة بدون مكتبات خارجية.
class SignaturePadWidget extends StatefulWidget {
  final Future<void> Function(Uint8List pngBytes) onConfirm;
  final String confirmLabel;

  const SignaturePadWidget({
    super.key,
    required this.onConfirm,
    this.confirmLabel = 'تأكيد التوقيع',
  });

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = <List<Offset>>[];
  List<Offset> _current = <Offset>[];
  bool _saving = false;

  bool get _hasInk => _strokes.any((s) => s.length >= 2) || _current.length >= 2;

  Future<void> _exportAndSubmit() async {
    if (!_hasInk || _saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      await widget.onConfirm(byteData.buffer.asUint8List());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: T.primary.withOpacity(.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: T.primary.withOpacity(.2)),
          ),
          child: Text(
            'متى وكيف يُستخدم: عند استلام الشحنة من المندوب أو مكتب الشحن، ارسم توقيعك ثم اضغط «تأكيد التوقيع» (أو «مسح» لإعادة الرسم).',
            style: TextStyle(fontSize: 11, color: T.muted, height: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 185,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: T.primary.withOpacity(.45), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              children: [
                if (!_hasInk)
                  const Center(
                    child: Text(
                      'وقّع بإصبعك داخل الإطار هنا',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                RepaintBoundary(
                  key: _boundaryKey,
                  child: GestureDetector(
                    onPanStart: (d) => setState(() => _current = [d.localPosition]),
                    onPanUpdate: (d) => setState(() => _current.add(d.localPosition)),
                    onPanEnd: (_) => setState(() {
                      if (_current.isNotEmpty) _strokes.add(List.of(_current));
                      _current = [];
                    }),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _SigPainter(_strokes, _current),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _strokes.clear();
                        _current.clear();
                      }),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('مسح', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (!_hasInk || _saving) ? null : _exportAndSubmit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.verified_outlined, size: 17),
                label: Text(widget.confirmLabel, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;
  _SigPainter(this.strokes, this.current);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF1E1038)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in [...strokes, current]) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (int i = 1; i < s.length; i++) {
        path.lineTo(s[i].dx, s[i].dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter oldDelegate) => true;
}

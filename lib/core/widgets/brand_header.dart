import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'brand_logo.dart';

/// ترويسة هوية يمن سيلو: تدرّج بنفسجي متوهج + شعار داخل إطار مضيء.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.badge = '',
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final String badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: dark
              ? const <Color>[Color(0xFF36169E), Color(0xFF5B21B6)]
              : const <Color>[Color(0xFF5B21B6), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? const Color(0xFF43337D) : const Color(0xFFC9A227),
          width: 1,
        ),
        boxShadow: dark
            ? <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF5B2EFF).withOpacity(.35),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: dark
                  ? <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF5B2EFF).withOpacity(.6),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: const BrandLogo(height: 34),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: Colors.white.withOpacity(.85))),
                ],
              ],
            ),
          ),
          if (badge.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge,
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: T.primary)),
            ),
        ],
      ),
    );
  }
}

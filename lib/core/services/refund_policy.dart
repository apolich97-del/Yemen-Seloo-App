/// سياسة القطع غير القابلة للاسترداد أو الاستبدال.
class SelooRefundPolicy {
  SelooRefundPolicy._();

  static final List<_Rule> _rules = <_Rule>[
    _Rule(
      RegExp(
        r'(ملابس داخلية|لانجري|حمالة صدر|بوكسر|سروال داخلي|لباس داخلي|lingerie|underwear|panties|bra\b|boxer)',
        caseSensitive: false,
      ),
      'ملابس داخلية',
    ),
    _Rule(
      RegExp(
        r'(ملابس سباحة|سباحة|مايوه|بيكيني|swimsuit|bikini|swimwear)',
        caseSensitive: false,
      ),
      'ملابس سباحة',
    ),
    _Rule(
      RegExp(
        r'(إكسسوار|اكسسوار|مجوهرات|أقراط|حلق|سلسال|خاتم|سوار|jewelry|earring|necklace|ring|bracelet|anklet)',
        caseSensitive: false,
      ),
      'إكسسوارات ومجوهرات',
    ),
    _Rule(
      RegExp(
        r'(عطر|عطور|مكياج|مستحضرات|تجميل|أحمر شفاه|ماسكارا|beauty|makeup|cosmetic|perfume|fragrance|skincare)',
        caseSensitive: false,
      ),
      'مستحضرات تجميل وعطور',
    ),
    _Rule(
      RegExp(
        r'(جوارب|شرابات|socks|stockings|tights|شعر مستعار|باروكة|wig)',
        caseSensitive: false,
      ),
      'جوارب أو مستلزمات شخصية',
    ),
    _Rule(
      RegExp(
        r'(تصفية|غير قابل للاسترداد|غير قابل للاسترجاع|final\s*sale|clearance|non[-\s]?returnable|non[-\s]?refundable)',
        caseSensitive: false,
      ),
      'عرض نهائي / غير قابل للاسترداد',
    ),
  ];

  static bool detectNonRefundable(String title, [String category = '']) {
    final text = '$title $category'.trim();
    if (text.isEmpty) return false;
    return _rules.any((r) => r.pattern.hasMatch(text));
  }

  static String reasonFor(String title, [String category = '', String custom = '']) {
    if (custom.trim().isNotEmpty) return custom.trim();
    final text = '$title $category'.trim();
    for (final r in _rules) {
      if (r.pattern.hasMatch(text)) return r.reason;
    }
    return '';
  }
}

class _Rule {
  const _Rule(this.pattern, this.reason);
  final RegExp pattern;
  final String reason;
}

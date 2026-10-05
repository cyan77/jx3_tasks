import 'package:flutter/material.dart';

/// Stable color assignment so a label keeps its color across devices and launches.
class TagColors {
  static const names = ['鼠尾草绿', '雾蓝', '暖杏', '浅紫', '玫瑰粉', '青灰',
    '橄榄', '陶土', '莓紫', '靛蓝', '沙棕', '石板灰'];
  static int colorAt(int index) => _light[index].$1.toARGB32();
  static const _light = [
    (Color(0xff356451), Color(0xffe8f2ec)),
    (Color(0xff3c607d), Color(0xffeaf1f8)),
    (Color(0xff80552e), Color(0xfffaf0e3)),
    (Color(0xff675184), Color(0xfff1ecf8)),
    (Color(0xff864f63), Color(0xfff8ebef)),
    (Color(0xff346b70), Color(0xffe6f2f2)),
    (Color(0xff626633), Color(0xfff1f3e3)),
    (Color(0xff8a4e3a), Color(0xfffaece5)),
    (Color(0xff7c487c), Color(0xfff6eaf6)),
    (Color(0xff4f588a), Color(0xffeceefa)),
    (Color(0xff716047), Color(0xfff3eee5)),
    (Color(0xff526572), Color(0xffedf1f4)),
  ];
  static const _dark = [
    (Color(0xffb2d7c2), Color(0xff293d33)),
    (Color(0xffb6cfe8), Color(0xff293747)),
    (Color(0xffe8c59e), Color(0xff443629)),
    (Color(0xffd0bfe8), Color(0xff383044)),
    (Color(0xffe5bacb), Color(0xff442e38)),
    (Color(0xffa9d5d8), Color(0xff273c3e)),
    (Color(0xffced39e), Color(0xff383c27)),
    (Color(0xffe9bbab), Color(0xff442f29)),
    (Color(0xffdfb5df), Color(0xff402d40)),
    (Color(0xffbdc4ef), Color(0xff2e3246)),
    (Color(0xffd7c8af), Color(0xff3b352b)),
    (Color(0xffbfcdd8), Color(0xff2e373e)),
  ];

  static ({Color foreground, Color background}) forLabel(
    String label,
    Brightness brightness, {
    int? color,
  }) {
    var hash = 0;
    for (final unit in label.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final palette = brightness == Brightness.dark ? _dark : _light;
    final chosen = _light.indexWhere((pair) => pair.$1.toARGB32() == color);
    final pair = palette[chosen >= 0 ? chosen : hash % palette.length];
    return (foreground: pair.$1, background: pair.$2);
  }
}

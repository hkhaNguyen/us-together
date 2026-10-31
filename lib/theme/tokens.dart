import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Design tokens from the "Design tokens" board of the us-together canvas.

abstract final class Paper {
  static const c1 = Color(0xFFFBF4EE); // card / light paper
  static const c2 = Color(0xFFF6EAE2);
  static const c3 = Color(0xFFF3E4DB); // page background
  static const c4 = Color(0xFFE6D2C6);
  static const c5 = Color(0xFFD8C0B2); // border
  static const c6 = Color(0xFFB99A8A);
  static const c7 = Color(0xFF87695F); // secondary text (4.6:1 on c3)
  static const c8 = Color(0xFF4A3426); // ink, primary text
  static const c9 = Color(0xFF2E1F16);
  static const polaroid = Color(0xFFFFFDF8);
}

abstract final class Sakura {
  static const c1 = Color(0xFFFBE4EB);
  static const c2 = Color(0xFFF7C1D1);
  static const c3 = Color(0xFFF39BB5);
  static const c4 = Color(0xFFEF7FA7);
  static const c5 = Color(0xFFE85C8A); // hkha
  static const c6 = Color(0xFFD23B74); // stamens, "+" button, heart
  static const c7 = Color(0xFFB8336A); // pink text (dates, script)
  static const petalStroke = Color(0xFFD97FA0);
}

abstract final class Sage {
  static const c1 = Color(0xFFD7DECB);
  static const c2 = Color(0xFF8C9A78); // leaves, Xuka
  static const c3 = Color(0xFF5C6A4C);
}

abstract final class Pollen {
  static const c1 = Color(0xFFF3DFA8);
  static const c2 = Color(0xFFE9C25C); // anthers
  static const c3 = Color(0xFFB8902E);
}

abstract final class Space {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;
  static const s8 = 64.0;
  static const s9 = 96.0;
}

abstract final class Radii {
  static const tape = 2.0;
  static const photo = 8.0;
  static const card = 14.0;
  static const sheet = 18.0;
  static const pill = 999.0;
}

abstract final class Shadows {
  static const _ink = Color(0xFF4A3426);
  static final paperSm = [BoxShadow(offset: const Offset(0, 2), blurRadius: 6, color: _ink.withValues(alpha: .12))];
  static final paper = [BoxShadow(offset: const Offset(0, 10), blurRadius: 24, color: _ink.withValues(alpha: .18))];
  static final lift = [BoxShadow(offset: const Offset(0, 24), blurRadius: 48, color: _ink.withValues(alpha: .28))];
  static final pink = [BoxShadow(offset: const Offset(0, 6), blurRadius: 14, color: Sakura.c7.withValues(alpha: .30))];
}

abstract final class Motion {
  /// Sheets, cards, FLIP.
  static const easePaper = Cubic(.2, .7, .2, 1);

  /// Petals, leaves, heart — overshoots past 1.
  static const easeBloom = Cubic(.34, 1.3, .5, 1);

  /// Stem and branches growing.
  static const easeGrow = Cubic(.25, 0, .3, 1);

  static const dur1 = Duration(milliseconds: 200); // buttons
  static const dur2 = Duration(milliseconds: 400); // cards, menus
  static const dur3 = Duration(milliseconds: 800); // stem + branch
  static const dur4 = Duration(milliseconds: 1600); // slow bloom ("xem từ đầu")
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Text roles from the tokens board (mobile sizes; desktop scales later).
abstract final class AppText {
  static TextStyle get display => GoogleFonts.playfairDisplay(fontSize: 40, fontWeight: FontWeight.w400, color: Paper.c8, height: 1.05);
  static TextStyle get h1 => GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w600, color: Paper.c8, height: 1.1);
  static TextStyle get title => GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w600, color: Paper.c8);
  static TextStyle get script => GoogleFonts.dancingScript(fontSize: 18, fontWeight: FontWeight.w500, color: Sakura.c7);
  static TextStyle get body => GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w300, color: Paper.c8, height: 1.5);
  static TextStyle get quote => GoogleFonts.playfairDisplay(fontSize: 15, fontStyle: FontStyle.italic, color: Paper.c8);
  static TextStyle get label => GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w500, color: Paper.c7, letterSpacing: 11 * .12);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: Paper.c8,
    onPrimary: Paper.c1,
    secondary: Sakura.c6,
    onSecondary: Colors.white,
    surface: Paper.c3,
    onSurface: Paper.c8,
    outline: Paper.c5,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Paper.c3,
    textTheme: GoogleFonts.beVietnamProTextTheme().apply(bodyColor: Paper.c8, displayColor: Paper.c8),
    splashFactory: NoSplash.splashFactory,
    popupMenuTheme: PopupMenuThemeData(
      color: Paper.c1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      textStyle: GoogleFonts.beVietnamPro(fontSize: 15, color: Paper.c8),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Paper.c8,
      contentTextStyle: GoogleFonts.beVietnamPro(fontSize: 14, color: Paper.c1),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

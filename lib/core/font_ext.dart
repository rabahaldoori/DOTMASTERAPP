import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'l10n/locale_provider.dart';

// ── Static helper ────────────────────────────────────────────────────────────
/// Use `AppFont.s(isAr, fontSize: 14, ...)` anywhere — no BuildContext needed.
class AppFont {
  AppFont._();

  /// Returns Cairo style for Arabic, Inter style otherwise.
  static TextStyle s(
    bool isAr, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    double? wordSpacing,
    TextOverflow? overflow,
    FontStyle? fontStyle,
  }) {
    if (isAr) {
      return TextStyle(
        fontFamily: 'Cairo',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
        wordSpacing: wordSpacing,
        overflow: overflow,
        fontStyle: fontStyle,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      wordSpacing: wordSpacing,
      fontStyle: fontStyle,
    );
  }
}

// ── BuildContext extension ────────────────────────────────────────────────────
/// App-font helper — returns Cairo for Arabic, Inter for EN/ES.
/// Usage: `context.af(fontSize: 14, fontWeight: FontWeight.w600)`
extension AppFontExt on BuildContext {
  bool get _isAr =>
      read<LocaleProvider>().locale.languageCode == 'ar';

  TextStyle af({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    double? wordSpacing,
    TextOverflow? overflow,
    FontStyle? fontStyle,
  }) =>
      AppFont.s(
        _isAr,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
        wordSpacing: wordSpacing,
        overflow: overflow,
        fontStyle: fontStyle,
      );
}

import 'package:flutter/widgets.dart';

/// The app's design tokens. These are the only colour, spacing, radius,
/// typography, and motion values the custom UI kit should consume directly.
abstract final class AppColors {
  static const accent = Color(0xFF1E90FF);
  static const accentDeep = Color(0xFF0B63C5);
  static const accentWash = Color(0xFFCCE5FF);
  static const accentInk = Color(0xFF08365C);
  static const accentWashDark = Color(0xFF102F4C);
  static const accentInkDark = Color(0xFFA9D4FF);

  static const page = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1C1C1C);
  static const surfaceRaised = Color(0xFF242424);

  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFFAFAFA);
  static const neutral100 = Color(0xFFF5F5F5);
  static const neutral200 = Color(0xFFE5E5E5);
  static const neutral300 = Color(0xFFD4D4D4);
  static const neutral400 = Color(0xFFA3A3A3);
  static const neutral500 = Color(0xFF737373);
  static const neutral600 = Color(0xFF525252);
  static const neutral700 = Color(0xFF404040);
  static const neutral800 = Color(0xFF262626);
  static const neutral900 = Color(0xFF171717);

  static const success = Color(0xFF16A34A);
  static const successWash = Color(0xFFE9F8EF);
  static const successInk = Color(0xFF0A3D22);
  static const successWashDark = Color(0xFF0E2A1B);
  static const successInkDark = Color(0xFFA8EFC4);
  static const danger = Color(0xFFDC2626);
}

abstract final class AppRadii {
  static const card = 18.0;
  static const field = 10.0;
  static const pill = 999.0;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
}

abstract final class AppTypography {
  /// Main page title, used on every screen. Colour is applied by the widget so
  /// the same style can serve both brightnesses.
  static const TextStyle pageTitle = TextStyle(
    fontFamily: 'Public Sans',
    fontFamilyFallback: ['Cairo'],
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'Public Sans',
    fontFamilyFallback: ['Cairo'],
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const TextStyle navLabel = TextStyle(
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Curve standard = Curves.easeOutCubic;
}
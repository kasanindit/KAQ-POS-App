import 'dart:ui';

class AppColors {
  static const Color primaryColor = Color(0xff346739);
  static const Color onPrimaryColor = Color(0xffF7F9F5);

  static const Color secondaryColor = Color(0xff79AE6F);
  static const Color onSecondaryColor = Color(0xff000000);

  static const Color textColor = Color(0xff233328);
  static const Color textOnTextField = AppColors.darkerGrey;

  static const Color primaryContainer = Color(0xffffffff);
  static const Color onPrimaryContainer = Color(0xff000000);
  static const Color iconContainer = Color(0xff12131A);

  static const Color surface = Color(0xffF7F9F5);
  static const Color onSurface = Color(0xff233328);

  static const Color cardSurface = Color(0xffF2EDC2);
  static const Color onCardSurface = Color(0xff233328);

  // shadow
  static const Color shadow = Color.fromARGB(255, 114, 114, 114);

  // Border colors
  static const Color borderPrimary = Color(0xffF2EDC2);
  // static const Color borderSecondary = Color(0xFFE6E6E6);

  // Error and validation colors
  static const Color error = Color(0xFFB42318);
  static const Color success = Color(0xFF346739);
  static const Color warning = Color(0xFFA06011);
  static const Color info = Color(0xFF315C85);

  // Neutral Shades
  static const Color black = Color(0xFF12131A);
  static const Color darkerGrey = Color(0xFF4F4F4F);
  static const Color darkGrey = Color(0xFF939393);
  static const Color grey = Color(0xFFE0E0E0);
  static const Color softGrey = Color(0xFFF3F5F6);
  static const Color lightGrey = Color(0xFFF9F9F9);
  static const Color white = Color(0xFFFFFFFF);

  static Color? get text => null;
}

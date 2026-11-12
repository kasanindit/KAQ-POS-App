// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:pos_app/utils/const/color.dart';
import 'package:pos_app/utils/themes/text_field_theme.dart';

class AppTheme {
  static ThemeData lightTheme(BuildContext context) => ThemeData(
    colorScheme: lightColorScheme,
    fontFamily: 'Jakarta_Sans',
    scaffoldBackgroundColor: AppColors.surface,
    inputDecorationTheme: CustomTextFieldTheme.inputDecorationTheme,

    textTheme: Theme.of(context).textTheme.apply(
      bodyColor: Colors.black,
      displayColor: Colors.black,
      fontFamily: 'Jakarta_Sans',
      // fontSizeFactor: 12,
    ),
  );

  static const lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primaryColor,
    onPrimary: AppColors.onPrimaryColor,
    secondary: AppColors.secondaryColor,
    onSecondary: AppColors.onSecondaryColor,
    error: AppColors.error,
    onError: AppColors.onCardSurface,
    background: AppColors.surface,
    onBackground: AppColors.onSurface,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
  );
}

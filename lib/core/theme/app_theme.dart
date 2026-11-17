import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

abstract final class AppTheme {
  static const String fontFamily = 'Cairo';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightDarkGreen,
        secondary: AppColors.mainGreen,
        surface: AppColors.lightCard,
        onSurface: AppColors.lightText,
      ),
      dividerColor: AppColors.lightDividers,
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDividers,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.lightText,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.lightText,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.lightSecondaryText,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkDarkGreen,
        secondary: AppColors.mainGreen,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkText,
      ),
      dividerColor: AppColors.darkDividers,
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDividers,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.darkText,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.darkText,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.darkSecondaryText,
        ),
      ),
    );
  }
}

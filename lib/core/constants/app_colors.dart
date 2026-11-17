import 'package:flutter/material.dart';

/// App design tokens - colors with full Light & Dark mode support
abstract final class AppColors {
  /// Global state flag for active theme mode
  static bool isDark = false;

  // Base Light Mode Tokens
  static const Color lightBackground = Color(0xFFF8F6F1);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1F2420);
  static const Color lightSecondaryText = Color(0xFF5F675F);
  static const Color lightDividers = Color(0xFFE8E3D8);
  static const Color lightProgressTrack = Color(0xFFE6E1D5);
  static const Color lightLightGreen = Color(0xFFE3EEE9);
  static const Color lightDarkGreen = Color(0xFF2F6B5A);

  // Base Dark Mode Tokens (Deep, neutral, sleek dark slate & charcoal - true Dark Theme)
  static const Color darkBackground = Color(0xFF0F1113);
  static const Color darkCard = Color(0xFF181B1E);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFFA0A6AD);
  static const Color darkDividers = Color(0xFF2A2E33);
  static const Color darkProgressTrack = Color(0xFF262A2F);
  static const Color darkLightGreen = Color(0xFF162E25);
  static const Color darkDarkGreen = Color(0xFF5CA390);

  // Adaptive Getters responding dynamically to current brightness
  static Color get background => isDark ? darkBackground : lightBackground;
  static Color get card => isDark ? darkCard : lightCard;
  static Color get text => isDark ? darkText : lightText;
  static Color get secondaryText => isDark ? darkSecondaryText : lightSecondaryText;
  static Color get dividers => isDark ? darkDividers : lightDividers;
  static Color get progressTrack => isDark ? darkProgressTrack : lightProgressTrack;
  static Color get lightGreen => isDark ? darkLightGreen : lightLightGreen;
  static Color get darkGreen => isDark ? darkDarkGreen : lightDarkGreen;

  // Semantic Input Tokens
  static Color get inputFill => isDark ? const Color(0xFF202428) : const Color(0xFFFFFFFF);
  static Color get inputBorder => isDark ? const Color(0xFF323840) : const Color(0xFFE2DDD5);

  // Semantic Subtle Container Tokens (Inner cards, stat panels, chips)
  static Color get subtleBox => isDark ? const Color(0xFF202428) : const Color(0xFFF9F7F2);
  static Color get subtleBorder => isDark ? const Color(0xFF2D3238) : const Color(0xFFEBE6DC);
  static Color get subtleButton => isDark ? const Color(0xFF262B30) : const Color(0xFFF4F0E8);

  // Static constant brand accents
  static const Color mainGreen = Color(0xFF4E8B7A);
  static const Color coinGold = Color(0xFFF2BE5A);
  static const Color coinBronze = Color(0xFFD9941F);

  // Category colors (remain vivid across both light and dark themes)
  static const Color categoryFood = Color(0xFF4E8B7A);
  static const Color categoryTransport = Color(0xFFE8A83A);
  static const Color categoryBills = Color(0xFF8FA3BD);
  static const Color categoryCharity = Color(0xFFD6A19A);
}

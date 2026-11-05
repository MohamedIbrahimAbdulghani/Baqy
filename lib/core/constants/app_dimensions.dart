import 'package:flutter/material.dart';

/// App design tokens - dimensions & shadows
abstract final class AppDimensions {
  static const double cardRadius = 16.0;
  static const double bottomBarHeight = 60.0;
  static const double bottomBarTopBorderWidth = 1.0;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0D000000), // very soft shadow
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];
}


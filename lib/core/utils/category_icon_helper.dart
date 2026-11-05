import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

abstract final class CategoryIconHelper {
  /// Available 8 custom icon keys displayed in the "نوع جديد" grid
  /// Row 1 (RTL: right to left): trending_up, medical, shopping_cart, gift
  /// Row 2 (RTL: right to left): heart, home, car, phone
  static const List<String> customIconKeys = [
    'trending_up',
    'medical',
    'shopping_cart',
    'gift',
    'heart',
    'home',
    'car',
    'phone',
  ];

  /// Available 6 color dots in the "نوع جديد" screen
  /// RTL (right to left):
  /// 1. #4E8B7A (Main Green)
  /// 2. #E8A83A (Warm Amber / Yellow)
  /// 3. #8FA3BD (Slate Blue)
  /// 4. #D6A19A (Dusty Rose Pink)
  /// 5. #7C6FA8 (Muted Purple)
  /// 6. #C0644B (Terracotta / Rust)
  static const List<String> customColorHexes = [
    '#4E8B7A',
    '#E8A83A',
    '#8FA3BD',
    '#D6A19A',
    '#7C6FA8',
    '#C0644B',
  ];

  static IconData getIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      // Default categories
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'charity':
        return Icons.favorite_border_rounded;
      case 'subscriptions':
        return Icons.subscriptions_outlined;
      case 'debts':
        return Icons.account_balance_wallet_outlined;

      // 8 Custom category icons
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'medical':
      case 'add_circle':
        return Icons.add_circle_outline_rounded;
      case 'shopping_cart':
      case 'shopping':
        return Icons.shopping_cart_outlined;
      case 'gift':
        return Icons.card_giftcard_outlined;
      case 'heart':
      case 'favorite':
        return Icons.favorite_border_rounded;
      case 'home':
        return Icons.home_outlined;
      case 'car':
        return Icons.directions_car_outlined;
      case 'phone':
      case 'smartphone':
        return Icons.smartphone_outlined;

      case 'other':
      default:
        return Icons.more_horiz_rounded;
    }
  }

  /// Parses a hex color string (e.g. "#4E8B7A") into a Color object safely
  static Color parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) {
      return AppColors.mainGreen;
    }
    try {
      var s = hexString.replaceAll('#', '').trim();
      if (s.length == 6) {
        s = 'FF$s';
      }
      return Color(int.parse(s, radix: 16));
    } catch (_) {
      return AppColors.mainGreen;
    }
  }
}

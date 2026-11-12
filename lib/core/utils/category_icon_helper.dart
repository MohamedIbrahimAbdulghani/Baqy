import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

abstract final class CategoryIconHelper {
  /// Available custom icon keys displayed in the "نوع جديد" grid
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

  /// Whitelist of allowed Material Icon names for AI generated categories
  static const List<String> allowedAiIconKeys = [
    'restaurant',
    'local_cafe',
    'directions_bus',
    'directions_car',
    'checkroom',
    'devices',
    'home',
    'vpn_key',
    'receipt_long',
    'subscriptions',
    'medical_services',
    'spa',
    'school',
    'sports_esports',
    'flight',
    'child_care',
    'pets',
    'card_giftcard',
    'favorite',
    'trending_up',
    'account_balance_wallet',
    'fitness_center',
    'build',
    'shopping_bag',
    'book',
    'lightbulb',
    'work',
    'camera_alt',
    'local_grocery_store',
    'more_horiz',
  ];

  /// Available color dots in the "نوع جديد" screen
  static const List<String> customColorHexes = [
    '#4E8B7A', // Main Green
    '#E8A83A', // Warm Amber
    '#8FA3BD', // Slate Blue
    '#D6A19A', // Dusty Rose Pink
    '#7C6FA8', // Muted Purple
    '#C0644B', // Terracotta / Rust
  ];

  /// Validates and normalizes an icon name, falling back to 'more_horiz' if not permitted
  static String sanitizeIconName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'other';
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    if (allowedAiIconKeys.contains(normalized) ||
        customIconKeys.contains(normalized)) {
      return normalized;
    }
    // Check known aliases
    switch (normalized) {
      case 'food':
        return 'restaurant';
      case 'coffee':
      case 'drinks':
        return 'local_cafe';
      case 'transport':
        return 'directions_bus';
      case 'car':
        return 'directions_car';
      case 'clothes':
        return 'checkroom';
      case 'phone':
        return 'devices';
      case 'rent':
        return 'vpn_key';
      case 'bills':
        return 'receipt_long';
      case 'health':
        return 'medical_services';
      case 'personal_care':
        return 'spa';
      case 'education':
        return 'school';
      case 'entertainment':
        return 'sports_esports';
      case 'travel':
        return 'flight';
      case 'kids':
        return 'child_care';
      case 'charity':
        return 'favorite';
      case 'investment':
        return 'trending_up';
      case 'debts':
        return 'account_balance_wallet';
      default:
        return 'more_horiz';
    }
  }

  static IconData getIcon(String? iconName) {
    switch (iconName?.toLowerCase().replaceAll(' ', '_')) {
      // Food & Drinks
      case 'food':
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'coffee':
      case 'drinks':
      case 'local_cafe':
        return Icons.local_cafe_rounded;

      // Transportation & Vehicle
      case 'transport':
      case 'directions_bus':
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'car':
      case 'directions_car':
        return Icons.directions_car_rounded;

      // Clothes & Shopping
      case 'clothes':
      case 'clothing':
      case 'checkroom':
        return Icons.checkroom_rounded;
      case 'shopping_cart':
      case 'shopping':
      case 'shopping_bag':
      case 'local_grocery_store':
        return Icons.shopping_bag_outlined;

      // Electronics & Devices
      case 'phone':
      case 'smartphone':
      case 'devices':
      case 'electronics':
        return Icons.devices_rounded;

      // Housing & Rent
      case 'home':
        return Icons.home_outlined;
      case 'rent':
      case 'vpn_key':
        return Icons.vpn_key_rounded;

      // Bills & Subscriptions
      case 'bills':
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'subscriptions':
        return Icons.subscriptions_outlined;

      // Health & Care
      case 'medical':
      case 'medical_services':
      case 'health':
      case 'add_circle':
        return Icons.medical_services_outlined;
      case 'personal_care':
      case 'spa':
      case 'care':
        return Icons.spa_outlined;

      // Education & Work
      case 'education':
      case 'school':
      case 'book':
        return Icons.school_outlined;
      case 'work':
        return Icons.work_outline_rounded;

      // Entertainment & Travel
      case 'entertainment':
      case 'sports_esports':
        return Icons.sports_esports_outlined;
      case 'travel':
      case 'flight':
        return Icons.flight_takeoff_rounded;

      // Kids & Pets
      case 'kids':
      case 'child_care':
        return Icons.child_care_rounded;
      case 'pets':
        return Icons.pets_rounded;

      // Gifts & Charity
      case 'gift':
      case 'card_giftcard':
        return Icons.card_giftcard_outlined;
      case 'charity':
      case 'heart':
      case 'favorite':
        return Icons.favorite_border_rounded;

      // Investment & Debts
      case 'investment':
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'debts':
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_outlined;

      // Additional whitelist icons
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'build':
        return Icons.build_outlined;
      case 'lightbulb':
        return Icons.lightbulb_outline_rounded;
      case 'camera_alt':
        return Icons.camera_alt_outlined;

      // Savings & Goals (Virtual category)
      case 'savings':
      case 'savings_outlined':
        return Icons.savings_outlined;

      case 'other':
      case 'more_horiz':
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

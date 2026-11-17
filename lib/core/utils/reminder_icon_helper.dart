import 'package:flutter/material.dart';

/// Helper for automatically resolving the most suitable Material icon from a reminder's name.
abstract final class ReminderIconHelper {
  static const IconData defaultIcon = Icons.calendar_today_outlined;

  static const List<({IconData icon, List<String> keywords})> _mappings = [
    // Cloud / Storage
    (
      icon: Icons.cloud_outlined,
      keywords: [
        'كلود',
        'كلاود',
        'سحابة',
        'سحابي',
        'cloud',
        'icloud',
        'درايف',
        'drive',
        'تخزين',
        'وان درايف',
        'جوجل درايف',
      ],
    ),
    // Gym / Fitness
    (
      icon: Icons.fitness_center_outlined,
      keywords: [
        'جيم',
        'gym',
        'تمرين',
        'رياضة',
        'لياقة',
        'فتنس',
        'fitness',
        'حديد',
        'كروس فيت',
        'كابتن',
        'سباحة',
      ],
    ),
    // Credit card / Bank / Visa
    (
      icon: Icons.credit_card_outlined,
      keywords: [
        'فيزا',
        'visa',
        'مشتريات',
        'كارت',
        'بطاقة',
        'ماستركارد',
        'ائتمان',
        'credit',
        'bank',
        'بنك',
        'بنكي',
        'cib',
        'qnb',
        'اهلي',
        'مصر',
      ],
    ),
    // Savings / الجمعية
    (
      icon: Icons.savings_outlined,
      keywords: [
        'جمعية',
        'تحويش',
        'ادخار',
        'حوش',
        'حصالة',
      ],
    ),
    // Subscriptions / Entertainment
    (
      icon: Icons.subscriptions_outlined,
      keywords: [
        'نتفلكس',
        'netflix',
        'شاهد',
        'shahid',
        'واتش ات',
        'watchit',
        'سبوتيفاي',
        'spotify',
        'يوتيوب',
        'youtube',
        'أنغامي',
        'anghami',
        'سينما',
        'ترفيه',
      ],
    ),
    // Internet / Communications
    (
      icon: Icons.wifi_outlined,
      keywords: [
        'نت',
        'انترنت',
        'إنترنت',
        'واي فاي',
        'wifi',
        'راوتر',
        'فودافون',
        'vodafone',
        'اورانج',
        'orange',
        'اتصالات',
        'etisalat',
        'وي',
      ],
    ),
    // Electricity
    (
      icon: Icons.bolt_outlined,
      keywords: [
        'كهرباء',
        'كهربا',
        'عداد',
        'نور',
        'طاقة',
      ],
    ),
    // Water
    (
      icon: Icons.water_drop_outlined,
      keywords: [
        'مياه',
        'ميه',
        'مية',
      ],
    ),
    // Gas
    (
      icon: Icons.local_fire_department_outlined,
      keywords: [
        'غاز',
        'أنبوبة',
        'انبوبة',
        'بوتاجاز',
      ],
    ),
    // Rent / Housing
    (
      icon: Icons.home_outlined,
      keywords: [
        'ايجار',
        'إيجار',
        'شقة',
        'سكن',
        'عمارة',
        'صيانة العمارة',
        'منزل',
        'بيت',
      ],
    ),
    // Mobile / Phone bill
    (
      icon: Icons.phone_android_outlined,
      keywords: [
        'تليفون',
        'هاتف',
        'موبايل',
        'شحن',
        'باقة',
      ],
    ),
    // Cars / Vehicles / Maintenance
    (
      icon: Icons.directions_car_outlined,
      keywords: [
        'عربية',
        'سيارة',
        'بنزين',
        'صيانة',
        'ميكانيكي',
        'زيت',
        'رخصة',
        'مخالفات',
        'موتوسيكل',
        'كاوتش',
      ],
    ),
    // School / Education
    (
      icon: Icons.school_outlined,
      keywords: [
        'مدرسة',
        'جامعة',
        'دروس',
        'سنتر',
        'مصاريف مدرسة',
        'تعليم',
        'كورس',
        'حضانة',
        'كتب',
      ],
    ),
    // Medical / Health
    (
      icon: Icons.medical_services_outlined,
      keywords: [
        'دكتور',
        'علاج',
        'أدوية',
        'ادوية',
        'صيدلية',
        'كشف',
        'مستشفى',
        'تأمين',
        'تحاليل',
        'أشعة',
      ],
    ),
    // Installments / Debt
    (
      icon: Icons.receipt_long_outlined,
      keywords: [
        'قسط',
        'أقساط',
        'اقساط',
        'دين',
        'سلفة',
        'قرض',
        'سداد',
      ],
    ),
    // Club
    (
      icon: Icons.sports_soccer_outlined,
      keywords: [
        'نادي',
        'نادى',
        'سبورتنج',
        'أهلي',
        'زمالك',
        'صيد',
      ],
    ),
    // Shopping
    (
      icon: Icons.shopping_bag_outlined,
      keywords: [
        'سوبر ماركت',
        'ماركت',
        'شوبينج',
        'طلب',
      ],
    ),
  ];

  /// Resolves an IconData matching the reminder [name].
  /// Matches case-insensitively and returns [defaultIcon] if no match is found.
  static IconData resolveIcon(String name) {
    final normalized = name.toLowerCase().trim();
    if (normalized.isEmpty) return defaultIcon;

    for (final mapping in _mappings) {
      for (final kw in mapping.keywords) {
        if (normalized.contains(kw.toLowerCase())) {
          return mapping.icon;
        }
      }
    }

    return defaultIcon;
  }
}

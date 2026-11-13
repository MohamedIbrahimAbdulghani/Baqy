import 'package:flutter/material.dart';

/// Helper for mapping Goal meanings to Material outlined icons.
/// Adheres strictly to the 22 allowed keys. Default is 'flag'.
/// Pig/savings icon is NEVER used as the default for goals.
class GoalIconHelper {
  const GoalIconHelper._();

  static const String defaultKey = 'flag';

  static const List<String> allowedKeys = [
    'laptop',
    'phone',
    'tv',
    'camera',
    'watch',
    'game',
    'car',
    'bike',
    'home',
    'flight',
    'mosque',
    'beach',
    'school',
    'work',
    'medical',
    'gift',
    'baby',
    'wedding',
    'fitness',
    'shopping',
    'savings',
    'flag',
  ];

  static const Map<String, IconData> _keyToIcon = {
    'laptop': Icons.laptop_outlined,
    'phone': Icons.phone_android_outlined,
    'tv': Icons.tv_outlined,
    'camera': Icons.camera_alt_outlined,
    'watch': Icons.watch_outlined,
    'game': Icons.sports_esports_outlined,
    'car': Icons.directions_car_outlined,
    'bike': Icons.directions_bike_outlined,
    'home': Icons.home_outlined,
    'flight': Icons.flight_outlined,
    'mosque': Icons.mosque_outlined,
    'beach': Icons.beach_access_outlined,
    'school': Icons.school_outlined,
    'work': Icons.work_outlined,
    'medical': Icons.medical_services_outlined,
    'gift': Icons.card_giftcard_outlined,
    'baby': Icons.child_care_outlined,
    'wedding': Icons.favorite_outline_rounded,
    'fitness': Icons.fitness_center_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'savings': Icons.savings_outlined,
    'flag': Icons.flag_outlined,
  };

  /// Arabic keyword mappings ordered so longer multi-word phrases match before shorter substrings.
  static const List<({String key, List<String> keywords})> _mappings = [
    (
      key: 'laptop',
      keywords: ['ماك بوك', 'ماك برو', 'ماك ميني', 'ماك', 'لابتوب', 'لاب', 'كمبيوتر'],
    ),
    (
      key: 'phone',
      keywords: ['ايفون', 'موبايل', 'تليفون', 'سامسونج', 'هاتف'],
    ),
    (
      key: 'tv',
      keywords: ['تلفزيون', 'تليفزيون', 'شاشة'],
    ),
    (
      key: 'camera',
      keywords: ['كاميرا'],
    ),
    (
      key: 'watch',
      keywords: ['ساعة'],
    ),
    (
      key: 'game',
      keywords: ['بلايستيشن', 'بلاي', 'اكس بوكس', 'العاب'],
    ),
    (
      key: 'car',
      keywords: ['عربية', 'سيارة', 'موتوسيكل'],
    ),
    (
      key: 'bike',
      keywords: ['عجلة', 'دراجة'],
    ),
    (
      key: 'home',
      keywords: ['شقة', 'بيت', 'فيلا', 'منزل', 'ارض'],
    ),
    (
      key: 'flight',
      keywords: ['طيران', 'تذكرة', 'سفر', 'رحلة'],
    ),
    (
      key: 'mosque',
      keywords: ['عمرة', 'عمره', 'حج'],
    ),
    (
      key: 'beach',
      keywords: ['اجازة', 'مصيف', 'ساحل'],
    ),
    (
      key: 'school',
      keywords: ['ماجستير', 'دراسة', 'تعليم', 'كورس', 'جامعة'],
    ),
    (
      key: 'work',
      keywords: ['مشروع', 'بيزنس', 'شغل'],
    ),
    (
      key: 'medical',
      keywords: ['عملية', 'دكتور', 'علاج'],
    ),
    (
      key: 'gift',
      keywords: ['هدية'],
    ),
    (
      key: 'baby',
      keywords: ['مولود', 'طفل'],
    ),
    (
      key: 'wedding',
      keywords: ['خطوبة', 'شبكة', 'جواز', 'فرح'],
    ),
    (
      key: 'fitness',
      keywords: ['رياضة', 'جيم'],
    ),
    (
      key: 'shopping',
      keywords: ['تسوق', 'لبس'],
    ),
    (
      key: 'savings',
      keywords: ['طوارئ', 'ادخار'],
    ),
  ];

  /// Normalizes Arabic text for flexible matching:
  /// - Removes tashkeel / harakat
  /// - Normalizes Alef forms (أ, إ, آ, ٱ) -> ا
  /// - Normalizes Taa Marbuta (ة) -> ه
  /// - Normalizes Yaa forms (ى) -> ي
  /// - Strips tatweel (ـ) and punctuation
  static String normalizeArabic(String text) {
    var s = text.trim().toLowerCase();
    // Remove diacritics / harakat
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    // Remove tatweel
    s = s.replaceAll('ـ', '');
    // Normalize Alef
    s = s.replaceAll(RegExp(r'[أإآٱ]'), 'ا');
    // Normalize Taa Marbuta
    s = s.replaceAll('ة', 'ه');
    // Normalize Yaa
    s = s.replaceAll('ى', 'ي');
    // Remove punctuation
    s = s.replaceAll(RegExp(r'[.,،:;!?؟\-_/\\()\[\]{}"\x27]'), ' ');
    // Collapse multi-spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Chooses the icon key locally from the goal name.
  /// Whole-word or contained matching on normalized text.
  /// Earliest keyword appearing in the name takes precedence (e.g. "تلفزيون سامسونج" -> tv).
  /// Falls back to 'flag' if no keyword matches.
  static String resolveIconKeyFromName(String name) {
    final normalized = normalizeArabic(name);
    if (normalized.isEmpty) return defaultKey;

    final tokens = normalized.split(' ').where((w) => w.isNotEmpty).toList();

    int earliestIndex = -1;
    String matchedKey = defaultKey;
    int longestLength = 0;

    for (final item in _mappings) {
      for (final kw in item.keywords) {
        final normKw = normalizeArabic(kw);
        int idx = -1;
        if (normKw.contains(' ')) {
          idx = normalized.indexOf(normKw);
        } else {
          // Token match or contained
          if (tokens.contains(normKw)) {
            idx = normalized.indexOf(normKw);
          } else if (normalized.contains(normKw)) {
            idx = normalized.indexOf(normKw);
          }
        }

        if (idx != -1) {
          if (earliestIndex == -1 || idx < earliestIndex || (idx == earliestIndex && normKw.length > longestLength)) {
            earliestIndex = idx;
            matchedKey = item.key;
            longestLength = normKw.length;
          }
        }
      }
    }

    return matchedKey;
  }

  /// Validates a key against the allowed keys list, falling back to local mapping or 'flag'.
  static String validateOrResolve(String? rawKey, {String? goalName}) {
    if (rawKey != null && allowedKeys.contains(rawKey.trim().toLowerCase())) {
      return rawKey.trim().toLowerCase();
    }
    if (goalName != null && goalName.trim().isNotEmpty) {
      return resolveIconKeyFromName(goalName);
    }
    return defaultKey;
  }

  /// Returns the Material outlined icon for a given key.
  /// Defaults to [Icons.flag_outlined] if key is unrecognized.
  static IconData getIcon(String? key) {
    if (key == null) return Icons.flag_outlined;
    return _keyToIcon[key.trim().toLowerCase()] ?? Icons.flag_outlined;
  }
}

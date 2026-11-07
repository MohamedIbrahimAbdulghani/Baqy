import '../../features/expenses/domain/models/category_item.dart';

/// Utility class to normalize Arabic category names and ensure reliable
/// matching between user input / AI responses and database category definitions.
class CategoryMatcher {
  /// Normalizes Arabic text for category matching:
  /// - Strips tashkeel
  /// - Unifies alef forms: [أإآ] -> ا
  /// - Unifies ى -> ي
  /// - Unifies ة -> ه
  /// - Collapses multiple spaces and trims
  static String normalize(String input) {
    var text = input.trim();
    // Diacritics
    text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    // Alef unification
    text = text.replaceAll(RegExp(r'[أإآ]'), 'ا');
    // ى -> ي
    text = text.replaceAll('ى', 'ي');
    // ة -> ه
    text = text.replaceAll('ة', 'ه');
    // Collapse spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  /// Maps common dialect and singular/plural variations to standard canonical names.
  static String toCanonical(String raw) {
    final norm = normalize(raw);

    // 1. Charity: صدقات, صدقة, صدقه, زكاة, زكاه, تبرع, تبرعات, كفالة, لله
    if (norm == 'صدقات' ||
        norm == 'صدقه' ||
        norm == 'صدقه لعمتي' ||
        norm.startsWith('صدق') ||
        norm.contains('زكاه') ||
        norm.contains('تبرع') ||
        norm.contains('كفاله') ||
        norm.contains('احسان') ||
        norm.contains('لله')) {
      return 'صدقات';
    }

    // 2. Supermarket: سوبر ماركت, هايبر, طلبات البيت, بقالة
    if (norm == 'سوبر ماركت' ||
        norm == 'سوبرماركت' ||
        norm == 'ماركت' ||
        norm == 'هايبر' ||
        norm.contains('سوبر ماركت') ||
        norm.contains('سوبرماركت') ||
        norm.contains('طلبات البيت') ||
        norm == 'بقاله') {
      return 'سوبر ماركت';
    }

    // 3. Food: أكل, اكل, طعام, وجبة, وجبه, مطعم, فطار, غدا, عشا, دليفري
    if (norm == 'اكل' ||
        norm == 'طعام' ||
        norm == 'وجبه' ||
        norm == 'وجبات' ||
        norm == 'مطعم' ||
        norm == 'مطاعم' ||
        norm == 'غدا' ||
        norm == 'عشا' ||
        norm == 'فطار' ||
        norm == 'دليفري') {
      return 'أكل';
    }

    // 4. Drinks: مشروبات وكافيهات, مشروبات, مشروب, عصائر, عصير, قهوة, قهوه, كافيه, فرابيه, شيشة
    if (norm == 'مشروبات وكافيهات' ||
        norm == 'مشروبات' ||
        norm == 'مشروب' ||
        norm == 'عصاير' ||
        norm == 'عصير' ||
        norm == 'قهوه' ||
        norm == 'كافيه' ||
        norm == 'شاي' ||
        norm.contains('فرابيه') ||
        norm.contains('شيشه') ||
        norm.contains('ساقعه') ||
        norm.contains('كافيهات')) {
      return 'مشروبات وكافيهات';
    }

    // 5. Transportation: مواصلات, مواصلة, مواصله, اوبر, تاكسي, مترو, توك توك
    if (norm == 'مواصلات' ||
        norm == 'مواصله' ||
        norm == 'مواصلا' ||
        norm == 'انتقالات' ||
        norm == 'اوبر' ||
        norm == 'تاكسي' ||
        norm == 'مترو' ||
        norm == 'توك توك' ||
        norm == 'تكتك' ||
        norm == 'ميكروباص') {
      return 'مواصلات';
    }

    // 6. Clothes: ملابس, لبس, هدوم, ازياء
    if (norm == 'ملابس' ||
        norm == 'لبس' ||
        norm == 'هدوم' ||
        norm == 'ازياء' ||
        norm == 'تيشيرت' ||
        norm == 'بنطلون') {
      return 'ملابس';
    }

    // 7. Car: سيارة, سياره, عربية, عربيه, سيارات
    if (norm == 'سياره' || norm == 'عربيه' || norm == 'سيارات') {
      return 'سيارة';
    }

    // 8. Electronics: إلكترونيات, الكترونيات, اجهزة
    if (norm == 'الكترونيات' || norm == 'اجهزه') {
      return 'إلكترونيات';
    }

    // 9. Investment: استثمار وادخار, استثمار, ادخار, ذهب, دهب
    if (norm == 'استثمار وادخار' ||
        norm == 'استثمار' ||
        norm == 'ادخار' ||
        norm == 'ذهب' ||
        norm == 'دهب' ||
        norm == 'دولار' ||
        norm.contains('سبيكه') ||
        norm.contains('جنيه دهب') ||
        norm.contains('جنيه ذهب') ||
        norm.contains('جمعيه')) {
      return 'استثمار وادخار';
    }

    // 10. Debts: ديون وأقساط, ديون واقساط, ديون, اقساط, قسط, سلف
    if (norm == 'ديون واقساط' ||
        norm == 'ديون' ||
        norm == 'اقساط' ||
        norm == 'قسط' ||
        norm == 'سلف') {
      return 'ديون وأقساط';
    }

    // 11. Bills & Telecom: فواتير واتصالات, فواتير, فاتورة, فاتوره, باقة نت
    if (norm == 'فواتير واتصالات' ||
        norm == 'فواتير' ||
        norm == 'فاتوره' ||
        norm.contains('باقه') ||
        norm.contains('رصيد') ||
        norm.contains('اتصالات')) {
      return 'فواتير واتصالات';
    }

    // 12. Subscriptions: اشتراكات, اشتراك
    if (norm == 'اشتراكات' || norm == 'اشتراك') {
      return 'اشتراكات';
    }

    // 13. Entertainment: ترفيه, العاب, فسح, سينما
    if (norm == 'ترفيه' || norm == 'العاب' || norm == 'فسح' || norm == 'سينما') {
      return 'ترفيه';
    }

    // 14. Personal Care: عناية شخصية, عنايه شخصيه, عناية, عنايه, برفيوم, بادز
    if (norm == 'عنايه شخصيه' ||
        norm == 'عنايه' ||
        norm.contains('برفيوم') ||
        norm.contains('بادز') ||
        norm.contains('حلاقه')) {
      return 'عناية شخصية';
    }

    // 15. Health: صحة, صحه, علاج, ادوية, ادويه, دكتور
    if (norm == 'صحه' || norm == 'علاج' || norm == 'ادويه' || norm == 'دكتور') {
      return 'صحة';
    }

    // 16. Education: تعليم, دروس, كورسات, مدرسة
    if (norm == 'تعليم' || norm == 'دروس' || norm == 'كورسات' || norm == 'مدرسه') {
      return 'تعليم';
    }

    // 17. Home: بيت وأثاث, بيت واثاث, بيت, اثاث
    if (norm == 'بيت واثاث' || norm == 'بيت' || norm == 'اثاث') {
      return 'بيت وأثاث';
    }

    // 18. Rent: إيجار, ايجار
    if (norm == 'ايجار') {
      return 'إيجار';
    }

    // 19. Kids: أطفال, اطفال
    if (norm == 'اطفال') {
      return 'أطفال';
    }

    // 20. Pets: حيوانات أليفة, حيوانات اليفه, حيوانات
    if (norm == 'حيوانات اليفه' || norm == 'حيوانات') {
      return 'حيوانات أليفة';
    }

    // 21. Gifts: هدايا ومناسبات, هدايا
    if (norm == 'هدايا ومناسبات' || norm == 'هدايا') {
      return 'هدايا ومناسبات';
    }

    // 22. Travel: سفر, سفر وسياحة, سفر وسياحه
    if (norm == 'سفر' || norm == 'سفر وسياحه' || norm.contains('سفر')) {
      return 'سفر';
    }

    return raw;
  }

  /// Matches an input category name to a [CategoryItem] from a given list.
  /// Falls back to "أخرى" or first category if no match is found.
  static CategoryItem matchItem({
    required String categoryName,
    required List<CategoryItem> categories,
  }) {
    if (categories.isEmpty) {
      return CategoryItem(
        id: 0,
        name: categoryName,
        icon: 'other',
        color: '#9A9488',
      );
    }

    final canonical = toCanonical(categoryName);
    final normCanonical = normalize(canonical);
    final normRaw = normalize(categoryName);

    // 1. Exact string match
    for (final cat in categories) {
      if (cat.name == canonical || cat.name == categoryName) {
        return cat;
      }
    }

    // 2. Normalized match
    for (final cat in categories) {
      final normCat = normalize(cat.name);
      if (normCat == normCanonical || normCat == normRaw) {
        return cat;
      }
    }

    // 3. Substring match
    for (final cat in categories) {
      final normCat = normalize(cat.name);
      if (normCat.contains(normCanonical) || normCanonical.contains(normCat)) {
        return cat;
      }
    }

    // 4. Fallback to "أخرى"
    return categories.firstWhere(
      (c) => normalize(c.name) == 'اخري' || c.name == 'أخرى',
      orElse: () => categories.first,
    );
  }

  /// Resolves the matching category name string from a list of available names.
  static String matchName({
    required String categoryName,
    required List<String> availableNames,
  }) {
    if (availableNames.isEmpty) return categoryName;

    final canonical = toCanonical(categoryName);
    final normCanonical = normalize(canonical);
    final normRaw = normalize(categoryName);

    for (final name in availableNames) {
      if (name == canonical || name == categoryName) return name;
    }

    for (final name in availableNames) {
      final normName = normalize(name);
      if (normName == normCanonical || normName == normRaw) return name;
    }

    for (final name in availableNames) {
      final normName = normalize(name);
      if (normName.contains(normCanonical) || normCanonical.contains(normName)) {
        return name;
      }
    }

    return availableNames.firstWhere(
      (n) => normalize(n) == 'اخري' || n == 'أخرى',
      orElse: () => availableNames.first,
    );
  }
}


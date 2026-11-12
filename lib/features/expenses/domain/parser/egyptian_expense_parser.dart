import '../models/parsed_expense.dart';

class NumberParseResult {
  final int value;
  final int consumedCount;

  const NumberParseResult(this.value, this.consumedCount);
}

class AmountMatch {
  final int startIndex;
  final int endIndex;
  final int amount;

  const AmountMatch({
    required this.startIndex,
    required this.endIndex,
    required this.amount,
  });
}

/// Pure Dart parser for Egyptian colloquial Arabic (ammiya) expense sentences.
class EgyptianExpenseParser {
  static const Map<String, int> _basicNumbers = {
    'صفر': 0,
    'واحد': 1,
    'واحده': 1,
    'اتنين': 2,
    'تنين': 2,
    'تلاته': 3,
    'تلات': 3,
    'اربعه': 4,
    'اربع': 4,
    'خمسه': 5,
    'خمس': 5,
    'سته': 6,
    'ست': 6,
    'سبعه': 7,
    'سبع': 7,
    'تمانيه': 8,
    'تمنيه': 8,
    'تمن': 8,
    'تسعه': 9,
    'تسع': 9,
    'عشره': 10,
    'عشر': 10,
    'حداشر': 11,
    'اتناشر': 12,
    'تلاتاشر': 13,
    'اربعتاشر': 14,
    'خمستاشر': 15,
    'ستاشر': 16,
    'سبعتاشر': 17,
    'تمنتاشر': 18,
    'تسعتاشر': 19,
    'عشرين': 20,
    'تلاتين': 30,
    'اربعين': 40,
    'خمسين': 50,
    'ستين': 60,
    'سبعين': 70,
    'تمانين': 80,
    'تسعين': 90,
    'ميه': 100,
    'ميت': 100,
    'مئه': 100,
    'مائه': 100,
    'ميتين': 200,
    'تلتميه': 300,
    'تلتوميه': 300,
    'ربعميه': 400,
    'ربعوميه': 400,
    'خمسميه': 500,
    'خمسوميه': 500,
    'ستميه': 600,
    'ستوميه': 600,
    'سبعميه': 700,
    'سبعوميه': 700,
    'تمنميه': 800,
    'تمنوميه': 800,
    'تسعميه': 900,
    'تسعوميه': 900,
    'الف': 1000,
    'الفين': 2000,
  };

  /// Noun keywords mapped by Category and their preferred canonical short name.
  /// Priority (a): noun keywords beat verbs.
  static const Map<String, Map<String, String>> _categoryNounKeywords = {
    'ترفيه': {
      'سينما': 'سينما',
      'فيلم': 'فيلم',
      'مسرح': 'مسرح',
      'ملاهي': 'ملاهي',
      'العاب': 'ألعاب',
      'ألعاب': 'ألعاب',
      'بلايستيشن': 'بلايستيشن',
      'كورة': 'كورة',
      'كوره': 'كورة',
      'كرة': 'كورة',
      'كره': 'كورة',
      'رحلة': 'رحلة',
      'رحله': 'رحلة',
      'حفلة': 'حفلة',
      'حفله': 'حفلة',
    },
    'أكل': {
      'غدا': 'غدا',
      'غداء': 'غدا',
      'غده': 'غدا',
      'غدة': 'غدا',
      'غدب': 'غدا',
      'غداب': 'غدا',
      'عشا': 'عشا',
      'عشاء': 'عشا',
      'عشه': 'عشا',
      'عشة': 'عشا',
      'فطار': 'فطار',
      'فطور': 'فطار',
      'كافيه': 'قهوة',
      'كافي': 'قهوة',
      'قهوة': 'قهوة',
      'قهوه': 'قهوة',
      'عصير': 'عصير',
      'شاي': 'شاي',
      'شاورما': 'شاورما',
      'كشري': 'كشري',
      'مطعم': 'أكل',
      'اكل': 'أكل',
      'أكل': 'أكل',
      'سندوتش': 'سندوتش',
      'ساندوتش': 'سندوتش',
      'خضار': 'خضار',
      'فاكهة': 'فاكهة',
      'فاكهه': 'فاكهة',
      'لحمة': 'لحمة',
      'لحمه': 'لحمة',
      'فراخ': 'فراخ',
      'بقالة': 'بقالة',
      'بقاله': 'بقالة',
      'حلويات': 'حلويات',
      'عيش': 'عيش',
      'لبن': 'لبن',
      'جبنة': 'جبنة',
      'جبنه': 'جبنة',
      'وجبة': 'وجبة',
      'وجبه': 'وجبة',
    },
    'مواصلات': {
      'ميكروباص': 'ميكروباص',
      'تاكسي': 'تاكسي',
      'اوبر': 'أوبر',
      'أوبر': 'أوبر',
      'مترو': 'مترو',
      'اتوبيس': 'أتوبيس',
      'أتوبيس': 'أتوبيس',
      'باص': 'أتوبيس',
      'بنزين': 'بنزين',
      'تذكرة': 'تذكرة',
      'تذكره': 'تذكرة',
      'أجرة': 'أجرة',
      'اجره': 'أجرة',
      'مواصلات': 'مواصلات',
      'كارته': 'كارتة',
      'كارتة': 'كارتة',
      'سواق': 'مواصلات',
      'موقف': 'مواصلات',
      'قطار': 'قطار',
      'قطر': 'قطار',
    },
    'فواتير واتصالات': {
      'كهربا': 'كهرباء',
      'كهرباء': 'كهرباء',
      'نور': 'كهرباء',
      'مياه': 'مياه',
      'مايه': 'مياه',
      'غاز': 'غاز',
      'نت': 'إنترنت',
      'انترنت': 'إنترنت',
      'إنترنت': 'إنترنت',
      'موبايل': 'رصيد موبايل',
      'رصيد': 'رصيد موبايل',
      'فاتورة': 'فاتورة',
      'فاتوره': 'فاتورة',
      'باقة': 'باقة نت',
      'باقه': 'باقة نت',
      'ايجار': 'إيجار',
      'إيجار': 'إيجار',
    },
    'اشتراكات': {
      'اشتراك': 'اشتراك',
      'جيم': 'جيم',
      'نتفلكس': 'نتفلكس',
      'نتفليكس': 'نتفلكس',
      'سبوتيفاي': 'سبوتيفاي',
      'كلود': 'اشتراك',
      'شاهد': 'شاهد',
    },
    'صدقات': {
      'صدقة': 'صدقة',
      'صدقه': 'صدقة',
      'صدقات': 'صدقة',
      'زكاة': 'زكاة',
      'زكاه': 'زكاة',
      'تبرع': 'تبرع',
      'لله': 'صدقة',
      'جامع': 'تبرع',
      'مسجد': 'تبرع',
      'كفالة': 'كفالة يتيم',
      'كفاله': 'كفالة يتيم',
    },
    'ديون وأقساط': {
      'قسط': 'قسط',
      'دين': 'دين',
      'سلف': 'سلف',
      'جمعية': 'جمعية',
      'قرض': 'قرض',
    },
    'مشروبات وكافيهات': {
      'قهوة': 'قهوة',
      'قهوه': 'قهوة',
      'فرابيه': 'فرابيه',
      'لاتيه': 'لاتيه',
      'موكا': 'موكا',
      'كابتشينو': 'كابتشينو',
      'نسكافيه': 'نسكافيه',
      'عصير': 'عصير',
      'شاي': 'شاي',
      'شيشة': 'شيشة',
      'شيشه': 'شيشة',
      'كافيه': 'قهوة',
      'كافي': 'قهوة',
      'مشروب': 'مشروب',
      'مشروبات': 'مشروبات',
    },
    'سوبر ماركت': {
      'سوبرماركت': 'سوبر ماركت',
      'سوبر ماركت': 'سوبر ماركت',
      'هايبر': 'سوبر ماركت',
      'ماركت': 'سوبر ماركت',
    },
    'ملابس': {
      'لبس': 'لبس',
      'هدوم': 'لبس',
      'تيشيرت': 'تيشيرت',
      'تي شيرت': 'تيشيرت',
      'قميص': 'قميص',
      'بنطلون': 'بنطلون',
      'جزمة': 'جزمة',
      'جزمه': 'جزمة',
      'شوز': 'حذاء',
      'حذاء': 'حذاء',
      'فستان': 'فستان',
      'بدلة': 'بدلة',
    },
    'إلكترونيات': {
      'شاحن': 'شاحن',
      'سماعة': 'سماعة',
      'سماعه': 'سماعة',
      'ايربودز': 'سماعة',
      'كابل': 'كابل',
      'وصلة': 'كابل',
      'موبايل': 'موبايل',
      'تليفون': 'موبايل',
      'باوربانك': 'باوربانك',
      'لابتوب': 'لابتوب',
      'كمبيوتر': 'كمبيوتر',
      'شاشة': 'شاشة',
    },
    'عناية شخصية': {
      'برفيوم': 'برفيوم',
      'عطر': 'عطر',
      'برفان': 'برفيوم',
      'بادز': 'بادز',
      'مزيل': 'مزيل عرق',
      'شامبو': 'شامبو',
      'حلاقة': 'حلاقة',
      'حلاقه': 'حلاقة',
      'كوافير': 'كوافير',
      'كوزمتكس': 'كوزمتكس',
      'ميكاب': 'ميكاب',
      'مكياج': 'مكياج',
    },
    'تعليم': {
      'كتب': 'كتب',
      'كتاب': 'كتاب',
      'كورس': 'كورس',
      'كورسات': 'كورس',
      'دروس': 'دروس',
      'درس': 'درس',
      'مدرسة': 'مدرسة',
      'جامعة': 'جامعة',
    },
    'استثمار وادخار': {
      'ذهب': 'ذهب',
      'دهب': 'ذهب',
      'سبيكة': 'سبيكة ذهب',
      'سبيكه': 'سبيكة ذهب',
      'اسهم': 'أسهم',
      'أسهم': 'أسهم',
      'بورصة': 'بورصة',
      'تحويش': 'ادخار',
      'شهادة': 'شهادة استثمار',
      'دولار': 'دولار',
    },
    'سيارة': {
      'بنزين': 'بنزين',
      'سولار': 'سولار',
      'صيانة': 'صيانة سيارة',
      'ركنة': 'ركنة',
      'غسيل': 'غسيل سيارة',
      'ميكانيكي': 'ميكانيكي',
      'كاوتش': 'كاوتش',
      'زيت': 'تغيير زيت',
    },
    'أخرى': {
      'ميكانيكي': 'ميكانيكي',
      'جزمة': 'جزمة',
      'علاج': 'علاج',
      'كتب': 'كتب',
      'كتاب': 'كتب',
      'بيتزا': 'بيتزا',
    },
  };

  /// Verbs mapped to category and short name.
  /// Priority (b): evaluated only if no noun keyword matches.
  static const Map<String, ({String category, String name})> _verbRules = {
    'اكلت': (category: 'أكل', name: 'أكل'),
    'أكلت': (category: 'أكل', name: 'أكل'),
    'اكلنا': (category: 'أكل', name: 'أكل'),
    'أكلنا': (category: 'أكل', name: 'أكل'),
    'اتغديت': (category: 'أكل', name: 'غدا'),
    'اتغدينا': (category: 'أكل', name: 'غدا'),
    'اتعشيت': (category: 'أكل', name: 'عشا'),
    'اتعشينا': (category: 'أكل', name: 'عشا'),
    'فطرت': (category: 'أكل', name: 'فطار'),
    'فطرنا': (category: 'أكل', name: 'فطار'),
    'شربت': (category: 'مشروبات وكافيهات', name: 'مشروب'),
    'شربنا': (category: 'مشروبات وكافيهات', name: 'مشروب'),
    'طلبت': (category: 'أكل', name: 'أكل'),
    'ركبت': (category: 'مواصلات', name: 'مواصلات'),
    'ركبنا': (category: 'مواصلات', name: 'مواصلات'),
    'رحت': (category: 'مواصلات', name: 'مواصلات'),
    'روحت': (category: 'مواصلات', name: 'مواصلات'),
    'روحنا': (category: 'مواصلات', name: 'مواصلات'),
    'رحنا': (category: 'مواصلات', name: 'مواصلات'),
    'رجعت': (category: 'مواصلات', name: 'مواصلات'),
    'رجعنا': (category: 'مواصلات', name: 'مواصلات'),
    'سافرت': (category: 'مواصلات', name: 'مواصلات'),
    'سافرنا': (category: 'مواصلات', name: 'مواصلات'),
  };

  /// Action verbs that can indicate the start of an item
  static const Set<String> _startVerbs = {
    'اكلت',
    'أكلت',
    'اكلنا',
    'أكلنا',
    'اتغديت',
    'اتغدينا',
    'اتعشيت',
    'اتعشينا',
    'فطرت',
    'فطرنا',
    'شربت',
    'شربنا',
    'طلبت',
    'طلبنا',
    'ركبت',
    'ركبنا',
    'رحت',
    'روحت',
    'روحنا',
    'رحنا',
    'رجعت',
    'رجعنا',
    'سافرت',
    'سافرنا',
    'اشتريت',
    'شريت',
    'جبت',
    'عملت',
    'حجزت',
    'قعدت',
    'دفعت',
    'صرفت',
    'اديت',
    'ادينا',
    'دخلت',
    'دخلنا',
    'سددت',
    'سددنا',
    'حولت',
    'حولنا',
    'شحنت',
    'نزلت',
  };

  /// Nouns that inherently begin with 'و' (not conjunction 'و').
  /// Words like ورق or وقود must NOT trigger conjunction splitting.
  static const Set<String> _inherentWawWords = {
    'ورق',
    'ورقة',
    'وقود',
    'وجبة',
    'وجبات',
    'ورد',
    'ورود',
    'ورشة',
    'وسادة',
    'ولاعة',
    'واحد',
    'واحده',
  };

  /// Filler words/phrases to ignore entirely from item names
  static const Set<String> _fillerWords = {
    'خرجت',
    'خرجنا',
    'صحابي',
    'اصحابي',
    'أصحابي',
    'اصدقائي',
    'أصدقائي',
    'زمايلي',
    'اخواتي',
    'اهلي',
    'لوحدي',
    'النهاردة',
    'النهارده',
    'امبارح',
    'إمبارح',
    'الصبح',
    'بالليل',
    'بليل',
    'الظهر',
    'العصر',
    'دفعت',
    'دفعنا',
    'صرفت',
    'صرفنا',
    'حاسبت',
    'حاسبنا',
    'اديت',
    'ادينا',
    'مع',
    'من',
    'في',
    'ف',
    'عند',
    'إلى',
    'الي',
    'على',
    'علي',
    'عن',
    'ب',
    'ل',
    'ثم',
    'بعدين',
    'وبعدين',
    'و',
  };

  static const Set<String> _currencyWords = {
    'جنيه',
    'جنيها',
    'ج.م',
    'جم',
    'egp',
    'ج',
  };

  /// Normalizes Arabic text:
  /// - Removes tashkeel
  /// - Unifies alef forms (أ إ آ → ا)
  /// - Unifies ى → ي and ة → ه
  /// - Converts Arabic-Indic digits to Western digits
  /// - Separates attached currency symbols (e.g. 30ج → 30)
  /// - Normalizes punctuation to spaces
  static String normalize(String input) {
    var text = input;

    // 1. Remove diacritics / tashkeel
    text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

    // 2. Unify digits (Arabic-Indic to Western)
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (int i = 0; i < 10; i++) {
      text = text.replaceAll(arabicDigits[i], '$i');
    }

    // 3. Unify alef forms
    text = text.replaceAll(RegExp(r'[أإآ]'), 'ا');

    // 4. ى -> ي
    text = text.replaceAll('ى', 'ي');

    // 5. ة -> ه
    text = text.replaceAll('ة', 'ه');

    // Separate attached currency letter "ج" from digits e.g. "30ج" -> "30"
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\s*ج(?=\s|$)'),
      (m) => '${m[1]} ',
    );

    // Normalize punctuation
    text = text.replaceAll(RegExp(r'[,،.;:!?؟-]'), ' ');

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Returns true if [rawToken] (after stripping prefixes) is a digit literal
  /// (Western 0-9 or already-converted Arabic-Indic).
  static bool _isDigitToken(String rawToken) {
    if (rawToken.isEmpty) return false;
    if (int.tryParse(rawToken) != null) return true;
    final prefixes = ['وب', 'ب', 'ل', 'و'];
    for (final prefix in prefixes) {
      if (rawToken.startsWith(prefix) && rawToken.length > prefix.length) {
        final rest = rawToken.substring(prefix.length);
        if (int.tryParse(rest) != null) return true;
      }
    }
    return false;
  }

  static int? _parseSingleToken(String rawToken) {
    if (rawToken.isEmpty) return null;

    final int? directDigits = int.tryParse(rawToken);
    if (directDigits != null) return directDigits;

    if (_basicNumbers.containsKey(rawToken)) {
      return _basicNumbers[rawToken];
    }

    final prefixes = ['وب', 'ب', 'ل', 'و'];
    for (final prefix in prefixes) {
      if (rawToken.startsWith(prefix) && rawToken.length > prefix.length) {
        final rest = rawToken.substring(prefix.length);
        final int? digitVal = int.tryParse(rest);
        if (digitVal != null) return digitVal;
        if (_basicNumbers.containsKey(rest)) {
          return _basicNumbers[rest];
        }
      }
    }

    return null;
  }

  /// Parses a compound number starting at [start] in [tokens].
  static NumberParseResult? tryParseNumber(List<String> tokens, int start) {
    if (start >= tokens.length) return null;

    final token = tokens[start];

    // Special cases: "نص الف", "ربع الف", "نص ميه", "ربع ميه"
    String cleanToken = token;
    for (final p in ['وب', 'ب', 'ل', 'و']) {
      if (cleanToken.startsWith(p) && cleanToken.length > p.length) {
        cleanToken = cleanToken.substring(p.length);
        break;
      }
    }

    if (cleanToken == 'نص' || cleanToken == 'ربع') {
      if (start + 1 < tokens.length) {
        final nextToken = tokens[start + 1];
        String cleanNext = nextToken;
        for (final p in ['وب', 'ب', 'ل', 'و']) {
          if (cleanNext.startsWith(p) && cleanNext.length > p.length) {
            cleanNext = cleanNext.substring(p.length);
            break;
          }
        }
        if (cleanNext == 'الف') {
          final val = cleanToken == 'نص' ? 500 : 250;
          return NumberParseResult(val, 2);
        } else if (cleanNext == 'ميه' || cleanNext == 'ميت') {
          final val = cleanToken == 'نص' ? 50 : 25;
          return NumberParseResult(val, 2);
        }
      }
    }

    final int? singleVal = _parseSingleToken(token);
    if (singleVal == null) return null;

    int currentVal = singleVal;
    int consumed = 1;

    // Check if followed by "تلاف" or "الاف" or "الف"
    if (start + 1 < tokens.length) {
      final nextToken = tokens[start + 1];
      if (nextToken == 'تلاف' || nextToken == 'الاف' || nextToken == 'الف') {
        currentVal = currentVal * 1000;
        consumed = 2;
      }
    }

    // Check compound additions: e.g. "الف وميه", "الف ونص", "خمسه وعشرين"
    // RULE (Task D): digits (Western/Arabic-Indic) NEVER merge with each
    // other even when joined by "و".  Number WORDS merge only when they form
    // a valid Arabic compound (units+tens, hundreds+tens, thousands+hundreds,
    // الف ونص / وربع).
    final bool baseIsDigit = _isDigitToken(token);

    if (start + consumed < tokens.length) {
      final nextToken = tokens[start + consumed];

      // "ونص" / "وربع" are always word-based, allowed after word-based or
      // after digit-based thousands/hundreds (e.g. "1000 ونص" is unusual
      // but "الف ونص" is common; both are word-based so this is fine).
      if (!baseIsDigit) {
        if (nextToken == 'ونص') {
          if (currentVal >= 1000) {
            return NumberParseResult(currentVal + 500, consumed + 1);
          } else if (currentVal >= 100) {
            return NumberParseResult(currentVal + 50, consumed + 1);
          }
        } else if (nextToken == 'وربع') {
          if (currentVal >= 1000) {
            return NumberParseResult(currentVal + 250, consumed + 1);
          } else if (currentVal >= 100) {
            return NumberParseResult(currentVal + 25, consumed + 1);
          }
        }
      }

      if (nextToken.startsWith('و') && nextToken.length > 1) {
        final andToken = nextToken.substring(1);
        final bool andIsDigit = _isDigitToken(andToken);

        // Never merge two digit literals.
        if (baseIsDigit && andIsDigit) {
          // Fall through — do NOT merge.
        } else {
          final int? andVal = _parseSingleToken(andToken);

          if (andVal != null) {
            int addedConsumed = 1;
            int finalAndVal = andVal;

            if (start + consumed + 1 < tokens.length) {
              final afterNext = tokens[start + consumed + 1];
              if (afterNext == 'تلاف' ||
                  afterNext == 'الاف' ||
                  afterNext == 'الف') {
                if (currentVal < 100 && andVal < 100) {
                  // e.g. "خمسة وتلاتين الف" -> (5 + 30) * 1000 = 35000
                  currentVal = (currentVal + andVal) * 1000;
                  consumed += 2;
                  return NumberParseResult(currentVal, consumed);
                } else {
                  finalAndVal = finalAndVal * 1000;
                  addedConsumed = 2;
                }
              }
            }

            // Validate that this forms a valid Arabic compound number:
            // - larger + smaller (e.g. ميت وخمسين = 100+50)
            // - smaller + larger only for multiplier (e.g. خمسه وعشرين = 5+20)
            // In both cases, one must be strictly greater than the other.
            if (_isValidCompound(currentVal, finalAndVal)) {
              if (currentVal > finalAndVal) {
                currentVal += finalAndVal;
              } else {
                currentVal = finalAndVal + currentVal;
              }
              consumed += addedConsumed;

              // Third component (e.g. الف وميتين وخمسين)
              if (start + consumed < tokens.length) {
                final thirdToken = tokens[start + consumed];
                if (thirdToken.startsWith('و') && thirdToken.length > 1) {
                  final thirdAnd = thirdToken.substring(1);
                  if (!_isDigitToken(thirdAnd)) {
                    final int? thirdVal = _parseSingleToken(thirdAnd);
                    if (thirdVal != null && thirdVal < currentVal) {
                      currentVal += thirdVal;
                      consumed += 1;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    return NumberParseResult(currentVal, consumed);
  }

  /// Returns true when [a] and [b] form a valid Arabic compound number.
  /// Valid compounds:
  ///  - thousands + hundreds/tens/units  (1000 + 200)
  ///  - hundreds  + tens/units           (100  + 50)
  ///  - tens      + units                (20   + 5)
  ///  - units     + tens                 (5    + 20) — "خمسه وعشرين"
  ///  - units     + hundreds/thousands   via multiplier (already handled by تلاف)
  /// Invalid: two values of the same magnitude or both very small standalone
  /// digit amounts that the user meant as separate items.
  static bool _isValidCompound(int a, int b) {
    if (a == b) return false;
    if (a == 0 || b == 0) return false;

    final int larger = a > b ? a : b;
    final int smaller = a > b ? b : a;

    // Thousands + anything smaller (e.g. الف وميتين، الفين وخمسمية)
    if (larger >= 1000 && smaller < 1000) return true;
    // Hundreds + tens or units (e.g. ميت وخمسين، تلتميه وعشرين)
    if (larger >= 100 && larger < 1000 && smaller < 100) return true;
    // Tens + units (e.g. خمسه وعشرين → units=5 tens=20)
    if (larger >= 10 && larger < 100 && smaller < 10) return true;

    return false;
  }

  static final Map<String, ({String category, String name})>
  _normalizedKeywords = _buildNormalizedKeywords();

  static Map<String, ({String category, String name})>
  _buildNormalizedKeywords() {
    final map = <String, ({String category, String name})>{};
    for (final catEntry in _categoryNounKeywords.entries) {
      final category = catEntry.key;
      for (final kwEntry in catEntry.value.entries) {
        final rawKey = kwEntry.key;
        final canonicalName = kwEntry.value;
        final normKey = normalize(rawKey);
        final val = (category: category, name: canonicalName);
        map[normKey] = val;
        map[rawKey] = val;
      }
    }
    return map;
  }

  static ({String category, String name})? _lookupKeyword(String key) {
    if (key.isEmpty) return null;
    return _normalizedKeywords[key];
  }

  /// Finds a recognized keyword for [normToken].
  ///
  /// Task A Rule:
  /// Prefix stripping (ب، ل، و) must apply ONLY to number words and amount
  /// attachments (بخمسين، بميتين، لخمسين، ب70), never to ordinary words.
  /// Words like بيت، بنزين، بقالة، بيتزا، لحمة، وجبة must stay intact.
  /// Check the whole word against the known-keyword list before stripping.
  static ({String category, String name})? _findKeyword(String normToken) {
    // 1. Check whole word against known keywords before any stripping (Task A)
    final wholeMatch = _lookupKeyword(normToken);
    if (wholeMatch != null) return wholeMatch;

    // 2. Definite article 'ال' (e.g. "البنزين", "اللحمة", "المترو", "السينما")
    if (normToken.startsWith('ال') && normToken.length > 3) {
      final strippedAl = normToken.substring(2);
      final alMatch = _lookupKeyword(strippedAl);
      if (alMatch != null) return alMatch;
    }

    // 3. Preposition 'لل' (e.g. "للميكانيكي", "للكهربا")
    if (normToken.startsWith('لل') && normToken.length > 3) {
      final strippedLl = normToken.substring(2);
      final llMatch = _lookupKeyword(strippedLl);
      if (llMatch != null) return llMatch;
    }

    // 4. Preposition 'ب' attached to a keyword (e.g. "بميكروباص", "بتاكسي", "بمترو")
    // NOTE: Whole word was already checked in step 1, so ordinary words like
    // "بنزين", "بقالة", "بيتزا" already matched intact. For non-keywords like "بيت",
    // stripping 'ب' gives "يت" which is not a keyword either.
    if (normToken.startsWith('ب') && normToken.length > 2) {
      final strippedB = normToken.substring(1);
      final bMatch = _lookupKeyword(strippedB);
      if (bMatch != null) return bMatch;

      if (strippedB.startsWith('ال') && strippedB.length > 3) {
        final bAlMatch = _lookupKeyword(strippedB.substring(2));
        if (bAlMatch != null) return bAlMatch;
      }
    }

    // 5. Conjunction 'و' (e.g. "ولحمة", "وكشري")
    // NOTE: Whole word was already checked in step 1, so words like "وجبة"
    // have already matched intact in step 1.
    if (normToken.startsWith('و') && normToken.length > 2) {
      final strippedWaw = normToken.substring(1);
      final wawMatch = _lookupKeyword(strippedWaw);
      if (wawMatch != null) return wawMatch;

      if (strippedWaw.startsWith('ال') && strippedWaw.length > 3) {
        final wawAlMatch = _lookupKeyword(strippedWaw.substring(2));
        if (wawAlMatch != null) return wawAlMatch;
      }

      if (strippedWaw.startsWith('ب') && strippedWaw.length > 2) {
        final strippedWawB = strippedWaw.substring(1);
        final wawBMatch = _lookupKeyword(strippedWawB);
        if (wawBMatch != null) return wawBMatch;
      }
    }

    return null;
  }

  static bool _isStartVerb(String word) {
    var w = word;
    if (w.startsWith('و') && w.length > 2) {
      w = w.substring(1);
    }
    return _startVerbs.contains(w);
  }

  static bool _isFiller(String word) {
    var w = word;
    if (w.startsWith('و') && w.length > 2) {
      w = w.substring(1);
    }
    return _fillerWords.contains(w) || _fillerWords.contains(word);
  }

  /// Extracts place note if item contains في / عند / ف followed by words
  /// that are not numbers, currency, verbs or filler. Max 40 characters.
  static ({String? note, Set<int> placeIndices}) _extractPlaceNote(
    List<String> originalTokens,
    List<String> normTokens,
  ) {
    int pIndex = -1;
    for (int i = 0; i < normTokens.length; i++) {
      final t = normTokens[i];
      if (t == 'في' || t == 'عند' || t == 'ف') {
        pIndex = i;
        break;
      }
    }

    if (pIndex == -1 || pIndex + 1 >= normTokens.length) {
      return (note: null, placeIndices: const <int>{});
    }

    final placeWords = <String>[];
    final placeIndices = <int>{pIndex};

    for (int j = pIndex + 1; j < normTokens.length; j++) {
      final norm = normTokens[j];

      // Stop on numbers
      final parsed = tryParseNumber(normTokens, j);
      if (parsed != null && parsed.value > 0) break;
      if (_parseSingleToken(norm) != null) break;

      // Stop on currency
      if (_currencyWords.contains(norm)) break;

      // Stop on verbs or fillers
      if (_isStartVerb(norm) || _isFiller(norm)) break;

      // Stop on conjunctions
      if (norm == 'و' || norm == 'ثم' || norm == 'وبعدين') break;

      // Stop on prepositions
      if (norm == 'ب' || norm == 'ل' || norm == 'على' || norm == 'علي') break;

      placeWords.add(originalTokens[j]);
      placeIndices.add(j);
    }

    if (placeWords.isEmpty) {
      return (note: null, placeIndices: const <int>{});
    }

    var note = placeWords.join(' ').trim();
    // Strip control characters
    note = note.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();
    if (note.length > 40) {
      note = note.substring(0, 40).trim();
    }

    return (note: note.isNotEmpty ? note : null, placeIndices: placeIndices);
  }

  /// Determines category and short item name for an item following the rules:
  /// (0) User rules first
  /// (a) Noun keywords
  /// (b) Verbs if no noun keywords
  /// (c) Otherwise أخرى
  static ({String category, String name}) _resolveCategoryAndName({
    required List<String> originalTokens,
    required List<String> normTokens,
    List<String> customCategories = const [],
    List<({int id, String keyword, String categoryName, int categoryId})>
        userRules = const [],
    Set<int> placeIndices = const {},
  }) {
    final itemText = normTokens.join(' ');

    // 0. Priority: User Rules (Section 4)
    for (final rule in userRules) {
      final normKey = normalize(rule.keyword);
      if (normKey.isNotEmpty &&
          (itemText.contains(normKey) ||
              normTokens.any((t) =>
                  t == normKey ||
                  t == 'و$normKey' ||
                  t == 'ب$normKey' ||
                  t == 'ل$normKey'))) {
        return (category: rule.categoryName, name: rule.keyword);
      }
    }

    // 1. Check custom categories
    for (final custom in customCategories) {
      final normCustom = normalize(custom);
      if (normCustom.isNotEmpty && itemText.contains(normCustom)) {
        return (category: custom, name: custom);
      }
    }

    // 2. Priority (a): Noun keywords first
    for (int i = 0; i < normTokens.length; i++) {
      final match = _findKeyword(normTokens[i]);
      if (match != null) {
        if (_hasQuantitySpecification(normTokens)) {
          final desc = _cleanItemDescription(
            originalTokens,
            normTokens,
            fallbackName: match.name,
            placeIndices: placeIndices,
          );
          final cat = (itemText.contains('دهب') ||
                  itemText.contains('ذهب') ||
                  itemText.contains('سبيكه') ||
                  itemText.contains('سبيكة'))
              ? 'استثمار وادخار'
              : match.category;
          return (category: cat, name: desc);
        }
        return match;
      }
    }

    // 3. Priority (b): Verbs if no noun keyword
    for (final token in normTokens) {
      var w = token;
      if (w.startsWith('و') && w.length > 2) {
        w = w.substring(1);
      }
      final rule = _verbRules[w];
      if (rule != null) {
        return (category: rule.category, name: rule.name);
      }
    }

    // 4. Priority (c): Otherwise أخرى
    // Category is أخرى, and description is extracted from user's words
    final filteredWords = <String>[];
    for (int k = 0; k < originalTokens.length; k++) {
      if (placeIndices.contains(k)) continue;
      final norm = normTokens[k];
      if (_currencyWords.contains(norm)) continue;
      if (_fillerWords.contains(norm)) continue;
      if (norm.startsWith('ب') && norm.length > 1 && _isDigitToken(norm.substring(1))) continue;
      if (_parseSingleToken(norm) != null) continue;
      var display = originalTokens[k];
      if (display.startsWith('و') && display.length > 2) {
        final afterW = norm.substring(1);
        if (_isStartVerb(afterW) || _findKeyword(afterW) != null) {
          display = display.substring(1);
        }
      }
      filteredWords.add(display);
    }

    final fallbackDescription = filteredWords.isNotEmpty
        ? filteredWords.take(4).join(' ')
        : 'أخرى';

    // If quantity or specification words are present (e.g. ربع جنيه دهب, سبيكة دهب 2 جرام, 3 كيلو فراخ)
    if (_hasQuantitySpecification(normTokens)) {
      final desc = _cleanItemDescription(
        originalTokens,
        normTokens,
        fallbackName: fallbackDescription,
        placeIndices: placeIndices,
      );
      final cat = (itemText.contains('دهب') ||
              itemText.contains('ذهب') ||
              itemText.contains('سبيكه') ||
              itemText.contains('سبيكة'))
          ? 'استثمار وادخار'
          : 'أخرى';
      return (category: cat, name: desc);
    }

    return (category: 'أخرى', name: fallbackDescription);
  }

  static const Set<String> _quantityUnits = {
    'جرام',
    'جم',
    'كيلو',
    'كجم',
    'لتر',
    'مل',
    'قطعه',
    'قطع',
    'عيار',
    'جيجا',
    'ميجا',
  };

  static bool _hasQuantitySpecification(List<String> normTokens) {
    final text = normTokens.join(' ');
    if (text.contains('جنيه دهب') ||
        text.contains('جنيه ذهب') ||
        text.contains('ربع جنيه') ||
        text.contains('نص جنيه') ||
        text.contains('سبيكه') ||
        text.contains('سبيكة')) {
      return true;
    }
    for (final unit in _quantityUnits) {
      if (normTokens.contains(unit)) return true;
    }
    return false;
  }

  static String? _extractQuantityText(
    List<String> originalTokens,
    List<String> normTokens,
  ) {
    final text = normTokens.join(' ');
    if (text.contains('ربع جنيه')) return 'ربع جنيه';
    if (text.contains('نص جنيه') || text.contains('نصف جنيه')) return 'نص جنيه';
    if (text.contains('جنيه دهب') || text.contains('جنيه ذهب')) return 'جنيه دهب';

    final regex = RegExp(
      r'(\d+)\s*(جرام|جم|كيلو|كجم|لتر|مل|قطعه|قطع|علبه|علب|باكو|كرتونه|متر|جيجا|عيار)',
    );
    final m = regex.firstMatch(text);
    if (m != null) {
      return '${m[1]} ${m[2]}';
    }

    final reverseRegex = RegExp(r'(عيار)\s*(\d+)');
    final rm = reverseRegex.firstMatch(text);
    if (rm != null) {
      return '${rm[1]} ${rm[2]}';
    }

    return null;
  }

  static String _cleanItemDescription(
    List<String> originalTokens,
    List<String> normTokens, {
    required String fallbackName,
    Set<int> placeIndices = const {},
  }) {
    final cleanWords = <String>[];
    for (int i = 0; i < originalTokens.length; i++) {
      if (placeIndices.contains(i)) continue;
      final norm = normTokens[i];
      if (_isStartVerb(norm) || _isFiller(norm)) continue;
      if (norm == 'ب' || norm == 'في' || norm == 'عند' || norm == 'من' || norm == 'مع') {
        continue;
      }

      // Strip currency "جنيه" only if not part of gold coins e.g. "جنيه دهب" or "ربع جنيه"
      if (norm == 'جنيه' || norm == 'جنيها' || norm == 'جم') {
        final isGoldCoin = (i + 1 < normTokens.length &&
                (normTokens[i + 1] == 'دهب' || normTokens[i + 1] == 'ذهب')) ||
            (i > 0 && (normTokens[i - 1] == 'ربع' || normTokens[i - 1] == 'نص'));
        if (!isGoldCoin) continue;
      }

      var word = originalTokens[i];
      if (word.startsWith('ب') && word.length > 1 && _isDigitToken(word.substring(1))) {
        continue;
      }
      cleanWords.add(word);
    }
    if (cleanWords.isEmpty) return fallbackName;
    return cleanWords.join(' ').trim();
  }

  static bool _isQuantityNumber(List<String> tokens, int start, int consumedCount) {
    final nextIdx = start + consumedCount;
    if (nextIdx < tokens.length) {
      final nextWord = tokens[nextIdx];
      if (_quantityUnits.contains(nextWord)) {
        return true;
      } else if (nextWord == 'جنيه' && nextIdx + 1 < tokens.length) {
        final afterGenieh = tokens[nextIdx + 1];
        if (afterGenieh == 'دهب' || afterGenieh == 'ذهب') {
          return true;
        }
      }
    }

    if (start > 0 && (_quantityUnits.contains(tokens[start - 1]) || tokens[start - 1] == 'عيار')) {
      return true;
    }

    return false;
  }

  static List<ParsedExpense>? _tryParseCurrencyEquivalence(
    String input, {
    List<String> customCategories = const [],
    List<({int id, String keyword, String categoryName, int categoryId})>
        userRules = const [],
  }) {
    final hasDollar = input.contains(r'$') || input.contains('دولار');
    final hasEuro = input.contains('يورو');
    final hasRiyal = input.contains('ريال');
    final hasDirham = input.contains('درهم');
    final hasPound = input.contains('استرليني') || input.contains('باوند');

    if (!hasDollar && !hasEuro && !hasRiyal && !hasDirham && !hasPound) {
      return null;
    }

    var currencyCode = 'USD';
    if (hasEuro) currencyCode = 'EUR';
    if (hasRiyal) currencyCode = 'SAR';
    if (hasDirham) currencyCode = 'AED';
    if (hasPound) currencyCode = 'GBP';

    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    var prep = input;
    for (int i = 0; i < 10; i++) {
      prep = prep.replaceAll(arabicDigits[i], '$i');
    }

    // Equivalence regex: foreign amount + currency + connector + egp amount
    final eqMatch = RegExp(
      r'(?:(?:\$|دولار(?:ات)?|يورو|ريال(?:ات)?|درهم|استرليني|باوند)\s*(\d+)|(\d+)\s*(?:\$|دولار(?:ات)?|يورو|ريال(?:ات)?|درهم|استرليني|باوند))\s*(?:بـ?|يعني|يساوي|بحوالي|بمقابل)\s*(\d+)\s*(?:جنيه)?',
    ).firstMatch(prep);

    if (eqMatch != null) {
      final foreignStr = eqMatch.group(1) ?? eqMatch.group(2);
      final egpStr = eqMatch.group(3);
      final foreignAmt = double.tryParse(foreignStr ?? '0') ?? 0.0;
      final egpAmt = int.tryParse(egpStr ?? '0') ?? 0;

      final prefix = prep.substring(0, eqMatch.start).trim();
      var desc = currencyCode == 'USD' ? 'دولار' : 'عملة أجنبية';
      var cat = 'أخرى';

      if (currencyCode == 'USD' && prefix.isEmpty) {
        cat = 'استثمار وادخار';
      }

      final words = prefix
          .replaceAll(RegExp(r'^(اشتريت|دفعت|جبت|حولت|خدت|اخدت)\s*'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && w != 'ب')
          .toList();

      if (words.isNotEmpty) {
        desc = words.take(3).join(' ');
        final normDesc = normalize(desc);
        final kwMatch = _findKeyword(normDesc);
        if (kwMatch != null) {
          cat = kwMatch.category;
        }
      }

      return [
        ParsedExpense(
          amount: egpAmt,
          description: desc,
          category: cat,
          foreignAmount: foreignAmt,
          foreignCurrency: currencyCode,
          sourceText: input,
          confidence: 0.95,
        ),
      ];
    }

    // Foreign currency without EGP equivalent
    final soloMatch = RegExp(
      r'(?:(?:\$|دولار(?:ات)?|يورو|ريال(?:ات)?|درهم|استرليني|باوند)\s*(\d+)|(\d+)\s*(?:\$|دولار(?:ات)?|يورو|ريال(?:ات)?|درهم|استرليني|باوند))',
    ).firstMatch(prep);

    if (soloMatch != null && !prep.contains('جنيه')) {
      final foreignStr = soloMatch.group(1) ?? soloMatch.group(2);
      final foreignAmt = double.tryParse(foreignStr ?? '0') ?? 0.0;

      var desc = 'يورو';
      if (currencyCode == 'USD') desc = 'دولار';
      if (currencyCode == 'SAR') desc = 'ريال';
      if (currencyCode == 'AED') desc = 'درهم';
      if (currencyCode == 'GBP') desc = 'استرليني';

      return [
        ParsedExpense(
          amount: null,
          description: desc,
          category: 'أخرى',
          foreignAmount: foreignAmt,
          foreignCurrency: currencyCode,
          sourceText: input,
          confidence: 0.4,
        ),
      ];
    }

    return null;
  }

  /// Extracts all numerical amounts found in an Egyptian Arabic text sentence.
  static List<int> extractAllAmounts(String input) {
    if (input.trim().isEmpty) return [];
    var prepText = input;
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (int i = 0; i < 10; i++) {
      prepText = prepText.replaceAll(arabicDigits[i], '$i');
    }
    prepText = prepText.replaceAllMapped(
      RegExp(r'(\d+)\s*ج(?=\s|$)'),
      (m) => '${m[1]} ',
    );
    prepText = prepText.replaceAll(RegExp(r'[,،.;:!?؟-]'), ' ');

    final rawTokens = prepText
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (rawTokens.isEmpty) return [];

    final normTokens = rawTokens.map(normalize).where((t) => t.isNotEmpty).toList();
    final amounts = <int>[];
    int i = 0;
    while (i < normTokens.length) {
      final parsed = tryParseNumber(normTokens, i);
      if (parsed != null && parsed.value > 0) {
        if (!_isQuantityNumber(normTokens, i, parsed.consumedCount)) {
          amounts.add(parsed.value);
        }
        i += parsed.consumedCount;
      } else {
        i++;
      }
    }
    return amounts;
  }

  /// Parses an Egyptian Arabic text sentence into a list of [ParsedExpense] items.
  static List<ParsedExpense> parse(
    String input, {
    List<String> customCategories = const [],
    List<({int id, String keyword, String categoryName, int categoryId})>
        userRules = const [],
  }) {
    if (input.trim().isEmpty) return [];

    // Currency equivalence check (Section 2 & 3: single item for $150 ب 8400 جنيه, etc.)
    final currencyResult = _tryParseCurrencyEquivalence(
      input,
      customCategories: customCategories,
      userRules: userRules,
    );
    if (currencyResult != null && currencyResult.isNotEmpty) {
      return currencyResult;
    }

    // 1. Digits unification & punctuation normalization
    var prepText = input;
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (int i = 0; i < 10; i++) {
      prepText = prepText.replaceAll(arabicDigits[i], '$i');
    }
    prepText = prepText.replaceAllMapped(
      RegExp(r'(\d+)\s*ج(?=\s|$)'),
      (m) => '${m[1]} ',
    );
    prepText = prepText.replaceAll(RegExp(r'[,،.;:!?؟-]'), ' ');

    final rawTokens = prepText
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (rawTokens.isEmpty) return [];

    final originalTokens = <String>[];
    final normTokens = <String>[];

    for (final raw in rawTokens) {
      final norm = normalize(raw);
      if (norm.isNotEmpty) {
        originalTokens.add(raw);
        normTokens.add(norm);
      }
    }

    if (normTokens.isEmpty) return [];

    // 2. Find all amounts
    final matches = <AmountMatch>[];
    int i = 0;
    while (i < normTokens.length) {
      final parsed = tryParseNumber(normTokens, i);
      if (parsed != null && parsed.value > 0) {
        if (!_isQuantityNumber(normTokens, i, parsed.consumedCount)) {
          matches.add(
            AmountMatch(
              startIndex: i,
              endIndex: i + parsed.consumedCount,
              amount: parsed.value,
            ),
          );
        }
        i += parsed.consumedCount;
      } else {
        i++;
      }
    }

    if (matches.isEmpty) {
      if (_hasQuantitySpecification(normTokens)) {
        final placeResult = _extractPlaceNote(originalTokens, normTokens);
        final resolved = _resolveCategoryAndName(
          originalTokens: originalTokens,
          normTokens: normTokens,
          customCategories: customCategories,
          userRules: userRules,
          placeIndices: placeResult.placeIndices,
        );
        final qText = _extractQuantityText(originalTokens, normTokens);
        return [
          ParsedExpense(
            amount: null,
            description: resolved.name,
            category: resolved.category,
            quantityText: qText,
            confidence: 0.4,
          ),
        ];
      }
      return [];
    }

    final expenses = <ParsedExpense>[];

    if (matches.length == 1) {
      final match = matches.first;
      final beforeOrig = originalTokens.sublist(0, match.startIndex);
      final beforeNorm = normTokens.sublist(0, match.startIndex);
      final afterOrig = originalTokens.sublist(match.endIndex);
      final afterNorm = normTokens.sublist(match.endIndex);

      final itemOrig = [...beforeOrig, ...afterOrig];
      final itemNorm = [...beforeNorm, ...afterNorm];

      // Task C: notes disabled — _extractPlaceNote is still called so
      // placeIndices can exclude place words from the item name, but the
      // note itself is always null.
      final placeResult = _extractPlaceNote(itemOrig, itemNorm);
      final resolved = _resolveCategoryAndName(
        originalTokens: itemOrig,
        normTokens: itemNorm,
        customCategories: customCategories,
        userRules: userRules,
        placeIndices: placeResult.placeIndices,
      );
      final qText = _extractQuantityText(itemOrig, itemNorm);

      expenses.add(
        ParsedExpense(
          amount: match.amount,
          description: resolved.name,
          category: resolved.category,
          quantityText: qText,
        ),
      );
    } else {
      // Multiple items: find item start boundaries
      // An item starts at the next start verb after a complete item
      final itemStartIndices = <int>[0];

      for (int k = 1; k < matches.length; k++) {
        final prevMatch = matches[k - 1];
        final currMatch = matches[k];

        // Search in the segment between previous amount and current amount
        // for a clear item separator (start verb or و-prefixed keyword).
        // Default: all gap words belong to the PREVIOUS item, so the new
        // item starts at the current amount's position.
        int splitAt = currMatch.startIndex;

        for (int idx = prevMatch.endIndex; idx < currMatch.startIndex; idx++) {
          final word = normTokens[idx];
          // Skip currency words — they belong to the previous amount.
          if (_currencyWords.contains(word)) continue;
          if (_isStartVerb(word)) {
            splitAt = idx;
            break;
          }
          if (word.startsWith('و') && word.length > 2) {
            // Words like ورق or وقود are inherent nouns, not conjunction separators
            if (_inherentWawWords.contains(word)) {
              continue;
            }
            final afterW = word.substring(1);
            if (_isStartVerb(afterW) ||
                _findKeyword(afterW) != null ||
                _inherentWawWords.contains(afterW) ||
                afterW.length >= 3) {
              splitAt = idx;
              break;
            }
          }
        }

        itemStartIndices.add(splitAt);
      }

      for (int k = 0; k < matches.length; k++) {
        final match = matches[k];
        final startIdx = itemStartIndices[k];
        final endIdx = (k == matches.length - 1)
            ? normTokens.length
            : itemStartIndices[k + 1];

        final segOrig = <String>[];
        final segNorm = <String>[];

        for (int idx = startIdx; idx < endIdx; idx++) {
          // Exclude the amount itself and immediate currency token
          if (idx >= match.startIndex && idx < match.endIndex) continue;
          if (idx == match.endIndex && _currencyWords.contains(normTokens[idx])) {
            continue;
          }

          segOrig.add(originalTokens[idx]);
          segNorm.add(normTokens[idx]);
        }

        // Task C: notes disabled — see single-item path above.
        final placeResult = _extractPlaceNote(segOrig, segNorm);
        final resolved = _resolveCategoryAndName(
          originalTokens: segOrig,
          normTokens: segNorm,
          customCategories: customCategories,
          userRules: userRules,
          placeIndices: placeResult.placeIndices,
        );
        final qText = _extractQuantityText(segOrig, segNorm);

        expenses.add(
          ParsedExpense(
            amount: match.amount,
            description: resolved.name,
            category: resolved.category,
            quantityText: qText,
          ),
        );
      }
    }

    return expenses;
  }
}

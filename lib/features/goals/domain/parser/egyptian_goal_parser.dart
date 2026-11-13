import '../../../../core/utils/goal_icon_helper.dart';
import '../../../expenses/domain/parser/egyptian_expense_parser.dart';
import '../../data/repositories/goal_repository_impl.dart';

class ParsedGoalResult {
  final String name;
  final int targetAmount; // in EGP
  final String? icon;

  const ParsedGoalResult({
    required this.name,
    required this.targetAmount,
    this.icon,
  });
}

class EgyptianGoalParser {
  static const Set<String> _knownCategoryNames = {
    'أكل',
    'مشروبات وكافيهات',
    'مشروبات',
    'سوبر ماركت',
    'مواصلات',
    'سيارة',
    'ملابس',
    'إلكترونيات',
    'بيت وأثاث',
    'إيجار',
    'فواتير واتصالات',
    'فواتير',
    'اشتراكات',
    'صحة',
    'عناية شخصية',
    'تعليم',
    'ترفيه',
    'سفر',
    'أطفال',
    'حيوانات أليفة',
    'هدايا ومناسبات',
    'صدقات',
    'استثمار وادخار',
    'ديون وأقساط',
    'أخرى',
  };

  static const Set<String> _fillerWords = {
    'عايز',
    'عايزة',
    'نفسي',
    'اجيب',
    'اشتري',
    'اشترى',
    'اشتريلي',
    'اوفر',
    'احوش',
    'احوّش',
    'هدف',
    'هدفي',
    'ان',
    'شاء',
    'الله',
    'ب',
    'بـ',
    'جنيه',
    'جنية',
    'ج',
    'في',
    'من',
    'على',
    'عشان',
    'علشان',
    'الهدف',
    'حوالي',
    'تقريبا',
    'كده',
  };

  static const Set<String> _numberWords = {
    'صفر',
    'واحد',
    'واحدة',
    'واحده',
    'اتنين',
    'تلاتة',
    'تلاته',
    'تلات',
    'اربعة',
    'اربعه',
    'اربع',
    'خمسة',
    'خمسه',
    'خمس',
    'ستة',
    'سته',
    'ست',
    'سبعة',
    'سبعه',
    'سبع',
    'تمانية',
    'تمانيه',
    'تمنيه',
    'تمن',
    'تسعة',
    'تسعه',
    'تسع',
    'عشرة',
    'عشره',
    'عشر',
    'حداشر',
    'اتناشر',
    'تلاتاشر',
    'اربعتاشر',
    'خمستاشر',
    'ستاشر',
    'سبعتاشر',
    'تمنتاشر',
    'تسعتاشر',
    'عشرين',
    'تلاتين',
    'اربعين',
    'خمسين',
    'ستين',
    'سبعين',
    'تمانين',
    'تسعين',
    'مية',
    'ماية',
    'ميت',
    'ميتين',
    'تلتمية',
    'ربعمية',
    'خمسمية',
    'ستمية',
    'سبعمية',
    'تمنمية',
    'تسعمية',
    'بمية',
    'بماية',
    'بميت',
    'بميتين',
    'بتلتمية',
    'بربعمية',
    'بخمسمية',
    'بستمية',
    'بسبعمية',
    'بتمنمية',
    'بتسعمية',
    'الف',
    'بالف',
    'الفين',
    'بالفين',
    'الاف',
    'آلاف',
    'ملايين',
    'مليون',
    'بمليون',
    'مليارات',
    'مليار',
    'نص',
    'ربع',
    'تلت',
  };

  static bool isCategoryName(String text) {
    final norm = text.trim();
    if (_knownCategoryNames.contains(norm)) return true;
    for (final cat in _knownCategoryNames) {
      if (norm == cat || norm.replaceAll(' ', '') == cat.replaceAll(' ', '')) {
        return true;
      }
    }
    return false;
  }

  /// Parses an Egyptian Arabic utterance into a goal item name and target amount (in EGP).
  /// Returns null if no valid amount or goal name is found.
  static ParsedGoalResult? parse(String utterance) {
    if (utterance.trim().isEmpty) return null;

    final tokens = utterance.split(RegExp(r'\s+'));

    // Check if there is a price particle (e.g. "ب", "بـ", "بخمسة", "بمية", "ب 8000")
    int priceStartIndex = -1;
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i].replaceAll(RegExp(r'[.,،:;!?؟-]'), '').trim();
      if (token == 'ب' || token == 'بـ' || token == 'بمبلغ') {
        priceStartIndex = i;
        break;
      }
      if (token.startsWith('ب') &&
          (_numberWords.contains(token.substring(1)) ||
              int.tryParse(token.substring(1)) != null)) {
        priceStartIndex = i;
        break;
      }
    }

    // 1. Extract amount from price segment if present, else whole utterance
    int? extractedAmount;
    if (priceStartIndex >= 0) {
      final priceSegment = tokens.sublist(priceStartIndex).join(' ');
      final amounts = EgyptianExpenseParser.extractAllAmounts(priceSegment);
      if (amounts.isNotEmpty) {
        extractedAmount = amounts.first;
      }
    }

    if (extractedAmount == null) {
      final amounts = EgyptianExpenseParser.extractAllAmounts(utterance);
      if (amounts.isNotEmpty) {
        // Prefer the last amount if multiple (e.g. "بلايستيشن 5 بخمسة وتلاتين الف")
        extractedAmount = amounts.last;
      }
    }

    if (extractedAmount == null || extractedAmount <= 0) {
      return null;
    }

    // 2. Extract item name from the exact words the user said
    final goalName = extractGoalName(utterance, extractedAmount);
    if (goalName == null || goalName.isEmpty || isCategoryName(goalName)) {
      return null;
    }

    final sanitized = GoalRepositoryImpl.sanitizeName(goalName);
    if (sanitized.isEmpty) return null;

    return ParsedGoalResult(
      name: sanitized,
      targetAmount: extractedAmount,
      icon: GoalIconHelper.resolveIconKeyFromName(sanitized),
    );
  }

  /// Extracts the goal name from words actually said, removing filler, numbers, and category names
  static String? extractGoalName(String utterance, int? amount) {
    var text = utterance.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), ' ').trim();
    if (text.isEmpty) return null;

    final tokens = text.split(RegExp(r'\s+'));

    // Check if there is a price particle (e.g. "ب", "بـ", "بخمسة", "بمية", "ب 8000")
    int priceStartIndex = -1;
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i].replaceAll(RegExp(r'[.,،:;!?؟-]'), '').trim();
      if (token == 'ب' || token == 'بـ' || token == 'بمبلغ') {
        priceStartIndex = i;
        break;
      }
      if (token.startsWith('ب') &&
          (_numberWords.contains(token.substring(1)) ||
              int.tryParse(token.substring(1)) != null)) {
        priceStartIndex = i;
        break;
      }
    }

    // If price particle is found, items before it take priority
    if (priceStartIndex > 0) {
      final beforePriceTokens = tokens.sublist(0, priceStartIndex);
      final itemCandidates = <String>[];
      for (var token in beforePriceTokens) {
        var clean = token.replaceAll(RegExp(r'[.,،:;!?؟-]'), '').trim();
        if (clean.isEmpty) continue;
        if (_fillerWords.contains(clean)) continue;
        if (isCategoryName(clean)) continue;
        itemCandidates.add(clean);
      }
      if (itemCandidates.isNotEmpty) {
        final result = itemCandidates.take(4).join(' ').trim();
        if (result.isNotEmpty && !isCategoryName(result)) {
          return result;
        }
      }
    }

    // Otherwise check tokens after price if any (e.g. "عايز احوش ميتين الف للشقة")
    if (priceStartIndex >= 0 && priceStartIndex < tokens.length - 1) {
      final afterPriceTokens = tokens.sublist(priceStartIndex);
      final itemCandidates = <String>[];
      for (var token in afterPriceTokens) {
        var clean = token.replaceAll(RegExp(r'[.,،:;!?؟-]'), '').trim();
        if (clean.isEmpty) continue;
        if (clean.startsWith('لل') && clean.length > 2) {
          clean = clean.substring(2);
        } else if (clean.startsWith('ل') &&
            clean.length > 1 &&
            !clean.startsWith('لا')) {
          clean = clean.substring(1);
        }
        if (_fillerWords.contains(clean)) continue;
        if (_isNumberToken(clean)) continue;
        if (isCategoryName(clean)) continue;
        itemCandidates.add(clean);
      }
      if (itemCandidates.isNotEmpty) {
        final result = itemCandidates.take(4).join(' ').trim();
        if (result.isNotEmpty && !isCategoryName(result)) {
          return result;
        }
      }
    }

    // Fallback: general token filtering
    final meaningfulTokens = <String>[];
    for (var token in tokens) {
      var clean = token.replaceAll(RegExp(r'[.,،:;!?؟-]'), '').trim();
      if (clean.isEmpty) continue;

      if (clean.startsWith('لل') && clean.length > 2) {
        clean = clean.substring(2);
      } else if (clean.startsWith('ل') &&
          clean.length > 1 &&
          !clean.startsWith('لا')) {
        clean = clean.substring(1);
      }

      if (_fillerWords.contains(clean)) continue;
      if (isCategoryName(clean)) continue;
      if (_isNumberToken(clean)) continue;

      meaningfulTokens.add(clean);
    }

    if (meaningfulTokens.isEmpty) return null;

    final candidate = meaningfulTokens.take(4).join(' ').trim();
    if (candidate.isEmpty || isCategoryName(candidate)) return null;

    return candidate;
  }

  static bool _isNumberToken(String clean) {
    if (_numberWords.contains(clean)) return true;
    if (clean.startsWith('ب') && _numberWords.contains(clean.substring(1))) {
      return true;
    }
    if (clean.startsWith('و') && _numberWords.contains(clean.substring(1))) {
      return true;
    }
    if (clean == 'جنيه' || clean == 'جنية' || clean == 'ج') return true;
    if (int.tryParse(clean) != null) return true;
    return false;
  }
}

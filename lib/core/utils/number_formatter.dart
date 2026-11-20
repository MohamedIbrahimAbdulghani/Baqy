import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Utility extension to format numbers into Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩)
extension ArabicIndicDigits on Object {
  String toArabicDigits() {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = toString();
    for (var i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], arabicDigits[i]);
    }
    return result;
  }
}

/// Helper methods for formatting currency and parsing numeric user inputs
abstract final class NumberFormatter {
  static final NumberFormat _thousands = NumberFormat('#,##0', 'en_US');

  /// Global locale tracking for numeric formatting ('ar' for Arabic-Indic digits, 'en' for Western digits)
  static String currentLocaleCode = 'ar';

  /// Formats an integer amount (in EGP) with thousands separators in English digits.
  /// Example: 10000 -> "10,000", 1000000 -> "1,000,000"
  static String formatWithCommas(int amount) {
    return _thousands.format(amount);
  }

  /// Formats an integer amount (in EGP) with thousands separators.
  /// Uses Arabic-Indic digits if locale is 'ar', or Western digits if 'en'.
  /// Example: 9000 -> "٩,٠٠٠" (ar) or "9,000" (en).
  static String formatCurrency(int amount, {bool? isArabic}) {
    final formatted = _thousands.format(amount);
    final useArabic = isArabic ?? (currentLocaleCode == 'ar');
    return useArabic ? formatted.toArabicDigits() : formatted;
  }

  /// Parses an Arabic or English digits string, removing commas and validating positive integer.
  /// Returns null if input is empty, invalid, or <= 0.
  static int? parsePositiveInteger(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;

    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (var i = 0; i < arabicDigits.length; i++) {
      s = s.replaceAll(arabicDigits[i], englishDigits[i]);
    }

    s = s.replaceAll(',', '').replaceAll('،', '');
    final val = int.tryParse(s);
    if (val != null && val > 0) {
      return val;
    }
    return null;
  }
}

/// Automatically formats numbers with comma separators as the user types:
/// e.g. 10000 -> 10,000, 1000000 -> 1,000,000.
/// Preserves cursor position correctly and converts Arabic-Indic digits (٠-٩) to ASCII digits.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // 1. Convert Arabic-Indic digits to ASCII 0-9
    var cleanText = newValue.text;
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (var i = 0; i < arabicDigits.length; i++) {
      cleanText = cleanText.replaceAll(arabicDigits[i], englishDigits[i]);
    }

    // 2. Count how many digits were before the cursor in newValue
    final selectionEnd = newValue.selection.end >= 0
        ? newValue.selection.end.clamp(0, newValue.text.length)
        : newValue.text.length;
    final textBeforeCursor = newValue.text.substring(0, selectionEnd);
    final digitsBeforeCursor =
        textBeforeCursor.replaceAll(RegExp(r'[^0-9٠-٩]'), '').length;

    // 3. Strip non-digits
    final digitsOnly = cleanText.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Prevent integer overflow on huge input (> 15 digits)
    final safeDigits =
        digitsOnly.length > 15 ? digitsOnly.substring(0, 15) : digitsOnly;
    final parsed = int.tryParse(safeDigits);
    if (parsed == null) {
      return oldValue;
    }

    // 4. Format with thousands commas
    final formatted = _formatter.format(parsed);

    // 5. Position cursor after digitsBeforeCursor
    var newCursorOffset = 0;
    var countedDigits = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (countedDigits >= digitsBeforeCursor) {
        break;
      }
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        countedDigits++;
      }
      newCursorOffset = i + 1;
    }

    if (newCursorOffset > formatted.length) {
      newCursorOffset = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }
}


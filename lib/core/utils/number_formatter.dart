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

  /// Formats an integer amount (in EGP) with thousands separators in Arabic-Indic digits.
  /// Example: 9000 -> "٩,٠٠٠", 10000 -> "١٠,٠٠٠", 150 -> "١٥٠"
  static String formatCurrency(int amount) {
    final formatted = _thousands.format(amount);
    return formatted.toArabicDigits();
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

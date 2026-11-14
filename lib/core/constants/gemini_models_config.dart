import 'package:flutter/foundation.dart';

/// Single configuration file for Gemini model fallback chain and request budget.
class GeminiModelsConfig {
  /// Ordered list of model IDs from AI Studio.
  /// 1. gemini-3.5-flash-lite (Daily limit 500)
  /// 2. gemini-3.8-flash (Daily limit 20)
  /// 3. gemini-3.6-flash (Daily limit 20)
  static const List<String> fallbackModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
    'gemini-3.6-flash',
  ];

  /// Total maximum delay allowed for Gemini across all fallback attempts (6 seconds).
  static const Duration maxTotalTimeout = Duration(seconds: 6);

  /// Cooldown duration for a model that returned 429 (10 minutes).
  static const Duration exhaustedCooldown = Duration(minutes: 10);

  /// User-facing daily notice text when fallback to local parser occurs.
  static const String fallbackNoticeText =
      'الصوت دلوقتي شغّال بالوضع العادي، ودقته أقل شوية';
}

/// In-memory manager for exhausted Gemini models.
/// A model returning 429 is marked exhausted for 10 minutes on that device and skipped.
class GeminiModelManager {
  static final Map<String, DateTime> _exhaustedUntil = {};

  /// Checks whether a model is currently exhausted.
  static bool isModelExhausted(String model, [DateTime? now]) {
    final expiry = _exhaustedUntil[model];
    if (expiry == null) return false;
    final current = now ?? DateTime.now();
    if (current.isAfter(expiry)) {
      _exhaustedUntil.remove(model);
      return false;
    }
    return true;
  }

  /// Marks a model as exhausted for [duration] (default 10 minutes).
  static void markExhausted(
    String model, {
    DateTime? now,
    Duration duration = GeminiModelsConfig.exhaustedCooldown,
  }) {
    final current = now ?? DateTime.now();
    _exhaustedUntil[model] = current.add(duration);
  }

  /// Clears in-memory exhaustion state (used for testing or device reset).
  static void clearExhausted() {
    _exhaustedUntil.clear();
  }

  /// Returns models that are not currently exhausted, preserving order.
  static List<String> getAvailableModels({
    List<String>? candidateModels,
    DateTime? now,
  }) {
    final list = candidateModels ?? GeminiModelsConfig.fallbackModels;
    return list.where((m) => !isModelExhausted(m, now)).toList();
  }

  @visibleForTesting
  static Map<String, DateTime> get exhaustedUntilMap =>
      Map.unmodifiable(_exhaustedUntil);
}


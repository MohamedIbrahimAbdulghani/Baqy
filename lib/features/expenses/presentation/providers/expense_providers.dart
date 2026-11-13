import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show TableUpdate;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/category_matcher.dart';
import '../../../../core/utils/goal_icon_helper.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../data/services/audio_recording_service.dart';
import '../../data/services/gemini_expense_parser.dart';
import '../../data/services/speech_recognition_service.dart';
import '../../domain/parser/egyptian_expense_parser.dart';
import '../../domain/models/category_item.dart';
import '../../domain/models/category_total.dart';
import '../../domain/models/month_remaining.dart';
import '../../domain/models/parsed_expense.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/repositories/expense_repository.dart';
import '../widgets/voice_expense_review_sheet.dart';
import '../../../goals/data/repositories/goal_repository_impl.dart';
import '../../../goals/domain/parser/egyptian_goal_parser.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../domain/usecases/add_category_usecase.dart';
import '../../domain/usecases/add_expense_usecase.dart';
import '../../domain/usecases/archive_category_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import '../../domain/usecases/get_category_totals_for_day_usecase.dart';
import '../../domain/usecases/get_category_totals_usecase.dart';
import '../../domain/usecases/get_category_transactions_for_day_usecase.dart';
import '../../domain/usecases/get_category_transactions_for_month_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_daily_transactions_usecase.dart';
import '../../domain/usecases/get_last_transactions_for_month_usecase.dart';
import '../../domain/usecases/get_last_transactions_usecase.dart';
import '../../domain/usecases/get_latest_expense_day_for_month_usecase.dart';
import '../../domain/usecases/get_month_budget_usecase.dart';
import '../../domain/usecases/get_month_remaining_usecase.dart';
import '../../domain/usecases/get_months_with_data_usecase.dart';
import '../../domain/usecases/get_years_with_data_usecase.dart';
import '../../domain/usecases/has_expenses_before_usecase.dart';
import '../../domain/usecases/restore_transaction_usecase.dart';
import '../../domain/usecases/save_user_rule_usecase.dart';
import '../../domain/usecases/set_month_budget_usecase.dart';
import '../../domain/usecases/update_category_usecase.dart';
import '../../domain/usecases/update_transaction_usecase.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ExpenseRepositoryImpl(db);
});

// Domain UseCases Providers
final getMonthRemainingUseCaseProvider = Provider<GetMonthRemainingUseCase>((
  ref,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetMonthRemainingUseCase(repo);
});

final getCategoryTotalsUseCaseProvider = Provider<GetCategoryTotalsUseCase>((
  ref,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetCategoryTotalsUseCase(repo);
});

final getCategoryTotalsForDayUseCaseProvider =
    Provider<GetCategoryTotalsForDayUseCase>((ref) {
      final repo = ref.watch(expenseRepositoryProvider);
      return GetCategoryTotalsForDayUseCase(repo);
    });

final getCategoryTransactionsForDayUseCaseProvider =
    Provider<GetCategoryTransactionsForDayUseCase>((ref) {
      final repo = ref.watch(expenseRepositoryProvider);
      return GetCategoryTransactionsForDayUseCase(repo);
    });

final getCategoryTransactionsForMonthUseCaseProvider =
    Provider<GetCategoryTransactionsForMonthUseCase>((ref) {
      final repo = ref.watch(expenseRepositoryProvider);
      return GetCategoryTransactionsForMonthUseCase(repo);
    });

final hasExpensesBeforeUseCaseProvider = Provider<HasExpensesBeforeUseCase>((
  ref,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  return HasExpensesBeforeUseCase(repo);
});

final getLatestExpenseDayForMonthUseCaseProvider =
    Provider<GetLatestExpenseDayForMonthUseCase>((ref) {
      final repo = ref.watch(expenseRepositoryProvider);
      return GetLatestExpenseDayForMonthUseCase(repo);
    });

final getLastTransactionsUseCaseProvider = Provider<GetLastTransactionsUseCase>(
  (ref) {
    final repo = ref.watch(expenseRepositoryProvider);
    return GetLastTransactionsUseCase(repo);
  },
);

final getLastTransactionsForMonthUseCaseProvider =
    Provider<GetLastTransactionsForMonthUseCase>((ref) {
      final repo = ref.watch(expenseRepositoryProvider);
      return GetLastTransactionsForMonthUseCase(repo);
    });

final getYearsWithDataUseCaseProvider = Provider<GetYearsWithDataUseCase>((
  ref,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetYearsWithDataUseCase(repo);
});

final getMonthsWithDataUseCaseProvider = Provider<GetMonthsWithDataUseCase>((
  ref,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetMonthsWithDataUseCase(repo);
});

final setMonthBudgetUseCaseProvider = Provider<SetMonthBudgetUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return SetMonthBudgetUseCase(repo);
});

final getMonthBudgetUseCaseProvider = Provider<GetMonthBudgetUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetMonthBudgetUseCase(repo);
});

final getDailyTransactionsUseCaseProvider =
    Provider<GetDailyTransactionsUseCase>((ref) {
      final repo = ref.watch(expenseRepositoryProvider);
      return GetDailyTransactionsUseCase(repo);
    });

final getCategoriesUseCaseProvider = Provider<GetCategoriesUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetCategoriesUseCase(repo);
});

final addCategoryUseCaseProvider = Provider<AddCategoryUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return AddCategoryUseCase(repo);
});

final updateCategoryUseCaseProvider = Provider<UpdateCategoryUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return UpdateCategoryUseCase(repo);
});

final addExpenseUseCaseProvider = Provider<AddExpenseUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return AddExpenseUseCase(repo);
});

final updateTransactionUseCaseProvider =
    Provider<UpdateTransactionUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return UpdateTransactionUseCase(repo);
});

final deleteTransactionUseCaseProvider =
    Provider<DeleteTransactionUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return DeleteTransactionUseCase(repo);
});

final restoreTransactionUseCaseProvider =
    Provider<RestoreTransactionUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return RestoreTransactionUseCase(repo);
});

final archiveCategoryUseCaseProvider = Provider<ArchiveCategoryUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return ArchiveCategoryUseCase(repo);
});

final saveUserRuleUseCaseProvider = Provider<SaveUserRuleUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return SaveUserRuleUseCase(repo);
});

/// Emits whenever any database table is modified (reactive trigger)
final databaseChangesProvider = StreamProvider.autoDispose<Set<TableUpdate>>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.tableUpdates();
});

/// List of all categories from DB (reactively updates on table changes)
final categoriesProvider = FutureProvider.autoDispose<List<CategoryItem>>((
  ref,
) async {
  ref.watch(databaseChangesProvider);
  final sw = Stopwatch()..start();
  final useCase = ref.watch(getCategoriesUseCaseProvider);
  final result = await useCase().timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw TimeoutException('انتهت مهلة تحميل التصنيفات'),
  );
  if (kDebugMode) {
    debugPrint('[PROVIDER_DEBUG] categoriesProvider: resolved ${result.length} categories in ${sw.elapsedMilliseconds}ms');
  }
  return result;
});

// Presentation State Providers

/// Notifier for the currently selected month in format "YYYY-MM" (e.g. "2026-11")
class SelectedYearMonthNotifier extends Notifier<String> {
  @override
  String build() {
    final now = DateTime.now();
    final ym = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
    if (kDebugMode) {
      debugPrint('[PROVIDER_DEBUG] SelectedYearMonthNotifier: initial state $ym');
    }
    return ym;
  }

  void selectYearMonth(String yearMonth) {
    if (kDebugMode) {
      debugPrint('[PROVIDER_DEBUG] SelectedYearMonthNotifier: switched to $yearMonth');
    }
    state = yearMonth;
  }
}

final selectedYearMonthProvider =
    NotifierProvider<SelectedYearMonthNotifier, String>(
      SelectedYearMonthNotifier.new,
    );

/// Month remaining calculation (budget, expenses, income, remaining) for the selected month
final currentMonthRemainingProvider =
    FutureProvider.autoDispose<MonthRemaining>((ref) async {
      ref.watch(databaseChangesProvider);
      final yearMonth = ref.watch(selectedYearMonthProvider);
      final sw = Stopwatch()..start();
      if (kDebugMode) {
        debugPrint('[PROVIDER_DEBUG] currentMonthRemainingProvider: starting fetch for $yearMonth');
      }
      final useCase = ref.watch(getMonthRemainingUseCaseProvider);
      final result = await useCase(yearMonth).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('انتهت مهلة تحميل بيانات ميزانية الشهر ($yearMonth)'),
      );
      if (kDebugMode) {
        debugPrint('[PROVIDER_DEBUG] currentMonthRemainingProvider: resolved in ${sw.elapsedMilliseconds}ms: remaining=${result.remaining}, budget=${result.budget}, expenses=${result.expenses}');
      }
      return result;
    });

/// Last 3 transactions for the currently selected month
final recentTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionItem>>((ref) async {
      ref.watch(databaseChangesProvider);
      final yearMonth = ref.watch(selectedYearMonthProvider);
      final sw = Stopwatch()..start();
      if (kDebugMode) {
        debugPrint('[PROVIDER_DEBUG] recentTransactionsProvider: starting fetch for $yearMonth');
      }
      final useCase = ref.watch(getLastTransactionsForMonthUseCaseProvider);
      final result = await useCase(yearMonth, limit: 3).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('انتهت مهلة تحميل آخر المعاملات'),
      );
      if (kDebugMode) {
        debugPrint('[PROVIDER_DEBUG] recentTransactionsProvider: resolved ${result.length} transactions in ${sw.elapsedMilliseconds}ms');
      }
      return result;
    });

/// Ascending list of years that have data plus the current year
final yearsWithDataProvider = FutureProvider.autoDispose<List<int>>((
  ref,
) async {
  ref.watch(databaseChangesProvider);
  final sw = Stopwatch()..start();
  final useCase = ref.watch(getYearsWithDataUseCaseProvider);
  final result = await useCase().timeout(
    const Duration(seconds: 10),
    onTimeout: () => [DateTime.now().year],
  );
  if (kDebugMode) {
    debugPrint('[PROVIDER_DEBUG] yearsWithDataProvider: resolved years $result in ${sw.elapsedMilliseconds}ms');
  }
  return result;
});

/// Set of month numbers (1..12) that have transactions or budgets in the specified year
final monthsWithDataProvider = FutureProvider.autoDispose.family<Set<int>, int>(
  (ref, year) async {
    ref.watch(databaseChangesProvider);
    final sw = Stopwatch()..start();
    final useCase = ref.watch(getMonthsWithDataUseCaseProvider);
    final result = await useCase(year).timeout(
      const Duration(seconds: 10),
      onTimeout: () => {DateTime.now().month},
    );
    if (kDebugMode) {
      debugPrint('[PROVIDER_DEBUG] monthsWithDataProvider: resolved months $result for year $year in ${sw.elapsedMilliseconds}ms');
    }
    return result;
  },
);

/// Category totals for a specific month (for Month Details bar chart)
final monthCategoryTotalsProvider = FutureProvider.autoDispose
    .family<List<CategoryTotal>, String>((ref, yearMonth) async {
      ref.watch(databaseChangesProvider);
      final useCase = ref.watch(getCategoryTotalsUseCaseProvider);
      return useCase(yearMonth);
    });

/// Category totals for a specific calendar day (for Month Details day list)
final dayCategoryTotalsProvider = FutureProvider.autoDispose
    .family<List<CategoryTotal>, DateTime>((ref, day) async {
      ref.watch(databaseChangesProvider);
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final useCase = ref.watch(getCategoryTotalsForDayUseCaseProvider);
      return useCase(normalizedDay);
    });

/// Whether any expenses exist prior to the given day
final hasExpensesBeforeProvider = FutureProvider.autoDispose
    .family<bool, DateTime>((ref, day) async {
      ref.watch(databaseChangesProvider);
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final useCase = ref.watch(hasExpensesBeforeUseCaseProvider);
      return useCase(normalizedDay);
    });

/// Transactions for a category on a specific day (for Category Details)
final categoryTransactionsForDayProvider = FutureProvider.autoDispose
    .family<List<TransactionItem>, ({int categoryId, DateTime day})>((
      ref,
      arg,
    ) async {
      ref.watch(databaseChangesProvider);
      final normalizedDay = DateTime(arg.day.year, arg.day.month, arg.day.day);
      final useCase = ref.watch(getCategoryTransactionsForDayUseCaseProvider);
      return useCase(categoryId: arg.categoryId, day: normalizedDay);
    });

/// Transactions for a category in a specific month (for Category Details)
final categoryTransactionsForMonthProvider = FutureProvider.autoDispose
    .family<List<TransactionItem>, ({int categoryId, String yearMonth})>((
      ref,
      arg,
    ) async {
      ref.watch(databaseChangesProvider);
      final useCase = ref.watch(getCategoryTransactionsForMonthUseCaseProvider);
      return useCase(categoryId: arg.categoryId, yearMonth: arg.yearMonth);
    });

/// Latest expense day for a month
final latestExpenseDayForMonthProvider = FutureProvider.autoDispose
    .family<DateTime?, String>((ref, yearMonth) async {
      ref.watch(databaseChangesProvider);
      final useCase = ref.watch(getLatestExpenseDayForMonthUseCaseProvider);
      return useCase(yearMonth);
    });

/// Total expenses for a specific category in a month in integer piastres
final categoryTotalForMonthProvider = FutureProvider.autoDispose
    .family<int, ({int categoryId, String yearMonth})>((ref, arg) async {
      ref.watch(databaseChangesProvider);
      final repo = ref.watch(expenseRepositoryProvider);
      final totals = await repo.getTotalsPerCategoryPerMonth(arg.yearMonth);
      final match = totals
          .where((c) => c.category.id == arg.categoryId)
          .firstOrNull;
      return match?.totalAmount ?? 0;
    });

/// Total expenses for a specific category on a specific day in integer piastres
final categoryTotalForDayProvider = FutureProvider.autoDispose
    .family<int, ({int categoryId, DateTime day})>((ref, arg) async {
      ref.watch(databaseChangesProvider);
      final repo = ref.watch(expenseRepositoryProvider);
      final normalizedDay = DateTime(arg.day.year, arg.day.month, arg.day.day);
      final totals = await repo.getCategoryTotalsForDay(normalizedDay);
      final match = totals
          .where((c) => c.category.id == arg.categoryId)
          .firstOrNull;
      return match?.totalAmount ?? 0;
    });

/// Tracks which months have already triggered the automatic budget sheet during this session
class HasAutoOpenedBudgetNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void markOpened(String yearMonth) {
    state = {...state, yearMonth};
  }
}

final hasAutoOpenedBudgetForMonthProvider =
    NotifierProvider<HasAutoOpenedBudgetNotifier, Set<String>>(
      HasAutoOpenedBudgetNotifier.new,
    );

// Voice Recognition & Parsing Providers

final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>((
  ref,
) {
  return SpeechToTextServiceImpl();
});

class LiveVoiceTextNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setText(String text) {
    state = text;
  }

  void clear() {
    state = '';
  }
}

final liveVoiceTextProvider = NotifierProvider<LiveVoiceTextNotifier, String>(
  LiveVoiceTextNotifier.new,
);

// Audio Recording & Parsing Providers

final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = RecordAudioRecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});

class VoiceAmplitudeNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
  void setVal(double v) => state = v;
}

class VoiceRecordingDurationNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setVal(int v) => state = v;
  void increment() => state++;
}

class VoiceIsAnalyzingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setVal(bool v) => state = v;
}

class PendingVoiceAudioPathNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setVal(String? v) => state = v;
}

final voiceAmplitudeProvider =
    NotifierProvider<VoiceAmplitudeNotifier, double>(
  VoiceAmplitudeNotifier.new,
);

final voiceRecordingDurationProvider =
    NotifierProvider<VoiceRecordingDurationNotifier, int>(
  VoiceRecordingDurationNotifier.new,
);

final voiceIsAnalyzingProvider =
    NotifierProvider<VoiceIsAnalyzingNotifier, bool>(
  VoiceIsAnalyzingNotifier.new,
);

final pendingVoiceAudioPathProvider =
    NotifierProvider<PendingVoiceAudioPathNotifier, String?>(
  PendingVoiceAudioPathNotifier.new,
);

/// Handles local persistence of pending unsaved voice recording path
class PendingRecordingStorage {
  static Future<File> _getFile() async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/baqy_pending_audio_path.txt');
  }

  static Future<void> save(String path) async {
    try {
      final f = await _getFile();
      await f.writeAsString(path);
    } catch (_) {}
  }

  static Future<String?> load() async {
    try {
      final f = await _getFile();
      if (await f.exists()) {
        final path = (await f.readAsString()).trim();
        if (path.isNotEmpty && await File(path).exists()) {
          return path;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clear() async {
    try {
      final f = await _getFile();
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }
}

enum VoiceRecordingMode { expense, goal }

class VoiceRecordingNotifier extends Notifier<bool> {
  AudioRecordingService? _audioService;
  SpeechRecognitionService? _speechService;
  Timer? _durationTimer;
  Timer? _maxDurationTimer;
  StreamSubscription<double>? _amplitudeSubscription;
  BuildContext? _currentContext;
  AppLifecycleListener? _lifecycleListener;

  VoiceRecordingMode _mode = VoiceRecordingMode.expense;
  VoiceRecordingMode get mode => _mode;

  // Multi-session text buffers & committed text across sessions
  String _committedText = '';
  String _currentPartialText = '';
  final int _sessionCount = 0;

  /// Public getters for committed text across all sessions
  String get committedText => _committedText;
  String get currentPartialText => _currentPartialText;
  int get sessionCount => _sessionCount;

  @override
  bool build() {
    _audioService = ref.watch(audioRecordingServiceProvider);
    _speechService = ref.watch(speechRecognitionServiceProvider);

    _lifecycleListener = AppLifecycleListener(
      onPause: () {
        if (state) {
          if (kDebugMode) {
            debugPrint(
              '[AUDIO_DEBUG] App went to background/paused. Stopping recording safely and preserving file.',
            );
          }
          stopRecording();
        }
      },
    );

    // Check for any pending unsaved recording upon initialization
    _checkPendingAudio();

    ref.onDispose(() {
      _lifecycleListener?.dispose();
      _durationTimer?.cancel();
      _maxDurationTimer?.cancel();
      _amplitudeSubscription?.cancel();
      _speechService?.cancel();
    });
    return false;
  }

  Future<void> _checkPendingAudio() async {
    try {
      final pending = await PendingRecordingStorage.load();
      if (pending != null) {
        ref.read(pendingVoiceAudioPathProvider.notifier).setVal(pending);
      }
    } catch (_) {}
  }

  /// Pre-initializes permissions and warms up Gemini connection
  Future<void> preInitialize({bool onlyIfPermissionGranted = false}) async {
    final service = _audioService;
    if (service == null) return;
    try {
      await service.hasPermission();
      ref.read(geminiExpenseParserProvider).warmUp();
    } catch (_) {}
  }

  Future<void> startRecording({
    required BuildContext context,
    VoiceRecordingMode mode = VoiceRecordingMode.expense,
  }) async {
    if (state) return;
    final service = _audioService;
    if (service == null) return;

    _mode = mode;
    _currentContext = context;
    _committedText = '';
    _currentPartialText = '';

    final hasPerm = await service.hasPermission();
    if (!hasPerm) {
      if (context.mounted) {
        _showVoiceFeedbackSnackBar(
          context: context,
          message: mode == VoiceRecordingMode.goal
              ? 'يرجى تفعيل إذن الميكروفون من الإعدادات لتسجيل الأهداف'
              : 'يرجى تفعيل إذن الميكروفون من الإعدادات لتسجيل المصاريف',
        );
      }
      return;
    }

    // Light haptic feedback on start
    HapticFeedback.lightImpact();

    // Keep screen awake
    unawaited(WakelockPlus.enable().catchError((_) {}));

    // Reset duration
    ref.read(voiceRecordingDurationProvider.notifier).setVal(0);
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state) {
        ref.read(voiceRecordingDurationProvider.notifier).increment();
      }
    });

    // Subscribe to amplitude
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = service.amplitudeStream.listen((amp) {
      ref.read(voiceAmplitudeProvider.notifier).setVal(amp);
    });

    // Only invoke fake speech service in mock/unit test environments
    if (_speechService != null && _speechService is! SpeechToTextServiceImpl) {
      try {
        await _speechService!.listen(
          onResult: (words, {bool isFinal = false}) {
            if (isFinal) {
              if (_committedText.isEmpty) {
                _committedText = words;
              } else {
                _committedText += ' $words';
              }
              _currentPartialText = '';
            } else {
              _currentPartialText = words;
            }
          },
        );
      } catch (_) {}
    }

    final path = await service.startRecording(
      onSafetyWarning: () {
        final ctx = _currentContext;
        if (ctx != null && ctx.mounted) {
          _showVoiceFeedbackSnackBar(
            context: ctx,
            message: 'تنبيه: أوشك التسجيل على بلوغ الحد الأقصى (15 دقيقة)',
          );
        }
      },
      onMaxDurationReached: (filePath) {
        stopRecording(context: _currentContext);
      },
    );

    if (path == null) {
      _durationTimer?.cancel();
      _amplitudeSubscription?.cancel();
      unawaited(WakelockPlus.disable().catchError((_) {}));
      if (context.mounted) {
        _showVoiceFeedbackSnackBar(
          context: context,
          message: 'تعذر بدء التسجيل، يرجى المحاولة مرة أخرى',
        );
      }
      return;
    }

    // State becomes true only when really listening (readiness handling)
    state = true;
  }

  Future<void> stopRecording({BuildContext? context}) async {
    if (!state) return;
    final totalSw = Stopwatch()..start();
    final activeContext = context ?? _currentContext;
    final messenger = (activeContext != null && activeContext.mounted)
        ? ScaffoldMessenger.maybeOf(activeContext)
        : null;

    // Light haptic feedback on stop
    HapticFeedback.lightImpact();

    // Disable wakelock
    unawaited(WakelockPlus.disable().catchError((_) {}));

    _durationTimer?.cancel();
    _amplitudeSubscription?.cancel();
    if (_speechService != null && _speechService is! SpeechToTextServiceImpl) {
      try {
        await _speechService!
            .stop()
            .timeout(const Duration(milliseconds: 300), onTimeout: () {});
      } catch (_) {}
    }
    ref.read(voiceAmplitudeProvider.notifier).setVal(0.0);
    state = false;

    final service = _audioService;
    final isFakeTest =
        _speechService != null && _speechService is! SpeechToTextServiceImpl;
    if (service == null && !isFakeTest) return;

    String? savedPath;
    if (service != null) {
      savedPath = await service.stopRecording();
    }
    final stopToRecognizeMs = totalSw.elapsedMilliseconds;
    final capturedSpeech = '$_committedText $_currentPartialText'.trim();
    // Buffers cleared at end of session
    _committedText = '';
    _currentPartialText = '';

    if (_mode == VoiceRecordingMode.goal) {
      await _processGoalVoice(
        savedPath: savedPath,
        fallbackSpeechText: capturedSpeech,
        context: (activeContext != null && activeContext.mounted)
            ? activeContext
            : null,
        messenger: messenger,
        totalSw: totalSw,
        stopToRecognizeMs: stopToRecognizeMs,
      );
      return;
    }

    if (savedPath == null) {
      if (activeContext != null && activeContext.mounted) {
        _showVoiceFeedbackSnackBar(
          context: activeContext,
          message: 'ما سمعتش حاجة، جرّب تاني',
        );
      }
      return;
    }

    final file = File(savedPath);
    if (!await file.exists() || await file.length() < 100) {
      if (activeContext != null && activeContext.mounted) {
        _showVoiceFeedbackSnackBar(
          context: activeContext,
          message: 'التسجيل فارغ، جرّب تاني',
        );
      }
      return;
    }

    // Persist pending audio path before processing (Data Safety: never lose recording)
    await PendingRecordingStorage.save(savedPath);
    ref.read(pendingVoiceAudioPathProvider.notifier).setVal(savedPath);

    // Immediate success feedback
    if (activeContext != null && activeContext.mounted) {
      _showVoiceFeedbackSnackBar(
        context: activeContext,
        message: 'تم التسجيل ✓',
      );
    }

    // Process audio file with Gemini
    await processAudioFile(
      savedPath,
      fallbackSpeechText: capturedSpeech,
      context: (activeContext != null && activeContext.mounted)
          ? activeContext
          : null,
      totalSw: totalSw,
      stopToRecognizeMs: stopToRecognizeMs,
    );
  }

  Future<void> _processGoalVoice({
    String? savedPath,
    required String fallbackSpeechText,
    BuildContext? context,
    ScaffoldMessengerState? messenger,
    Stopwatch? totalSw,
    int stopToRecognizeMs = 0,
  }) async {
    final activeContext = context ?? _currentContext;
    final activeMessenger = messenger ??
        (activeContext != null && activeContext.mounted
            ? ScaffoldMessenger.maybeOf(activeContext)
            : null);
    ref.read(voiceIsAnalyzingProvider.notifier).setVal(true);

    ParsedGoalResult? goalResult;
    int geminiRequestMs = 0;
    final geminiSw = Stopwatch()..start();

    final isFakeTest =
        _speechService != null && _speechService is! SpeechToTextServiceImpl;

    // 1. Try Gemini Audio Parser if file exists and has content
    if (!isFakeTest && savedPath != null) {
      final file = File(savedPath);
      if (await file.exists() && await file.length() >= 100) {
        final parser = ref.read(geminiExpenseParserProvider);
        if (parser.apiKey != null && parser.apiKey!.isNotEmpty) {
          try {
            final result = await parser.parseGoalAudio(file);
            geminiRequestMs = geminiSw.elapsedMilliseconds;
            if (result != null && result.targetAmountEgp > 0) {
              goalResult = ParsedGoalResult(
                name: GoalRepositoryImpl.sanitizeName(result.goalName),
                targetAmount: result.targetAmountEgp,
                icon: GoalIconHelper.validateOrResolve(
                  result.icon,
                  goalName: result.goalName,
                ),
              );
            }
          } catch (_) {}
        }
      }
    }
    if (geminiRequestMs == 0) geminiRequestMs = geminiSw.elapsedMilliseconds;

    // 2. Fallback to speech recognition text if Gemini didn't find goal
    if (goalResult == null && fallbackSpeechText.isNotEmpty) {
      goalResult = EgyptianGoalParser.parse(fallbackSpeechText);
    }

    ref.read(voiceIsAnalyzingProvider.notifier).setVal(false);

    // Clean up temporary audio file immediately (never log or save spoken sentence)
    if (savedPath != null) {
      try {
        final f = File(savedPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      await PendingRecordingStorage.clear();
      ref.read(pendingVoiceAudioPathProvider.notifier).setVal(null);
    }

    // Validation: If no amount found, save nothing and show snackbar above button
    if (goalResult == null || goalResult.targetAmount <= 0) {
      _showVoiceFeedbackSnackBar(
        context: activeContext,
        messenger: activeMessenger,
        message: 'ماسمعتش مبلغ، جرّب تاني',
      );
      return;
    }

    // Save goal with target in piastres (never log or save spoken sentence)
    final saveSw = Stopwatch()..start();
    try {
      await ref.read(goalRepositoryProvider).addGoal(
            name: goalResult.name,
            targetAmount: goalResult.targetAmount * 100,
            icon: goalResult.icon,
          );
    } catch (_) {}
    final parseAndSaveMs = saveSw.elapsedMilliseconds;
    final totalMs = totalSw?.elapsedMilliseconds ??
        (stopToRecognizeMs + geminiRequestMs + parseAndSaveMs);

    if (kDebugMode) {
      debugPrint(
        '[VOICE_METRICS] stop_to_recognize: ${stopToRecognizeMs}ms, gemini_request: ${geminiRequestMs}ms, parse_and_save: ${parseAndSaveMs}ms, total: ${totalMs}ms',
      );
    }
  }

  Future<void> processAudioFile(
    String audioPath, {
    String? fallbackSpeechText,
    BuildContext? context,
    Stopwatch? totalSw,
    int stopToRecognizeMs = 0,
  }) async {
    final activeContext = context ?? _currentContext;

    // Show analyzing state
    ref.read(voiceIsAnalyzingProvider.notifier).setVal(true);

    final parser = ref.read(geminiExpenseParserProvider);
    final key = parser.apiKey;
    if (key == null || key.isEmpty) {
      ref.read(voiceIsAnalyzingProvider.notifier).setVal(false);
      if (activeContext != null && activeContext.mounted) {
        _showConfigErrorDialog(
          context: activeContext,
          message:
              'مفتاح GEMINI_API_KEY غير موجود في ملف .env أو إعدادات التطبيق. يرجى إضافته لمعالجة الصوت بالذكاء الاصطناعي.',
          onManual: () {
            activeContext.push('/add-expense');
          },
        );
      }
      return;
    }

    final categories = await ref.read(getCategoriesUseCaseProvider)();
    final userRules =
        await ref.read(saveUserRuleUseCaseProvider).getRecentRules(limit: 50);

    AudioParseResult? result;
    int geminiRequestMs = 0;
    final geminiSw = Stopwatch()..start();
    try {
      result = await parser.parseAudio(
        File(audioPath),
        categories: categories,
        userRules: userRules,
      );
      geminiRequestMs = geminiSw.elapsedMilliseconds;
    } catch (e) {
      geminiRequestMs = geminiSw.elapsedMilliseconds;
      if (kDebugMode) {
        debugPrint('[AUDIO_DEBUG] Exception in processAudioFile: $e');
      }
    }

    // Fallback to local parser if Gemini failed or timed out (never calls network)
    if (result == null && fallbackSpeechText != null && fallbackSpeechText.isNotEmpty) {
      final localOps = EgyptianExpenseParser.parse(
        fallbackSpeechText,
        customCategories: categories.map((c) => c.name).toList(),
        userRules: userRules,
      );
      if (localOps.isNotEmpty) {
        result = AudioParseResult(
          transcript: fallbackSpeechText,
          operations: localOps,
        );
      }
    }

    ref.read(voiceIsAnalyzingProvider.notifier).setVal(false);

    if (result == null) {
      // Failed (network / timeout / server error): Do NOT delete audio file!
      final errorReason = parser.lastErrorMessage;
      if (activeContext != null && activeContext.mounted) {
        _showErrorRetryDialog(
          context: activeContext,
          message: errorReason,
          onRetry: () => processAudioFile(
            audioPath,
            fallbackSpeechText: fallbackSpeechText,
            context: activeContext,
          ),
          onManual: () {
            activeContext.push('/add-expense');
          },
        );
      }
      return;
    }

    if (result.operations.isEmpty) {
      if (activeContext != null && activeContext.mounted) {
        _showVoiceFeedbackSnackBar(
          context: activeContext,
          message: 'ماسمعتش مبالغ في التسجيل، جرّب تاني',
        );
      }
      return;
    }

    final skipReview = ref.read(skipVoiceReviewProvider);

    final saveSw = Stopwatch()..start();
    if (skipReview || activeContext == null || !activeContext.mounted) {
      await _saveExpenses(expenses: result.operations, categories: categories);
      await _deleteAudioAfterSuccess(audioPath);
    } else {
      await VoiceExpenseReviewSheet.show(
        context: activeContext,
        initialExpenses: result.operations,
        categories: categories,
        transcript: result.transcript,
        onSave: (reviewedExpenses) async {
          await _saveExpenses(expenses: reviewedExpenses, categories: categories);
          await _deleteAudioAfterSuccess(audioPath);
        },
      );
    }
    final parseAndSaveMs = saveSw.elapsedMilliseconds;
    final totalMs = totalSw?.elapsedMilliseconds ??
        (stopToRecognizeMs + geminiRequestMs + parseAndSaveMs);

    if (kDebugMode) {
      debugPrint(
        '[VOICE_METRICS] stop_to_recognize: ${stopToRecognizeMs}ms, gemini_request: ${geminiRequestMs}ms, parse_and_save: ${parseAndSaveMs}ms, total: ${totalMs}ms',
      );
    }
  }

  Future<void> _deleteAudioAfterSuccess(String audioPath) async {
    try {
      final f = File(audioPath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    await PendingRecordingStorage.clear();
    ref.read(pendingVoiceAudioPathProvider.notifier).setVal(null);
  }

  Future<void> discardPendingAudio() async {
    final current = ref.read(pendingVoiceAudioPathProvider);
    if (current != null) {
      try {
        final f = File(current);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    await PendingRecordingStorage.clear();
    ref.read(pendingVoiceAudioPathProvider.notifier).setVal(null);
  }

  void _showErrorRetryDialog({
    required BuildContext context,
    required String message,
    required VoidCallback onRetry,
    required VoidCallback onManual,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.card,
          title: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text(
                'تعذر الاتصال',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onManual();
              },
              child: const Text(
                'إضافة يدوي',
                style: TextStyle(fontFamily: AppTheme.fontFamily),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigErrorDialog({
    required BuildContext context,
    required String message,
    required VoidCallback onManual,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.card,
          title: const Row(
            children: [
              Icon(Icons.key_off_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'إعدادات الذكاء الاصطناعي',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'إغلاق',
                style: TextStyle(fontFamily: AppTheme.fontFamily),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onManual();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'إضافة يدوي',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Backward compatibility static helpers
  static String mergeVoiceSessions(List<String> sessions) {
    String result = '';
    for (final s in sessions) {
      result = mergeCommittedWithNew(result, s);
    }
    return result;
  }

  static String mergeCommittedWithNew(String committed, String newText) {
    final cTrim = committed.trim();
    final nTrim = newText.trim();

    if (cTrim.isEmpty) return nTrim;
    if (nTrim.isEmpty) return cTrim;
    if (cTrim == nTrim) return cTrim;
    if (cTrim.endsWith(nTrim)) return cTrim;
    if (nTrim.startsWith(cTrim)) return nTrim;

    final cWords = cTrim.split(RegExp(r'\s+'));
    final nWords = nTrim.split(RegExp(r'\s+'));
    final maxOverlap = cWords.length < nWords.length ? cWords.length : nWords.length;

    int overlapCount = 0;
    for (int k = maxOverlap; k >= 1; k--) {
      final cSuffix = cWords.sublist(cWords.length - k).join(' ');
      final nPrefix = nWords.sublist(0, k).join(' ');
      if (cSuffix == nPrefix) {
        overlapCount = k;
        break;
      }
    }

    if (overlapCount > 0) {
      final remaining = nWords.sublist(overlapCount).join(' ');
      if (remaining.isEmpty) {
        return cTrim;
      }
      return '$cTrim $remaining';
    }

    return '$cTrim $nTrim';
  }

  Future<void> _saveExpenses({
    required List<ParsedExpense> expenses,
    required List<CategoryItem> categories,
  }) async {
    final addExpense = ref.read(addExpenseUseCaseProvider);
    final addCategory = ref.read(addCategoryUseCaseProvider);
    final now = DateTime.now().toUtc();

    // Clear committed accumulator after save
    _committedText = '';
    _currentPartialText = '';

    var currentCategories = List<CategoryItem>.from(categories);

    for (final exp in expenses) {
      if (exp.amount == null || exp.amount! <= 0) continue;

      // Handle category matching with normalization and canonical synonyms
      CategoryItem matchedCategory = CategoryMatcher.matchItem(
        categoryName: exp.category,
        categories: currentCategories,
      );

      if (exp.isNewCategory) {
        final propName = exp.newCategoryProposal?.name ?? exp.category;
        final propIcon = exp.newCategoryProposal?.icon ?? 'label';
        final propColor = exp.newCategoryProposal?.color ?? '#2ECC71';

        final existingCat = currentCategories.where(
          (c) =>
              CategoryMatcher.normalize(c.name) ==
              CategoryMatcher.normalize(propName),
        ).firstOrNull;

        if (existingCat != null) {
          matchedCategory = existingCat;
        } else {
          try {
            final newId = await addCategory(
              name: propName,
              icon: propIcon,
              color: propColor,
              createdByAi: true,
            );
            matchedCategory = CategoryItem(
              id: newId,
              name: propName,
              icon: propIcon,
              color: propColor,
              createdByAi: true,
            );
            currentCategories.add(matchedCategory);
          } catch (_) {}
        }
      }

      await addExpense(
        amountInPiastres: exp.amountInPiastres,
        description: exp.description,
        categoryId: matchedCategory.id,
        source: 'voice',
        note: exp.note,
        foreignAmount: exp.foreignAmount,
        foreignCurrency: exp.foreignCurrency,
        createdAt: now,
      );
    }

    // Refresh Home data
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(currentMonthRemainingProvider);
    ref.invalidate(yearsWithDataProvider);
    ref.invalidate(monthsWithDataProvider(now.year));
    final currentYm = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
    ref.invalidate(monthCategoryTotalsProvider(currentYm));
    ref.invalidate(categoriesProvider);
  }

  void _showVoiceFeedbackSnackBar({
    BuildContext? context,
    ScaffoldMessengerState? messenger,
    required String message,
  }) {
    final target = messenger ??
        (context != null && context.mounted
            ? ScaffoldMessenger.maybeOf(context)
            : null);
    if (target == null) return;
    target.hideCurrentSnackBar();
    target.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 84.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

final geminiExpenseParserProvider = Provider<GeminiExpenseParser>((ref) {
  return GeminiExpenseParser();
});

final skipVoiceReviewProvider = Provider<bool>((ref) => false);

final voiceRecordingProvider = NotifierProvider<VoiceRecordingNotifier, bool>(
  VoiceRecordingNotifier.new,
);

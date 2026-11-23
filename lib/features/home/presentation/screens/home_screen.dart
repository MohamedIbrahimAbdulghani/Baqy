import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/action_feedback_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../expenses/domain/models/month_remaining.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../expenses/presentation/widgets/month_rollover_dialog.dart';
import '../controllers/budget_monitor_controller.dart';
import '../widgets/budget_bottom_sheet.dart';
import '../widgets/budget_ring.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/month_selector_popup.dart';
import '../widgets/recent_transactions_section.dart';
import '../../../../core/theme/theme_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isMonthPopupOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(voiceRecordingProvider.notifier)
            .preInitialize(onlyIfPermissionGranted: true);
      }
    });
  }

  bool _isCheckingMonthTransition = false;

  void _checkMonthTransition(
    String yearMonth,
    int monthNumber,
    MonthRemaining remaining,
  ) {
    if (_isCheckingMonthTransition) return;
    if (ref.read(activeUserIdProvider) == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || ref.read(activeUserIdProvider) == null) return;
      _isCheckingMonthTransition = true;
      try {
        // 1. Check and prompt rollover if previous month had remaining money
        await MonthRolloverHelper.checkAndPromptRollover(
          context: context,
          ref: ref,
          currentYearMonth: yearMonth,
        );

        // 2. Check if current active month needs budget set AFTER rollover completes
        if (mounted && ref.read(activeUserIdProvider) != null) {
          final updatedRemaining = await ref
              .read(getMonthRemainingUseCaseProvider)(yearMonth);
          _checkAutoOpenBudget(yearMonth, monthNumber, updatedRemaining);
        }
      } finally {
        _isCheckingMonthTransition = false;
      }
    });
  }

  void _checkAutoOpenBudget(
    String yearMonth,
    int monthNumber,
    MonthRemaining remaining,
  ) {
    // Never auto-open budget if user is not signed in / logging out
    if (ref.read(activeUserIdProvider) == null) return;

    final now = DateTime.now();
    final currentYm = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
    // Only auto-open for the current ongoing month, never past months
    if (yearMonth != currentYm) return;

    if (remaining.budget <= 0) {
      final promptedMonths = ref.read(hasAutoOpenedBudgetForMonthProvider);
      if (!promptedMonths.contains(yearMonth)) {
        if (mounted && ref.read(activeUserIdProvider) != null) {
          final currentPrompted = ref.read(
            hasAutoOpenedBudgetForMonthProvider,
          );
          if (!currentPrompted.contains(yearMonth)) {
            ref
                .read(hasAutoOpenedBudgetForMonthProvider.notifier)
                .markOpened(yearMonth);
            _openBudgetSheet(yearMonth, monthNumber, 0);
          }
        }
      }
    }
  }

  Future<void> _openBudgetSheet(
    String yearMonth,
    int monthNumber,
    int currentBudgetPiastres,
  ) async {
    if (!mounted || ref.read(activeUserIdProvider) == null) return;

    final now = DateTime.now();
    final currentYm = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
    if (yearMonth.compareTo(currentYm) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هذا الشهر مؤرشف للاطلاع فقط ولا يمكن تعديل ميزانيته.',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: AppTheme.fontFamily),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Prompt rollover if pending for this month before setting budget
    await MonthRolloverHelper.checkAndPromptRollover(
      context: context,
      ref: ref,
      currentYearMonth: yearMonth,
    );
    if (!mounted || ref.read(activeUserIdProvider) == null) return;

    int? initialBudgetEgp;

    if (currentBudgetPiastres > 0) {
      initialBudgetEgp = currentBudgetPiastres ~/ 100;
    } else {
      // At the start of a new month, pre-fill with last month's budget
      final prevYm = ArabicDateHelper.getPreviousYearMonth(yearMonth);
      final prevBudgetPiastres = await ref.read(getMonthBudgetUseCaseProvider)(
        prevYm,
      );
      if (prevBudgetPiastres != null && prevBudgetPiastres > 0) {
        initialBudgetEgp = prevBudgetPiastres ~/ 100;
      }
    }

    if (!mounted || ref.read(activeUserIdProvider) == null) return;

    int? savedBudgetPiastres;
    await BudgetBottomSheet.show(
      context: context,
      monthNumber: monthNumber,
      initialBudgetEgp: initialBudgetEgp,
      onSave: (budgetPiastres) async {
        await ref.read(setMonthBudgetUseCaseProvider)(
          yearMonth: yearMonth,
          amount: budgetPiastres,
        );
        savedBudgetPiastres = budgetPiastres;
        final userId = ref.read(activeUserIdProvider);
        await BudgetMonitorController.resetAlertFlag(yearMonth, userId: userId);
        ref.invalidate(currentMonthRemainingProvider);
        ref.invalidate(yearsWithDataProvider);
        final (year, _) = ArabicDateHelper.parseYearMonthKey(yearMonth);
        ref.invalidate(monthsWithDataProvider(year));
      },
    );

    if (savedBudgetPiastres != null && mounted) {
      final monthName = ArabicDateHelper.getMonthName(monthNumber);
      final formatted = '${NumberFormatter.formatCurrency(savedBudgetPiastres! ~/ 100)} جنيه';
      final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
      if (targetContext != null && targetContext.mounted) {
        await ActionFeedbackDialog.show(
          context: targetContext,
          type: ActionFeedbackType.updated,
          title: 'تم تعديل الميزانية بنجاح',
          subtitle: 'تم ضبط ميزانية شهر $monthName بمبلغ $formatted وتحديث الحسابات.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final selectedYm = ref.watch(selectedYearMonthProvider);
    final (year, month) = ArabicDateHelper.parseYearMonthKey(selectedYm);
    final selectedMonthText = ArabicDateHelper.formatMonthYear(year, month);

    final monthRemainingAsync = ref.watch(currentMonthRemainingProvider);
    final recentTransactionsAsync = ref.watch(recentTransactionsProvider);
    final yearsAsync = ref.watch(yearsWithDataProvider);
    final monthsWithDataAsync = ref.watch(monthsWithDataProvider(year));

    final isViewingPastMonth = ref.watch(isViewingPastMonthProvider);

    // Month transition: check rollover first, then auto-open budget if needed
    monthRemainingAsync.whenData((remaining) {
      _checkMonthTransition(selectedYm, month, remaining);
    });

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main Scrollable Content
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 150.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: "صباح الخير", Month Selector, and Settings Icon
                  HomeTopBar(
                    selectedMonthText: selectedMonthText,
                    onTapMonthSelector: () {
                      setState(() {
                        _isMonthPopupOpen = !_isMonthPopupOpen;
                      });
                    },
                  ),

                  // Archived / View-only banner when browsing past months
                  if (isViewingPastMonth)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(
                          color: Colors.amber.shade700.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.archive_outlined,
                            color: Colors.amber.shade800,
                            size: 20.0,
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              'هذا الشهر مؤرشف للاطلاع فقط. تم إغلاقه ولا يمكن إضافة أو تعديل مصاريفه.',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20.0),

                  // Center: Big Ring
                  monthRemainingAsync.when(
                    data: (remaining) => BudgetRing(
                      remainingPiastres: remaining.remaining,
                      spentPiastres: remaining.expenses,
                      monthMoneyPiastres: remaining.monthMoney,
                      savedPiastres: remaining.goalSavings,
                      isReadOnly: isViewingPastMonth,
                      onTap: () =>
                          _openBudgetSheet(selectedYm, month, remaining.budget),
                    ),
                    loading: () => const Center(
                      child: SizedBox(
                        height: 250.0,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mainGreen,
                          ),
                        ),
                      ),
                    ),
                    error: (error, stack) => Container(
                      height: 250.0,
                      margin: const EdgeInsets.symmetric(horizontal: 20.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 36.0),
                            const SizedBox(height: 8.0),
                            Text(
                              'تعذر تحميل بيانات الميزانية',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            OutlinedButton.icon(
                              onPressed: () {
                                ref.invalidate(currentMonthRemainingProvider);
                              },
                              icon: const Icon(Icons.refresh, size: 18.0),
                              label: const Text(
                                'إعادة المحاولة',
                                style: TextStyle(fontFamily: 'Cairo'),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.mainGreen,
                                side: const BorderSide(color: AppColors.mainGreen),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28.0),

                  // Below: "آخر المصاريف" and the last 3 transactions
                  recentTransactionsAsync.when(
                    data: (transactions) =>
                        RecentTransactionsSection(transactions: transactions),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.mainGreen,
                        ),
                      ),
                    ),
                    error: (error, stack) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'تعذر تحميل آخر العمليات',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            TextButton.icon(
                              onPressed: () {
                                ref.invalidate(recentTransactionsProvider);
                              },
                              icon: const Icon(Icons.refresh, size: 18.0, color: AppColors.mainGreen),
                              label: const Text(
                                'إعادة المحاولة',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AppColors.mainGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Transparent barrier & Month Selector Popup (no dimming of background)
          if (_isMonthPopupOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() {
                    _isMonthPopupOpen = false;
                  });
                },
              ),
            ),
            Positioned(
              top: topInset + 66.0,
              right: 20.0,
              child: MonthSelectorPopup(
                selectedYear: year,
                selectedMonth: month,
                availableYears: yearsAsync.value ?? [year],
                monthsWithData: monthsWithDataAsync.value ?? {month},
                onClose: () {
                  setState(() {
                    _isMonthPopupOpen = false;
                  });
                },
                onSelectMonth: (selectedNewYear, selectedNewMonth) {
                  final newYm = ArabicDateHelper.formatYearMonthKey(
                    selectedNewYear,
                    selectedNewMonth,
                  );
                  ref
                      .read(selectedYearMonthProvider.notifier)
                      .selectYearMonth(newYm);

                  setState(() {
                    _isMonthPopupOpen = false;
                  });

                  // Tapping a month opens Month details screen
                  context.push('/month-details', extra: newYm);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../expenses/domain/models/month_remaining.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../widgets/budget_bottom_sheet.dart';
import '../widgets/budget_ring.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/month_selector_popup.dart';
import '../widgets/recent_transactions_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isMonthPopupOpen = false;

  void _checkAutoOpenBudget(String yearMonth, int monthNumber, MonthRemaining remaining) {
    if (remaining.budget <= 0) {
      final promptedMonths = ref.read(hasAutoOpenedBudgetForMonthProvider);
      if (!promptedMonths.contains(yearMonth)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final currentPrompted = ref.read(hasAutoOpenedBudgetForMonthProvider);
            if (!currentPrompted.contains(yearMonth)) {
              ref.read(hasAutoOpenedBudgetForMonthProvider.notifier).markOpened(yearMonth);
              _openBudgetSheet(yearMonth, monthNumber, 0);
            }
          }
        });
      }
    }
  }

  Future<void> _openBudgetSheet(
    String yearMonth,
    int monthNumber,
    int currentBudgetPiastres,
  ) async {
    int? initialBudgetEgp;

    if (currentBudgetPiastres > 0) {
      initialBudgetEgp = currentBudgetPiastres ~/ 100;
    } else {
      // At the start of a new month, pre-fill with last month's budget
      final prevYm = ArabicDateHelper.getPreviousYearMonth(yearMonth);
      final prevBudgetPiastres = await ref.read(getMonthBudgetUseCaseProvider)(prevYm);
      if (prevBudgetPiastres != null && prevBudgetPiastres > 0) {
        initialBudgetEgp = prevBudgetPiastres ~/ 100;
      }
    }

    if (!mounted) return;

    await BudgetBottomSheet.show(
      context: context,
      monthNumber: monthNumber,
      initialBudgetEgp: initialBudgetEgp,
      onSave: (budgetPiastres) async {
        await ref.read(setMonthBudgetUseCaseProvider)(
          yearMonth: yearMonth,
          amount: budgetPiastres,
        );
        ref.invalidate(currentMonthRemainingProvider);
        ref.invalidate(yearsWithDataProvider);
        final (year, _) = ArabicDateHelper.parseYearMonthKey(yearMonth);
        ref.invalidate(monthsWithDataProvider(year));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedYm = ref.watch(selectedYearMonthProvider);
    final (year, month) = ArabicDateHelper.parseYearMonthKey(selectedYm);
    final selectedMonthText = ArabicDateHelper.formatMonthYear(year, month);

    final monthRemainingAsync = ref.watch(currentMonthRemainingProvider);
    final recentTransactionsAsync = ref.watch(recentTransactionsProvider);
    final yearsAsync = ref.watch(yearsWithDataProvider);
    final monthsWithDataAsync = ref.watch(monthsWithDataProvider(year));

    // Auto-open budget bottom sheet if current month has no budget
    monthRemainingAsync.whenData((remaining) {
      _checkAutoOpenBudget(selectedYm, month, remaining);
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
              padding: const EdgeInsets.only(bottom: 90.0),
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

                  const SizedBox(height: 20.0),

                  // Center: Big Ring
                  monthRemainingAsync.when(
                    data: (remaining) => BudgetRing(
                      remainingPiastres: remaining.remaining,
                      spentPiastres: remaining.expenses,
                      monthMoneyPiastres: remaining.monthMoney,
                      onTap: () => _openBudgetSheet(selectedYm, month, remaining.budget),
                    ),
                    loading: () => const Center(
                      child: SizedBox(
                        height: 250.0,
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.mainGreen),
                        ),
                      ),
                    ),
                    error: (error, stack) => BudgetRing(
                      remainingPiastres: 0,
                      spentPiastres: 0,
                      monthMoneyPiastres: 0,
                      onTap: () => _openBudgetSheet(selectedYm, month, 0),
                    ),
                  ),

                  const SizedBox(height: 28.0),

                  // Below: "آخر المصاريف" and the last 3 transactions
                  recentTransactionsAsync.when(
                    data: (transactions) => RecentTransactionsSection(
                      transactions: transactions,
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.mainGreen),
                      ),
                    ),
                    error: (error, stack) => const RecentTransactionsSection(
                      transactions: [],
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
                  final newYm =
                      ArabicDateHelper.formatYearMonthKey(selectedNewYear, selectedNewMonth);
                  ref.read(selectedYearMonthProvider.notifier).selectYearMonth(newYm);

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

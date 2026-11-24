import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/month_rollover_info.dart';
import '../providers/expense_providers.dart';

abstract final class MonthRolloverHelper {
  static bool _hasCheckedThisSession = false;

  /// Resets session memory (e.g. after data reset or in tests)
  static void resetSession() {
    _hasCheckedThisSession = false;
  }

  /// Checks if the immediately preceding month ended with positive leftover money.
  /// If so, shows a dialog notifying the user that this leftover will be transferred
  /// to the new month. When the user taps "تم", it adds it as an income transaction.
  static Future<bool> checkAndPromptRollover({
    required BuildContext context,
    required WidgetRef ref,
    required String currentYearMonth,
    bool force = false,
  }) async {
    if (!force && _hasCheckedThisSession) return false;

    final user = ref.read(activeUserIdProvider);
    if (user == null) return false;

    final now = DateTime.now();
    final actualCurrentYm =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    // Allow checking if viewing real current month OR if user navigated forward to an upcoming month
    if (!force && currentYearMonth.compareTo(actualCurrentYm) < 0) return false;

    final checkUseCase = ref.read(checkMonthRolloverUseCaseProvider);
    final info = await checkUseCase(
      currentYearMonth: currentYearMonth,
      userId: user,
    );

    if (info == null || info.leftoverPiastres <= 0) return false;

    _hasCheckedThisSession = true;

    if (!context.mounted) return false;

    // Show dialog to the user informing them of the leftover money
    // Rollover is executed only when the user taps "تم"
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MonthRolloverDialog(
        info: info,
        onConfirm: () async {
          final executeUseCase = ref.read(executeRolloverUseCaseProvider);
          await executeUseCase.transferToCurrentMonth(
            info: info,
            userId: user,
          );

          // Invalidate state to reflect updated month money / transactions immediately
          ref.invalidate(currentMonthRemainingProvider);
          ref.invalidate(recentTransactionsProvider);
          ref.invalidate(yearsWithDataProvider);
          final (year, _) = ArabicDateHelper.parseYearMonthKey(currentYearMonth);
          ref.invalidate(monthsWithDataProvider(year));
        },
      ),
    );

    return confirmed ?? false;
  }

  /// Alias for backward compatibility
  static Future<bool> checkAndAutoRollover({
    required BuildContext context,
    required WidgetRef ref,
    required String currentYearMonth,
    bool force = false,
  }) async {
    return checkAndPromptRollover(
      context: context,
      ref: ref,
      currentYearMonth: currentYearMonth,
      force: force,
    );
  }

  /// Alias for backward compatibility
  static Future<void> checkAndPrompt({
    required BuildContext context,
    required WidgetRef ref,
    required String currentYearMonth,
    bool force = false,
  }) async {
    await checkAndPromptRollover(
      context: context,
      ref: ref,
      currentYearMonth: currentYearMonth,
      force: force,
    );
  }
}

/// Dialog notifying the user that remaining money from the previous month
/// will be transferred to the new month as an added amount.
class MonthRolloverDialog extends StatefulWidget {
  const MonthRolloverDialog({
    super.key,
    required this.info,
    this.onConfirm,
  });

  final MonthRolloverInfo info;
  final Future<void> Function()? onConfirm;

  @override
  State<MonthRolloverDialog> createState() => _MonthRolloverDialogState();
}

class _MonthRolloverDialogState extends State<MonthRolloverDialog> {
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (widget.onConfirm != null) {
        await widget.onConfirm!();
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prevMonthName =
        ArabicDateHelper.getMonthName(widget.info.previousMonthNumber);
    final currentMonthName =
        ArabicDateHelper.getMonthName(widget.info.currentMonthNumber);
    final formattedAmount =
        '${NumberFormatter.formatCurrency(widget.info.leftoverEgp)} جنيه';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64.0,
                height: 64.0,
                decoration: BoxDecoration(
                  color: AppColors.mainGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  color: AppColors.mainGreen,
                  size: 34.0,
                ),
              ),
            ),
            const SizedBox(height: 18.0),
            Text(
              'ترحيل متبقي الشهر السابق',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 20.0,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 14.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              decoration: BoxDecoration(
                color: AppColors.subtleBox,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: Column(
                children: [
                  Text(
                    formattedAmount,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 24.0,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mainGreen,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'متبقي من شهر $prevMonthName',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              'فيه مبلغ $formattedAmount من الشهر اللي فات ($prevMonthName) هيتم نقلهم للشهر الجديد ($currentMonthName).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14.5,
                color: AppColors.text,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'تم',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

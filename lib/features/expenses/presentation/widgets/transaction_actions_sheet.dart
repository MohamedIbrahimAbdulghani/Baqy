import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/action_feedback_dialog.dart';
import '../../../backup/presentation/controllers/backup_sync_controller.dart';
import '../../../backup/presentation/providers/backup_providers.dart';
import '../../../shell/presentation/providers/tab_provider.dart';
import '../../domain/models/transaction_item.dart';
import '../providers/expense_providers.dart';

abstract final class TransactionActionsHelper {
  /// Helper to check if a transaction belongs to an expired / past month
  static bool isTransactionFromPastMonth(TransactionItem transaction) {
    final localDate = transaction.createdAt.toLocal();
    final txYm = ArabicDateHelper.formatYearMonthKey(localDate.year, localDate.month);
    final now = DateTime.now();
    final currentYm = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
    return txYm.compareTo(currentYm) < 0;
  }

  /// Shows options bottom sheet on Tap or Long Press.
  /// If the transaction belongs to debts or goals, it displays an explanatory card
  /// preventing edit/delete and directing the user to the dedicated screen.
  static Future<void> showActionsBottomSheet({
    required BuildContext context,
    required WidgetRef ref,
    required TransactionItem transaction,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDebt = transaction.source == 'debt';
        final isLocked = transaction.isLockedFromExpenses;
        final isPastMonth = isTransactionFromPastMonth(transaction);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.dividers,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      transaction.description,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${NumberFormatter.formatCurrency(transaction.amount ~/ 100)} جنيه',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15.0,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    if (transaction.foreignAmount != null &&
                        transaction.foreignCurrency != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '≈ ${transaction.foreignAmount} ${transaction.foreignCurrency}',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13.0,
                          color: AppColors.mainGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    if (isLocked) ...[
                      // Locked Transaction Info Card: strictly no edit or delete from general expenses
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: AppColors.inputBorder.withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36.0,
                              height: 36.0,
                              decoration: BoxDecoration(
                                color: AppColors.mainGreen.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 20.0,
                                  color: AppColors.mainGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Text(
                                isDebt
                                    ? 'هذه المعاملة مسجلة كدفعة دين. لتعديلها أو حذفها، يمكنك ذلك من شاشة «الديون» فقط للحفاظ على صحة حساباتك.'
                                    : 'هذه المعاملة مسجلة كتحويش لهدف. لإدارتها، يمكنك ذلك من شاشة «الأهداف» فقط للحفاظ على صحة الأهداف.',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.secondaryText,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      SizedBox(
                        width: double.infinity,
                        height: 46.0,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            if (isDebt) {
                              ref.read(tabIndexProvider.notifier).selectTab(3);
                            } else {
                              ref.read(tabIndexProvider.notifier).selectTab(1);
                            }
                            if (context.mounted && Navigator.of(context).canPop()) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                          icon: Icon(
                            isDebt
                                ? Icons.payments_outlined
                                : Icons.flag_outlined,
                            size: 18.0,
                          ),
                          label: Text(
                            isDebt
                                ? 'الذهاب إلى صفحة الديون'
                                : 'الذهاب إلى صفحة الأهداف',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mainGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ] else if (isPastMonth) ...[
                      // Past Month Read-Only Info Card: strictly no edit or delete from past months
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: Colors.amber.shade600.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36.0,
                              height: 36.0,
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.archive_outlined,
                                size: 20.0,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'شهر مؤرشف (للاطلاع فقط)',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    'هذه المعاملة تنتمي لشهر سابق تم قفله وأرشفته. لا يمكن تعديل أو حذف المعاملات السابقة للحفاظ على دقة الحسابات والميزانية.',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.secondaryText,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      SizedBox(
                        width: double.infinity,
                        height: 46.0,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text(
                            'إغلاق',
                            style: TextStyle(fontFamily: AppTheme.fontFamily),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Regular Expense: Edit & Delete available
                      ListTile(
                        leading: const Icon(Icons.edit_outlined, color: AppColors.mainGreen),
                        title: Text(
                          'تعديل العملية',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          showEditSheet(
                            context: context,
                            ref: ref,
                            transaction: transaction,
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        title: const Text(
                          'حذف العملية',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w600,
                            color: Colors.redAccent,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          confirmAndDelete(
                            context: context,
                            ref: ref,
                            transaction: transaction,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shows the Edit Transaction Sheet on Normal Tap.
  /// If transaction is locked from general expenses, opens the explanatory sheet instead.
  static Future<void> showEditSheet({
    required BuildContext context,
    required WidgetRef ref,
    required TransactionItem transaction,
  }) {
    if (transaction.isLockedFromExpenses || isTransactionFromPastMonth(transaction)) {
      return showActionsBottomSheet(
        context: context,
        ref: ref,
        transaction: transaction,
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditTransactionSheet(
        transaction: transaction,
      ),
    );
  }

  /// Shows confirmation dialog and deletes with 5-second undo SnackBar
  static Future<void> confirmAndDelete({
    required BuildContext context,
    required WidgetRef ref,
    required TransactionItem transaction,
  }) async {
    if (transaction.isLockedFromExpenses || isTransactionFromPastMonth(transaction)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: AppColors.card,
          title: Text(
            'حذف العملية',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          content: Text(
            'هل أنت متأكد من حذف عملية "${transaction.description}" بمبلغ ${NumberFormatter.formatCurrency(transaction.amount ~/ 100)} جنيه؟',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppColors.secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text('إلغاء', style: TextStyle(color: AppColors.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await ref.read(deleteTransactionUseCaseProvider)(transaction.id);
      ref.invalidate(categoryTransactionsForDayProvider);
      ref.invalidate(categoryTotalForDayProvider);
      ref.invalidate(categoryTransactionsForMonthProvider);
      ref.invalidate(categoryTotalForMonthProvider);
      ref.invalidate(dayCategoryTotalsProvider);
      ref.invalidate(monthCategoryTotalsProvider);
      ref.invalidate(currentMonthRemainingProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.read(backupSyncControllerProvider)?.flush();

      if (context.mounted) {
        final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
        if (targetContext != null && targetContext.mounted) {
          final formattedAmount = '${NumberFormatter.formatCurrency(transaction.amount ~/ 100)} جنيه';
          await ActionFeedbackDialog.show(
            context: targetContext,
            type: ActionFeedbackType.deleted,
            title: 'تم حذف المعاملة',
            subtitle: 'تم حذف "${transaction.description}" بمبلغ $formattedAmount.',
            onUndo: () async {
              await ref.read(restoreTransactionUseCaseProvider)(transaction);
              ref.invalidate(categoryTransactionsForDayProvider);
              ref.invalidate(categoryTotalForDayProvider);
              ref.invalidate(categoryTransactionsForMonthProvider);
              ref.invalidate(categoryTotalForMonthProvider);
              ref.invalidate(dayCategoryTotalsProvider);
              ref.invalidate(monthCategoryTotalsProvider);
              ref.invalidate(currentMonthRemainingProvider);
              ref.invalidate(recentTransactionsProvider);
            },
          );
        }
      }
    }
  }
}

class _EditTransactionSheet extends ConsumerStatefulWidget {
  const _EditTransactionSheet({required this.transaction});

  final TransactionItem transaction;

  @override
  ConsumerState<_EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<_EditTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _descController;
  late final TextEditingController _noteController;
  BackupSyncController? _syncController;
  late int _selectedCategoryId;
  String? _amountError;
  String? _descError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _syncController = ref.read(backupSyncControllerProvider);
    _syncController?.setExpenseScreenOpen(true);
    _amountController = TextEditingController(
      text: (widget.transaction.amount ~/ 100).toString(),
    );
    _descController = TextEditingController(text: widget.transaction.description);
    _noteController = TextEditingController(text: widget.transaction.note ?? '');
    _selectedCategoryId = widget.transaction.categoryId;
  }

  @override
  void dispose() {
    _syncController?.setExpenseScreenOpen(false);
    _amountController.dispose();
    _descController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rawAmount = _amountController.text.trim();
    final parsed = NumberFormatter.parsePositiveInteger(rawAmount);
    if (parsed == null || parsed <= 0) {
      setState(() {
        _amountError = 'المبلغ يجب أن يكون أكبر من صفر';
      });
      return;
    }

    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      setState(() {
        _descError = 'الوصف لا يمكن أن يكون فارغاً';
      });
      return;
    }

    setState(() {
      _amountError = null;
      _descError = null;
      _isSaving = true;
    });

    try {
      final noteText = _noteController.text.trim();
      await ref.read(updateTransactionUseCaseProvider)(
        id: widget.transaction.id,
        amountInPiastres: parsed * 100,
        description: desc,
        categoryId: _selectedCategoryId,
        note: noteText.isNotEmpty ? noteText : null,
        foreignAmount: widget.transaction.foreignAmount,
        foreignCurrency: widget.transaction.foreignCurrency,
      );

      // Section 4: If category was modified by user, save a user learning rule
      if (_selectedCategoryId != widget.transaction.categoryId) {
        await ref.read(saveUserRuleUseCaseProvider)(
          keyword: desc,
          categoryId: _selectedCategoryId,
        );
      }

      ref.read(backupSyncControllerProvider)?.flush();

      if (mounted) {
        Navigator.of(context).pop();
        final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
        if (targetContext != null && targetContext.mounted) {
          final formattedAmount = '${NumberFormatter.formatCurrency(parsed * 100 ~/ 100)} جنيه';
          await ActionFeedbackDialog.show(
            context: targetContext,
            type: ActionFeedbackType.updated,
            title: 'تم تعديل العملية بنجاح',
            subtitle: 'تم تعديل تفاصيل "$desc" بمبلغ $formattedAmount.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final categoriesAsync = ref.watch(categoriesProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        margin: EdgeInsets.only(bottom: bottomInset),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.dividers,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'تعديل العملية',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 16),

                // Amount field with validation
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9٠-٩,،]'),
                    ),
                    ThousandsSeparatorInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'المبلغ (جنيه مصري)',
                    errorText: _amountError,
                    suffixText: 'ج.م',
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: AppColors.dividers),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Description field
                TextFormField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: 'الوصف',
                    errorText: _descError,
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: AppColors.dividers),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Foreign currency info if present
                if (widget.transaction.foreignAmount != null &&
                    widget.transaction.foreignCurrency != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.currency_exchange,
                          size: 18,
                          color: AppColors.mainGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'المبلغ الأجنبي المرجعي: ≈ ${widget.transaction.foreignAmount} ${widget.transaction.foreignCurrency}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mainGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Category selector
                categoriesAsync.when(
                  data: (categories) {
                    final validCategories =
                        categories.where((c) => !c.isArchived).toList();
                    return DropdownButtonFormField<int>(
                      initialValue: validCategories.any((c) => c.id == _selectedCategoryId)
                          ? _selectedCategoryId
                          : (validCategories.isNotEmpty ? validCategories.first.id : null),
                      decoration: InputDecoration(
                        labelText: 'التصنيف',
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: AppColors.dividers),
                        ),
                      ),
                      items: validCategories.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(
                                CategoryIconHelper.getIcon(c.icon),
                                size: 18,
                                color: CategoryIconHelper.parseColor(c.color),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategoryId = val;
                          });
                        }
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => TextButton.icon(
                    onPressed: () => ref.invalidate(categoriesProvider),
                    icon: const Icon(Icons.refresh, size: 16, color: AppColors.mainGreen),
                    label: const Text(
                      'تعذر تحميل التصنيفات، اضغط لإعادة المحاولة',
                      style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppColors.mainGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Note field
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: AppColors.dividers),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mainGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'حفظ التعديلات',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/action_feedback_dialog.dart';
import '../../../shell/presentation/providers/tab_provider.dart';
import '../../domain/models/debt_item.dart';
import '../../domain/models/debt_payment_item.dart';
import '../providers/debt_providers.dart';
import '../widgets/record_payment_sheet.dart';

class DebtDetailsScreen extends ConsumerWidget {
  const DebtDetailsScreen({
    super.key,
    required this.debtId,
  });

  final int debtId;

  void _popOrGoToDebts(BuildContext context, WidgetRef ref) {
    ref.read(tabIndexProvider.notifier).selectTab(3);
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (router != null) {
      router.go('/main');
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, DebtItem debt) async {
    final isOwe = debt.direction == 'owe';
    final isSettled = debt.archived || debt.remaining <= 0;

    final String dialogTitle;
    final String dialogBody;
    final String confirmBtnText;

    if (isSettled) {
      dialogTitle = 'حذف نهائي؟';
      dialogBody = 'في حالة الحذف هيتم حذفه نهائياً من التطبيق ومش هتقدر تعرضه تاني.';
      confirmBtnText = 'حذف نهائياً';
    } else if (isOwe) {
      dialogTitle = 'حذف الدين؟';
      dialogBody = 'هيتحذف الدين وكل دفعاته، واللي اتسجل بيها هيرجع زي ما كان.';
      confirmBtnText = 'حذف';
    } else {
      dialogTitle = 'حذف المبلغ المستحق؟';
      dialogBody = 'هيتحذف المبلغ المستحق وكل دفعاته، واللي اتسجل بيها هيرجع زي ما كان.';
      confirmBtnText = 'حذف';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            dialogTitle,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          content: Text(
            dialogBody,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppColors.secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                confirmBtnText,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      final name = debt.personName;
      await ref.read(debtRepositoryProvider).deleteDebt(debtId);
      if (context.mounted) {
        _popOrGoToDebts(context, ref);

        final String feedbackTitle;
        final String feedbackSubtitle;

        if (isSettled) {
          feedbackTitle = 'تم الحذف نهائياً';
          feedbackSubtitle = 'تم حذف سجل $name نهائياً من التطبيق.';
        } else if (isOwe) {
          feedbackTitle = 'تم حذف الدين';
          feedbackSubtitle = 'اتحذف الدين الخاص بـ $name ورجعت الحسابات زي ما كانت.';
        } else {
          feedbackTitle = 'تم حذف المبلغ المستحق';
          feedbackSubtitle = 'اتحذف المبلغ المستحق عند $name ورجعت الحسابات زي ما كانت.';
        }

        final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
        if (targetContext != null && targetContext.mounted) {
          await ActionFeedbackDialog.show(
            context: targetContext,
            type: ActionFeedbackType.deleted,
            title: feedbackTitle,
            subtitle: feedbackSubtitle,
          );
        }
      }
    }
  }

  void _showRecordPaymentSheet(BuildContext context, WidgetRef ref, DebtItem debt) {
    if (debt.remaining <= 0) return;

    int? recordedPaymentId;
    int? recordedAmountPiastres;

    RecordPaymentSheet.show(
      context: context,
      maxRemainingPiastres: debt.remaining,
      onSave: (amountPiastres) async {
        final paymentId = await ref.read(debtRepositoryProvider).recordPayment(
              debtId: debt.id,
              amount: amountPiastres,
              paidAt: DateTime.now(),
            );
        recordedPaymentId = paymentId;
        recordedAmountPiastres = amountPiastres;
      },
    ).then((_) async {
      if (recordedPaymentId == null || recordedAmountPiastres == null) return;
      if (!context.mounted) return;

      final amountPiastres = recordedAmountPiastres!;
      final paymentId = recordedPaymentId!;
      final newRemaining = debt.remaining - amountPiastres;
      final isOwe = debt.direction == 'owe';
      final formattedAmount = '${NumberFormatter.formatCurrency(amountPiastres ~/ 100)} جنيه';

      if (newRemaining <= 0) {
        // سداد الدين بالكامل: تحويل تلقائي لصفحة الديون مع إظهار نافذة التهنئة
        _popOrGoToDebts(context, ref);

        final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
        if (targetContext != null && targetContext.mounted) {
          await ActionFeedbackDialog.show(
            context: targetContext,
            type: ActionFeedbackType.settled,
            title: 'مبروك! تم سداد الدين بالكامل',
            subtitle: isOwe
                ? 'سددت كل اللي عليك لـ ${debt.personName}، واتنقل لقائمة تم سدادها.'
                : 'استلمت كل اللي ليك عند ${debt.personName}، واتنقل لقائمة تم سدادها.',
            onUndo: () async {
              await ref.read(debtRepositoryProvider).undoPayment(paymentId);
            },
          );
        }
      } else {
        // دفعة جزئية: البقاء في تفاصيل الدين مع تأكيد تسجيل الدفعة
        await ActionFeedbackDialog.show(
          context: context,
          type: ActionFeedbackType.paymentRecorded,
          title: 'تم تسجيل الدفعة بنجاح',
          subtitle: isOwe
              ? 'اتخصمت الدفعة ($formattedAmount) من ميزانية الشهر وتحدث المتبقي.'
              : 'اتضافت الدفعة ($formattedAmount) لميزانية الشهر وتحدث المتبقي.',
          onUndo: () async {
            await ref.read(debtRepositoryProvider).undoPayment(paymentId);
          },
        );
      }
    });
  }

  void _showEditPaymentSheet(
    BuildContext context,
    WidgetRef ref,
    DebtItem debt,
    DebtPaymentItem payment,
  ) {
    int? updatedNewAmount;
    final initialRemaining = debt.remaining;

    RecordPaymentSheet.show(
      context: context,
      title: 'تعديل الدفعة',
      initialAmountPiastres: payment.amount,
      maxRemainingPiastres: debt.remaining + payment.amount,
      onSave: (newAmount) async {
        await ref.read(debtRepositoryProvider).updatePayment(
              paymentId: payment.id,
              newAmount: newAmount,
            );
        updatedNewAmount = newAmount;
      },
    ).then((_) async {
      if (updatedNewAmount == null || !context.mounted) return;

      final newAmount = updatedNewAmount!;
      final newRemaining = (initialRemaining + payment.amount) - newAmount;
      final isOwe = debt.direction == 'owe';

      if (newRemaining <= 0) {
        _popOrGoToDebts(context, ref);

        final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
        if (targetContext != null && targetContext.mounted) {
          await ActionFeedbackDialog.show(
            context: targetContext,
            type: ActionFeedbackType.settled,
            title: 'مبروك! تم سداد الدين بالكامل',
            subtitle: isOwe
                ? 'سددت كل اللي عليك لـ ${debt.personName}، واتنقل لقائمة تم سدادها.'
                : 'استلمت كل اللي ليك عند ${debt.personName}، واتنقل لقائمة تم سدادها.',
          );
        }
      } else {
        final formatted = '${NumberFormatter.formatCurrency(newAmount ~/ 100)} جنيه';
        await ActionFeedbackDialog.show(
          context: context,
          type: ActionFeedbackType.updated,
          title: 'تم تعديل الدفعة بنجاح',
          subtitle: 'تم تعديل مبلغ الدفعة إلى $formatted وتحديث المتبقي وميزانية الشهر.',
        );
      }
    });
  }

  Future<void> _confirmDeletePayment(
    BuildContext context,
    WidgetRef ref,
    DebtItem debt,
    DebtPaymentItem payment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'حذف الدفعة؟',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          content: Text(
            'هتتحذف الدفعة ويتعدل المتبقي، وميزانية الشهر هترجع زي ما كانت.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppColors.secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'حذف',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(debtRepositoryProvider).deletePayment(payment.id);
      if (context.mounted) {
        await ActionFeedbackDialog.show(
          context: context,
          type: ActionFeedbackType.deleted,
          title: 'تم حذف الدفعة',
          subtitle: 'اتحذفت الدفعة ورجعت الحسابات زي ما كانت.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(debtDetailsStreamProvider(debtId));
    final paymentsAsync = ref.watch(debtPaymentsStreamProvider(debtId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: debtAsync.when(
        data: (debt) {
          if (debt == null) {
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
              body: const SizedBox.shrink(),
            );
          }

          final isOwe = debt.direction == 'owe';
          final isSettled = debt.archived || debt.remaining <= 0;
          final remainingEgp = debt.remaining ~/ 100;
          final totalEgp = debt.totalAmount ~/ 100;
          final paidEgp = debt.paidAmount ~/ 100;

          final remainingFormatted = NumberFormatter.formatCurrency(remainingEgp);
          final totalFormatted = NumberFormatter.formatCurrency(totalEgp);
          final paidFormatted = NumberFormatter.formatCurrency(paidEgp);

          final verbText = isOwe ? 'دفعت' : 'استلمت';
          final remainingLabel = isOwe ? 'المتبقي عليك' : 'المتبقي ليك';
          final monthNote = isOwe
              ? 'الدفعة بتتخصم من ميزانية الشهر وبتتسجل تحت نوع «ديون»'
              : 'الدفعة بتضاف لميزانية الشهر';

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              title: Text(
                debt.personName,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 32.0,
                  color: AppColors.text,
                ),
                onPressed: () => context.pop(),
              ),
              actions: [
                // Edit button (pencil) - only show when NOT settled
                if (!isSettled)
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 22.0,
                      color: AppColors.text,
                    ),
                    onPressed: () {
                      context.push('/add-debt', extra: debt);
                    },
                  ),
                // Delete button (trash can)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 22.0,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _confirmDelete(context, ref, debt),
                ),
                const SizedBox(width: 8.0),
              ],
            ),
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Summary Card
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: AppColors.inputBorder.withValues(alpha: 0.5),
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  remainingLabel,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14.0,
                                    color: AppColors.secondaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  '$remainingFormatted جنيه',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 34.0,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 16.0),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6.0),
                                  child: SizedBox(
                                    height: 8.0,
                                    child: LinearProgressIndicator(
                                      value: debt.progress,
                                      backgroundColor: const Color(0xFFE2DDD5),
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF4A7C59),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12.0),
                                Text(
                                  '$verbText $paidFormatted من $totalFormatted',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14.0,
                                    color: AppColors.secondaryText,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          // Section: "الدفعات"
                          Text(
                            'الدفعات',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 12.0),

                          // Payments List
                          paymentsAsync.when(
                            data: (payments) {
                              if (payments.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: payments.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10.0),
                                itemBuilder: (context, index) {
                                  final p = payments[index];
                                  final pAmountEgp = p.amount ~/ 100;
                                  final pAmountStr = NumberFormatter.formatCurrency(pAmountEgp);
                                  final pDate = p.paidAt.toLocal();
                                  final dateStr =
                                      '${pDate.day.toArabicDigits()} ${ArabicDateHelper.getMonthName(pDate.month)}';

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 14.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.card,
                                      borderRadius: BorderRadius.circular(14.0),
                                      border: Border.all(
                                        color: AppColors.inputBorder.withValues(alpha: 0.5),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Right in RTL: "دفعة"
                                        Text(
                                          'دفعة',
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF4A7C59),
                                          ),
                                        ),
                                        // Left in RTL: Amount & Date + Edit & Delete Actions
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '$pAmountStr جنيه',
                                                  style: TextStyle(
                                                    fontFamily: AppTheme.fontFamily,
                                                    fontSize: 16.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 2.0),
                                                Text(
                                                  dateStr,
                                                  style: TextStyle(
                                                    fontFamily: AppTheme.fontFamily,
                                                    fontSize: 13.0,
                                                    color: AppColors.secondaryText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Edit & delete payment only if debt is NOT settled (active)
                                            if (!isSettled) ...[
                                              const SizedBox(width: 12.0),
                                              // Edit button
                                              InkWell(
                                                onTap: () => _showEditPaymentSheet(context, ref, debt, p),
                                                borderRadius: BorderRadius.circular(8.0),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(6.0),
                                                  child: Icon(
                                                    Icons.edit_outlined,
                                                    size: 19.0,
                                                    color: AppColors.secondaryText,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4.0),
                                              // Delete button
                                              InkWell(
                                                onTap: () => _confirmDeletePayment(context, ref, debt, p),
                                                borderRadius: BorderRadius.circular(8.0),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(6.0),
                                                  child: Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 19.0,
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (e, s) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Note & "تسجيل دفعة" button OR Settled History banner
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 20.0,
                      right: 20.0,
                      bottom: 20.0,
                      top: 8.0,
                    ),
                    child: isSettled
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14.0),
                              border: Border.all(
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.30),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF2E7D32),
                                  size: 20.0,
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  isOwe
                                      ? 'تم سداد هذا الدين بالكامل (سجل محفوظ)'
                                      : 'تم استلام هذا المبلغ بالكامل (سجل محفوظ)',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                monthNote,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13.0,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              SizedBox(
                                width: double.infinity,
                                height: 52.0,
                                child: ElevatedButton(
                                  onPressed: debt.remaining > 0
                                      ? () => _showRecordPaymentSheet(context, ref, debt)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A7C59),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'تسجيل دفعة',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 17.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => Scaffold(
          backgroundColor: AppColors.background,
          body: const SizedBox.shrink(),
        ),
        error: (e, s) => Scaffold(
          backgroundColor: AppColors.background,
          body: const SizedBox.shrink(),
        ),
      ),
    );
  }
}

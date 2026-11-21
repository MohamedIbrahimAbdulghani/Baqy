import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/goal_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/action_feedback_dialog.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../domain/models/goal_item.dart';
import '../providers/goal_providers.dart';
import '../widgets/goal_progress_chart_card.dart';
import '../widgets/goal_save_bottom_sheet.dart';
import '../widgets/goal_transaction_success_dialog.dart';

class GoalDetailsScreen extends ConsumerStatefulWidget {
  const GoalDetailsScreen({
    super.key,
    required this.goalId,
  });

  final int goalId;

  @override
  ConsumerState<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends ConsumerState<GoalDetailsScreen> {
  static final NumberFormat _thousands = NumberFormat('#,##0', 'en_US');

  void _openEditGoal(BuildContext context, GoalItem goal) {
    context.push('/add-goal', extra: goal);
  }

  Future<void> _confirmDeleteGoal(BuildContext context, GoalItem goal) async {
    final isAchieved = goal.isAchieved;

    final String title = isAchieved ? 'حذف نهائي؟' : 'حذف الهدف؟';
    final String content = isAchieved
        ? 'سيتم حذف الهدف بالكامل من التطبيق ولا يمكن الرجوع له مرة أخرى.'
        : 'هيتحذف الهدف وكل اللي حوّشته فيه هيرجع للباقي.';
    final String confirmBtnText = isAchieved ? 'حذف نهائياً' : 'حذف';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: AppColors.card,
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            content,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                elevation: 0,
              ),
              child: Text(
                confirmBtnText,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final goalName = goal.name;
      await ref.read(goalRepositoryProvider).deleteGoal(goal.id);
      if (context.mounted) {
        final router = GoRouter.maybeOf(context);
        if (router != null && router.canPop()) {
          router.pop();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
        if (targetContext != null && targetContext.mounted) {
          await ActionFeedbackDialog.show(
            context: targetContext,
            type: ActionFeedbackType.deleted,
            title: isAchieved ? 'تم الحذف نهائياً' : 'تم حذف الهدف',
            subtitle: isAchieved
                ? 'تم حذف هدف "$goalName" نهائياً من التطبيق.'
                : 'اتحذف هدف "$goalName" ورجعت مدخراته للباقي.',
          );
        }
      }
    }
  }

  Future<void> _showUndoFeedback(BuildContext context) async {
    final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
    if (targetContext != null && targetContext.mounted) {
      await ActionFeedbackDialog.show(
        context: targetContext,
        type: ActionFeedbackType.deleted,
        title: 'تم التراجع عن التحويش',
        subtitle: 'تم إلغاء عملية التحويش وإرجاع المبلغ للباقي وتحديث الهدف.',
      );
    }
  }

  void _openSaveBottomSheet(
    BuildContext context,
    GoalItem goal,
    int remainingEgp, {
    bool isWithdrawal = false,
  }) {
    GoalSaveBottomSheet.show(
      context: context,
      goal: goal,
      remainingEgp: remainingEgp,
      isWithdrawal: isWithdrawal,
      onSave: (amountPiastres) async {
        if (isWithdrawal) {
          await ref.read(goalRepositoryProvider).addGoalWithdrawal(
                goalId: goal.id,
                amount: amountPiastres,
              );
          if (context.mounted) {
            GoalTransactionSuccessDialog.show(
              context: context,
              goal: goal,
              amountEgp: amountPiastres ~/ 100,
              isWithdrawal: true,
            );
          }
        } else {
          final savingId =
              await ref.read(goalRepositoryProvider).addGoalSaving(
                    goalId: goal.id,
                    amount: amountPiastres,
                  );
          if (context.mounted) {
            GoalTransactionSuccessDialog.show(
              context: context,
              goal: goal,
              amountEgp: amountPiastres ~/ 100,
              isWithdrawal: false,
              onUndo: () async {
                await ref
                    .read(goalRepositoryProvider)
                    .deleteGoalSaving(savingId);
                if (context.mounted) {
                  _showUndoFeedback(context);
                }
              },
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final goalAsync = ref.watch(goalByIdProvider(widget.goalId));
    final monthRemainingAsync = ref.watch(currentMonthRemainingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: goalAsync.when(
          data: (GoalItem? goal) {
            if (goal == null) {
              return Center(
                child: Text(
                  'الهدف غير موجود',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppColors.secondaryText,
                  ),
                ),
              );
            }

            final remainingPiastres =
                monthRemainingAsync.asData?.value.remaining ?? 0;
            final remainingEgp = (remainingPiastres / 100).round();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12.0),
                  // Header: Back Arrow, Goal Name, Pencil & Trash Buttons
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          final router = GoRouter.maybeOf(context);
                          if (router != null && router.canPop()) {
                            router.pop();
                          } else if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 20.0,
                          color: AppColors.text,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8.0),
                      Container(
                        width: 44.0,
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: AppColors.mainGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Icon(
                          GoalIconHelper.getIcon(
                            goal.icon ??
                                GoalIconHelper.resolveIconKeyFromName(
                                  goal.name,
                                ),
                          ),
                          color: AppColors.mainGreen,
                          size: 24.0,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      // Pencil (Edit) - only if NOT achieved
                      if (!goal.isAchieved) ...[
                        IconButton(
                          onPressed: () => _openEditGoal(context, goal),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 22.0,
                            color: AppColors.text,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8.0),
                      ],
                      // Trash (Delete)
                      IconButton(
                        onPressed: () => _confirmDeleteGoal(context, goal),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 22.0,
                          color: Colors.redAccent,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card 1: Goal Progress Chart with Animated Gauge & Stats
                          GoalProgressChartCard(goal: goal),
                          const SizedBox(height: 14.0),

                          if (goal.isAchieved) ...[
                            // Achieved History Card
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 22.0,
                              ),
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
                                  Container(
                                    width: 52.0,
                                    height: 52.0,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF2E7D32),
                                        size: 28.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12.0),
                                  Text(
                                    'تم تحقيق الهدف بنجاح',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 6.0),
                                  Text(
                                    'مبروك! حققت هدفك بالكامل وحوّشت ${NumberFormatter.formatCurrency(goal.targetEgp)} جنيه. هذا السجل محفوظ كإنجاز وتاريخ فقط.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13.5,
                                      color: AppColors.secondaryText,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16.0),
                          ] else ...[
                            // Active Goal Fields: Monthly Saving & Months to Goal
                            // Card 2: المتبقي معاك الشهر ده: X جنيه (Live from repository)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 18.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16.0),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0C000000),
                                    blurRadius: 8.0,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المتبقي معاك الشهر ده',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14.0,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  Text(
                                    '${_thousands.format(remainingEgp)} جنيه',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 0,
                                    height: 0,
                                    child: Opacity(
                                      opacity: 0,
                                      child: Text(
                                        '${NumberFormatter.formatCurrency(remainingEgp)} جنيه',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18.0),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Bottom Area: Settled history badge if achieved, OR action buttons if active
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                    child: goal.isAchieved
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
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF2E7D32),
                                  size: 20.0,
                                ),
                                SizedBox(width: 8.0),
                                Text(
                                  'تم تحقيق هذا الهدف بالكامل (سجل محفوظ)',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 52.0,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _openSaveBottomSheet(context, goal, remainingEgp, isWithdrawal: false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.mainGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14.0),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'حوّشت',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: SizedBox(
                                  height: 52.0,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _openSaveBottomSheet(context, goal, remainingEgp, isWithdrawal: true),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.isDark ? AppColors.coinGold : const Color(0xFFB5883E),
                                      side: BorderSide(
                                        color: AppColors.isDark ? AppColors.coinGold : const Color(0xFFB5883E),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14.0),
                                      ),
                                    ),
                                    child: const Text(
                                      'سحب',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.mainGreen),
          ),
          error: (_, _) => const Center(
            child: Text(
              'حدث خطأ في تحميل بيانات الهدف',
              style: TextStyle(fontFamily: AppTheme.fontFamily),
            ),
          ),
        ),
      ),
    );
  }
}

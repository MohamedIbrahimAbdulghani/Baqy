import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../domain/models/goal_item.dart';
import '../providers/goal_providers.dart';
import '../widgets/goal_save_bottom_sheet.dart';

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
  final TextEditingController _savingController = TextEditingController();
  bool _isControllerInitialized = false;
  String? _savingError;

  @override
  void dispose() {
    _savingController.dispose();
    super.dispose();
  }

  void _initControllerIfNeeded(GoalItem goal) {
    if (!_isControllerInitialized) {
      if (goal.monthlySavingEgp > 0) {
        _savingController.text =
            NumberFormatter.formatCurrency(goal.monthlySavingEgp);
      }
      _isControllerInitialized = true;
    }
  }

  Future<void> _onSavingChanged(String text, GoalItem goal) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() => _savingError = null);
      await ref
          .read(goalRepositoryProvider)
          .updateMonthlySaving(id: goal.id, monthlySaving: 0);
      return;
    }

    final parsed = NumberFormatter.parsePositiveInteger(trimmed);
    if (parsed == null || parsed <= 0) {
      setState(() => _savingError = 'يرجى إدخال مبلغ صحيح');
      return;
    }

    if (parsed > goal.targetEgp) {
      setState(() => _savingError = 'المبلغ لا يمكن أن يزيد عن الهدف');
      return;
    }

    setState(() => _savingError = null);
    await ref
        .read(goalRepositoryProvider)
        .updateMonthlySaving(id: goal.id, monthlySaving: parsed * 100);
  }

  void _openEditGoal(BuildContext context, GoalItem goal) {
    context.push('/add-goal', extra: goal);
  }

  Future<void> _confirmDeleteGoal(BuildContext context, GoalItem goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: AppColors.card,
          title: const Text(
            'حذف الهدف؟',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'هيتحذف الهدف وكل اللي حوّشته فيه هيرجع للباقي.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
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
              child: const Text(
                'حذف',
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

    if (confirmed == true && mounted) {
      await ref.read(goalRepositoryProvider).deleteGoal(goal.id);
      if (context.mounted) {
        final router = GoRouter.maybeOf(context);
        if (router != null && router.canPop()) {
          router.pop();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
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
        } else {
          await ref.read(goalRepositoryProvider).addGoalSaving(
                goalId: goal.id,
                amount: amountPiastres,
              );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalAsync = ref.watch(goalByIdProvider(widget.goalId));
    final monthRemainingAsync = ref.watch(currentMonthRemainingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: goalAsync.when(
          data: (GoalItem? goal) {
            if (goal == null) {
              return const Center(
                child: Text(
                  'الهدف غير موجود',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppColors.secondaryText,
                  ),
                ),
              );
            }

            _initControllerIfNeeded(goal);

            final remainingPiastres =
                monthRemainingAsync.asData?.value.remaining ?? 0;
            final remainingEgp = (remainingPiastres / 100).round();

            final int? monthsResult = goal.monthsToGoal;

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
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 20.0,
                          color: AppColors.text,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      // Pencil (Edit)
                      IconButton(
                        onPressed: () => _openEditGoal(context, goal),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 22.0,
                          color: AppColors.text,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8.0),
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
                          // Card 1: المبلغ المطلوب
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24.0,
                              horizontal: 16.0,
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'المبلغ المطلوب',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13.5,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  '${NumberFormatter.formatCurrency(goal.targetEgp)} جنيه',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 28.0,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14.0),

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
                                const Text(
                                  'المتبقي معاك الشهر ده',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14.0,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                Text(
                                  '${NumberFormatter.formatCurrency(remainingEgp)} جنيه',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18.0),

                          // Field 3: هتوفر كام في الشهر؟
                          const Text(
                            'هتوفر كام في الشهر؟',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.5,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.0),
                              border: Border.all(
                                color: _savingError != null
                                    ? Colors.redAccent
                                    : const Color(0xFFE2DDD5),
                                width: 1.0,
                              ),
                            ),
                            child: TextField(
                              controller: _savingController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9٠-٩,،]'),
                                ),
                              ],
                              onChanged: (val) => _onSavingChanged(val, goal),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 14.0,
                                ),
                              ),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 16.0,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          if (_savingError != null) ...[
                            const SizedBox(height: 4.0),
                            Text(
                              _savingError!,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.0,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16.0),

                          // Card 4: Result ("هتوصل لهدفك في N شهر")
                          // If saving is empty/invalid, show nothing for the result
                          if (monthsResult != null && _savingError == null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 22.0,
                                horizontal: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lightGreen,
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'هتوصل لهدفك في',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14.0,
                                      color: AppColors.mainGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 6.0),
                                  Text(
                                    '${monthsResult.toArabicDigits()} شهر',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 32.0,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.mainGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 22.0),

                          // Progress bar and percent
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: LinearProgressIndicator(
                              value: goal.progress,
                              minHeight: 7.0,
                              backgroundColor: AppColors.progressTrack,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.mainGreen,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${goal.percentage.toArabicDigits()}٪ من الهدف',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13.0,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons: "حوّشت" and "سحبت"
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                    child: Row(
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
                                foregroundColor: const Color(0xFFB5883E),
                                side: const BorderSide(
                                  color: Color(0xFFB5883E),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                              ),
                              child: const Text(
                                'سحبت',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/baqy_refresh.dart';
import '../../../../core/widgets/empty_state_welcome_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../goals/domain/models/goal_item.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../../goals/presentation/widgets/completed_goals_section.dart';
import '../../../goals/presentation/widgets/goal_card.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final title = AppLocalizations.of(context)?.tabGoals ?? 'الأهداف';
    final goalsAsync = ref.watch(goalsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16.0),
              // Page Title (Top Right in RTL)
              Text(
                title,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16.0),

              // Goals List / Empty State
              Expanded(
                child: BaqyRefresh(
                  onRefresh: () async {
                    ref.invalidate(databaseChangesProvider);
                    ref.invalidate(goalsStreamProvider);
                  },
                  child: goalsAsync.when(
                    data: (List<GoalItem> goals) {
                      if (goals.isEmpty) {
                        return LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                                  child: EmptyStateWelcomeCard(
                                    icon: Icons.stars_rounded,
                                    title: 'خطوتك الأولى نحو تحقيق أحلامك',
                                    subtitle:
                                        'سجل هدفك المالي (عربية، سفرية، جهاز جديد...) وتابع تقدم تحويشك خطوة بخطوة بالضغط على (+).',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final activeGoals = goals.where((g) => !g.isAchieved).toList();
                      final completedGoals = goals.where((g) => g.isAchieved).toList();

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 90.0),
                        children: [
                          // Active Goals
                          ...activeGoals.map((goal) => GoalCard(goal: goal)),

                          // Completed Goals Section (Accordion like Settled Debts)
                          if (completedGoals.isNotEmpty) ...[
                            const SizedBox(height: 8.0),
                            CompletedGoalsSection(
                              completedGoals: completedGoals,
                              onGoalTap: (goal) {
                                context.push('/goal-details', extra: goal.id);
                              },
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.mainGreen),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

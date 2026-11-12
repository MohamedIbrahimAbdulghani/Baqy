import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../goals/domain/models/goal_item.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../../goals/presentation/widgets/goal_card.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16.0),

              // Goals List / Empty State
              Expanded(
                child: goalsAsync.when(
                  data: (List<GoalItem> goals) {
                    if (goals.isEmpty) {
                      // Rule: When there are no goals yet, show only the page title
                      // and the "+" button, with no extra text.
                      return const SizedBox.shrink();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90.0),
                      itemCount: goals.length,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        return GoalCard(goal: goal);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.mainGreen),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

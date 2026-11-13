import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/goal_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/goal_item.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
  });

  final GoalItem goal;

  @override
  Widget build(BuildContext context) {
    final iconData = GoalIconHelper.getIcon(
      goal.icon ?? GoalIconHelper.resolveIconKeyFromName(goal.name),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: () {
            context.push('/goal-details', extra: goal.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Icon chip + Goal Name & Percentage
                Row(
                  children: [
                    Container(
                      width: 44.0,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: AppColors.mainGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(
                        iconData,
                        color: AppColors.mainGreen,
                        size: 24.0,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  goal.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                '${goal.percentage.toArabicDigits()}٪',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mainGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            'الهدف: ${NumberFormatter.formatCurrency(goal.targetEgp)} جنيه',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.0,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),

                // Bottom: Horizontal Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 7.0,
                    backgroundColor: AppColors.progressTrack,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mainGreen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


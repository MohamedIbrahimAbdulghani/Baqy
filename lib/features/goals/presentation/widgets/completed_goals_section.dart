import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/goal_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/goal_item.dart';

class CompletedGoalsSection extends StatefulWidget {
  const CompletedGoalsSection({
    super.key,
    required this.completedGoals,
    required this.onGoalTap,
  });

  final List<GoalItem> completedGoals;
  final ValueChanged<GoalItem> onGoalTap;

  @override
  State<CompletedGoalsSection> createState() => _CompletedGoalsSectionState();
}

class _CompletedGoalsSectionState extends State<CompletedGoalsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.completedGoals.isEmpty) {
      return const SizedBox.shrink();
    }

    final countStr = widget.completedGoals.length.toArabicDigits();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Completed goals header row
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: AppColors.inputBorder.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تم تحقيقها',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      countStr,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Icon(
                      _isExpanded ? Icons.expand_more : Icons.chevron_left,
                      size: 20.0,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Expanded completed goals list under it inside the same screen
        if (_isExpanded) ...[
          const SizedBox(height: 8.0),
          ...widget.completedGoals.map((goal) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: InkWell(
                onTap: () => widget.onGoalTap(goal),
                borderRadius: BorderRadius.circular(14.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: AppColors.inputBorder.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36.0,
                            height: 36.0,
                            decoration: BoxDecoration(
                              color: AppColors.mainGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Icon(
                              GoalIconHelper.getIcon(
                                goal.icon ??
                                    GoalIconHelper.resolveIconKeyFromName(goal.name),
                              ),
                              color: AppColors.mainGreen,
                              size: 20.0,
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Text(
                            goal.name,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2EFEA),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Text(
                          'تم التحقيق',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2A5949),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}


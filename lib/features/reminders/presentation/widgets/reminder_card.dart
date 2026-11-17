import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/utils/reminder_icon_helper.dart';
import '../../domain/models/reminder_item.dart';
import '../../domain/utils/reminder_date_calculator.dart';

/// Card widget displaying a single reminder in the list.
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
  });

  final ReminderItem reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isPast = ReminderDateCalculator.isPastOneTime(
      dueDate: reminder.dueDate,
      repeat: reminder.repeat,
    );

    final nextDue = ReminderDateCalculator.calculateNextDueDate(
      dueDate: reminder.dueDate,
      repeat: reminder.repeat,
    );

    final dayStr = nextDue.day.toArabicDigits();
    final monthStr = ArabicDateHelper.getMonthName(nextDue.month);
    final dateDisplay = '$dayStr $monthStr';
    final amountDisplay =
        '${NumberFormatter.formatCurrency(reminder.amountEgp)} جنيه';
    final iconData = ReminderIconHelper.resolveIcon(reminder.name);

    final cardContent = Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.subtleBorder,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                // Icon Chip on the right (start in RTL)
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
                    size: 22.0,
                  ),
                ),
                const SizedBox(width: 12.0),

                // Name and Date in middle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        reminder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        dateDisplay,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12.0),

                // Amount on the left (end in RTL)
                Text(
                  amountDisplay,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isPast) {
      return Opacity(
        opacity: 0.45,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

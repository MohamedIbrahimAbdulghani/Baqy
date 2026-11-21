import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/utils/reminder_icon_helper.dart';
import '../../domain/models/reminder_item.dart';
import '../../domain/utils/reminder_date_calculator.dart';

/// Smooth, classy modal success popup shown after adding or editing a reminder,
/// matching the exact animation and feel of the Goals success dialog.
class ReminderSuccessDialog extends StatefulWidget {
  const ReminderSuccessDialog({
    super.key,
    required this.reminder,
    required this.isEdit,
    this.onDone,
  });

  final ReminderItem reminder;
  final bool isEdit;
  final VoidCallback? onDone;

  /// Shows the smooth modal success popup with easeOutBack scale + fade transition
  static Future<void> show({
    required BuildContext context,
    required ReminderItem reminder,
    required bool isEdit,
    VoidCallback? onDone,
  }) async {
    HapticFeedback.lightImpact();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return Dialog(
          backgroundColor: AppColors.card,
          elevation: 16.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ReminderSuccessDialog(
            reminder: reminder,
            isEdit: isEdit,
            onDone: onDone,
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );

    onDone?.call();
  }

  @override
  State<ReminderSuccessDialog> createState() => _ReminderSuccessDialogState();
}

class _ReminderSuccessDialogState extends State<ReminderSuccessDialog> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    // Auto-dismiss smoothly after 4 seconds if not closed manually
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = AppColors.mainGreen;
    final String formattedAmount =
        NumberFormatter.formatCurrency(widget.reminder.amountEgp);

    final dayStr = widget.reminder.dueDate.day.toArabicDigits();
    final monthStr =
        ArabicDateHelper.getMonthName(widget.reminder.dueDate.month);
    final leadText =
        ReminderDateCalculator.formatLeadDaysText(widget.reminder.leadDays);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 26.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge
            Container(
              width: 68.0,
              height: 68.0,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle_rounded,
                  color: themeColor,
                  size: 38.0,
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Title
            Text(
              widget.isEdit
                  ? 'تم تعديل الموعد بنجاح'
                  : 'تم حفظ الموعد بنجاح',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 20.0,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16.0),

            // Amount Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 14.0,
              ),
              decoration: BoxDecoration(
                color: AppColors.subtleBox,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: Column(
                children: [
                  Text(
                    '$formattedAmount جنيه',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 26.0,
                      fontWeight: FontWeight.w800,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28.0,
                        height: 28.0,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          ReminderIconHelper.resolveIcon(widget.reminder.name),
                          color: themeColor,
                          size: 15.0,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Flexible(
                        child: Text(
                          widget.reminder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),

            // Subtext message
            Text(
              widget.isEdit
                  ? 'تم تحديث الموعد والإشعار بتاعه بنجاح'
                  : 'الاستحقاق: $dayStr $monthStr · تذكير قبلها بـ $leadText في ٩:٠٠ ص',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22.0),

            // Primary Action Button ("تمام")
            SizedBox(
              width: double.infinity,
              height: 48.0,
              child: ElevatedButton(
                onPressed: () {
                  _autoDismissTimer?.cancel();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                child: Text(
                  'تمام',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

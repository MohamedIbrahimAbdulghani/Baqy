import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/number_formatter.dart';

enum DebtActionType {
  added,
  updated,
  deleted,
  paymentRecorded,
  settled,
}

/// A smooth, beautiful modal popup shown after debt actions (add, edit, delete, payment, settle),
/// with auto-dismiss and haptic feedback.
class DebtActionDialog extends StatefulWidget {
  const DebtActionDialog({
    super.key,
    required this.type,
    required this.personName,
    this.direction = 'owe',
    this.amountEgp,
    this.onUndo,
  });

  final DebtActionType type;
  final String personName;
  final String direction; // "owe" or "owed"
  final int? amountEgp;
  final VoidCallback? onUndo;

  /// Shows the modal popup with smooth scale + fade animation
  static Future<void> show({
    required BuildContext context,
    required DebtActionType type,
    required String personName,
    String direction = 'owe',
    int? amountEgp,
    VoidCallback? onUndo,
  }) async {
    HapticFeedback.lightImpact();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withValues(alpha: 0.40),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) {
        return Dialog(
          backgroundColor: AppColors.card,
          elevation: 16.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: DebtActionDialog(
            type: type,
            personName: personName,
            direction: direction,
            amountEgp: amountEgp,
            onUndo: onUndo,
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<DebtActionDialog> createState() => _DebtActionDialogState();
}

class _DebtActionDialogState extends State<DebtActionDialog> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    // Auto-dismiss smoothly after 2.8 seconds
    _autoDismissTimer = Timer(const Duration(milliseconds: 2800), () {
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
    final isOwe = widget.direction == 'owe';

    IconData icon;
    Color iconColor;
    Color iconBgColor;
    String title;
    String subtitle;

    final formattedAmount = widget.amountEgp != null
        ? '${NumberFormatter.formatCurrency(widget.amountEgp!)} جنيه'
        : null;

    switch (widget.type) {
      case DebtActionType.added:
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.mainGreen;
        iconBgColor = AppColors.mainGreen.withValues(alpha: 0.12);
        title = 'تم تسجيل الدين بنجاح';
        subtitle = isOwe
            ? 'تم حفظ دين عليك لـ ${widget.personName}${formattedAmount != null ? ' بمبلغ $formattedAmount' : ''}'
            : 'تم حفظ دين لك عند ${widget.personName}${formattedAmount != null ? ' بمبلغ $formattedAmount' : ''}';
        break;

      case DebtActionType.updated:
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.mainGreen;
        iconBgColor = AppColors.mainGreen.withValues(alpha: 0.12);
        title = 'تم تعديل الدين بنجاح';
        subtitle = 'تم تحديث بيانات الدين الخاص بـ ${widget.personName}';
        break;

      case DebtActionType.deleted:
        icon = Icons.delete_outline_rounded;
        iconColor = Colors.redAccent;
        iconBgColor = Colors.redAccent.withValues(alpha: 0.12);
        title = 'تم حذف الدين';
        subtitle = 'اتحذف الدين الخاص بـ ${widget.personName} ورجعت الحسابات زي ما كانت.';
        break;

      case DebtActionType.paymentRecorded:
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.mainGreen;
        iconBgColor = AppColors.mainGreen.withValues(alpha: 0.12);
        title = 'تم تسجيل الدفعة بنجاح';
        subtitle = isOwe
            ? 'اتخصمت الدفعة${formattedAmount != null ? ' ($formattedAmount)' : ''} من ميزانية الشهر وتحدث المتبقي.'
            : 'اتضافت الدفعة${formattedAmount != null ? ' ($formattedAmount)' : ''} لميزانية الشهر وتحدث المتبقي.';
        break;

      case DebtActionType.settled:
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF2E7D32);
        iconBgColor = const Color(0xFF2E7D32).withValues(alpha: 0.14);
        title = 'مبروك! تم سداد الدين بالكامل';
        subtitle = isOwe
            ? 'سددت كل اللي عليك لـ ${widget.personName}، واتنقل لقائمة تم سدادها.'
            : 'استلمت كل اللي ليك عند ${widget.personName}، واتنقل لقائمة تم سدادها.';
        break;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 26.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Badge
            Container(
              width: 64.0,
              height: 64.0,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 34.0,
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 19.0,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8.0),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: AppColors.secondaryText,
                height: 1.45,
              ),
            ),

            if (widget.onUndo != null) ...[
              const SizedBox(height: 18.0),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onUndo?.call();
                },
                icon: const Icon(Icons.undo_rounded, size: 18.0),
                label: const Text(
                  'تراجع عن الدفعة',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mainGreen,
                  side: const BorderSide(color: AppColors.mainGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


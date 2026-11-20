import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/account_status.dart';

class AccountStatusDialog extends StatelessWidget {
  const AccountStatusDialog({
    super.key,
    required this.status,
    this.customReason,
    this.buttonText = 'تسجيل الخروج',
    this.onDismissed,
  });

  final AccountStatus status;
  final String? customReason;
  final String buttonText;
  final VoidCallback? onDismissed;

  static bool _isShowing = false;

  /// Display the account security status dialog in a modal that cannot be dismissed
  /// by clicking outside or pressing back without acknowledging and tapping logout.
  static Future<void> show(
    BuildContext context, {
    required AccountStatus status,
    String? customReason,
    String buttonText = 'تسجيل الخروج',
    VoidCallback? onDismissed,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        routeSettings: const RouteSettings(name: '/account-status-dialog'),
        builder: (dialogCtx) {
          return PopScope(
            canPop: false,
            child: AccountStatusDialog(
              status: status,
              customReason: customReason,
              buttonText: buttonText,
              onDismissed: () {
                Navigator.of(dialogCtx, rootNavigator: true).pop();
                onDismissed?.call();
              },
            ),
          );
        },
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeleted = status == AccountStatus.deleted;
    final title = isDeleted ? 'تم حذف الحساب' : 'تم تعطيل الحساب';

    final defaultReason = isDeleted
        ? 'تم حذف هذا الحساب نهائياً من قِبل إدارة التطبيق.\n\nلم تعد بيانات هذا الحساب متوفرة، ويجب تسجيل الخروج الآن.'
        : 'تم إيقاف هذا الحساب من قِبل إدارة التطبيق لمراجعة النشاط أو لمخالفة شروط الاستخدام.\n\nإذا كنت تعتقد أن هذا الإجراء تم بالخطأ، يُرجى التواصل مع إدارة التطبيق والدعم الفني.';

    final reasonText = (customReason != null && customReason!.trim().isNotEmpty)
        ? customReason!
        : defaultReason;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top circular icon badge
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isDeleted
                      ? Icons.person_off_rounded
                      : Icons.lock_person_rounded,
                  size: 42,
                  color: AppColors.errorRed,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Dialog Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: AppColors.text,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 16),

            // Detailed Reason Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.subtleBox,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.subtleBorder,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.errorRed,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'إشعار من إدارة التطبيق',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reasonText,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                      color: AppColors.secondaryText,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Mandatory Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onDismissed,
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                label: Text(
                  buttonText,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

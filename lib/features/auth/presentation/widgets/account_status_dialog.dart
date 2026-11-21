import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/whatsapp_icon.dart';
import '../../domain/models/account_status.dart';

class AccountStatusDialog extends StatelessWidget {
  const AccountStatusDialog({
    super.key,
    required this.status,
    this.customReason,
    this.userEmail,
    this.buttonText = 'خروج',
    this.buttonColor,
    this.buttonIcon,
    this.showContactOptions = true,
    this.onDismissed,
  });

  final AccountStatus status;
  final String? customReason;
  final String? userEmail;
  final String buttonText;
  final Color? buttonColor;
  final IconData? buttonIcon;
  final bool showContactOptions;
  final VoidCallback? onDismissed;

  static const String _adminEmail = 'mohamedibrahimabdulghani@gmail.com';
  static const String _adminWhatsAppNumber = '201205481045';

  static bool _isShowing = false;
  static bool get isShowing => _isShowing;

  /// Display the account security status dialog in a modal that cannot be dismissed
  /// by clicking outside or pressing back without acknowledging and tapping the action button.
  static Future<void> show(
    BuildContext context, {
    required AccountStatus status,
    String? customReason,
    String? userEmail,
    String buttonText = 'خروج',
    Color? buttonColor,
    IconData? buttonIcon,
    bool showContactOptions = true,
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
              userEmail: userEmail,
              buttonText: buttonText,
              buttonColor: buttonColor,
              buttonIcon: buttonIcon,
              showContactOptions: showContactOptions,
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

  Future<void> _launchWhatsApp() async {
    final emailInfo = (userEmail != null && userEmail!.trim().isNotEmpty)
        ? userEmail!.trim()
        : 'غير محدد';

    final message = '''السلام عليكم إدارة تطبيق باقي،
تم تعطيل حسابي وأرغب في مراجعته وإعادة تفعيله.

بيانات الحساب:
• البريد الإلكتروني: $emailInfo
• الحالة: حساب معطّل

أرجو من الإدارة التكرم بتفعيل الحساب. شكراً لكم.''';

    final url = 'https://wa.me/$_adminWhatsAppNumber?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final emailInfo = (userEmail != null && userEmail!.trim().isNotEmpty)
        ? userEmail!.trim()
        : 'غير محدد';

    final subject = 'طلب تفعيل حساب معطّل - تطبيق باقي';
    final body = '''السلام عليكم إدارة تطبيق باقي،
تم تعطيل حسابي وأرغب في مراجعته وإعادة تفعيله.

بيانات الحساب:
• البريد الإلكتروني: $emailInfo
• الحالة: حساب معطّل

أرجو من الإدارة التكرم بتفعيل الحساب. شكراً لكم.''';

    final uri = Uri(
      scheme: 'mailto',
      path: _adminEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeleted = status == AccountStatus.deleted;
    final title = isDeleted ? 'تم حذف الحساب' : 'تم تعطيل الحساب';

    final defaultReason = isDeleted
        ? 'تم حذف هذا الحساب نهائياً من قِبل إدارة التطبيق.\n\nلم تعد بيانات هذا الحساب متوفرة، ولا يمكن تسجيل الدخول به.'
        : showContactOptions
            ? 'تم إيقاف هذا الحساب من قِبل إدارة التطبيق لمراجعة النشاط أو لمخالفة شروط الاستخدام.\n\nإذا كنت تعتقد أن هذا الإجراء تم بالخطأ، يُرجى التواصل مع إدارة التطبيق عبر واتساب أو جيميل لإعادة تفعيله.'
            : 'تم إيقاف هذا الحساب من قِبل إدارة التطبيق لمراجعة النشاط أو لمخالفة شروط الاستخدام.\n\nيُرجى تسجيل الخروج للمتابعة.';

    final reasonText = (customReason != null && customReason!.trim().isNotEmpty)
        ? customReason!
        : defaultReason;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
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
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isDeleted
                      ? Icons.person_off_rounded
                      : Icons.lock_person_rounded,
                  size: 40,
                  color: AppColors.errorRed,
                ),
              ),
            ),

            const SizedBox(height: 18),

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

            const SizedBox(height: 14),

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

            if (showContactOptions) ...[
              const SizedBox(height: 18),

              // Contact Administration Label
              Text(
                'تواصل مع الإدارة لإعادة تفعيل الحساب:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),

              const SizedBox(height: 10),

              // WhatsApp and Gmail Buttons Row
              Row(
                children: [
                  // WhatsApp Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _launchWhatsApp,
                      icon: const WhatsAppIcon(size: 20),
                      label: const Text(
                        'واتساب',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFF25D366),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Gmail Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _launchEmail,
                      icon: const Icon(
                        Icons.mail_rounded,
                        size: 20,
                        color: Color(0xFFEA4335),
                      ),
                      label: const Text(
                        'جيميل',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFFEA4335),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFEA4335), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Main Action Button (Red "خروج" or customizable)
            Builder(
              builder: (context) {
                final effectiveButtonColor = buttonColor ??
                    ((buttonText == 'خروج' || buttonText == 'تسجيل الخروج')
                        ? AppColors.errorRed
                        : AppColors.darkGreen);

                final effectiveButtonIcon = buttonIcon ??
                    ((buttonText == 'خروج' || buttonText == 'تسجيل الخروج')
                        ? Icons.logout_rounded
                        : Icons.check_circle_outline_rounded);

                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onDismissed,
                    icon: Icon(
                      effectiveButtonIcon,
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
                      backgroundColor: effectiveButtonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

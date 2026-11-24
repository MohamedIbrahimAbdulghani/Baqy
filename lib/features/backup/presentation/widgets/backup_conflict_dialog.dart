import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

enum ConflictResolution {
  keepLocal,
  keepCloud,
}

class BackupConflictDialog {
  static Future<ConflictResolution?> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return showDialog<ConflictResolution>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              l10n?.backupConflictDialogTitle ?? 'في تعارض في البيانات',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.text,
              ),
            ),
            content: Text(
              l10n?.backupConflictDialogBody ??
                  'في تعديلات على الموبايل ده ومش اتحفظت، وفي نسخة أحدث على حسابك. تحب تحتفظ بإيه؟',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop(ConflictResolution.keepCloud);
                },
                child: Text(
                  l10n?.backupConflictKeepCloud ?? 'النسخة اللي على الحساب',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop(ConflictResolution.keepLocal);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  l10n?.backupConflictKeepLocal ?? 'اللي على الموبايل ده',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

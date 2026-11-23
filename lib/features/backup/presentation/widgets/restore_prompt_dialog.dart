import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/backup_meta.dart';

class RestorePromptDialog {
  /// Shows the dialog when an existing backup is found on a new phone.
  /// Title: "لقينا نسخة احتياطية"
  /// Body: "لقينا بيانات محفوظة على حسابك (آخر تحديث <التاريخ والوقت>). تحب نسترجعها؟"
  /// Buttons: "استرجاع" and "ابدأ من جديد"
  static Future<void> showNewPhonePrompt({
    required BuildContext context,
    required WidgetRef ref,
    required String uid,
    required BackupMeta meta,
    required VoidCallback onRestoreConfirmed,
    required VoidCallback onStartFreshConfirmed,
  }) async {
    final l10n = AppLocalizations.of(context);
    final formattedDate = ArabicDateHelper.formatDateTime(meta.updatedAt);
    final bodyText = l10n?.backupFoundDialogBody(formattedDate) ??
        'لقينا بيانات محفوظة على حسابك (آخر تحديث $formattedDate). تحب نسترجعها؟';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l10n?.backupFoundDialogTitle ?? 'لقينا نسخة احتياطية',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.text,
            ),
          ),
          content: Text(
            bodyText,
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
                Navigator.of(dialogCtx).pop();
                _showConfirmStartFresh(
                  context: context,
                  ref: ref,
                  uid: uid,
                  meta: meta,
                  onRestoreConfirmed: onRestoreConfirmed,
                  onStartFreshConfirmed: onStartFreshConfirmed,
                );
              },
              child: Text(
                l10n?.backupStartFresh ?? 'ابدأ من جديد',
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
                Navigator.of(dialogCtx).pop();
                onRestoreConfirmed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                l10n?.backupRestore ?? 'استرجاع',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Second dialog when "ابدأ من جديد" is clicked:
  /// Title: "متأكد؟"
  /// Body: "النسخة القديمة هتتبدّل لما التطبيق يحفظ نسخة جديدة."
  /// Buttons: "ابدأ من جديد" and "رجوع"
  static Future<void> _showConfirmStartFresh({
    required BuildContext context,
    required WidgetRef ref,
    required String uid,
    required BackupMeta meta,
    required VoidCallback onRestoreConfirmed,
    required VoidCallback onStartFreshConfirmed,
  }) async {
    final l10n = AppLocalizations.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l10n?.backupConfirmStartFreshTitle ?? 'متأكد؟',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.text,
            ),
          ),
          content: Text(
            l10n?.backupConfirmStartFreshBody ??
                'النسخة القديمة هتتبدّل لما التطبيق يحفظ نسخة جديدة.',
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
                Navigator.of(dialogCtx).pop();
                // Return to first prompt
                showNewPhonePrompt(
                  context: context,
                  ref: ref,
                  uid: uid,
                  meta: meta,
                  onRestoreConfirmed: onRestoreConfirmed,
                  onStartFreshConfirmed: onStartFreshConfirmed,
                );
              },
              child: Text(
                l10n?.backupBack ?? 'رجوع',
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
                Navigator.of(dialogCtx).pop();
                onStartFreshConfirmed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                l10n?.backupStartFresh ?? 'ابدأ من جديد',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Progress dialog while restoring: "بنسترجع بياناتك..."
  static void showLoading(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.mainGreen),
                  const SizedBox(width: 20),
                  Text(
                    l10n?.backupRestoringProgress ?? 'بنسترجع بياناتك...',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


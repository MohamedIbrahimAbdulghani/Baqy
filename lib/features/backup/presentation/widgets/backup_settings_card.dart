import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../domain/exceptions/backup_exceptions.dart';
import '../providers/backup_providers.dart';
import 'restore_prompt_dialog.dart';

class BackupSettingsCard extends ConsumerStatefulWidget {
  const BackupSettingsCard({super.key});

  @override
  ConsumerState<BackupSettingsCard> createState() => _BackupSettingsCardState();
}

class _BackupSettingsCardState extends ConsumerState<BackupSettingsCard> {
  bool _isSaving = false;
  bool _isRestoring = false;

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF2C2C2C),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSaveNow() async {
    final l10n = AppLocalizations.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final uid = user.uid;
    final db = ref.read(appDatabaseProvider);
    final repo = ref.read(backupRepositoryProvider);

    setState(() => _isSaving = true);
    try {
      final hasData = await repo.hasUserData(db);
      final hasCloud = await repo.hasCloudBackup(uid);
      if (!hasData && hasCloud) {
        _showSnackbar(
          l10n?.backupSaveFailed ?? 'مقدرتش أحفظ النسخة، جرّب تاني',
        );
        return;
      }

      final meta = await repo.uploadBackup(uid: uid, db: db);
      ref.read(lastBackupTimeProvider.notifier).update(meta.updatedAt);
      _showSnackbar(
        l10n?.backupSavedSuccess ?? 'تم حفظ النسخة',
      );
    } catch (e, st) {
      debugPrint('[BACKUP_SETTINGS_ERROR] _handleSaveNow failed: $e\n$st');
      _showSnackbar(
        l10n?.backupSaveFailed ?? 'مقدرتش أحفظ النسخة، جرّب تاني',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleRestore() async {
    final l10n = AppLocalizations.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final uid = user.uid;
    final db = ref.read(appDatabaseProvider);
    final repo = ref.read(backupRepositoryProvider);

    // Ask confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l10n?.backupManualRestoreTitle ?? 'استرجاع النسخة؟',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.text,
            ),
          ),
          content: Text(
            l10n?.backupManualRestoreBody ??
                'اللي على الموبايل ده هيتبدّل بآخر نسخة محفوظة على حسابك.',
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
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                l10n?.cancel ?? 'إلغاء',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
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

    if (confirmed != true || !mounted) return;

    // Check if cloud backup exists
    setState(() => _isRestoring = true);
    final backupMeta = await repo.getCloudBackupMeta(uid);
    if (backupMeta == null || backupMeta.chunkCount == 0) {
      if (mounted) setState(() => _isRestoring = false);
      _showSnackbar(
        l10n?.backupNotFound ?? 'مفيش نسخة محفوظة',
      );
      return;
    }

    if (!mounted) return;
    RestorePromptDialog.showLoading(context);

    try {
      await repo.restoreBackup(uid: uid, db: db);
      ref.read(lastBackupTimeProvider.notifier).update(backupMeta.updatedAt);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        _showSnackbar(
          l10n?.backupRestoreSuccess ?? 'تم استرجاع بياناتك',
        );
      }
    } on NewerSchemaVersionException {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        _showSnackbar(
          l10n?.backupNewerVersionError ?? 'النسخة دي من إصدار أحدث، حدّث التطبيق',
        );
      }
    } catch (e, st) {
      debugPrint('[BACKUP_SETTINGS_RESTORE_ERROR] $e\n$st');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        _showSnackbar(
          l10n?.backupRestoreFailed ?? 'مقدرتش أسترجع بياناتك، جرّب تاني',
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lastTime = ref.watch(lastBackupTimeProvider);

    final String statusLine;
    if (lastTime != null) {
      final formatted = ArabicDateHelper.formatDateTime(lastTime);
      statusLine = l10n?.backupLastBackup(formatted) ?? 'آخر نسخة: $formatted';
    } else {
      statusLine = l10n?.backupNoBackupYet ?? 'لسه مفيش نسخة';
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: AppDimensions.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.backupCardTitle ?? 'النسخة الاحتياطية',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Icon(
                Icons.cloud_sync_outlined,
                color: AppColors.mainGreen,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusLine,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Save Now Button
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: _isSaving || _isRestoring
                        ? null
                        : () => _handleSaveNow(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.mainGreen, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.mainGreen,
                            ),
                          )
                        : Text(
                            l10n?.backupSaveNow ?? 'احفظ دلوقتي',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mainGreen,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Restore Button
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _isSaving || _isRestoring
                        ? null
                        : () => _handleRestore(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: _isRestoring
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n?.backupRestore ?? 'استرجاع',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

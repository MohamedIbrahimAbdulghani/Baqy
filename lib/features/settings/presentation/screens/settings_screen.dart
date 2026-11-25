import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/action_feedback_dialog.dart';
import '../../../../core/widgets/baqy_refresh.dart';
import '../../../../core/widgets/whatsapp_icon.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../backup/presentation/providers/backup_providers.dart';
import '../../../backup/presentation/widgets/backup_settings_card.dart';
import '../../../debts/presentation/providers/debt_providers.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../expenses/presentation/widgets/month_rollover_dialog.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../../home/presentation/controllers/budget_monitor_controller.dart';
import '../../../home/presentation/widgets/budget_bottom_sheet.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../../security/presentation/providers/security_providers.dart';
import '../../../security/presentation/widgets/pin_setup_sheet.dart';
import '../../../shell/presentation/providers/tab_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String feedbackEmail = 'mohamedibrahimabdulghani@gmail.com';
  static const String feedbackWhatsApp = 'https://wa.me/201205481045';

  Future<void> _launchEmail() async {
    final uri = Uri.parse('mailto:$feedbackEmail');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse(feedbackWhatsApp);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openBudgetSheet(
    BuildContext context,
    WidgetRef ref,
    String yearMonth,
    int monthNumber,
    int currentBudgetPiastres,
  ) async {
    final now = DateTime.now();
    final currentYm = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
    if (yearMonth.compareTo(currentYm) < 0) return;

    int? initialBudgetEgp;
    if (currentBudgetPiastres > 0) {
      initialBudgetEgp = currentBudgetPiastres ~/ 100;
    } else {
      final prevYm = ArabicDateHelper.getPreviousYearMonth(yearMonth);
      final prevBudgetPiastres =
          await ref.read(getMonthBudgetUseCaseProvider)(prevYm);
      if (prevBudgetPiastres != null && prevBudgetPiastres > 0) {
        initialBudgetEgp = prevBudgetPiastres ~/ 100;
      }
    }

    if (!context.mounted) return;

    int? savedBudgetPiastres;
    try {
      await BudgetBottomSheet.show(
        context: context,
        monthNumber: monthNumber,
        initialBudgetEgp: initialBudgetEgp,
        onSave: (budgetPiastres) async {
          final container = ProviderScope.containerOf(context, listen: false);
          await container.read(setMonthBudgetUseCaseProvider)(
            yearMonth: yearMonth,
            amount: budgetPiastres,
          );
          savedBudgetPiastres = budgetPiastres;
          final userId = container.read(activeUserIdProvider);
          await BudgetMonitorController.resetAlertFlag(yearMonth, userId: userId);
          container.invalidate(currentMonthRemainingProvider);
          container.invalidate(yearsWithDataProvider);
          final (year, _) = ArabicDateHelper.parseYearMonthKey(yearMonth);
          container.invalidate(monthsWithDataProvider(year));
        },
      );
    } catch (e) {
      debugPrint('[SETTINGS] Error showing budget sheet: $e');
    }

    if (savedBudgetPiastres != null) {
      final monthName = ArabicDateHelper.getMonthName(monthNumber);
      final formatted = '${NumberFormatter.formatCurrency(savedBudgetPiastres! ~/ 100)} جنيه';
      final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
      if (targetContext != null && targetContext.mounted) {
        await ActionFeedbackDialog.show(
          context: targetContext,
          type: ActionFeedbackType.updated,
          title: 'تم تعديل الميزانية بنجاح',
          subtitle: 'تم ضبط ميزانية شهر $monthName بمبلغ $formatted وتحديث الحسابات.',
        );
      }
    }
  }

  Future<void> _confirmResetData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9534F).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD9534F),
                  size: 26.0,
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  'تصفير جميع البيانات؟',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من رغبتك في حذف كافة البيانات والبدء من جديد تماماً؟',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12.0),
              Text(
                '• سيتم مسح جميع المصاريف والمعاملات المسجلة.\n'
                '• سيتم تصفير الميزانيات وأهداف التوفير والديون.\n'
                '• سيتم مسح النسخة الاحتياطية السحابية للبدء بحساب نظيف.\n'
                '• لا يمكن التراجع عن هذه الخطوة بعد التأكيد.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13.0,
                  color: AppColors.secondaryText,
                  height: 1.6,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 15.0,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9534F),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: const Text(
                'تصفير البيانات',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 15.0,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      // Show loading indicator
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD9534F)),
            ),
          ),
        ),
      );

      try {
        final db = ref.read(appDatabaseProvider);
        await db.clearAllData();

        // Cancel debt and reminder notifications
        await NotificationService.instance.rescheduleDebts([]);
        await NotificationService.instance.rescheduleReminders([]);

        // Handle backup & sync reset
        final syncController = ref.read(backupSyncControllerProvider);
        if (syncController != null) {
          await syncController.handleDataReset().timeout(
            const Duration(seconds: 5),
            onTimeout: () => debugPrint('[SETTINGS] handleDataReset timed out'),
          );
        } else {
          final uid = ref.read(activeUserIdProvider);
          if (uid != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('backup_last_upload_time_$uid');
            await prefs.remove('backup_last_content_hash_$uid');
            await prefs.setBool('backup_start_fresh_$uid', true);
            try {
              await ref.read(backupRepositoryProvider).deleteCloudBackup(uid).timeout(
                const Duration(seconds: 5),
                onTimeout: () {},
              );
            } catch (_) {}
          }
        }

        // Reset providers & budget monitor
        final now = DateTime.now();
        final currentYm = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
        final userId = ref.read(activeUserIdProvider);
        await BudgetMonitorController.resetAlertFlag(currentYm, userId: userId);

        // Clear stored rollover & alert keys from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final allKeys = prefs.getKeys();
        for (final key in allKeys) {
          if (key.startsWith('month_rollover_handled_') ||
              key.startsWith('budget_alert_threshold_25_')) {
            await prefs.remove(key);
          }
        }
        MonthRolloverHelper.resetSession();

        ref.read(lastBackupTimeProvider.notifier).update(null);
        ref.read(selectedYearMonthProvider.notifier).selectYearMonth(currentYm);
        // Reset auto-open flag so HomeScreen natively prompts for the fresh month's budget
        ref.read(hasAutoOpenedBudgetForMonthProvider.notifier).reset();
        ref.read(tabIndexProvider.notifier).selectTab(0);

        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(currentMonthRemainingProvider);
        ref.invalidate(yearsWithDataProvider);
        ref.invalidate(monthsWithDataProvider(now.year));
        ref.invalidate(monthCategoryTotalsProvider(currentYm));
        ref.invalidate(categoriesProvider);
        ref.invalidate(activeDebtsStreamProvider);
        ref.invalidate(settledDebtsStreamProvider);
        ref.invalidate(goalsStreamProvider);
        ref.invalidate(remindersStreamProvider);
      } finally {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // dismiss loading
        }
      }

      if (context.mounted) {
        final targetContext = rootNavigatorKey.currentContext ?? context;
        await ActionFeedbackDialog.show(
          context: targetContext,
          type: ActionFeedbackType.deleted,
          title: 'تم تصفير البيانات بنجاح',
          subtitle: 'تم مسح كافة البيانات بنجاح. يمكنك الآن إدخال ميزانيتك الجديدة للبدء من جديد.',
        );

        if (context.mounted) {
          if (GoRouter.maybeOf(context) != null) {
            context.go('/main');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final l10n = AppLocalizations.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode == 'ar';

    final selectedYm = ref.watch(selectedYearMonthProvider);
    final (year, month) = ArabicDateHelper.parseYearMonthKey(selectedYm);
    final monthName = ArabicDateHelper.getMonthName(month);
    final monthRemainingAsync = ref.watch(currentMonthRemainingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BaqyRefresh(
          onRefresh: () async {
            ref.invalidate(databaseChangesProvider);
            ref.invalidate(lastBackupTimeProvider);
            ref.invalidate(currentMonthRemainingProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Back button + Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Text(
                    l10n?.settingsTitle ?? 'الإعدادات',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isArabic
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.arrow_back_ios_rounded,
                      color: AppColors.text,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 1. User Profile Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: AppDimensions.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.mainGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: currentUser?.photoUrl != null &&
                              currentUser!.photoUrl!.isNotEmpty
                          ? Image.network(
                              currentUser.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person_rounded,
                                color: AppColors.mainGreen,
                                size: 28,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: AppColors.mainGreen,
                              size: 28,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (currentUser?.displayName != null &&
                              currentUser!.displayName!.isNotEmpty) ...[
                            Text(
                              currentUser.displayName!,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            currentUser?.email ??
                                currentUser?.displayName ??
                                'حساب جوجل',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Budget Row Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: AppDimensions.cardShadow,
                ),
                child: monthRemainingAsync.when(
                  data: (remaining) {
                    final budgetEgp = remaining.budget ~/ 100;
                    final now = DateTime.now();
                    final currentYm = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
                    final isPastMonth = selectedYm.compareTo(currentYm) < 0;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isPastMonth)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: Colors.amber.shade700.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'مؤرشف للاطلاع فقط',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => _openBudgetSheet(
                              context,
                              ref,
                              selectedYm,
                              month,
                              remaining.budget,
                            ),
                            child: Text(
                              l10n?.edit ?? 'تعديل',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mainGreen,
                              ),
                            ),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${l10n?.budgetForMonth ?? "ميزانية شهر"} $monthName',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${NumberFormatter.formatCurrency(budgetEgp)} ${l10n?.currencyEgp ?? "جنيه"}',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child:
                          CircularProgressIndicator(color: AppColors.mainGreen),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),

              const SizedBox(height: 16),

              // Backup Card
              const BackupSettingsCard(),

              const SizedBox(height: 16),

              // Theme Appearance Card (المظهر)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: AppDimensions.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المظهر',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اختر مظهر التطبيق المفضل لديك (الوضع الفاتح أو الليلي)',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Light Mode Option
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(ThemeMode.light);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: !AppColors.isDark
                                    ? AppColors.mainGreen.withValues(alpha: 0.12)
                                    : AppColors.subtleButton,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !AppColors.isDark
                                      ? AppColors.mainGreen
                                      : AppColors.dividers,
                                  width: !AppColors.isDark ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.light_mode_rounded,
                                    size: 19,
                                    color: !AppColors.isDark
                                        ? AppColors.mainGreen
                                        : AppColors.secondaryText,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'فاتح',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14,
                                      fontWeight: !AppColors.isDark
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: !AppColors.isDark
                                          ? AppColors.mainGreen
                                          : AppColors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Dark Mode Option
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(ThemeMode.dark);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.isDark
                                    ? AppColors.mainGreen.withValues(alpha: 0.15)
                                    : AppColors.subtleButton,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.isDark
                                      ? AppColors.mainGreen
                                      : AppColors.dividers,
                                  width: AppColors.isDark ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.dark_mode_rounded,
                                    size: 19,
                                    color: AppColors.isDark
                                        ? AppColors.mainGreen
                                        : AppColors.secondaryText,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ليلي',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14,
                                      fontWeight: AppColors.isDark
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: AppColors.isDark
                                          ? AppColors.mainGreen
                                          : AppColors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Privacy Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: AppDimensions.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.privacyTitle ?? 'خصوصيتك',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.privacyDescription ??
                          'بياناتك ومصاريفك بتتحفظ بأمان ومرتبطة بحساب الجيميل بتاعك لحمايتها وتقدر تسترجعها في أي وقت، ومفيش حد يقدر يوصلها.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Security Card (الأمان وقفل التطبيق)
              Builder(
                builder: (context) {
                  final securityAsync = ref.watch(securitySettingsProvider);
                  final settings = securityAsync.value;
                  final isLockEnabled = settings?.isAppLockEnabled ?? false;
                  final isBiometricsEnabled = settings?.isBiometricsEnabled ?? false;
                  final isBiometricsSupported = settings?.isBiometricsSupported ?? false;

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
                        Text(
                          'الأمان وقفل التطبيق',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'حماية تعاملاتك المالية برمز سري وبصمة الإصبع عند مغادرة التطبيق.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            color: AppColors.secondaryText,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Switch: App Lock with PIN
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.mainGreen.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.lock_outline_rounded,
                                      size: 18,
                                      color: AppColors.mainGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'قفل التطبيق برمز مرور',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: isLockEnabled,
                              activeTrackColor: AppColors.mainGreen,
                              onChanged: (val) async {
                                if (val) {
                                  await PinSetupSheet.show(
                                    context,
                                    mode: PinSetupMode.create,
                                  );
                                } else {
                                  final disabled = await PinSetupSheet.show(
                                    context,
                                    mode: PinSetupMode.disable,
                                  );
                                  if (disabled == true && context.mounted) {
                                    final targetContext = rootNavigatorKey.currentContext ?? context;
                                    await ActionFeedbackDialog.show(
                                      context: targetContext,
                                      type: ActionFeedbackType.deleted,
                                      title: 'تم إيقاف قفل التطبيق',
                                      subtitle: 'تم حذف رمز المرور وإلغاء القفل بنجاح.',
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),

                        // If Lock is enabled: Change PIN row
                        if (isLockEnabled) ...[
                          const SizedBox(height: 10),
                          Divider(color: AppColors.dividers, height: 1),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              final changed = await PinSetupSheet.show(
                                context,
                                mode: PinSetupMode.change,
                              );
                              if (changed == true && context.mounted) {
                                final targetContext = rootNavigatorKey.currentContext ?? context;
                                await ActionFeedbackDialog.show(
                                  context: targetContext,
                                  type: ActionFeedbackType.updated,
                                  title: 'تم تغيير رمز المرور',
                                  subtitle: 'تم تحديث رمز المرور بنجاح.',
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.darkGreen.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.pin_outlined,
                                            size: 18,
                                            color: AppColors.darkGreen,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'تغيير رمز المرور',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    isArabic
                                        ? Icons.arrow_back_ios_rounded
                                        : Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: AppColors.secondaryText,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Lock on exit toggle
                          const SizedBox(height: 10),
                          Divider(color: AppColors.dividers, height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.categoryTransport.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.phonelink_lock_rounded,
                                        size: 19,
                                        color: AppColors.categoryTransport,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'القفل عند مغادرة التطبيق',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      Text(
                                        'طلب الرمز فوراً عند الخروج والعودة',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 11.5,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: settings?.lockOnExit ?? true,
                                activeTrackColor: AppColors.mainGreen,
                                onChanged: (val) {
                                  ref
                                      .read(securitySettingsProvider.notifier)
                                      .setLockOnExitEnabled(val);
                                },
                              ),
                            ],
                          ),

                          // Biometrics Switch (if supported by device)
                          if (isBiometricsSupported) ...[
                            const SizedBox(height: 10),
                            Divider(color: AppColors.dividers, height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.mainGreen.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.fingerprint_rounded,
                                          size: 20,
                                          color: AppColors.mainGreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'فتح التطبيق بالبصمة',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch.adaptive(
                                  value: isBiometricsEnabled,
                                  activeTrackColor: AppColors.mainGreen,
                                  onChanged: (val) async {
                                    if (val) {
                                      final success = await ref
                                          .read(securitySettingsProvider.notifier)
                                          .authenticateBiometrics();
                                      if (success) {
                                        await ref
                                            .read(securitySettingsProvider.notifier)
                                            .setBiometricsEnabled(true);
                                      }
                                    } else {
                                      await ref
                                          .read(securitySettingsProvider.notifier)
                                          .setBiometricsEnabled(false);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 5. Feedback Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: AppDimensions.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.feedbackTitle ?? 'ابعتلنا رأيك',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n?.feedbackDescription ??
                          'عندك فكرة أو مشكلة؟ ابعتهالنا عشان نحسّن التطبيق.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // WhatsApp button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _launchWhatsApp,
                            icon: const WhatsAppIcon(size: 20.0),
                            label: Text(
                              l10n?.whatsapp ?? 'واتساب',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.mainGreen,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Email button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _launchEmail,
                            icon: const Icon(
                              Icons.mail_outline_rounded,
                              size: 18,
                              color: AppColors.mainGreen,
                            ),
                            label: const Text(
                              'إيميل',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.mainGreen,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reset Data Card
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _confirmResetData(context, ref),
                  borderRadius: BorderRadius.circular(16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: const Color(0xFFD9534F).withValues(alpha: 0.25),
                        width: 1.0,
                      ),
                      boxShadow: AppDimensions.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44.0,
                          height: 44.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9534F).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: const Icon(
                            Icons.restart_alt_rounded,
                            color: Color(0xFFD9534F),
                            size: 24.0,
                          ),
                        ),
                        const SizedBox(width: 14.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تصفير جميع البيانات',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD9534F),
                                ),
                              ),
                              const SizedBox(height: 3.0),
                              Text(
                                'حذف كافة المصاريف والديون والميزانيات للبدء من جديد',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.secondaryText.withValues(alpha: 0.6),
                          size: 24.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 5. Logout Card
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    isSigningOut = true;
                    // Flush any pending backup before signing out
                    try {
                      final syncController = ref.read(backupSyncControllerProvider);
                      if (syncController != null) {
                        await syncController.flush();
                      }
                    } catch (_) {}
                    // Navigate immediately with smooth fade animation
                    appRouter.go('/sign-in');
                    ref.read(authControllerProvider.notifier).signOut();
                    ref.read(hasAutoOpenedBudgetForMonthProvider.notifier).reset();
                    appAuthNotifier.notifyAuthChanged();
                  },
                  borderRadius: BorderRadius.circular(16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: AppDimensions.cardShadow,
                    ),
                    child: Center(
                      child: Text(
                        l10n?.signOut ?? 'تسجيل الخروج',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD9534F),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Bottom Attribution
              Center(
                child: Text(
                  l10n?.madeBy ?? 'صُنع بواسطة محمد إبراهيم',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

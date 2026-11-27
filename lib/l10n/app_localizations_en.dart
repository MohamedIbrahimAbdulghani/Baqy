// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Baqy';

  @override
  String get appNameSub => 'BAQY';

  @override
  String get tabHome => 'Home';

  @override
  String get tabGoals => 'Goals';

  @override
  String get tabAppointments => 'Appointments';

  @override
  String get tabDebts => 'Debts';

  @override
  String get signInTitle => 'Welcome to Baqy';

  @override
  String get signInSubtitle =>
      'Sign in and track your expenses with your voice';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInError => 'Couldn\'t sign you in, try again';

  @override
  String get privacyLine =>
      'Your data is securely saved and linked to your Gmail account for protection, and no one saves your voice or speech.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageLabel => 'Language';

  @override
  String get langArabic => 'عربي';

  @override
  String get langEnglish => 'English';

  @override
  String get budgetForMonth => 'Budget for';

  @override
  String get edit => 'Edit';

  @override
  String get privacyTitle => 'Your Privacy';

  @override
  String get privacyDescription =>
      'Your data and expenses are securely saved and linked to your Gmail account for protection so you can restore them anytime if you change devices, and no one else can access your data.';

  @override
  String get backupCardTitle => 'Cloud Backup';

  @override
  String backupLastBackup(String dateTime) {
    return 'Last backup: $dateTime';
  }

  @override
  String get backupNoBackupYet => 'No backup yet';

  @override
  String get backupSaveNow => 'Back up now';

  @override
  String get backupRestore => 'Restore';

  @override
  String get backupSavedSuccess => 'Backup saved successfully';

  @override
  String get backupSaveFailed => 'Couldn\'t save backup, try again';

  @override
  String get backupRestoreSuccess => 'Data restored successfully';

  @override
  String get backupRestoreFailed => 'Couldn\'t restore data, try again';

  @override
  String get backupNotFound => 'No saved backup found';

  @override
  String get backupNewerVersionError =>
      'This backup is from a newer version, update the app';

  @override
  String get backupFoundDialogTitle => 'Backup Found';

  @override
  String backupFoundDialogBody(String dateTime) {
    return 'We found saved data on your account (last updated $dateTime). Would you like to restore it?';
  }

  @override
  String get backupStartFresh => 'Start Fresh';

  @override
  String get backupConfirmStartFreshTitle => 'Are you sure?';

  @override
  String get backupConfirmStartFreshBody =>
      'The old backup will be replaced when the app saves a new backup.';

  @override
  String get backupBack => 'Back';

  @override
  String get backupRestoringProgress => 'Restoring your data...';

  @override
  String get backupManualRestoreTitle => 'Restore Backup?';

  @override
  String get backupManualRestoreBody =>
      'The data on this phone will be replaced with the latest backup saved on your account.';

  @override
  String get feedbackTitle => 'Send Us Feedback';

  @override
  String get feedbackDescription =>
      'Have an idea or an issue? Send it to help us improve the app.';

  @override
  String get gmail => 'Gmail';

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String get signOut => 'Sign Out';

  @override
  String get madeBy => 'Made by Mohamed Ibrahim';

  @override
  String get currencyEgp => 'EGP';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get recentExpenses => 'Recent Expenses';

  @override
  String get remaining => 'Remaining';

  @override
  String get spent => 'Spent';

  @override
  String get saved => 'Saved';

  @override
  String get totalBudget => 'Budget';

  @override
  String get savings => 'Savings';

  @override
  String get debt => 'Debts';

  @override
  String get monthJan => 'January';

  @override
  String get monthFeb => 'February';

  @override
  String get monthMar => 'March';

  @override
  String get monthApr => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'June';

  @override
  String get monthJul => 'July';

  @override
  String get monthAug => 'August';

  @override
  String get monthSep => 'September';

  @override
  String get monthOct => 'October';

  @override
  String get monthNov => 'November';

  @override
  String get monthDec => 'December';

  @override
  String get backupDataUpdatedSnackbar => 'Your data has been updated';

  @override
  String get backupConflictDialogTitle => 'Data Conflict';

  @override
  String get backupConflictDialogBody =>
      'There are unsaved edits on this device, and a newer version exists on your account. What would you like to keep?';

  @override
  String get backupConflictKeepLocal => 'Keep device version';

  @override
  String get backupConflictKeepCloud => 'Keep account version';

  @override
  String get refreshOffline =>
      'No connection, showing data stored on this device';

  @override
  String get refreshFailed => 'Couldn\'t refresh, try again';

  @override
  String get exportPdfTooltip => 'Export as PDF';

  @override
  String get exportPdfSemantics => 'Export month details as PDF';

  @override
  String get exportExcelTooltip => 'Export as Excel';

  @override
  String get exportExcelSemantics => 'Export month details as Excel';

  @override
  String get exportNoOperationsSnackbar => 'No operations in this month';

  @override
  String get exportFailedSnackbar => 'Couldn\'t prepare the file, try again';

  @override
  String get exportSummaryTitle => 'Month Summary';

  @override
  String get exportTotalExpenses => 'Total Expenses';

  @override
  String get exportTotalIncome => 'Total Income';

  @override
  String get exportMonthBudget => 'Month Budget';

  @override
  String get exportRemainingAmount => 'Remaining Amount';

  @override
  String get exportOperationsCount => 'Operations Count';

  @override
  String get exportCreatedAt => 'Created At';

  @override
  String get exportSheetSummary => 'Summary';

  @override
  String get exportSheetOperations => 'Operations';

  @override
  String get exportChartCategoryExpenses => 'Expenses by Category';

  @override
  String get exportChartDailyExpenses => 'Daily Expenses';

  @override
  String get exportChartCategoryPercentage => 'Category Percentage Share';

  @override
  String get exportColCategory => 'Category';

  @override
  String get exportColOperationsCount => 'Operations';

  @override
  String get exportColTotal => 'Total';

  @override
  String get exportColPercentage => 'Percentage';

  @override
  String get exportColDate => 'Date';

  @override
  String get exportColDay => 'Day';

  @override
  String get exportColTime => 'Time';

  @override
  String get exportColDescription => 'Description / Note';

  @override
  String get exportColType => 'Type';

  @override
  String get exportColAmount => 'Amount';

  @override
  String get exportTypeExpense => 'Expense';

  @override
  String get exportTypeIncome => 'Income';

  @override
  String get exportTypeSaving => 'Saving';

  @override
  String exportPageOf(String current, String total) {
    return 'Page $current of $total';
  }

  @override
  String get daySaturday => 'Saturday';

  @override
  String get daySunday => 'Sunday';

  @override
  String get dayMonday => 'Monday';

  @override
  String get dayTuesday => 'Tuesday';

  @override
  String get dayWednesday => 'Wednesday';

  @override
  String get dayThursday => 'Thursday';

  @override
  String get dayFriday => 'Friday';

  @override
  String get exportDownloadButton => 'Download to Phone';

  @override
  String get exportShareButton => 'Share File';

  @override
  String get exportSavedSuccess => 'File saved to Downloads folder';

  @override
  String get exportVisualChart => 'Visual Distribution';

  @override
  String get exportTotalLabel => 'Grand Total';

  @override
  String shortcutExpenseRecordedSingle(String amount, String category) {
    return 'Recorded $amount EGP in $category';
  }

  @override
  String shortcutExpenseRecordedMultiple(int count, String amount) {
    return 'Recorded $count expenses totaling $amount EGP';
  }

  @override
  String get undo => 'Undo';

  @override
  String get shortcutVoiceRecord => 'Voice Record';
}

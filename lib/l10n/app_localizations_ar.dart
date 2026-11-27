// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'باقي';

  @override
  String get appNameSub => 'BAQY';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabGoals => 'الأهداف';

  @override
  String get tabAppointments => 'المواعيد';

  @override
  String get tabDebts => 'الديون';

  @override
  String get signInTitle => 'أهلاً بيك في Baqy';

  @override
  String get signInSubtitle => 'سجّل دخولك وابدأ تتابع مصاريفك بصوتك';

  @override
  String get signInWithGoogle => 'الدخول بحساب جوجل';

  @override
  String get signInError => 'مقدرتش أسجّلك، جرّب تاني';

  @override
  String get privacyLine =>
      'بياناتك ومصاريفك بتتحفظ بأمان ومرتبطة بحساب الجيميل بتاعك لحمايتها، ومحدش بيحفظ صوتك أو كلامك.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get langArabic => 'عربي';

  @override
  String get langEnglish => 'English';

  @override
  String get budgetForMonth => 'ميزانية شهر';

  @override
  String get edit => 'تعديل';

  @override
  String get privacyTitle => 'خصوصيتك';

  @override
  String get privacyDescription =>
      'بياناتك ومصاريفك بتتحفظ بأمان ومرتبطة بحساب الجيميل بتاعك لحمايتها وتقدر تسترجعها في أي وقت لو غيرت تليفونك، ومفيش أي حد يقدر يطّلع على بياناتك ومصاريفك.';

  @override
  String get backupCardTitle => 'النسخة الاحتياطية';

  @override
  String backupLastBackup(String dateTime) {
    return 'آخر نسخة: $dateTime';
  }

  @override
  String get backupNoBackupYet => 'لسه مفيش نسخة';

  @override
  String get backupSaveNow => 'احفظ دلوقتي';

  @override
  String get backupRestore => 'استرجاع';

  @override
  String get backupSavedSuccess => 'تم حفظ النسخة';

  @override
  String get backupSaveFailed => 'مقدرتش أحفظ النسخة، جرّب تاني';

  @override
  String get backupRestoreSuccess => 'تم استرجاع بياناتك';

  @override
  String get backupRestoreFailed => 'مقدرتش أسترجع بياناتك، جرّب تاني';

  @override
  String get backupNotFound => 'مفيش نسخة محفوظة';

  @override
  String get backupNewerVersionError => 'النسخة دي من إصدار أحدث، حدّث التطبيق';

  @override
  String get backupFoundDialogTitle => 'لقينا نسخة احتياطية';

  @override
  String backupFoundDialogBody(String dateTime) {
    return 'لقينا بيانات محفوظة على حسابك (آخر تحديث $dateTime). تحب نسترجعها؟';
  }

  @override
  String get backupStartFresh => 'ابدأ من جديد';

  @override
  String get backupConfirmStartFreshTitle => 'متأكد؟';

  @override
  String get backupConfirmStartFreshBody =>
      'النسخة القديمة هتتبدّل لما التطبيق يحفظ نسخة جديدة.';

  @override
  String get backupBack => 'رجوع';

  @override
  String get backupRestoringProgress => 'بنسترجع بياناتك...';

  @override
  String get backupManualRestoreTitle => 'استرجاع النسخة؟';

  @override
  String get backupManualRestoreBody =>
      'اللي على الموبايل ده هيتبدّل بآخر نسخة محفوظة على حسابك.';

  @override
  String get feedbackTitle => 'ابعتلنا رأيك';

  @override
  String get feedbackDescription =>
      'عندك فكرة أو مشكلة؟ ابعتهالنا عشان نحسّن التطبيق.';

  @override
  String get gmail => 'جيميل';

  @override
  String get whatsapp => 'واتساب';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get madeBy => 'صُنع بواسطة محمد إبراهيم';

  @override
  String get currencyEgp => 'جنيه';

  @override
  String get goodMorning => 'صباح الخير';

  @override
  String get goodEvening => 'مساء الخير';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get confirm => 'تأكيد';

  @override
  String get addExpense => 'إضافة مصاريف';

  @override
  String get recentExpenses => 'آخر المصاريف';

  @override
  String get remaining => 'المتبقي';

  @override
  String get spent => 'صرفت';

  @override
  String get saved => 'حوّشت';

  @override
  String get totalBudget => 'الميزانية';

  @override
  String get savings => 'تحويش';

  @override
  String get debt => 'ديون';

  @override
  String get monthJan => 'يناير';

  @override
  String get monthFeb => 'فبراير';

  @override
  String get monthMar => 'مارس';

  @override
  String get monthApr => 'أبريل';

  @override
  String get monthMay => 'مايو';

  @override
  String get monthJun => 'يونيو';

  @override
  String get monthJul => 'يوليو';

  @override
  String get monthAug => 'أغسطس';

  @override
  String get monthSep => 'سبتمبر';

  @override
  String get monthOct => 'أكتوبر';

  @override
  String get monthNov => 'نوفمبر';

  @override
  String get monthDec => 'ديسمبر';

  @override
  String get backupDataUpdatedSnackbar => 'تم تحديث بياناتك';

  @override
  String get backupConflictDialogTitle => 'في تعارض في البيانات';

  @override
  String get backupConflictDialogBody =>
      'في تعديلات على الموبايل ده ومش اتحفظت، وفي نسخة أحدث على حسابك. تحب تحتفظ بإيه؟';

  @override
  String get backupConflictKeepLocal => 'اللي على الموبايل ده';

  @override
  String get backupConflictKeepCloud => 'النسخة اللي على الحساب';

  @override
  String get refreshOffline => 'مفيش اتصال، اتعرضت البيانات اللي على الموبايل';

  @override
  String get refreshFailed => 'مقدرتش أحدّث، جرّب تاني';

  @override
  String get exportPdfTooltip => 'تصدير كملف PDF';

  @override
  String get exportPdfSemantics => 'تصدير تفاصيل الشهر كملف PDF';

  @override
  String get exportExcelTooltip => 'تصدير كملف Excel';

  @override
  String get exportExcelSemantics => 'تصدير تفاصيل الشهر كملف Excel';

  @override
  String get exportNoOperationsSnackbar => 'مفيش عمليات في الشهر ده';

  @override
  String get exportFailedSnackbar => 'مقدرتش أجهّز الملف، جرّب تاني';

  @override
  String get exportSummaryTitle => 'ملخص الشهر';

  @override
  String get exportTotalExpenses => 'إجمالي المصاريف';

  @override
  String get exportTotalIncome => 'إجمالي الدخل';

  @override
  String get exportMonthBudget => 'ميزانية الشهر';

  @override
  String get exportRemainingAmount => 'المبلغ المتبقي';

  @override
  String get exportOperationsCount => 'عدد العمليات';

  @override
  String get exportCreatedAt => 'تاريخ الإنشاء';

  @override
  String get exportSheetSummary => 'ملخص';

  @override
  String get exportSheetOperations => 'العمليات';

  @override
  String get exportChartCategoryExpenses => 'توزيع المصاريف حسب التصنيف';

  @override
  String get exportChartDailyExpenses => 'المصاريف اليومية خلال الشهر';

  @override
  String get exportChartCategoryPercentage => 'نسبة كل تصنيف من المصاريف';

  @override
  String get exportColCategory => 'التصنيف';

  @override
  String get exportColOperationsCount => 'عدد العمليات';

  @override
  String get exportColTotal => 'الإجمالي';

  @override
  String get exportColPercentage => 'النسبة';

  @override
  String get exportColDate => 'التاريخ';

  @override
  String get exportColDay => 'اليوم';

  @override
  String get exportColTime => 'الوقت';

  @override
  String get exportColDescription => 'البيان / الملاحظة';

  @override
  String get exportColType => 'النوع';

  @override
  String get exportColAmount => 'المبلغ';

  @override
  String get exportTypeExpense => 'مصروف';

  @override
  String get exportTypeIncome => 'دخل';

  @override
  String get exportTypeSaving => 'تحويش';

  @override
  String exportPageOf(String current, String total) {
    return 'صفحة $current من $total';
  }

  @override
  String get daySaturday => 'السبت';

  @override
  String get daySunday => 'الأحد';

  @override
  String get dayMonday => 'الاثنين';

  @override
  String get dayTuesday => 'الثلاثاء';

  @override
  String get dayWednesday => 'الأربعاء';

  @override
  String get dayThursday => 'الخميس';

  @override
  String get dayFriday => 'الجمعة';

  @override
  String get exportDownloadButton => 'تحميل على الهاتف';

  @override
  String get exportShareButton => 'مشاركة الملف';

  @override
  String get exportSavedSuccess => 'تم حفظ الملف في مجلد التنزيلات (Downloads)';

  @override
  String get exportVisualChart => 'التمثيل البياني';

  @override
  String get exportTotalLabel => 'الإجمالي العام';

  @override
  String shortcutExpenseRecordedSingle(String amount, String category) {
    return 'تم تسجيل $amount جنيه في $category';
  }

  @override
  String shortcutExpenseRecordedMultiple(int count, String amount) {
    return 'تم تسجيل $count مصاريف بقيمة $amount جنيه';
  }

  @override
  String get undo => 'تراجع';

  @override
  String get shortcutVoiceRecord => 'تسجيل بالصوت';
}

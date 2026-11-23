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
}

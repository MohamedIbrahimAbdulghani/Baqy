import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'باقي'**
  String get appTitle;

  /// No description provided for @appNameSub.
  ///
  /// In ar, this message translates to:
  /// **'BAQY'**
  String get appNameSub;

  /// No description provided for @tabHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get tabHome;

  /// No description provided for @tabGoals.
  ///
  /// In ar, this message translates to:
  /// **'الأهداف'**
  String get tabGoals;

  /// No description provided for @tabAppointments.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد'**
  String get tabAppointments;

  /// No description provided for @tabDebts.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get tabDebts;

  /// No description provided for @signInTitle.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بيك في Baqy'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخولك وابدأ تتابع مصاريفك بصوتك'**
  String get signInSubtitle;

  /// No description provided for @signInWithGoogle.
  ///
  /// In ar, this message translates to:
  /// **'الدخول بحساب جوجل'**
  String get signInWithGoogle;

  /// No description provided for @signInError.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أسجّلك، جرّب تاني'**
  String get signInError;

  /// No description provided for @privacyLine.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك ومصاريفك بتتحفظ بأمان ومرتبطة بحساب الجيميل بتاعك لحمايتها، ومحدش بيحفظ صوتك أو كلامك.'**
  String get privacyLine;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @languageLabel.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get languageLabel;

  /// No description provided for @langArabic.
  ///
  /// In ar, this message translates to:
  /// **'عربي'**
  String get langArabic;

  /// No description provided for @langEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @budgetForMonth.
  ///
  /// In ar, this message translates to:
  /// **'ميزانية شهر'**
  String get budgetForMonth;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @privacyTitle.
  ///
  /// In ar, this message translates to:
  /// **'خصوصيتك'**
  String get privacyTitle;

  /// No description provided for @privacyDescription.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك ومصاريفك بتتحفظ بأمان ومرتبطة بحساب الجيميل بتاعك لحمايتها وتقدر تسترجعها في أي وقت لو غيرت تليفونك، ومفيش أي حد يقدر يطّلع على بياناتك ومصاريفك.'**
  String get privacyDescription;

  /// No description provided for @backupCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخة الاحتياطية'**
  String get backupCardTitle;

  /// No description provided for @backupLastBackup.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة: {dateTime}'**
  String backupLastBackup(String dateTime);

  /// No description provided for @backupNoBackupYet.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش نسخة'**
  String get backupNoBackupYet;

  /// No description provided for @backupSaveNow.
  ///
  /// In ar, this message translates to:
  /// **'احفظ دلوقتي'**
  String get backupSaveNow;

  /// No description provided for @backupRestore.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع'**
  String get backupRestore;

  /// No description provided for @backupSavedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ النسخة'**
  String get backupSavedSuccess;

  /// No description provided for @backupSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أحفظ النسخة، جرّب تاني'**
  String get backupSaveFailed;

  /// No description provided for @backupRestoreSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم استرجاع بياناتك'**
  String get backupRestoreSuccess;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أسترجع بياناتك، جرّب تاني'**
  String get backupRestoreFailed;

  /// No description provided for @backupNotFound.
  ///
  /// In ar, this message translates to:
  /// **'مفيش نسخة محفوظة'**
  String get backupNotFound;

  /// No description provided for @backupNewerVersionError.
  ///
  /// In ar, this message translates to:
  /// **'النسخة دي من إصدار أحدث، حدّث التطبيق'**
  String get backupNewerVersionError;

  /// No description provided for @backupFoundDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'لقينا نسخة احتياطية'**
  String get backupFoundDialogTitle;

  /// No description provided for @backupFoundDialogBody.
  ///
  /// In ar, this message translates to:
  /// **'لقينا بيانات محفوظة على حسابك (آخر تحديث {dateTime}). تحب نسترجعها؟'**
  String backupFoundDialogBody(String dateTime);

  /// No description provided for @backupStartFresh.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ من جديد'**
  String get backupStartFresh;

  /// No description provided for @backupConfirmStartFreshTitle.
  ///
  /// In ar, this message translates to:
  /// **'متأكد؟'**
  String get backupConfirmStartFreshTitle;

  /// No description provided for @backupConfirmStartFreshBody.
  ///
  /// In ar, this message translates to:
  /// **'النسخة القديمة هتتبدّل لما التطبيق يحفظ نسخة جديدة.'**
  String get backupConfirmStartFreshBody;

  /// No description provided for @backupBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get backupBack;

  /// No description provided for @backupRestoringProgress.
  ///
  /// In ar, this message translates to:
  /// **'بنسترجع بياناتك...'**
  String get backupRestoringProgress;

  /// No description provided for @backupManualRestoreTitle.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع النسخة؟'**
  String get backupManualRestoreTitle;

  /// No description provided for @backupManualRestoreBody.
  ///
  /// In ar, this message translates to:
  /// **'اللي على الموبايل ده هيتبدّل بآخر نسخة محفوظة على حسابك.'**
  String get backupManualRestoreBody;

  /// No description provided for @feedbackTitle.
  ///
  /// In ar, this message translates to:
  /// **'ابعتلنا رأيك'**
  String get feedbackTitle;

  /// No description provided for @feedbackDescription.
  ///
  /// In ar, this message translates to:
  /// **'عندك فكرة أو مشكلة؟ ابعتهالنا عشان نحسّن التطبيق.'**
  String get feedbackDescription;

  /// No description provided for @gmail.
  ///
  /// In ar, this message translates to:
  /// **'جيميل'**
  String get gmail;

  /// No description provided for @whatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get whatsapp;

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// No description provided for @madeBy.
  ///
  /// In ar, this message translates to:
  /// **'صُنع بواسطة محمد إبراهيم'**
  String get madeBy;

  /// No description provided for @currencyEgp.
  ///
  /// In ar, this message translates to:
  /// **'جنيه'**
  String get currencyEgp;

  /// No description provided for @goodMorning.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير'**
  String get goodMorning;

  /// No description provided for @goodEvening.
  ///
  /// In ar, this message translates to:
  /// **'مساء الخير'**
  String get goodEvening;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @addExpense.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مصاريف'**
  String get addExpense;

  /// No description provided for @recentExpenses.
  ///
  /// In ar, this message translates to:
  /// **'آخر المصاريف'**
  String get recentExpenses;

  /// No description provided for @remaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get remaining;

  /// No description provided for @spent.
  ///
  /// In ar, this message translates to:
  /// **'صرفت'**
  String get spent;

  /// No description provided for @saved.
  ///
  /// In ar, this message translates to:
  /// **'حوّشت'**
  String get saved;

  /// No description provided for @totalBudget.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get totalBudget;

  /// No description provided for @savings.
  ///
  /// In ar, this message translates to:
  /// **'تحويش'**
  String get savings;

  /// No description provided for @debt.
  ///
  /// In ar, this message translates to:
  /// **'ديون'**
  String get debt;

  /// No description provided for @monthJan.
  ///
  /// In ar, this message translates to:
  /// **'يناير'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In ar, this message translates to:
  /// **'فبراير'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In ar, this message translates to:
  /// **'مارس'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In ar, this message translates to:
  /// **'أبريل'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In ar, this message translates to:
  /// **'مايو'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In ar, this message translates to:
  /// **'يونيو'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In ar, this message translates to:
  /// **'يوليو'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In ar, this message translates to:
  /// **'أغسطس'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In ar, this message translates to:
  /// **'سبتمبر'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In ar, this message translates to:
  /// **'أكتوبر'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In ar, this message translates to:
  /// **'نوفمبر'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In ar, this message translates to:
  /// **'ديسمبر'**
  String get monthDec;

  /// No description provided for @backupDataUpdatedSnackbar.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث بياناتك'**
  String get backupDataUpdatedSnackbar;

  /// No description provided for @backupConflictDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'في تعارض في البيانات'**
  String get backupConflictDialogTitle;

  /// No description provided for @backupConflictDialogBody.
  ///
  /// In ar, this message translates to:
  /// **'في تعديلات على الموبايل ده ومش اتحفظت، وفي نسخة أحدث على حسابك. تحب تحتفظ بإيه؟'**
  String get backupConflictDialogBody;

  /// No description provided for @backupConflictKeepLocal.
  ///
  /// In ar, this message translates to:
  /// **'اللي على الموبايل ده'**
  String get backupConflictKeepLocal;

  /// No description provided for @backupConflictKeepCloud.
  ///
  /// In ar, this message translates to:
  /// **'النسخة اللي على الحساب'**
  String get backupConflictKeepCloud;

  /// No description provided for @refreshOffline.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال، اتعرضت البيانات اللي على الموبايل'**
  String get refreshOffline;

  /// No description provided for @refreshFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أحدّث، جرّب تاني'**
  String get refreshFailed;

  /// No description provided for @exportPdfTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تصدير كملف PDF'**
  String get exportPdfTooltip;

  /// No description provided for @exportPdfSemantics.
  ///
  /// In ar, this message translates to:
  /// **'تصدير تفاصيل الشهر كملف PDF'**
  String get exportPdfSemantics;

  /// No description provided for @exportExcelTooltip.
  ///
  /// In ar, this message translates to:
  /// **'تصدير كملف Excel'**
  String get exportExcelTooltip;

  /// No description provided for @exportExcelSemantics.
  ///
  /// In ar, this message translates to:
  /// **'تصدير تفاصيل الشهر كملف Excel'**
  String get exportExcelSemantics;

  /// No description provided for @exportNoOperationsSnackbar.
  ///
  /// In ar, this message translates to:
  /// **'مفيش عمليات في الشهر ده'**
  String get exportNoOperationsSnackbar;

  /// No description provided for @exportFailedSnackbar.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أجهّز الملف، جرّب تاني'**
  String get exportFailedSnackbar;

  /// No description provided for @exportSummaryTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الشهر'**
  String get exportSummaryTitle;

  /// No description provided for @exportTotalExpenses.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المصاريف'**
  String get exportTotalExpenses;

  /// No description provided for @exportTotalIncome.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الدخل'**
  String get exportTotalIncome;

  /// No description provided for @exportMonthBudget.
  ///
  /// In ar, this message translates to:
  /// **'ميزانية الشهر'**
  String get exportMonthBudget;

  /// No description provided for @exportRemainingAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المتبقي'**
  String get exportRemainingAmount;

  /// No description provided for @exportOperationsCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد العمليات'**
  String get exportOperationsCount;

  /// No description provided for @exportCreatedAt.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإنشاء'**
  String get exportCreatedAt;

  /// No description provided for @exportSheetSummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص'**
  String get exportSheetSummary;

  /// No description provided for @exportSheetOperations.
  ///
  /// In ar, this message translates to:
  /// **'العمليات'**
  String get exportSheetOperations;

  /// No description provided for @exportChartCategoryExpenses.
  ///
  /// In ar, this message translates to:
  /// **'توزيع المصاريف حسب التصنيف'**
  String get exportChartCategoryExpenses;

  /// No description provided for @exportChartDailyExpenses.
  ///
  /// In ar, this message translates to:
  /// **'المصاريف اليومية خلال الشهر'**
  String get exportChartDailyExpenses;

  /// No description provided for @exportChartCategoryPercentage.
  ///
  /// In ar, this message translates to:
  /// **'نسبة كل تصنيف من المصاريف'**
  String get exportChartCategoryPercentage;

  /// No description provided for @exportColCategory.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get exportColCategory;

  /// No description provided for @exportColOperationsCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد العمليات'**
  String get exportColOperationsCount;

  /// No description provided for @exportColTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get exportColTotal;

  /// No description provided for @exportColPercentage.
  ///
  /// In ar, this message translates to:
  /// **'النسبة'**
  String get exportColPercentage;

  /// No description provided for @exportColDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get exportColDate;

  /// No description provided for @exportColDay.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get exportColDay;

  /// No description provided for @exportColTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get exportColTime;

  /// No description provided for @exportColDescription.
  ///
  /// In ar, this message translates to:
  /// **'البيان / الملاحظة'**
  String get exportColDescription;

  /// No description provided for @exportColType.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get exportColType;

  /// No description provided for @exportColAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get exportColAmount;

  /// No description provided for @exportTypeExpense.
  ///
  /// In ar, this message translates to:
  /// **'مصروف'**
  String get exportTypeExpense;

  /// No description provided for @exportTypeIncome.
  ///
  /// In ar, this message translates to:
  /// **'دخل'**
  String get exportTypeIncome;

  /// No description provided for @exportTypeSaving.
  ///
  /// In ar, this message translates to:
  /// **'تحويش'**
  String get exportTypeSaving;

  /// No description provided for @exportPageOf.
  ///
  /// In ar, this message translates to:
  /// **'صفحة {current} من {total}'**
  String exportPageOf(String current, String total);

  /// No description provided for @daySaturday.
  ///
  /// In ar, this message translates to:
  /// **'السبت'**
  String get daySaturday;

  /// No description provided for @daySunday.
  ///
  /// In ar, this message translates to:
  /// **'الأحد'**
  String get daySunday;

  /// No description provided for @dayMonday.
  ///
  /// In ar, this message translates to:
  /// **'الاثنين'**
  String get dayMonday;

  /// No description provided for @dayTuesday.
  ///
  /// In ar, this message translates to:
  /// **'الثلاثاء'**
  String get dayTuesday;

  /// No description provided for @dayWednesday.
  ///
  /// In ar, this message translates to:
  /// **'الأربعاء'**
  String get dayWednesday;

  /// No description provided for @dayThursday.
  ///
  /// In ar, this message translates to:
  /// **'الخميس'**
  String get dayThursday;

  /// No description provided for @dayFriday.
  ///
  /// In ar, this message translates to:
  /// **'الجمعة'**
  String get dayFriday;

  /// No description provided for @exportDownloadButton.
  ///
  /// In ar, this message translates to:
  /// **'تحميل على الهاتف'**
  String get exportDownloadButton;

  /// No description provided for @exportShareButton.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الملف'**
  String get exportShareButton;

  /// No description provided for @exportSavedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الملف في مجلد التنزيلات (Downloads)'**
  String get exportSavedSuccess;

  /// No description provided for @exportVisualChart.
  ///
  /// In ar, this message translates to:
  /// **'التمثيل البياني'**
  String get exportVisualChart;

  /// No description provided for @exportTotalLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي العام'**
  String get exportTotalLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

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
  /// **'بياناتك بتتحفظ على موبايلك إنت بس، ومفيش حد في الفريق يقدر يشوفها.'**
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
  /// **'بياناتك بتتحفظ على موبايلك إنت بس، ومفيش حد في الفريق يقدر يشوفها.'**
  String get privacyDescription;

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

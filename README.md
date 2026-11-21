<div align="center">

# 💰 باقي | Baqy

**تطبيق أندرويد لتتبع المصاريف الشهرية، الميزانية، والأهداف المالية — بالعربي وبالصوت بالعامية المصرية.**

*An intuitive, privacy-first Android expense tracker with Egyptian-Arabic voice logging, local SQLite encryption, and smart monthly budgeting.*

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.x%20Stable-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Architecture-4E8B7A?style=for-the-badge)](https://blog.cleancoder.com/)
[![State Management](https://img.shields.io/badge/State-Riverpod-00599C?style=for-the-badge)](https://riverpod.dev)
[![Database](https://img.shields.io/badge/Database-Drift%20%2B%20SQLCipher-E8A83A?style=for-the-badge)](https://drift.simonbinder.eu/)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)

</div>

---

## 🌟 نبذة عن التطبيق

تطبيق **باقي** معمول عشان يجاوب على أهم سؤال بيشغل بالك طول الشهر: **"فاضلي كام الشهر ده؟"**

- 🎯 **ميزانية ذكية وحلقة تفاعلية:** بتحدد ميزانيتك الشهرية، وحلقة الشاشة الرئيسية بتعرضلك المتبقي ونسبة الصرف والتحويش لحظة بلحظة.
- 🎙️ **تسجيل المصاريف بالصوت (عامية مصرية):** بضغطة زرار على المايك اتكلم بطبيعتك (مثلاً: *"اتغديت بتمانين وركبت مواصلات بخمسة وعشرين"*) والذكاء الاصطناعي بيوزع المصاريف ويسجلها فوراً دون أي تعقيد.
- 🔒 **أمان وخصوصية 100%:** جميع بياناتك المالية بتتسجل محلياً على جهازك داخل قاعدة بيانات مشفرة بالكامل بـ **SQLCipher**، ومفتاح التشفير محفوظ داخل **Android Keystore**.
- 🏆 **أهداف مالية وتحويش:** خطط لأهدافك وحوش فيها أو اسحب منها بسهولة مع حساب فوري للمتبقي ومعدل التوفير.
- ⏰ **مواعيد واشتراكات:** مواعيد دورية أو لمرة واحدة مع إشعارات تذكير ذكية على جهازك قبل موعد الاستحقاق.
- 🤝 **سجل الديون:** إدارة كاملة للديون (عليا / ليا) ومتابعة دفعات السداد الجزئي والكامل وأرشيف الديون المسددة.

---

## 📱 معرض شاشات التطبيق (Screenshots)

### ١. البداية وتسجيل الدخول
<table align="center">
  <tr>
    <td align="center"><b>شاشة البداية (Splash)</b></td>
    <td align="center"><b>تسجيل الدخول (Google Sign-In)</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/01_splash.png" width="260" alt="Splash Screen" /></td>
    <td><img src="docs/screenshots/02_sign_in.png" width="260" alt="Sign In Screen" /></td>
  </tr>
</table>

<br/>

### ٢. الشاشة الرئيسية والميزانية
<table align="center">
  <tr>
    <td align="center"><b>الرئيسية وحلقة الميزانية</b></td>
    <td align="center"><b>قائمة الإجراءات السريعة (+)</b></td>
    <td align="center"><b>تعديل ميزانية الشهر</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/03_home.png" width="240" alt="Home Screen" /></td>
    <td><img src="docs/screenshots/04_home_quick_actions.png" width="240" alt="Quick Actions Menu" /></td>
    <td><img src="docs/screenshots/05_home_edit_budget.png" width="240" alt="Edit Budget" /></td>
  </tr>
</table>

<br/>

### ٣. تصفح التواريخ والشهور
<table align="center">
  <tr>
    <td align="center"><b>قائمة الشهور</b></td>
    <td align="center"><b>قائمة السنين</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/06_home_month_picker.png" width="260" alt="Month Picker" /></td>
    <td><img src="docs/screenshots/07_home_year_picker.png" width="260" alt="Year Picker" /></td>
  </tr>
</table>

<br/>

### ٤. التسجيل الصوتي بالعامية المصرية
<table align="center">
  <tr>
    <td align="center"><b>أثناء التسجيل الصوتي</b></td>
    <td align="center"><b>بعد المعالجة والحفظ التلقائي</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/08_voice_recording.png" width="260" alt="Voice Recording" /></td>
    <td><img src="docs/screenshots/09_voice_success.png" width="260" alt="Voice Success" /></td>
  </tr>
</table>

<br/>

### ٥. إضافة المصاريف والتصنيفات
<table align="center">
  <tr>
    <td align="center"><b>إضافة مصروف بالكتابة</b></td>
    <td align="center"><b>إنشاء تصنيف جديد مخصص</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/10_add_expense_manual.png" width="260" alt="Add Expense Manual" /></td>
    <td><img src="docs/screenshots/11_add_category.png" width="260" alt="New Category" /></td>
  </tr>
</table>

<br/>

### ٦. تفاصيل وتحليلات الشهر
<table align="center">
  <tr>
    <td align="center"><b>تفاصيل الشهر ومصاريف اليوم</b></td>
    <td align="center"><b>التنقل بين الأيام السابقة</b></td>
    <td align="center"><b>تفاصيل مصاريف النوع المحدد</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/12_month_details_today.png" width="240" alt="Month Details Today" /></td>
    <td><img src="docs/screenshots/13_month_details_by_day.png" width="240" alt="Month Details By Day" /></td>
    <td><img src="docs/screenshots/14_category_breakdown.png" width="240" alt="Category Breakdown" /></td>
  </tr>
</table>

<br/>

### ٧. الأهداف المالية والتحويش
<table align="center">
  <tr>
    <td align="center"><b>قائمة الأهداف</b></td>
    <td align="center"><b>إضافة هدف جديد</b></td>
    <td align="center"><b>تفاصيل الهدف والتحويش والسحب</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/15_goals_list.png" width="240" alt="Goals List" /></td>
    <td><img src="docs/screenshots/16_add_goal.png" width="240" alt="Add Goal" /></td>
    <td><img src="docs/screenshots/17_goal_details.png" width="240" alt="Goal Details" /></td>
  </tr>
</table>

<br/>

### ٨. المواعيد والإشعارات المجدولة
<table align="center">
  <tr>
    <td align="center"><b>قائمة المواعيد والالتزامات</b></td>
    <td align="center"><b>إضافة موعد أو قسط</b></td>
    <td align="center"><b>إشعار التذكير المحلي</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/18_reminders_list.png" width="240" alt="Reminders List" /></td>
    <td><img src="docs/screenshots/19_add_reminder.png" width="240" alt="Add Reminder" /></td>
    <td><img src="docs/screenshots/20_notification_reminder.png" width="240" alt="Notification Reminder" /></td>
  </tr>
</table>

<br/>

### ٩. إدارة الديون والالتزامات
<table align="center">
  <tr>
    <td align="center"><b>سجل الديون (عليا / ليا)</b></td>
    <td align="center"><b>إضافة دين جديد</b></td>
    <td align="center"><b>تفاصيل الدين ودفعات السداد</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/21_debts_list.png" width="240" alt="Debts List" /></td>
    <td><img src="docs/screenshots/22_add_debt.png" width="240" alt="Add Debt" /></td>
    <td><img src="docs/screenshots/23_debt_details.png" width="240" alt="Debt Details" /></td>
  </tr>
</table>

<br/>

### ١٠. الإعدادات وتخصيص المظهر (Dark & Light Mode)
<table align="center">
  <tr>
    <td align="center"><b>شاشة الإعدادات، الثيم، والحساب</b></td>
    <td align="center"><b>الوضع الليلي (Dark Mode)</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/24_settings.png" width="260" alt="Settings Screen" /></td>
    <td><img src="docs/screenshots/home_dark_mode.png" width="260" alt="Dark Mode Home" /></td>
  </tr>
</table>

---

## 🛠️ التقنيات المستخدمة (Tech Stack)

| الغرض / الميزة | التقنية / المكتبة | الوصف |
|---|---|---|
| **الإطار الأساسي** | `Flutter` & `Dart` | بناء التطبيق بأداء عالي وتجربة Native سلسة |
| **المعمارية** | `Clean Architecture` | تقسيم المشروع لـ Presentation, Domain, Data مع Feature-First |
| **إدارة الحالة** | `Riverpod` (`flutter_riverpod`) | إدارة تدفق البيانات وتحديث الواجهات بكفاءة واختبارية عالية |
| **قاعدة البيانات** | `Drift` + `SQLCipher` | قاعدة بيانات محلية Relational فائقة السرعة مع تشفير كامل 256-bit |
| **تخزين المفاتيح** | `flutter_secure_storage` | حفظ مفتاح التشفير داخل بيئة Android Keystore المشفرة |
| **التنقل والروابط** | `go_router` | نظام توجيه مسارات مركزي وDeclartive Routing |
| **فهم الصوت والذكاء الاصطناعي** | `speech_to_text` + Gemini AI & Pure Dart Regex Engine | التعرف على الصوت وتحليل اللهجة العامية المصرية مع Fallback محلي كامل |
| **الإشعارات المجدولة** | `flutter_local_notifications` + `timezone` | جدولة التنبيهات المحلية بدقة حسب التوقيت المحلي (Africa/Cairo) |
| **الهوية والمصادقة** | `Firebase Auth` + `Google Sign In` | تسجيل دخول آمن بالهوية فقط دون رفع أي بيانات مالية |
| **الخط والتصميم** | خط `Cairo` وتنسيق RTL أصيل | خط عربي أنيق مدمج مع دعم كامل للأرقام العربية المشرقية والإنجليزية |

---

## 🏗️ هيكل المشروع (Project Structure)

تم بناء المشروع باتباع مبادئ **Clean Architecture** و**Feature-First Pattern**:

```text
lib/
├── core/
│   ├── constants/        # ألوان التطبيق، الثوابت، وأيقونات النظام
│   ├── database/         # إعداد Drift وSQLCipher وإدارة اتصالات الحسابات
│   ├── errors/           # كلاسات الفشل والأخطاء الموحدة (Failures)
│   ├── network/          # عميل الشبكة والمزامنة
│   ├── routing/          # تعريف المسارات عبر GoRouter
│   ├── services/         # خدمات الإشعارات، الصوت، والنسخ الاحتياطي
│   ├── theme/            # ثيم التطبيق والألوان (Light & Dark)
│   ├── utils/            # منسق الأرقام، مساعد الأيقونات، والتاريخ
│   └── widgets/          # عناصر الواجهة المشتركة والقابلة لإعادة الاستخدام
│
├── features/
│   ├── auth/             # تسجيل الدخول بجوجل وإدارة حالة الحساب
│   ├── debts/            # إدارة الديون وسجل الدفعات
│   ├── expenses/         # إضافة المصروف، التصنيفات، ومحلل الصوت المصري
│   ├── goals/            # الأهداف المالية، التحويش، والسحب
│   ├── home/             # الشاشة الرئيسية، حلقة الميزانية، وتصفح الشهور
│   ├── month_details/    # تحليلات الشهر، الرسم البياني، ومصاريف الأيام
│   ├── reminders/        # المواعيد، الاشتراكات، وجدولة الإشعارات
│   ├── security/         # فحص أمان الجهاز وحماية الجلسة
│   ├── settings/         # الإعدادات، الثيم، ومسح وتصدير البيانات
│   ├── shell/            # الإطار الخارجي وشريط التنقل السفلي
│   └── splash/           # شاشة البداية وفحص التوجيه الأولي
│
└── main.dart             # نقطة انطلاق التطبيق وتهيئة الخدمات
```

---

## 🔐 الأمان والخصوصية (Privacy & Security)

- 🔒 **تشفير كامل للبيانات:** قاعدة البيانات مشفرة باستخدام معيار AES-256 عبر SQLCipher.
- 🔑 **مفاتيح التشفير:** يتم توليد مفتاح عشوائي فريد لكل جهاز، ويُخزن في Android Keystore الآمن، ولا يمكن استخراجه أو الوصول إليه خارج التطبيق.
- 🛡️ **Offline-First:** جميع معاملاتك المالية وحساباتك وأهدافك لا تغادر هاتفك إطلاقاً، وتظل ملكاً لك وحدك.
- 👤 **تسجيل الدخول:** يتم استخدام Google Auth فقط لتأكيد الهوية وعزل قاعدة بيانات كل حساب على الجهاز.

---

## 🚀 طريقة تشغيل المشروع محلياً (Getting Started)

### المتطلبات الأساسية
- مثبت **Flutter SDK** (الإصدار 3.24+ أو أحدث).
- بيئة **Android Studio** مع Android SDK وJava 17.
- هاتف أندرويد حقيقي أو محاكي (Android Emulator).

### خطوات التثبيت والتشغيل

1. **استنساخ المستودع (Clone Repository):**
   ```bash
   git clone https://github.com/your-username/Baqy.git
   cd Baqy
   ```

2. **تثبيت الحزم والاعتماديات:**
   ```bash
   flutter pub get
   ```

3. **توليد ملفات الكود المساعد (Drift & Code Generation):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **تشغيل الفحص الآلي للاختبارات:**
   ```bash
   flutter test
   ```

5. **تشغيل التطبيق على الهاتف / المحاكي:**
   ```bash
   flutter run
   ```

---

## 👨‍💻 المطور (Author)

**محمد إبراهيم (Mohamed Ibrahim)**
- تخصص: تطوير تطبيقات الهاتف المحمول باستخدام Flutter.
- رؤية المشروع: تقديم حل مالي عربي بسيط، أنيق، وسريع يعتمد على الخصوصية والذكاء وسهولة الاستخدام اليومي.

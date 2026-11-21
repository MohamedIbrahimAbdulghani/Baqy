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

## 💡 فكرة المشروع

تطبيق **باقي** معمول عشان يجاوب على أهم سؤال بيشغل بالك طول الشهر:

> **"فاضلي كام الشهر ده؟"**

بتحدد ميزانيتك، وتسجل مصاريفك بالكتابة أو بالصوت بالعامية المصرية، والتطبيق بيحسبلك المتبقي ونسبة الصرف لحظة بلحظة — من غير تعقيد، ومن غير ما بياناتك تسيب موبايلك.

### إزاي بيشتغل؟

1. **حدد ميزانية الشهر** — حلقة الشاشة الرئيسية بتوريك الباقي أول بأول.
2. **سجل مصروفك** — اضغط على المايك وقول: *"اتغديت بتمانين وركبت مواصلات بخمسة وعشرين"* والتطبيق يوزعها ويسجلها لوحده.
3. **تابع وحلل** — شوف مصاريف الشهر حسب اليوم والتصنيف.
4. **نظّم التزاماتك** — أهداف تحويش، مواعيد واشتراكات، وسجل ديون.

---

## 📱 لقطات من التطبيق

<table align="center">
  <tr>
    <td align="center"><b>الرئيسية وحلقة الميزانية</b></td>
    <td align="center"><b>التسجيل بالصوت</b></td>
    <td align="center"><b>الحفظ التلقائي</b></td>
    <td align="center"><b>تفاصيل الشهر</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/03_home.png" width="200" alt="Home" /></td>
    <td><img src="docs/screenshots/08_voice_recording.png" width="200" alt="Voice Recording" /></td>
    <td><img src="docs/screenshots/09_voice_success.png" width="200" alt="Voice Success" /></td>
    <td><img src="docs/screenshots/12_month_details_today.png" width="200" alt="Month Details" /></td>
  </tr>
  <tr>
    <td align="center"><b>الأهداف والتحويش</b></td>
    <td align="center"><b>المواعيد والاشتراكات</b></td>
    <td align="center"><b>سجل الديون</b></td>
    <td align="center"><b>الوضع الليلي</b></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/17_goal_details.png" width="200" alt="Goal Details" /></td>
    <td><img src="docs/screenshots/18_reminders_list.png" width="200" alt="Reminders" /></td>
    <td><img src="docs/screenshots/21_debts_list.png" width="200" alt="Debts" /></td>
    <td><img src="docs/screenshots/home_dark_mode.png" width="200" alt="Dark Mode" /></td>
  </tr>
</table>

---

## 🌟 أهم المميزات

- 🎯 **ميزانية ذكية:** حلقة تفاعلية بتعرض المتبقي ونسبة الصرف.
- 🎙️ **تسجيل بالصوت بالعامية المصرية:** Gemini AI مع محلل Regex محلي كـ Fallback.
- 🏆 **أهداف مالية:** حوّش أو اسحب مع حساب فوري للمتبقي.
- ⏰ **مواعيد واشتراكات:** إشعارات تذكير قبل موعد الاستحقاق.
- 🤝 **سجل الديون (عليا / ليا):** دفعات سداد جزئي وكامل وأرشيف للمسدد.
- 🌗 **ثيم فاتح وداكن** بخط Cairo وتنسيق RTL كامل.

---

## 🔐 الأمان والخصوصية

- 🔒 قاعدة البيانات مشفرة بـ **AES-256** عبر SQLCipher.
- 🔑 مفتاح التشفير فريد لكل جهاز ومحفوظ في **Android Keystore**.
- 🛡️ **Offline-First:** بياناتك المالية لا تغادر هاتفك.
- 👤 Google Sign-In لتأكيد الهوية فقط، من غير رفع أي بيانات مالية.

---

## 🛠️ التقنيات المستخدمة

| الغرض | التقنية |
|---|---|
| الإطار الأساسي | `Flutter` & `Dart` |
| المعمارية | `Clean Architecture` (Feature-First) |
| إدارة الحالة | `Riverpod` |
| قاعدة البيانات | `Drift` + `SQLCipher` |
| تخزين المفاتيح | `flutter_secure_storage` |
| التنقل | `go_router` |
| الصوت والذكاء الاصطناعي | `speech_to_text` + Gemini AI + Regex Engine |
| الإشعارات | `flutter_local_notifications` + `timezone` |
| المصادقة | `Firebase Auth` + `Google Sign In` |

---

## 🚀 التشغيل محلياً

```bash
git clone https://github.com/MohamedIbrahimAbdulghani/Baqy.git
cd Baqy
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

**المتطلبات:** Flutter 3.24+، Android Studio مع Android SDK وJava 17، وهاتف أو محاكي أندرويد.

---

## 👨‍💻 المطور

**محمد إبراهيم (Mohamed Ibrahim)** — مطور تطبيقات موبايل بـ Flutter.

رؤية المشروع: حل مالي عربي بسيط وأنيق وسريع، يعتمد على الخصوصية وسهولة الاستخدام اليومي.

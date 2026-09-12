# تقرير تجهيز وبناء SAKI — 2026-09-12

## النتيجة

تم تجهيز مشروع Flutter/Dart الموجود في مستودع GitHub `ahmedxd90/isoo` وربطه بمشروع Supabase الحقيقي `saki` ذي المعرّف `vzooppdaqayerpmvdotl`. إعداد التطبيق يستخدم عنوان Supabase والمفتاح العام Publishable Key الموجودين في `lib/core/config/supabase_config.dart`، ولا يحتوي على Service Role Key.

## بيئة البناء

| العنصر | القيمة |
|---|---|
| Flutter | 3.47.4 stable |
| Dart | 3.13.3 |
| Java/JDK متاح | OpenJDK 21.0.12 |
| JDK المستخدم في Gradle | OpenJDK 17.0.20، بسبب اعتماد `audioplayers_android` القديم المتوافق مع Java 17 |
| Android SDK | Platform 37 وPlatform 36 |
| Android Build Tools | 36.0.0 |
| Android package | `saki.room.ch` |
| versionName / versionCode | `3.2.2 / 122` |
| compileSdk / targetSdk / minSdk | `37 / 36 / 24` |

تم تثبيت Java 21 كما طُلب، مع تثبيت JDK 17 إضافية فقط لتوافق Gradle مع الاعتمادات الحالية. لم يتم تغيير منطق التطبيق أو الميزات الموجودة في المستودع.

## Supabase

المشروع في Supabase بحالة `ACTIVE_HEALTHY`، وقاعدة PostgreSQL تعمل على الإصدار 17.6.1. تم التحقق من وجود الجداول الرئيسية مثل `profiles`, `posts`, `rooms`, `reels`, `conversations`, `messages`, و`notifications`، وجميعها مفعّل عليها RLS. كما أن migrations المحلية مطبقة في المشروع حتى migration الخاصة بحظر مستخدمي الغرف وتحديث Realtime في 2026-09-12.

توجد ملاحظات Security Advisor قائمة في Supabase حول بعض Security Definer views/functions؛ لم أغيّرها تلقائياً لأن تعديل صلاحيات RPC قد يؤثر على ميزات التطبيق الحالية. يجب مراجعتها قبل الإنتاج العام، خصوصاً الدوال التي لا ينبغي أن تكون قابلة للتنفيذ بواسطة مستخدم غير مسجل.

## التغييرات المحلية

تم تعديل إعداد Android فقط:

- ضبط `compileSdk` على 37 لمطابقة `permission_handler_android`.
- ضبط Gradle على JDK 17 المتوفر والمتوافق مع اعتماد Android القديم، مع إبقاء Java 21 مثبتة في النظام.
- عند غياب `android/key.properties` يستخدم Release توقيع debug القياسي حتى يكون APK قابلاً للتثبيت. للحصول على إصدار Google Play يجب استبدال ذلك بمفتاح توقيع إنتاجي يملكه صاحب التطبيق.

## ملفات APK

- `build/app/outputs/flutter-apk/app-release.apk`: إصدار Release قابل للتثبيت، موقّع بتوقيع debug المحلي لغياب مفتاح إنتاجي.
- `build/app/outputs/flutter-apk/app-debug.apk`: إصدار Debug للاختبار.

## التحقق

- `flutter pub get`: نجح.
- `flutter analyze`: نجح بدون أخطاء (`No issues found`).
- بناء Release: نجح.
- بناء Debug: نجح.
- تم التحقق من package name والإصدار وSDK بواسطة `aapt`.
- تم التحقق من توقيع APK بواسطة `apksigner`.

## ملاحظة الإصدار الإنتاجي

النسخة الحالية مناسبة للتثبيت والاختبار والتوزيع المباشر. قبل النشر في Google Play يجب توفير keystore إنتاجي ثابت، وضع بياناته خارج Git، ثم إعادة بناء Release؛ لا تستخدم debug keystore لتحديثات Play Store طويلة الأمد.

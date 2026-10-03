# تقرير إعداد SAKI — نسخة محدثة

> هذا الملف يختصر الحالة الحالية للمشروع. التقرير التفصيلي الموثق بتاريخ 3 أكتوبر 2026 موجود في [`SAKI_BUILD_SETUP_20261003_AR.md`](SAKI_BUILD_SETUP_20261003_AR.md).

## الحالة الحالية

- المستودع: `ahmedxd90/isoo`، الفرع `main`.
- التطبيق: Flutter/Dart Native Android.
- Flutter: `3.47.6` stable.
- Dart: `3.13.5`.
- Java/JDK: OpenJDK `21.0.12.1` مع `javac`.
- Android SDK: API `36`، وBuild Tools `36.0.0`.
- Android NDK: `28.2.13676358` مع `27.0.12077973` للتوافق.

## Supabase الحالي

التطبيق متصل بالمشروع المتاح في الحساب:

- اسم المشروع: `Saki chat`.
- Project ref: `faxtmvvovorxximsnxzy`.
- URL: `https://faxtmvvovorxximsnxzy.supabase.co`.
- إعداد العميل: `lib/core/config/supabase_config.dart`.
- التهيئة: `lib/main.dart`.

تم التحقق من الجداول الرئيسية، وRLS، وحاويات Storage اللازمة للتطبيق. يستخدم التطبيق Publishable Key فقط، ولا يضع Service Role Key داخل Flutter أو APK.

## التحقق والبناء

- `flutter pub get`: ناجح.
- `flutter analyze`: ناجح بلا أخطاء.
- APK Release: `build/app/outputs/flutter-apk/app-release.apk`.
- الحزمة: `saki.room.ch`.
- الإصدار: `3.3.16 (146)`.
- `minSdk`: `24`، و`targetSdk`: `36`.
- الحجم: نحو `445.8 MB`.
- توقيع APK: صالح عبر APK Signature Scheme v2.
- SHA-256: `ec3dc2b929795d91166cbdf7bcf1b6ee8fdbeb6b6da687a4d58db1be23d083da`.

هذه نسخة Release قابلة للتثبيت والاختبار. وللنشر على Google Play يجب توفير keystore إنتاجي مستقل خارج Git وربطه عبر `android/key.properties`؛ في البناء الحالي استُخدم توقيع debug fallback المحلي لعدم وجود ملف مفاتيح إنتاجي في المستودع.

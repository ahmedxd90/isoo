# تقرير تجهيز وبناء تطبيق SAKI

**التاريخ:** 3 أكتوبر 2026  
**المستودع:** `ahmedxd90/isoo`  
**الفرع:** `main`

## الحالة النهائية

تم التحقق من مشروع Flutter/Dart الموجود في GitHub، وتجهيز بيئة Android، والتحقق من ربط التطبيق بمشروع Supabase الحقيقي، وبناء APK Release قابل للتثبيت.

## بيئة البناء

| المكوّن | الإصدار أو المسار |
|---|---|
| Flutter | 3.47.6 stable |
| Dart | 3.13.5 |
| Java/JDK | OpenJDK 21.0.12.1 مع `javac` |
| Android SDK | API 36 |
| Android Build Tools | 36.0.0 |
| Android NDK | 28.2.13676358، مع تثبيت 27.0.12077973 للتوافق |
| CMake | 3.22.1 |
| Flutter project | `/home/ubuntu/isoo` |

## Supabase

التطبيق متصل بمشروع Supabase المتاح في الحساب:

| العنصر | القيمة |
|---|---|
| اسم المشروع | `Saki chat` |
| Project ref | `faxtmvvovorxximsnxzy` |
| URL | `https://faxtmvvovorxximsnxzy.supabase.co` |
| إعداد التطبيق | `lib/core/config/supabase_config.dart` |
| مخطط قاعدة البيانات | PostgreSQL مع RLS |

تم التحقق من وجود الجداول الرئيسية للتطبيق، وتفعيل RLS على جداول `public`، وحاويات Storage اللازمة مثل `avatars`, `posts`, `reels`, `rooms`, `banners`, `store` و`room_music`. يحتوي المستودع على migrations الخاصة بميزات التطبيق في `supabase/migrations/`.

يستخدم التطبيق Publishable Key فقط داخل Flutter. لا يوجد Service Role Key داخل APK أو المستودع.

## التحقق والبناء

- `flutter pub get` — نجح.
- `flutter analyze` — نجح: `No issues found`.
- `flutter build apk --release --no-tree-shake-icons` — نجح.
- اسم الحزمة: `saki.room.ch`.
- الإصدار: `3.3.16 (146)`.
- `minSdkVersion`: 24.
- `targetSdkVersion`: 36.
- الحجم: `445.8 MB` تقريبًا.
- سلامة ZIP: ناجحة.
- توقيع APK: صالح عبر APK Signature Scheme v2.
- SHA-256: `ec3dc2b929795d91166cbdf7bcf1b6ee8fdbeb6b6da687a4d58db1be23d083da`.

## ملف APK

```text
build/app/outputs/flutter-apk/app-release.apk
```

هذه النسخة Release قابلة للتثبيت والاختبار. وبما أن ملف `android/key.properties` غير موجود في Git، استخدم إعداد Android الحالي توقيع debug fallback المحلي؛ للنشر على Google Play يجب إنشاء keystore إنتاجي مستقل وحفظه خارج Git ثم ربطه عبر `android/key.properties`.

## ملاحظات

- توجد تحديثات أحدث لبعض حزم pub، لكن لم يتم رفعها تلقائيًا حتى لا تتغير ميزات التطبيق المستقرة.
- تحذيرات Flutter الحالية تخص قرب انتهاء دعم إصدارات Gradle/AGP/Kotlin، ولا تمنع البناء الحالي.
- Google OAuth وAgora/ZEGOCLOUD يحتاجان إعدادات اعتماد خارجية إذا كانت مطلوبة في بيئة الإنتاج.

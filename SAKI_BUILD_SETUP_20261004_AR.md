# تقرير تجهيز وبناء تطبيق SAKI — 2026-10-04

**المستودع:** `ahmedxd90/isoo`  
**الفرع:** `main`  
**الالتزام الأساسي:** `e36cecb` (fix: add room exit trend sheet and restore bubble reopen)  
**الحالة:** تم تجهيز بيئة Flutter/Dart/Java/Android بالكامل، والتحقق من ربط تطبيق SAKI بمشروع Supabase الحقيقي، وبناء **APK Release حقيقي موقّع بمفتاح إنتاجي** قابل للتثبيت مباشرة على الهواتف.

---

## 1. بيئة البناء المنزّلة في هذه الجلسة

| المكوّن | الإصدار / المسار |
|---|---|
| Flutter SDK | `3.47.6` stable (`/home/ubuntu/flutter`) |
| Dart SDK | `3.13.5` |
| Java / JDK | OpenJDK `21.0.12.1` مع `javac` (`/usr/lib/jvm/java-21-openjdk-amd64`) |
| Android SDK | `/home/ubuntu/android-sdk` |
| Android Platform | `android-36` + `android-35` |
| Android Build Tools | `36.0.0` |
| Android NDK | `28.2.13676358` + `27.0.12077973` (توافق الإضافات) |
| CMake | `3.22.1` |
| Gradle | `8.14.1` (wrapper) |
| Android Gradle Plugin | `8.11.1` |
| Kotlin | `2.2.20` |
| المشروع | `/home/ubuntu/isoo` |

### الأوامر المستخدمة

```bash
flutter pub get
flutter analyze                                  # No issues found!
flutter build apk --release --no-tree-shake-icons
flutter build apk --release --split-per-abi --no-tree-shake-icons
```

### ملاحظة مهمة عن Java
كان JDK الموجود مسبقًا في النظام **JRE فقط** (بدون `javac`)، وهو ما كان يُفشل البناء بالخطأ:

```text
Toolchain installation '/usr/lib/jvm/java-21-openjdk-amd64'
does not provide the required capabilities: [JAVA_COMPILER]
```

تم حل المشكلة بتثبيت `openjdk-21-jdk-headless` (يوفّر `javac` 21.0.12.1)، ثم إعادة تشغيل خدمات Gradle، وبعدها اكتمل البناء بنجاح دون أي تعديل على كود التطبيق.

---

## 2. ربط Supabase (تحقق فعلي)

| العنصر | القيمة |
|---|---|
| اسم المشروع | `Saki chat` |
| Project ref | `faxtmvvovorxximsnxzy` |
| URL | `https://faxtmvvovorxximsnxzy.supabase.co` |
| إعداد التطبيق | `lib/core/config/supabase_config.dart` |
| نوع المفتاح داخل APK | **Publishable Key** فقط — لا يوجد Service Role Key |

نتائج التحقق المباشر على المشروع الحي:

- `GET /auth/v1/health` → **HTTP 200**.
- `GET /rest/v1/countries` بالمفتاح العام → **HTTP 200** مع بيانات حقيقية (249 دولة).
- عدد جداول `public` → **100 جدول** (منها `profiles`, `posts`, `reels`, `rooms`, `room_gifts`, `messages`, `conversations`, `notifications`, `wallet_topup_packages`, `user_task_definitions`, `saki_store_products`, `family_square`, `love_relationships`, `pk_battles`, ...).
- **جميع جداول `public` مفعّل عليها RLS** (لا يوجد أي جدول بدون RLS).
- حاويات Storage موجودة: `avatars`, `banners`, `posts`, `reels`, `rooms`, `room_music`, `store`, `user-media`, `report_evidence`.
- Edge Function `agora-token` منشورة وحالتها **ACTIVE** (الإصدار 5) مع `verify_jwt = true` — أي أنها تُستدعى فقط بمستخدم مسجّل داخل التطبيق، وهذا هو السلوك الصحيح لأمان الصوت.

---

## 3. مخرجات البناء والتوقيع

### نسخة Universal (تعمل على كل الهواتف)

```text
build/app/outputs/flutter-apk/app-release.apk
```

| العنصر | القيمة |
|---|---|
| اسم الحزمة | `saki.room.ch` |
| versionName / versionCode | `3.3.18` / `148` |
| compileSdk / targetSdk | `36` / `36` |
| minSdk | `24` (أندرويد 7.0 وأعلى) |
| الحجم | `446.3 MB` تقريبًا |
| المعماريات المضمّنة | `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| التوقيع | APK Signature Scheme **v2** — صالح |
| سجل التوقيع (DN) | `CN=SAKI, OU=Mobile, O=SAKI, L=Riyadh, ST=Riyadh, C=SA` |
| SHA-1 للشهادة | `D9:42:B0:9C:E3:AA:18:CC:5A:50:30:53:E8:7C:6C:8B:C9:AB:16:F7` |
| SHA-256 للشهادة | `9B:F2:E5:83:32:64:47:C2:86:27:93:B7:15:AD:AE:96:FE:21:A3:F9:48:2C:28:92:70:8B:5B:FD:D1:B5:20:72` |
| SHA-256 لملف APK | `965a8a76fdda530a9ff7c44fec331f9ba8848ab5ce94bd1841729364a52b0603` |
| سلامة ZIP | `No errors detected` |

### نسخ مقسّمة حسب المعمارية (`--split-per-abi`)

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

نسخة `arm64-v8a` هي الأنسب لأغلب الهواتف الحديثة لأن حجمها أصغر بكثير من نسخة Universal مع نفس الميزات.

---

## 4. مفتاح التوقيع الإنتاجي

تم إنشاء keystore إنتاجي حقيقي (`RSA 2048`, صلاحية 10000 يوم) وتوقيع نسخة Release به بدلًا من توقيع debug المستخدم سابقًا:

```text
android/key.properties      (مستثنى من Git)
android/app/saki-release.jks (مستثنى من Git)
```

**مهم:** احتفظ بهذين الملفين في مكان آمن خارج Git. أي تحديث مستقبلي على Google Play يجب أن يُوقَّع بنفس المفتاح، وإذا فُقد لن تستطيع تحديث التطبيق على متجر Play.

---

## 5. الميزات الموجودة في التطبيق (كما في المستودع)

تم بناء التطبيق بكل طبقاته من المستودع دون حذف أو تعطيل أي ميزة، ويشمل ذلك:

- تسجيل الدخول والتسجيل عبر Supabase Auth مع الدول الـ249 و`SAKI ID` التسلسلي.
- الرئيسية: منشورات حقيقية، إعجابات، تعليقات، مشاركات، متابعة، carousel ورفع صور.
- الريلز: تشغيل/إيقاف، إعجاب، تعليقات، مشاركة، ورفع فيديو إلى Storage.
- الغرف الصوتية: قائمة الغرف، بنرات، فلاتر الدول، وموجة صوتية.
- الغرفة الحقيقية: Agora RTC (عبر `agora-token`)، مقاعد، رسائل، هدايا، ترتيب، إيموجيات، سينما، حظ، PK battles، إدارة ومشرفون.
- الرسائل: محادثات حقيقية + Unread Count + Realtime.
- صفحة «أنا»: ملف شخصي، محفظة، VIP، أرستقراطية، متجر، مهام، وكالة شحن، سوبر أدمن، أكواد استرداد، إعدادات.
- الميزات الاجتماعية: العائلة، بيت الحب، مربع العائلة، الزيارات، الحظر، الإبلاغات، الشارات، لوحات المتصدرين.
- الإشعارات: `flutter_local_notifications` + Realtime.

---

## 6. ملاحظات وتنبيهات

1. تحذيرات Gradle/AGP/Kotlin الحالية (ترقية مقترحة لـ Gradle 9.1 وAGP 9.0.1 وKotlin 2.3.20) لا تمنع البناء، ولا تم تغيير إصداراتها للحفاظ على استقرار الميزات.
2. `flutter analyze` أعاد **No issues found** قبل البناء.
3. 52 حزمة pub لديها إصدارات أحدث غير متوافقة مع قيود الاعتماد الحالية؛ لم يتم رفعها تلقائيًا حتى لا تتغير سلوكيات التطبيق المستقر.
4. Google OAuth وAgora Token يعملان من داخل التطبيق عبر Supabase؛ أي مفاتيح خارجية إضافية (Google Cloud OAuth Client) تبقى مسؤولية مالك التطبيق في بيئة الإنتاج.
5. لا يحتوي APK على أي مفتاح سري (Service Role) ولا على ملفات توقيع.
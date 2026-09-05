# SAKI — تطبيق شبكة اجتماعية حقيقي

تم تجهيز هذا المشروع كتطبيق Android حقيقي باستخدام **Flutter/Dart فقط**، مع اتصال مباشر بمشروع Supabase الحقيقي `saki`، ومصادقة Supabase Auth، وPostgreSQL، وStorage، وRealtime. لم يتم بناء الواجهات على React Native أو HTML/CSS، ولم تتم إضافة مستخدمين أو منشورات وهمية من داخل التطبيق.

## حالة الاتصال الحقيقية

| العنصر | القيمة |
|---|---|
| Supabase URL | `https://vzooppdaqayerpmvdotl.supabase.co` |
| Supabase project ref | `vzooppdaqayerpmvdotl` |
| Android package | `com.saki.saki` |
| Flutter | `3.47.2` |
| Dart | `3.13.2` |
| compileSdk | `36` |
| قاعدة البيانات | PostgreSQL في Supabase |
| التخزين | `avatars`, `posts`, `reels`, `rooms`, `banners` |
| صفحة أنا | تصميم HTML-matched بالبرتقالي والسماوي والأبيض مع Font Awesome 11.0.0 |
| account modules | جدول Supabase حقيقي للمحفظة وVIP والأرستقراطية والمتجر والإعدادات |

المفتاح الموجود داخل Flutter هو **Publishable Key** مخصص للعميل، وليس Service Role Key. لا تضع Service Role Key داخل تطبيق Android.

## الميزات المنفذة

يبدأ التطبيق بشاشة Splash متدرجة، ثم يقرر تلقائيًا بين جلسة المستخدم الحالية وتسجيل الدخول. تتصل شاشة التسجيل بـ Supabase Auth وتقرأ 249 دولة من جدول `countries` الحقيقي مع العلم والاسم، بينما ينشأ `SAKI ID` داخل PostgreSQL باستخدام sequence يبدأ من `964379846`.

صفحة «أنا» الآن تطابق كود HTML المرفق داخل Flutter Native: رأس أبيض ثابت، زر تعديل برتقالي، بطاقة ملف بصورة بإطار برتقالي/وردي وشارة تاج، شبكة المحفظة وVIP والأرستقراطية والمتجر، وقائمة المستوى والمهام ووكالة الشحن وسوبر أدمن وكود الاسترداد والإعدادات. تم إخفاء Posts/Reels/Media من واجهة صفحة «أنا» فقط دون حذف بياناتها أو خدماتها من التطبيق. جميع الأيقونات الجديدة تأتي من Font Awesome Flutter 11.0.0، وعناصر المحفظة وVIP والمتجر والإعدادات تقرأ وتحفظ بياناتها في جدول `saki_account_modules` الحقيقي عبر RLS.

الصفحة الرئيسية الآن تطابق كود HTML الجديد: خلفية `#F8FAFC`، شريط أبيض شبه شفاف، تبويبا «الكل» و«متابعة» مربوطان باستعلام Supabase حقيقي، زر إنشاء منشور دائري بتدرج برتقالي، وبطاقات منشورات بيضاء ذات زوايا مستديرة وظل ناعم. كل بطاقة تعرض الصورة والحالة وVIP والمتابعة والقائمة والنص والصورة والعدادات وشريط الشعلة والتعليق والمشاركة، مع الحفاظ على الإعجاب الحقيقي والتعليق والمشاركة والمتابعة والـ carousel والرفع إلى Storage.

تمت إضافة صفحة بروفايل المستخدم الآخر المطابقة لكود HTML المرفق: Hero بصورة حقيقية بتدرج رمادي وطبقة Overlay، اسم المستخدم، SAKI ID قابل للنسخ، مستوى وبلد وجنس، إحصاءات المتابعين والمتابعة، تبويبات الصفحة الشخصية والمنشورات والريلز والهدايا، وسيرة ذاتية ومحتوى حقيقي. البحث الآن يدعم اسم المستخدم وDisplay Name و`SAKI ID` الرقمي، والضغط على نتيجة المستخدم يفتح بروفايله مباشرة. أسفل بروفايل المستخدم الآخر يوجد شريط ثابت بزر متابعة حقيقي مرتبط بجدول `follows` وزر رسالة خاصة ينشئ أو يعيد استخدام Conversation حقيقية ويفتح المحادثة عبر Realtime.

صفحة الغرف الآن مطابقة لكود HTML المرفق: تدرج Violet/Pink، شريط علوي بتبويبي «الكل» و«متابعة»، بنر Carousel متحرك كل 3 ثوانٍ مع بيانات Supabase أو صور احتياطية، اختصارات ترتيب الثروة والسحر والغرف، فلاتر الدول، بحث الغرف، وبطاقات مربعة ذات TOP 1/2/3 وصورة المالك والدولة وعدد الأعضاء وموجة صوتية متحركة. الضغط على البطاقة يفتح الغرفة الحقيقية مع الرسائل وإنشاء الغرف ورفع الصور محفوظة كما هي.

صفحة الريلز الآن مطابقة لكود HTML: خلفية سوداء داكنة، ريلز عمودي بملء الشاشة، تشغيل تلقائي للريلز النشط وإيقاف غير النشط، نقر الفيديو للتشغيل والإيقاف مع أيقونة Play، رأس شفاف باسم Saki ونقطة حمراء، تبويبا «متابعين» و«الكل»، زر رفع سماوي، شعلة إعجاب برتقالية، تعليقات، مشاركات، قرص صوت دائري دوّار، وصف واسم الصوت، وواجهة رفع فيديو داكنة مع معاينة ووصف وخصوصية ونشر حقيقي إلى Supabase. كما تم توحيد الشريط السفلي على مستوى التطبيق بالكامل ليطابق HTML: الرئيسية، الريلز، الغرف، الرسائل، وأنا، باستخدام Font Awesome وحالة نشطة سماوية وخلفية دائرية للريلز.

تم إصلاح سبب رسالة «تحقق من اتصال الإنترنت» في الصفحة الرئيسية. السبب كان أن استعلام Supabase يطلب `post_shares(id)` بينما جدول `post_shares` الحقيقي لا يحتوي عمود `id`، فتم تغييره إلى `post_shares(user_id)`. تم اختبار نفس طلب REST على المشروع الحي ونجح بحالة HTTP 200 وأعاد المنشورات والوسائط والإعجابات والتعليقات والمشاركات.تتضمن النسخة الحالية خلاصة منشورات حقيقية من جدول `posts` مع ملفات `post_media` من Storage، وإعجابات شعلة، وتعليقات، ومشاركة حقيقية في `post_shares`، ورفع حتى عشر صور، والخصوصية العامة أو المتابعين. كما تتضمن Reels حقيقية مع رفع فيديو إلى Storage وتشغيل `video_player`، وتعليقات ومشاركة في `reel_comments` و`reel_shares`، وغرفًا حقيقية من PostgreSQL مع banners من Supabase وCarousel كل 3 ثوانٍ وتصنيف All/New وبحث، وRoom Cards مع Audio Wave Animation، ورسائل مباشرة مع إنشاء المحادثة وآخر رسالة وUnread Count والاشتراك في Supabase Realtime، وصفحة Search حقيقية للملفات والمنشورات والغرف، وصفحة Notifications مرتبطة بـ Realtime، وملفًا شخصيًا مع SAKI ID وFollower Stats وTabs Posts/Reels/Media وGrid ورفع الصورة وتسجيل الخروج.

## قاعدة البيانات والأمان

المجلد `supabase/migrations/` يحتوي على migrations التي تم تطبيقها فعليًا على مشروع Supabase، وتشمل الجداول المفقودة، sequence الخاص بـ SAKI ID، Storage buckets، RLS policies، trigger إنشاء profile بعد التسجيل، Realtime للجداول الضرورية، البلدان، وفهارس المفاتيح الأجنبية.

تم تفعيل RLS للجداول الجديدة وتطبيق سياسات تمنع تعديل profile أو post أو comment أو رسالة لا يملكها المستخدم. كما تم جعل ملفات Storage قابلة للقراءة العامة فقط، بينما الكتابة والتعديل والحذف مقيدة بمجلد المستخدم وملكية الملف. بعد hardening لا يظهر في Supabase Security Advisor سوى تنبيه إعداد **Leaked Password Protection**، ويمكن تفعيله من إعدادات Authentication في لوحة Supabase.

## بناء التطبيق

بعد فك ضغط المشروع وتشغيل Flutter، نفّذ:

```bash
flutter pub get
flutter build apk --debug
flutter build apk --release
```

ينتج البناء النهائي الملفات التالية:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

تم التحقق من أن APK الإصدار يحمل الحزمة `com.saki.saki`، وأنه يستهدف Android 24 أو أحدث، ويحتوي على صلاحية الإنترنت، وأن البناء Release وDebug اكتمل بنجاح.

## ملاحظات التشغيل

يلزم وجود حساب حقيقي في Supabase Auth لتجربة الوظائف المقيدة. إذا كانت خاصية تأكيد البريد مفعلة في مشروعك، فبعد التسجيل يجب فتح رسالة البريد ثم تسجيل الدخول. رفع الفيديو يعتمد على مساحة Storage وحجم الملف المسموح في مشروع Supabase. غرف SAKI تعرض بيانات ومحادثات وPresence-ready Audio Wave حقيقية، أما نقل الصوت الحي نفسه فيحتاج WebRTC/TURN أو مزود Voice خارجي بمفاتيح تشغيل.

لتغيير اسم الحزمة لاحقًا، عدّل `--org` عند إنشاء مشروع جديد أو عدّل `namespace` و`applicationId` في ملفات Android، من دون تغيير منطق Flutter أو إعداد Supabase.

## ملفات التسليم المهمة

| الملف | الغرض |
|---|---|
| `lib/` | واجهة Flutter والمنطق المتصل بـ Supabase |
| `supabase/migrations/` | SQL migrations المطبقة على قاعدة البيانات الحقيقية |
| `build/app/outputs/flutter-apk/app-release.apk` | APK إصدار قابل للتثبيت |
| `build/app/outputs/flutter-apk/app-debug.apk` | APK Debug للاختبار |
| `android/` | إعداد Android والـ package والـ manifest |
| `pubspec.yaml` | حزم Flutter المطلوبة |

## مراجع رسمية

- [Flutter documentation](https://docs.flutter.dev/)
- [Supabase Flutter quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control)

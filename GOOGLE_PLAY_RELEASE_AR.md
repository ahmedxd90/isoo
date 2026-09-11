# تسليم SAKI للحزمة saki.room.ch

## النتيجة

تم تغيير معرّف تطبيق Android من `saki.chat.co` إلى `saki.room.ch` في إعدادات Gradle وnamespace وملفات Kotlin، ثم تم بناء نسخة Release حقيقية بصيغتي Android App Bundle وAPK. تم توقيع الملفين بمفتاح رفع Google Play جديد من نوع PKCS12 وبخوارزمية RSA 4096.

| البيان | القيمة |
|---|---|
| Application ID | `saki.room.ch` |
| Namespace | `saki.room.ch` |
| Version name | `3.0.2` |
| Version code | `91` |
| Compile SDK | 37 |
| Target SDK | 36 |
| Minimum SDK | 24 |
| نوع توقيع APK | APK Signature Scheme v2 |

## ملفات الرفع

الملف `SAKI-saki.room.ch-release.aab` هو الملف المخصص للرفع إلى Google Play Console. والملف `SAKI-saki.room.ch-release.apk` مخصص للتثبيت المباشر والاختبار على الأجهزة. تم التحقق من أن معرف الحزمة في APK هو `saki.room.ch` وأن التوقيع صالح.

ملفات مفتاح الرفع منفصلة عن ملفات التطبيق. يجب حفظ `saki-upload-key.jks` و`key.properties` و`UPLOAD_KEY_INFO.txt` في مكان آمن ومشفر، وعدم رفعها إلى GitHub أو إرسالها في مستودع عام. ملف `key.properties` مهيأ ليعمل عند وضعه داخل مجلد `android` بجانب `saki-upload-key.jks`.

## إعداد Google Play Console

أنشئ تطبيقًا جديدًا في Google Play Console باستخدام معرف الحزمة `saki.room.ch`، ثم ارفع ملف AAB. عند تفعيل Google Play App Signing اختر استخدام مفتاح رفع موجود، ثم استخدم شهادة مفتاح الرفع الموضحة في ملف `UPLOAD_KEY_INFO.txt`. لا يمكن إكمال إنشاء التطبيق أو تفعيل Play App Signing من بيئة البناء نيابةً عنك، لأن ذلك يتطلب حساب Google Play Console الخاص بك.

إذا كان تسجيل الدخول عبر Google مطلوبًا، أضف اسم الحزمة `saki.room.ch` وبصمة SHA-1 الخاصة بمفتاح الرفع في إعدادات Google/Firebase OAuth. أما رابط Supabase OAuth الحالي `io.supabase.saki://login-callback` فتم إبقاؤه كما هو لأنه رابط إعادة توجيه مستقل عن Application ID ويتطلب تغييره أيضًا تحديث إعدادات Supabase الخارجية.

## التحقق

نجح `flutter pub get` و`flutter analyze`، ونجح بناء AAB وAPK Release. تم فحص APK بواسطة `apksigner`، وتم التأكد من توقيعه، كما تم التأكد من توقيع حزمة AAB بواسطة `jarsigner`. تحذيرات Gradle وAndroid Gradle Plugin وKotlin الظاهرة أثناء البناء تحذيرات توافق مستقبلية ولم تمنع البناء.

بصمة SHA-1 وSHA-256 وكلمات المرور موجودة داخل ملف `UPLOAD_KEY_INFO.txt` الخاص بمفتاح الرفع، وليست مكررة في هذا التقرير لحماية بيانات الاعتماد.

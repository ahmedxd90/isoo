# مطابقة تصميم ومميزات SAKI مع الملف المرفق

هذه الوثيقة تحول الملف المرفق إلى مواصفات تنفيذية واضحة. الهدف ليس إنشاء نموذج شكلي؛ كل شاشة يجب أن تقرأ وتكتب البيانات من Supabase، وكل زر يجب أن ينفذ عملية حقيقية أو يعرض سببًا واضحًا لعدم توفر الإعداد الخارجي المطلوب.

## الهوية البصرية الثابتة

التصميم الرئيسي هو Dark Premium بواجهة RTL عربية، بخلفية `#09090B` وبطاقات `#18181B` ونص أبيض ونص ثانوي `#A1A1AA`. اللون الأساسي هو التدرج `#7C3AED → #22D3EE`، مع البنفسجي الداكن `#4C1D95` للأزرار والحالات النشطة والذهبي `#F59E0B` للتفاصيل. جميع البطاقات تستخدم زوايا بين 18 و24 بكسل، مع ظل خفيف وGlassmorphism محدود حتى لا تصبح الواجهة مزدحمة.

## خريطة الصفحات المطلوبة

| الصفحة | التصميم المطلوب | البيانات أو الإجراء الحقيقي |
|---|---|---|
| Splash | شعار SAKI متدرج Purple/Cyan على خلفية داكنة مع Animation | فحص Supabase Session ثم الانتقال إلى Home أو Login |
| Login | شعار كبير، Email، Password، إظهار/إخفاء، Login، Create Account، Loading | Supabase Auth `signInWithPassword` |
| Create Account | صورة، Username، Email، Password، دولة بعلم، جنس | Supabase Auth ثم trigger ينشئ profile وSAKI ID من PostgreSQL |
| Home | شريط علوي ثابت، SAKI، إضافة Post، Search، Bottom Navigation | بيانات Feed من `posts` وملحقاته |
| Feed/Post Card | Avatar، Username، SAKI ID، الوقت، النص، الصور، Flame، Comment، Share | `posts`, `post_media`, `post_likes`, `post_comments`, `post_shares` |
| Create Post | حتى 10 صور، Preview، حذف وترتيب، نص، Privacy | Storage bucket `posts` ثم PostgreSQL |
| Reels | Full-screen vertical، Following/All، إضافة Reel | `reels`, `reel_media`, Storage `reels` |
| Create Reel | اختيار فيديو، وصف، Privacy، نشر | رفع حقيقي للفيديو ثم insert في `reels` |
| Reel Viewer | Swipe up/down، Flame، Comment، Share، Avatar، Username، وصف | Likes/comments/shares حقيقية مع تشغيل الفيديو |
| Messages | Conversations مع Avatar، Username، آخر رسالة، وقت، Unread Count | `conversations`, `conversation_members`, `messages` |
| Chat | Bubbles متدرجة للمستخدم الحالي وCards للطرف الآخر | Supabase Realtime على `messages` |
| Profile | Avatar كبير، Username، SAKI ID، Bio، Followers/Following/Posts | `profiles`, `follows`, `posts`, `reels` |
| Profile Tabs | Posts، Reels، Media مع Grid | استعلامات حقيقية حسب المستخدم |
| Rooms | Banner Carousel كل 3 ثوانٍ، All/New، Search، Create | `room_banners`, `rooms`, Storage `banners` |
| Room Card | صورة، Room ID، Host، عدد الموجودين، Audio Wave متحركة | `rooms`, `room_members`, Realtime Presence |
| Create Room | صورة، اسم، دولة، وصف، نوع، Room ID | insert حقيقي في `rooms` وتعيين Owner/Host |
| Notifications | قائمة تنبيهات الإعجاب والتعليق والمتابعة والرسائل | `notifications` مع Realtime محدود |

## حالة النسخة الحالية والفجوات التي يجب إغلاقها

النسخة الحالية متصلة فعليًا بـ Supabase وتملك Login وRegister وFeed ورفع صور المنشورات وReels ورفع الفيديو والرسائل والغرف والملف الشخصي. لكنها لا تطابق الملف بنسبة كاملة بعد؛ توجد فجوات في Search، وProfile Tabs، وShare الحقيقي، وRoom Banner Carousel، وتصنيف New، وUnread Count، وNotifications، وReel Comments، وRoom Presence/Audio Wave، وبعض تفاصيل التصميم المطلوبة في الشريط العلوي.

| الفجوة | المطلوب لإغلاقها |
|---|---|
| البحث | صفحة أو Bottom Sheet بحث حقيقي في profiles/posts/rooms مع نتائج Supabase |
| ملف المستخدم | أُغلقت Tabs Posts/Reels/Media وGrid؛ مشاركة الرابط/المعرف يمكن توسيعها لاحقًا إلى نظام Share خارجي |
| الغرف | أُغلقت واجهة banners من Supabase وCarousel كل 3 ثوانٍ وAll/New وSearch وAudio Wave؛ الصوت الحي يحتاج WebRTC/TURN خارجي |
| الرسائل | جلب آخر رسالة والوقت وعدد غير المقروء وتحديث `is_read` |
| Reels | إضافة Comments وShares حقيقية والالتزام بتبويب Following/All |
| المنشورات | جعل Share ينشئ row في `post_shares` مع مشاركة داخلية حقيقية |
| الإشعارات | أُغلقت الفجوة؛ UI حقيقي وSupabase Realtime مع triggers فعلية للإعجاب والتعليق والمتابعة والرسائل |
| الدول | أُغلقت الفجوة؛ تم توسيع `countries` إلى 249 دولة/إقليمًا مع code وname وname_ar fallback وflag داخل Supabase |
| الصوت الحي | يحتاج WebRTC أو مزود Voice مع signaling وTURN؛ Realtime وحده لا ينقل الصوت |
| الاختبار | اختبار session persistence، الرفع، navigation، RLS، Realtime، وبناء APK بعد كل تعديل |

## قواعد التنفيذ

لا تُستخدم بيانات مستخدمين أو منشورات أو رسائل وهمية. لا تُضاف counters ثابتة. لا تُعرض بطاقة نجاح إذا فشل طلب Supabase. أي فشل شبكة يظهر كحالة Error قابلة لإعادة المحاولة. يجب أن تبقى الواجهة Responsive على الهاتف واللوحي باستخدام `SafeArea` و`MediaQuery` و`LayoutBuilder`، مع الحفاظ على RTL وMaterial 3.

## تعريف الاكتمال

يُعتبر التصميم مطابقًا عندما تظهر الصفحات السابقة بنفس التسلسل البصري والهوية والألوان، وتعمل إجراءات Auth وCRUD وStorage وRealtime حقيقيًا، ويستطيع المشروع تنفيذ `flutter pub get` ثم `flutter build apk --release` من دون أخطاء، مع بقاء أي تكامل صوتي خارجي موثقًا بوضوح إذا احتاج مفتاح خدمة أو TURN server.

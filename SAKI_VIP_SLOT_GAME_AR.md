# لعبة ماكينة السلوت الملكية VIP في SAKI

## الوصف

تمت إضافة لعبة «ماكينة السلوت الملكية VIP» داخل الغرف. تظهر من زر الألعاب ذي الأربع مربعات في أعلى الغرفة، ثم تظهر كبطاقة داخل Bottom Sheet مع صورة مصغرة مخصصة. عند الضغط على البطاقة تفتح الماكينة في Bottom Sheet كامل تقريبًا بتصميم أخضر زمردي وذهبي مستوحى من تصميم HTML المرفق.

اللعبة تحتوي على شبكة 3×3، وستة رموز، وخمسة خطوط فوز: ثلاثة أفقية وقطران. يمكن اختيار الرهان من 10 و50 و100 و500 و1000 و5000 و10000 ذهب، ثم الضغط على زر الدوران. الحركة المرئية داخل التطبيق تعرض دورانًا سريعًا للرموز، بينما النتيجة النهائية تأتي من Supabase.

## الرموز والمضاعفات

| الرمز | المضاعف لكل خط فائز |
|---|---:|
| ألماس | 50× |
| تاج | 30× |
| بطيخ | 20× |
| عنب | 10× |
| كرز | 5× |
| مانجو | 3× |

الربح يساوي مجموع مضاعفات خطوط الفوز المطابقة مضروبًا في قيمة الرهان.

## الربط الحقيقي

أضيف جدول `saki_slot_spins` لتسجيل كل جولة، والمستخدم، والغرفة، والرهان، والنتيجة، والربح، والتاريخ. أضيفت الدالة الآمنة `saki_vip_slot_spin` في Supabase.

الدالة تقوم بالخطوات التالية داخل الخادم:

1. التأكد من تسجيل دخول المستخدم.
2. التأكد من أن الغرفة فعالة.
3. التحقق من قيمة الرهان المسموحة.
4. خصم الرهان من `saki_account_modules.gold_coins` بقفل وتحديث ذري.
5. توليد نتيجة الجولة على الخادم، وليس داخل Flutter.
6. احتساب خطوط الفوز والمكافأة.
7. تسجيل الجولة في `saki_slot_spins`.
8. إضافة الربح إلى رصيد الذهب عند الفوز.
9. إرجاع النتيجة والرصيد الحالي للتطبيق.

عملة الذهب المستخدمة هي عملة SAKI الداخلية كما طلب المستخدم. يجب أن تبقى داخل التطبيق وغير قابلة للسحب النقدي أو التحويل إلى أموال.

## البرومبت الأصلي المعتمد

```text
Create a fully playable Arabic VIP slot machine inside a Flutter bottom sheet for a social live-room application. Use a premium emerald-teal and gold casino-inspired interface, RTL Arabic layout, a 3x3 reel grid, tactile 3D gold/teal buttons, animated symbol rolling, a balance header, wager chips, win feedback, and a large spin button.

Use six symbols: diamond, crown, watermelon, grape, cherry, and mango. Use five paylines: top row, middle row, bottom row, main diagonal, and reverse diagonal. The server must generate the final result and calculate payouts. The client must never be trusted to modify the balance.

Integrate the game with Supabase. Deduct the wager atomically from the user's internal SAKI gold balance, record every spin, add payouts atomically, return the final 3x3 symbols and updated balance, reject insufficient balance, reject invalid wagers, and validate that the room is active. Gold is an in-app virtual currency and is not redeemable for cash or transferable as money.
```

## ملفات التنفيذ

- `lib/features/rooms/saki_vip_slot_sheet.dart`
- `supabase/migrations/20260908_saki_vip_slot_game.sql`
- `assets/saki_games/saki_slot_thumbnail.png`

## التحقق

تم تشغيل `flutter analyze` بنجاح بدون أي مشاكل، وتم بناء APK Release جديد.

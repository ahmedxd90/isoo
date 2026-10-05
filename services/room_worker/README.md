# Saki Room Worker

خدمة Python اختيارية تعمل **خارج تطبيق Flutter/Android**. لا تستبدل Supabase ولا Agora.

## المسؤوليات

- فحص ملفات MP4/GIF/SVGA والصور قبل نشرها.
- قراءة metadata عبر `ffprobe` عند توفره.
- توحيد أحداث الغرفة في شكل ثابت للـ workers أو لوحات المراقبة.
- توفير health check وmetrics لمعرفة البطء وعدد أحداث الهدايا.

## ما لا تفعله الخدمة

- لا تخصم العملات ولا تمنح المكافآت.
- لا تتحقق من صلاحيات المقاعد.
- لا تدير Agora أو الميكروفون.
- لا تُضمّن داخل APK.

العمليات المالية والصلاحيات تبقى داخل Supabase RPC/Postgres، والصوت يبقى داخل Agora Native/Flutter.

## التشغيل المحلي

```bash
cd services/room_worker
python3 app.py
```

النقاط المتاحة:

```bash
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/metrics
curl -X POST http://127.0.0.1:8787/events/normalize \
  -H 'content-type: application/json' \
  -d '{"event_id":"gift-1","event_type":"gift","room_id":"room-1"}'
```

لفحص ملف وسائط محلي:

```bash
curl -X POST http://127.0.0.1:8787/media/inspect \
  -H 'content-type: application/json' \
  -d '{"path":"/absolute/path/to/gift.mp4"}'
```

يمكن تشغيل `SAKI_WORKER_HOST` و`SAKI_WORKER_PORT` من البيئة. لا تضع مفاتيح Supabase أو JWT داخل ملفات المشروع؛ عند ربط الخدمة ببيئة إنتاجية استخدم secrets manager أو متغيرات بيئة محمية.

## اختبار

```bash
python3 -m unittest discover -s . -p 'test_*.py'
```

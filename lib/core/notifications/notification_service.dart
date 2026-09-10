import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SakiNotificationService {
  SakiNotificationService._();
  static final instance = SakiNotificationService._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      settings: InitializationSettings(android: settings),
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showMessage({
    required String sender,
    required String body,
  }) async {
    const details = AndroidNotificationDetails(
      'saki_messages',
      'رسائل SAKI',
      channelDescription: 'إشعارات الرسائل الخاصة في SAKI',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(''),
    );
    await plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: 'SAKI • $sender',
      body: body.isEmpty ? 'أرسل لك صورة' : 'أرسل لك رسالة: $body',
      notificationDetails: const NotificationDetails(android: details),
      payload: 'messages',
    );
  }
}

import 'package:easy_localization/easy_localization.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

import '../localization/locale_keys.dart';

bool get _isMobilePlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

typedef OrderUpdateCallback = void Function();



@pragma('vm:entry-point')

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

}



class NotificationService {

  NotificationService._();



  static final NotificationService instance = NotificationService._();



  static OrderUpdateCallback? onOrderUpdate;



  final _local = FlutterLocalNotificationsPlugin();

  bool _fcmReady = false;



  Future<void> initialize() async {

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings();

    await _local.initialize(

      const InitializationSettings(

        android: androidSettings,

        iOS: iosSettings,

      ),

      onDidReceiveNotificationResponse: (_) {},

    );



    if (!kIsWeb && _isMobilePlatform) {

      try {

        await Firebase.initializeApp(

          options: DefaultFirebaseOptions.currentPlatform,

        );

        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        await FirebaseMessaging.instance.requestPermission();

        FirebaseMessaging.onMessage.listen(_onForegroundMessage);

        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

        _fcmReady = true;

      } catch (e) {

        debugPrint('FCM init skipped: $e');

      }

    }

  }



  Future<String?> getToken() async {

    if (!_fcmReady) return null;

    try {

      return FirebaseMessaging.instance.getToken();

    } catch (_) {

      return null;

    }

  }



  void _onForegroundMessage(RemoteMessage message) {

    final title = message.notification?.title ?? LocaleKeys.appName.tr();

    final body = message.notification?.body ?? '';

    showLocal(title: title, body: body);

    if (message.data['type'] == 'order_update') {

      onOrderUpdate?.call();

    }

  }



  void _onMessageOpened(RemoteMessage message) {

    if (message.data['type'] == 'order_update') {

      onOrderUpdate?.call();

    }

  }



  Future<void> showLocal({

    required String title,

    required String body,

  }) async {

    final androidDetails = AndroidNotificationDetails(

      'tostu_orders',

      LocaleKeys.notificationChannelName.tr(),

      channelDescription: LocaleKeys.notificationChannelName.tr(),

      importance: Importance.high,

      priority: Priority.high,

    );

    const iosDetails = DarwinNotificationDetails();

    await _local.show(

      DateTime.now().millisecondsSinceEpoch ~/ 1000,

      title,

      body,

      NotificationDetails(android: androidDetails, iOS: iosDetails),

    );

  }



  Future<void> notifyOrderStatus(String statusKey) async {

    await showLocal(

      title: LocaleKeys.appName.tr(),

      body: statusKey.tr(),

    );

  }



  Future<void> notifyNewOrder() async {

    await showLocal(

      title: LocaleKeys.branchNewOrderAlert.tr(),

      body: LocaleKeys.notificationNewOrderBody.tr(),

    );

  }

  Future<void> notifyApproach(int minutes) async {
    await showLocal(
      title: LocaleKeys.notificationApproachTitle.tr(),
      body: LocaleKeys.notificationApproachBody.tr(
        namedArgs: {'minutes': '$minutes'},
      ),
    );
  }

}


import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import '../localization/locale_keys.dart';
import '../../shared/domain/entities/order.dart';
import '../utils/order_status_utils.dart';

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

  /// Bildirime tıklanınca ayrıntı ekranını açan köprü.
  static void Function(String broadcastId)? onBroadcastOpened;

  static String? pendingBroadcastId;

  /// Garson oturumunda "hazırlanıyor / iptal" durum push'larını gösterme.
  static bool suppressOrderStatusNotifications = false;

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
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    final launch = await _local.getNotificationAppLaunchDetails();
    _handlePayload(launch?.notificationResponse?.payload);

    if (!kIsWeb && _isMobilePlatform) {
      try {
        // Firebase is already initialized in main(); only init if missing.
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        // Do not block cold start on the iOS permission dialog.
        unawaited(FirebaseMessaging.instance.requestPermission());
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) _onMessageOpened(initial);
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
    final data = message.data;
    if (data['type'] == 'broadcast') return;

    final statusName = data['status'] as String?;
    final isOrderUpdate = data['type'] == 'order_update';

    if (isOrderUpdate) {
      onOrderUpdate?.call();
      if (suppressOrderStatusNotifications) return;
    }

    var body = message.notification?.body ?? '';
    if (statusName != null && isOrderUpdate) {
      try {
        final status = OrderStatus.values.byName(statusName);
        final label = OrderStatusUtils.label(status);
        final notifBody = message.notification?.body ?? '';
        if (notifBody.contains('#')) {
          final prefix = notifBody.split('—').first.trim();
          body = '$prefix — $label';
        } else {
          body = label;
        }
      } catch (_) {}
    }

    final title = message.notification?.title ?? LocaleKeys.appName.tr();

    showLocal(title: title, body: body);
  }



  void _onMessageOpened(RemoteMessage message) {
    if (message.data['type'] == 'broadcast') {
      _handlePayload('broadcast:${message.data['broadcast_id']}');
      return;
    }
    if (message.data['type'] == 'order_update') {
      onOrderUpdate?.call();
    }
  }

  static void _handlePayload(String? payload) {
    if (payload == null || !payload.startsWith('broadcast:')) return;
    final id = payload.substring('broadcast:'.length);
    if (id.isEmpty) return;
    pendingBroadcastId = id;
    onBroadcastOpened?.call(id);
  }

  static void consumePending(void Function(String id) open) {
    final id = pendingBroadcastId;
    if (id == null || id.isEmpty) return;
    pendingBroadcastId = null;
    open(id);
  }



  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
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
      payload: payload,
    );

  }



  Future<void> notifyOrderStatus(String statusKey) async {
    if (suppressOrderStatusNotifications) return;
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


import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/localization/localization_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/printing/cashier_printer_provider.dart';
import 'core/printing/kitchen_printer_provider.dart';
import 'core/utils/boot_log.dart';
import 'core/utils/platform_layout_utils.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'firebase_options.dart';
import 'shared/presentation/providers/orders_provider.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

bool get _isMobilePlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await BootLog.clear();
      await BootLog.write('boot: binding ok');

      await EasyLocalization.ensureInitialized();
      await BootLog.write('boot: localization ok');

      if (AppConfig.useFirestore) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          await BootLog.write('boot: firebase ok');
          if (_isMobilePlatform) {
            FirebaseMessaging.onBackgroundMessage(
              firebaseMessagingBackgroundHandler,
            );
          }
        } catch (e, st) {
          await BootLog.write('boot: firebase FAIL $e');
          await BootLog.write(st.toString());
          debugPrint('Firebase init failed: $e');
        }
      } else if (AppConfig.useWindowsOpsFirestoreRest) {
        await BootLog.write('boot: firestore REST mode (windows ops)');
      }

      try {
        await NotificationService.instance.initialize();
        await BootLog.write('boot: notifications ok');
      } catch (e, st) {
        await BootLog.write('boot: notifications FAIL $e');
        await BootLog.write(st.toString());
      }

      final container = ProviderContainer();
      NotificationService.onOrderUpdate =
          () => container.read(ordersProvider.notifier).refresh();

      await container.read(authProvider.notifier).loadSavedAuth();
      await BootLog.write('boot: auth ok');

      if (PlatformLayout.isOpsDesktop) {
        await container.read(kitchenPrinterProvider.notifier).load();
        await container.read(cashierPrinterProvider.notifier).load();
        await BootLog.write('boot: printer prefs ok');
      }

      final savedLocale = await LocalizationService.getSavedLocale();
      await BootLog.write('boot: runApp');

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: LocalizationService.supportedLocales,
            path: 'assets/translations',
            fallbackLocale: LocalizationService.fallbackLocale,
            startLocale: savedLocale ?? LocalizationService.fallbackLocale,
            child: const TostuSahaneApp(),
          ),
        ),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await BootLog.write('boot: first frame ok');
      });
    },
    (error, stack) async {
      await BootLog.write('boot: UNCAUGHT $error');
      await BootLog.write(stack.toString());
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

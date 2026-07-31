import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'core/config/app_config.dart';

/// Firebase yapılandırması.
///
/// Yerel geliştirme (gerçek anahtarlar — asla commit etmeyin):
/// 1. `dart_defines.local.json.example` → `dart_defines.local.json` kopyala, doldur
/// 2. `flutter run --dart-define-from-file=dart_defines.local.json`
/// veya `flutterfire configure --project=YOUR_PROJECT_ID` (yerel; commit etme)
///
/// CI: Secrets + `--dart-define=FIREBASE_*` ile override.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (AppConfig.useFirebaseOverrides) {
      return _fromEnvironment();
    }
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.windows => windows,
      _ => web,
    };
  }

  static FirebaseOptions _fromEnvironment() => FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        appId: AppConfig.firebaseAppId,
        messagingSenderId: AppConfig.firebaseMessagingSenderId,
        projectId: AppConfig.firebaseProjectId,
        storageBucket: AppConfig.firebaseStorageBucket,
        iosBundleId: AppConfig.firebaseIosBundleId,
      );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_WEB_API_KEY',
    appId: 'REPLACE_WITH_FIREBASE_WEB_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FIREBASE_SENDER_ID',
    projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
    authDomain: 'REPLACE_WITH_FIREBASE_AUTH_DOMAIN',
    storageBucket: 'REPLACE_WITH_FIREBASE_STORAGE_BUCKET',
    measurementId: 'REPLACE_WITH_FIREBASE_MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_FIREBASE_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FIREBASE_SENDER_ID',
    projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_FIREBASE_STORAGE_BUCKET',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_IOS_API_KEY',
    appId: 'REPLACE_WITH_FIREBASE_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FIREBASE_SENDER_ID',
    projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_FIREBASE_STORAGE_BUCKET',
    iosBundleId: 'com.tostusahane.tostuSahane',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_WEB_API_KEY',
    appId: 'REPLACE_WITH_FIREBASE_WEB_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FIREBASE_SENDER_ID',
    projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
    authDomain: 'REPLACE_WITH_FIREBASE_AUTH_DOMAIN',
    storageBucket: 'REPLACE_WITH_FIREBASE_STORAGE_BUCKET',
  );
}

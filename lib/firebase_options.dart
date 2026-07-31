import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'core/config/app_config.dart';

/// Firebase yapılandırması.
///
/// Yerel geliştirme:
/// 1. `dart pub global activate flutterfire_cli`
/// 2. `flutterfire configure --project=YOUR_PROJECT_ID`
///
/// CI / production: `--dart-define=FIREBASE_*` ile override edin.
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
    apiKey: 'AIzaSyCru2ksZtgaeUmg5UB_rPVHQZ9ujRYJj0Y',
    appId: '1:512275443807:web:fa809bb41a6b1e50f8abea',
    messagingSenderId: '512275443807',
    projectId: 'tostusahane-e4e71',
    authDomain: 'tostusahane-e4e71.firebaseapp.com',
    storageBucket: 'tostusahane-e4e71.firebasestorage.app',
    measurementId: 'G-S892L4MV4M',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDZ5iC72yPBXgLvYdndknKjNl83CbWkxuY',
    appId: '1:512275443807:android:f7c5a66155c03719f8abea',
    messagingSenderId: '512275443807',
    projectId: 'tostusahane-e4e71',
    storageBucket: 'tostusahane-e4e71.firebasestorage.app',
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
    apiKey: 'AIzaSyCru2ksZtgaeUmg5UB_rPVHQZ9ujRYJj0Y',
    appId: '1:512275443807:web:fa809bb41a6b1e50f8abea',
    messagingSenderId: '512275443807',
    projectId: 'tostusahane-e4e71',
    authDomain: 'tostusahane-e4e71.firebaseapp.com',
    storageBucket: 'tostusahane-e4e71.firebasestorage.app',
  );
}

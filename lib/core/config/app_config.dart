import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  /// `true` → mock datasource, `false` → gerçek REST API
  static const useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.tostusahane.com/v1',
  );

  /// Google Maps JavaScript / SDK anahtarı.
  /// Android: android/app/src/main/AndroidManifest.xml içindeki meta-data ile aynı olmalı.
  /// Web: web/index.html script src key parametresi.
  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Mock modda PayTR demo WebView'ı açmak için `true` yapın.
  /// Production (`USE_MOCK_API=false`) modunda PayTR otomatik aktif olur.
  static const usePaytr = bool.fromEnvironment(
    'USE_PAYTR',
    defaultValue: false,
  );

  /// PayTR iframe başarı / hata redirect URL kalıpları (backend ile aynı olmalı).
  static const paytrSuccessUrl = String.fromEnvironment(
    'PAYTR_SUCCESS_URL',
    defaultValue: 'tostusahane://payment/success',
  );

  static const paytrFailUrl = String.fromEnvironment(
    'PAYTR_FAIL_URL',
    defaultValue: 'tostusahane://payment/fail',
  );

  /// Production Firebase — tüm alanlar doluysa dart-define override aktif olur.
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static const firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  static const firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );

  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  static const firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );

  static const firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.tostusahane.tostuSahane',
  );

  static const apiTimeout = Duration(seconds: 30);

  static bool get useFirebaseOverrides =>
      firebaseProjectId.isNotEmpty &&
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty;

  static bool get hasGoogleMapsKey => googleMapsApiKey.isNotEmpty;

  /// Uygulama içi harita widget'ları (adres seçici, teslimat bölgesi, canlı takip)
  /// her zaman OpenStreetMap kullanır. Dış navigasyon için Maps uygulaması açılır.
  static bool get useInAppOsmMaps => true;

  /// Android/iOS: yalnızca dart-define ile anahtar verildiyse Google widget kullanılır.
  static bool get useGoogleMaps {
    if (useInAppOsmMaps) return false;
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return false;
    }
    return hasGoogleMapsKey;
  }

  /// Production modunda PayTR kullanılır (`USE_PAYTR=true`).
  static bool get usePaytrPayment => usePaytr;

  /// Windows ops masaüstü: native SDK yerine Firestore REST (HTTP polling).
  static bool get useWindowsOpsFirestoreRest =>
      opsDesktop &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows;

  /// Native cloud_firestore SDK (mobil / web).
  static bool get useFirestore => !useMockApi && !useWindowsOpsFirestoreRest;

  /// Firestore verisi (native veya Windows REST).
  static bool get useFirestoreBackend => !useMockApi;

  /// Windows şube/yönetici masaüstü paketi (`--dart-define=OPS_DESKTOP=true`).
  static const opsDesktop = bool.fromEnvironment(
    'OPS_DESKTOP',
    defaultValue: false,
  );

  /// Sadece mock modda demo kart formu.
  static bool get useDemoCardPayment => useMockApi && !usePaytr;
}

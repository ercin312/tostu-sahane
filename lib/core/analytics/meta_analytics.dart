import 'dart:async';
import 'dart:convert';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../utils/platform_layout_utils.dart';
import '../../shared/domain/entities/order.dart';

/// Meta (Facebook) App Events — müşteri mobil uygulaması dönüşüm ölçümü.
///
/// App Secret asla burada veya native config'te tutulmaz.
/// Client Token public'tir (Meta docs); App ID ile birlikte native plist/strings'te gerekir.
abstract final class MetaAnalytics {
  static final FacebookAppEvents _fb = FacebookAppEvents();
  static bool _initialized = false;
  static Timer? _searchDebounce;
  static String? _lastSearchLogged;
  static final Set<String> _viewedProductIds = {};
  static const _purchaseIdsPrefsKey = 'meta_logged_purchase_order_ids';

  static const currencyTry = 'TRY';
  static const contentTypeProduct = 'product';

  /// Canlı ölçüm: release müşteri build'i.
  /// Test Events: `--dart-define=META_TEST_EVENTS=true` (mock/Windows hariç).
  static bool get isEnabled {
    if (kIsWeb) return false;
    if (PlatformLayout.isOpsDesktop) return false;
    if (AppConfig.useMockApi) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    if (AppConfig.metaTestEvents) return true;
    return kReleaseMode;
  }

  static Future<void> initialize() async {
    if (_initialized || !isEnabled) return;
    _initialized = true;
    try {
      await _fb.setAutoLogAppEventsEnabled(true);
      await _fb.setAdvertiserIdCollectionEnabled(true);

      if (AppConfig.metaTestEvents || kDebugMode) {
        await _fb.setDebugLoggingEnabled(true);
      }

      await _configureIosAtt();

      // fb_mobile_activate_app
      await _fb.activateApp();
      await _fb.flush();
      debugPrint('MetaAnalytics: initialized (activateApp)');
    } catch (e, st) {
      debugPrint('MetaAnalytics init failed: $e\n$st');
    }
  }

  static Future<void> _configureIosAtt() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      // İzin diyaloğu; reddedilse de SKAdNetwork / AEM toplu ölçüm çalışır.
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      final granted =
          await AppTrackingTransparency.trackingAuthorizationStatus ==
              TrackingStatus.authorized;
      // iOS SDK ATT durumunu da okur; burada reklam kimliği toplamayı hizalarız.
      await _fb.setAdvertiserIdCollectionEnabled(granted);
    } catch (e) {
      debugPrint('MetaAnalytics ATT: $e');
      try {
        await _fb.setAdvertiserIdCollectionEnabled(false);
      } catch (_) {}
    }
  }

  static Future<void> logCompleteRegistration({
    String method = 'email',
  }) async {
    if (!isEnabled) return;
    try {
      await _fb.logCompletedRegistration(registrationMethod: method);
      await _flushIfTesting();
    } catch (e) {
      debugPrint('MetaAnalytics registration: $e');
    }
  }

  /// Debounced search (min 2 karakter, 600ms).
  static void logSearchDebounced(String query, {int? resultCount}) {
    if (!isEnabled) return;
    _searchDebounce?.cancel();
    final q = query.trim();
    if (q.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (_lastSearchLogged == q) return;
      _lastSearchLogged = q;
      try {
        await _fb.logSearched(
          searchString: q,
          contentType: contentTypeProduct,
          parameters: {
            if (resultCount != null) ...{
              'fb_success': resultCount > 0 ? 1 : 0,
              'result_count': resultCount,
            },
          },
        );
        await _flushIfTesting();
      } catch (e) {
        debugPrint('MetaAnalytics search: $e');
      }
    });
  }

  static Future<void> logViewContent({
    required String productId,
    required String productName,
    required double price,
  }) async {
    if (!isEnabled) return;
    if (_viewedProductIds.contains(productId)) return;
    _viewedProductIds.add(productId);
    try {
      await _fb.logViewContent(
        id: productId,
        type: contentTypeProduct,
        currency: currencyTry,
        price: price,
        content: {
          'id': productId,
          'quantity': 1,
        },
        parameters: {
          'fb_description': productName,
        },
      );
      await _flushIfTesting();
    } catch (e) {
      debugPrint('MetaAnalytics viewContent: $e');
    }
  }

  static Future<void> logAddToCart({
    required String productId,
    required String productName,
    required double price,
    required int quantity,
  }) async {
    if (!isEnabled) return;
    try {
      await _fb.logAddToCart(
        id: productId,
        type: contentTypeProduct,
        currency: currencyTry,
        price: price * quantity,
        content: {
          'id': productId,
          'quantity': quantity,
        },
        parameters: {
          'fb_description': productName,
        },
      );
      await _flushIfTesting();
    } catch (e) {
      debugPrint('MetaAnalytics addToCart: $e');
    }
  }

  static Future<void> logInitiatedCheckout({
    required double totalPrice,
    required int numItems,
    required List<String> productIds,
    bool paymentInfoAvailable = false,
  }) async {
    if (!isEnabled) return;
    try {
      await _fb.logInitiatedCheckout(
        totalPrice: totalPrice,
        currency: currencyTry,
        contentType: contentTypeProduct,
        contentId: productIds.join(','),
        numItems: numItems,
        paymentInfoAvailable: paymentInfoAvailable,
        parameters: {
          'fb_content': jsonEncode([
            for (final id in productIds) {'id': id, 'quantity': 1},
          ]),
        },
      );
      await _flushIfTesting();
    } catch (e) {
      debugPrint('MetaAnalytics initiatedCheckout: $e');
    }
  }

  /// Yalnızca başarılı siparişten sonra; aynı sipariş bir kez.
  static Future<void> logPurchase(Order order) async {
    if (!isEnabled) return;
    final dedupeKey = order.id.isNotEmpty ? order.id : '${order.orderNumber}';
    if (await _wasPurchaseLogged(dedupeKey)) {
      debugPrint('MetaAnalytics purchase skip duplicate: $dedupeKey');
      return;
    }

    try {
      final content = [
        for (final item in order.items)
          {
            'id': item.productId,
            'quantity': item.quantity,
            'item_price': item.unitPrice,
          },
      ];
      final numItems =
          order.items.fold<double>(0, (s, i) => s + i.quantity).round();

      await _fb.logPurchase(
        amount: order.totalAmount,
        currency: currencyTry,
        parameters: {
          'fb_order_id': dedupeKey,
          'order_number': order.orderNumber,
          'fb_content_type': contentTypeProduct,
          'fb_content_id': order.items.map((e) => e.productId).join(','),
          'fb_num_items': numItems,
          'fb_content': jsonEncode(content),
          if (order.paymentMethod.name.isNotEmpty)
            'fb_payment_method': order.paymentMethod.name,
        },
      );
      await _markPurchaseLogged(dedupeKey);
      await _flushIfTesting();
      debugPrint(
        'MetaAnalytics purchase: $dedupeKey '
        '${order.totalAmount} $currencyTry',
      );
    } catch (e) {
      debugPrint('MetaAnalytics purchase: $e');
    }
  }

  static Future<bool> _wasPurchaseLogged(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_purchaseIdsPrefsKey) ?? const [];
    return raw.contains(orderId);
  }

  static Future<void> _markPurchaseLogged(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = List<String>.from(
      prefs.getStringList(_purchaseIdsPrefsKey) ?? const [],
    );
    raw.add(orderId);
    // Son 200 sipariş kimliğini tut (yerel yinelenme koruması).
    while (raw.length > 200) {
      raw.removeAt(0);
    }
    await prefs.setStringList(_purchaseIdsPrefsKey, raw);
  }

  static Future<void> _flushIfTesting() async {
    if (AppConfig.metaTestEvents || kDebugMode) {
      await _fb.flush();
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../firebase_options.dart';

/// Resolves Gemini API key from compile-time define, then Firestore.
class GeminiKeyResolver {
  GeminiKeyResolver({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  String? _cached;

  Future<String?> resolve() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached;

    final fromDefine = AppConfig.geminiApiKey.trim();
    if (fromDefine.isNotEmpty) {
      _cached = fromDefine;
      return _cached;
    }

    if (AppConfig.useMockApi) return null;

    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      final url =
          'https://firestore.googleapis.com/v1/projects/${options.projectId}'
          '/databases/(default)/documents/meta/designer_settings'
          '?key=${options.apiKey}';
      final response = await _dio.get<Map<String, dynamic>>(url);
      final fields = response.data?['fields'] as Map<String, dynamic>?;
      final key =
          (fields?['gemini_api_key'] as Map<String, dynamic>?)?['stringValue']
                  as String? ??
              '';
      final trimmed = key.trim();
      if (trimmed.isNotEmpty) {
        _cached = trimmed;
        return _cached;
      }
    } catch (e) {
      debugPrint('GeminiKeyResolver Firestore failed: $e');
    }
    return null;
  }

  void clearCache() => _cached = null;
}

final geminiKeyResolverProvider = Provider<GeminiKeyResolver>((ref) {
  return GeminiKeyResolver();
});

final geminiApiKeyProvider = FutureProvider<String?>((ref) async {
  return ref.watch(geminiKeyResolverProvider).resolve();
});

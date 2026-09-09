import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/design_models.dart';
import 'gemini_key_resolver.dart';

class GeminiDesignException implements Exception {
  GeminiDesignException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GeminiDesignService {
  GeminiDesignService({
    required Future<String?> Function() resolveApiKey,
    Dio? dio,
  })  : _resolveApiKey = resolveApiKey,
        _dio = dio ?? Dio();

  final Future<String?> Function() _resolveApiKey;
  final Dio _dio;
  final _rng = math.Random();

  static const _base =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _textModel = 'gemini-2.5-flash';
  static const _imageModel = 'gemini-2.5-flash-image';

  Future<String> _requireKey() async {
    final key = (await _resolveApiKey())?.trim() ?? '';
    if (key.isEmpty) {
      throw GeminiDesignException(
        'Gemini API anahtarı yok. Uygulamayı dart_defines.local.json ile yeniden derleyin.',
      );
    }
    return key;
  }

  Future<DesignCopyPack> generateCopy({
    required String productName,
    required DesignFormat format,
    String? productDescription,
  }) async {
    final apiKey = await _requireKey();
    final formatLabel = format.labelTr;
    final prompt = '''
Sen Tost-u Şahane markasının sosyal medya metin yazarısın.
Ürün/konu: $productName
${productDescription != null && productDescription.isNotEmpty ? 'Açıklama: $productDescription' : ''}
Format: $formatLabel
Dil: Türkçe. Ton: sıcak, iştah açıcı, yerel gurur.
Sadece JSON: {"headline":"...","subline":"...","cta":"..."}
''';

    final text = await _generateText(prompt, apiKey);
    final json = _extractJson(text);
    return DesignCopyPack(
      headline: (json['headline'] as String?)?.trim().isNotEmpty == true
          ? json['headline'] as String
          : productName.toUpperCase(),
      subline: (json['subline'] as String?)?.trim() ?? '',
      cta: (json['cta'] as String?)?.trim().isNotEmpty == true
          ? json['cta'] as String
          : DesignerBrand.defaultCta,
    );
  }

  /// Örnek kreatifler + logo referanslı tam görsel üretimi (kalıp yok).
  Future<Uint8List> generateCreativeImage({
    required DesignFormat format,
    required String subjectName,
    String? headline,
    String? cta,
    String? userBrief,
    bool mixedStyle = true,
    String? productImageUrl,
    Uint8List? referenceImageBytes,
    String referenceMimeType = 'image/jpeg',
  }) async {
    final apiKey = await _requireKey();
    final sizeHint = format == DesignFormat.story
        ? 'vertical 9:16 Instagram/TikTok story'
        : 'square 1:1 Instagram feed post';
    final brief = userBrief?.trim() ?? '';
    final title = (headline?.trim().isNotEmpty == true)
        ? headline!.trim()
        : subjectName;
    final callToAction = (cta?.trim().isNotEmpty == true)
        ? cta!.trim()
        : DesignerBrand.defaultCta;

    final parts = <Map<String, dynamic>>[
      {
        'text': '''
Create ONE finished social media advertisement image for Turkish toast brand "Tost-u Şahane".
Output format MUST be exactly: $sizeHint.

Brand: Tost-u Şahane — famous sanayi toast restaurant since 2006 (Manavgat/Alanya region).
Subject/product: $subjectName
Visible headline text (Turkish): "$title"
CTA button text: "$callToAction"
Include small phones at bottom: 0242 515 06 57, 0532 512 03 49
Brand colors: deep red (#9E0B1F / #EA004B), navy (#001F3F), white.
MUST use the attached circular mascot badge logo as the real brand mark.
${mixedStyle || brief.isEmpty ? 'Create a fresh premium variation inspired by the attached EXAMPLE creatives — match their energy, color blocking, food photography polish, and composition craft. Do NOT copy text literally from examples. Do NOT produce a flat Flutter UI mockup or a repeated single template.' : 'Creator brief (follow closely): "$brief" — still match the attached example creatives\' brand look.'}

Attached EXAMPLE JPGs are style references of real Tost-u Şahane ads. Produce something that could sit next to them in the brand Instagram feed.
${referenceImageBytes != null && referenceImageBytes.isNotEmpty ? 'CRITICAL: A user/product photo is attached — use that exact food as the hero (keep recognizable).' : 'Appetizing toast/food photography as hero.'}
No watermarks. No unrelated logos. High-end restaurant advertising quality.
''',
      },
    ];

    // Logo
    try {
      final logoBytes =
          (await rootBundle.load(DesignerBrand.mascotAsset)).buffer.asUint8List();
      parts.add({
        'inline_data': {
          'mime_type': 'image/png',
          'data': base64Encode(logoBytes),
        },
      });
      parts.add({
        'text':
            'Official Tost-u Şahane circular mascot badge — place it clearly on the creative.',
      });
    } catch (e) {
      debugPrint('GeminiDesignService logo load failed: $e');
    }

    // 2–3 random example style refs
    final examples = List<String>.of(DesignerBrand.exampleAssets)..shuffle(_rng);
    final picked = examples.take(3).toList();
    for (final asset in picked) {
      try {
        final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(bytes),
          },
        });
      } catch (e) {
        debugPrint('GeminiDesignService example load failed ($asset): $e');
      }
    }
    parts.add({
      'text':
          'The previous images are brand EXAMPLE creatives (style reference only). Match their premium look.',
    });

    // User / product hero photo
    if (referenceImageBytes != null && referenceImageBytes.isNotEmpty) {
      parts.add({
        'inline_data': {
          'mime_type': referenceMimeType,
          'data': base64Encode(referenceImageBytes),
        },
      });
      parts.add({
        'text': 'User/product photo — compose the ad around this exact image.',
      });
    } else if (productImageUrl != null && productImageUrl.startsWith('http')) {
      try {
        final res = await _dio.get<List<int>>(
          productImageUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = Uint8List.fromList(res.data ?? const []);
        if (bytes.isNotEmpty) {
          parts.add({
            'inline_data': {
              'mime_type': _mimeFromUrl(productImageUrl),
              'data': base64Encode(bytes),
            },
          });
          parts.add({
            'text': 'Catalog product photo for the food hero.',
          });
        }
      } catch (e) {
        debugPrint('GeminiDesignService product fetch failed: $e');
      }
    }

    final url = '$_base/$_imageModel:generateContent?key=$apiKey';
    late final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'contents': [
            {'role': 'user', 'parts': parts},
          ],
          'generationConfig': {
            'responseModalities': ['TEXT', 'IMAGE'],
            'temperature': mixedStyle ? 1.0 : 0.9,
          },
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
          validateStatus: (code) => code != null && code < 500,
        ),
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      debugPrint('Gemini image DioException: $e body=$body');
      throw GeminiDesignException(
        'Gemini isteği başarısız: ${e.message ?? e.type.name}',
      );
    }

    if (response.statusCode != null && response.statusCode! >= 400) {
      final err = response.data?['error'];
      final msg = err is Map
          ? (err['message'] as String? ?? response.data.toString())
          : response.data.toString();
      debugPrint('Gemini image API error: $msg');
      throw GeminiDesignException('Gemini hata: $msg');
    }

    final bytes = _firstImageBytes(response.data);
    if (bytes == null || bytes.isEmpty) {
      final block = _blockReason(response.data);
      throw GeminiDesignException(
        block != null
            ? 'Gemini görsel üretmedi ($block). Tekrar deneyin.'
            : 'Gemini görsel üretmedi. Tekrar deneyin veya isteği sadeleştirin.',
      );
    }
    return bytes;
  }

  Future<String> _generateText(String prompt, String apiKey) async {
    final url = '$_base/$_textModel:generateContent?key=$apiKey';
    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.8,
          'responseMimeType': 'application/json',
        },
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final candidates = response.data?['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiDesignException('Gemini metin boş döndü');
    }
    final content = candidates.first as Map<String, dynamic>;
    final parts =
        (content['content'] as Map<String, dynamic>?)?['parts'] as List<dynamic>?;
    final text = parts
            ?.whereType<Map>()
            .map((p) => p['text'])
            .whereType<String>()
            .join('\n') ??
        '';
    if (text.trim().isEmpty) {
      throw GeminiDesignException('Gemini metin üretmedi');
    }
    return text;
  }

  Map<String, dynamic> _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      text = text.substring(start, end + 1);
    }
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw GeminiDesignException('JSON parse edilemedi');
  }

  Uint8List? _firstImageBytes(Map<String, dynamic>? data) {
    final candidates = data?['candidates'] as List<dynamic>?;
    if (candidates == null) return null;
    for (final c in candidates) {
      if (c is! Map) continue;
      final parts = (c['content'] as Map?)?['parts'] as List<dynamic>?;
      if (parts == null) continue;
      for (final p in parts) {
        if (p is! Map) continue;
        final inline = p['inlineData'] ?? p['inline_data'];
        if (inline is Map && inline['data'] is String) {
          return base64Decode(inline['data'] as String);
        }
      }
    }
    return null;
  }

  String? _blockReason(Map<String, dynamic>? data) {
    final candidates = data?['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return data?['promptFeedback']?.toString();
    }
    final first = candidates.first;
    if (first is Map && first['finishReason'] != null) {
      return first['finishReason'].toString();
    }
    return null;
  }

  String _mimeFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return 'image/png';
    if (lower.contains('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

final geminiDesignServiceProvider = Provider<GeminiDesignService>((ref) {
  return GeminiDesignService(
    resolveApiKey: () => ref.read(geminiKeyResolverProvider).resolve(),
  );
});

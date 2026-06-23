import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Galeriden görsel seçip cihaza kaydeder; Firestore senkronu için base64 döner.
abstract final class MediaStorageService {
  static const base64Prefix = 'base64:';

  static Future<String?> pickAndSaveImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: AppConfig.useFirestore ? 1024 : 1600,
      imageQuality: AppConfig.useFirestore ? 75 : 85,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();

    if (kIsWeb || AppConfig.useFirestore) {
      return '$base64Prefix${base64Encode(bytes)}';
    }

    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${dir.path}/media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destPath = '${mediaDir.path}/$fileName';
    await File(picked.path).copy(destPath);
    return destPath;
  }

  /// Yerel dosya yolunu Firestore'da paylaşılabilir base64'e çevirir.
  static Future<String?> ensureRemoteReady(String? source) async {
    if (source == null || source.isEmpty) return source;
    if (isNetworkSource(source) || isBase64Source(source)) return source;
    if (!AppConfig.useFirestore || kIsWeb) return source;

    final file = File(source);
    if (!await file.exists()) return source;

    try {
      final bytes = await file.readAsBytes();
      return '$base64Prefix${base64Encode(bytes)}';
    } catch (_) {
      return source;
    }
  }

  static bool localFileExists(String source) {
    if (kIsWeb || isNetworkSource(source) || isBase64Source(source)) {
      return false;
    }
    return File(source).existsSync();
  }

  static Future<void> deleteIfLocal(String? source) async {
    if (source == null || source.isEmpty || kIsWeb) return;
    if (source.startsWith('http') || source.startsWith(base64Prefix)) return;
    final file = File(source);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static bool isNetworkSource(String source) =>
      source.startsWith('http://') || source.startsWith('https://');

  static bool isBase64Source(String source) => source.startsWith(base64Prefix);

  static Uint8List? decodeBase64(String source) {
    if (!isBase64Source(source)) return null;
    try {
      return base64Decode(source.substring(base64Prefix.length));
    } catch (_) {
      return null;
    }
  }
}

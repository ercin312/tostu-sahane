import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'media_storage_service.dart';

/// URL, yerel dosya veya base64 görselleri tek widget ile gösterir.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
  });

  final String? source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;

  static const _networkImageHeaders = {
    'User-Agent': 'TostuSahane/1.0 (Flutter; ops-desktop)',
    'Accept': 'image/*',
  };

  static bool get _preferNativeNetworkImage =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    final src = source?.trim();
    if (src == null || src.isEmpty) {
      return _wrap(errorWidget ?? const SizedBox.shrink());
    }

    Widget image;
    if (MediaStorageService.isNetworkSource(src)) {
      if (_preferNativeNetworkImage) {
        image = Image.network(
          src,
          width: width,
          height: height,
          fit: fit,
          headers: _networkImageHeaders,
          errorBuilder: (_, _, _) => errorWidget ?? _defaultError(),
        );
      } else {
        image = CachedNetworkImage(
          imageUrl: src,
          width: width,
          height: height,
          fit: fit,
          httpHeaders: _networkImageHeaders,
          errorWidget: (_, _, _) => errorWidget ?? _defaultError(),
        );
      }
    } else if (MediaStorageService.isBase64Source(src)) {
      final bytes = MediaStorageService.decodeBase64(src);
      image = bytes != null
          ? Image.memory(bytes, width: width, height: height, fit: fit)
          : errorWidget ?? _defaultError();
    } else if (!MediaStorageService.localFileExists(src)) {
      return _wrap(errorWidget ?? _defaultError());
    } else {
      final file = File(src);
      image = Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => errorWidget ?? _defaultError(),
      );
    }

    return _wrap(image);
  }

  Widget _wrap(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _defaultError() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }
}

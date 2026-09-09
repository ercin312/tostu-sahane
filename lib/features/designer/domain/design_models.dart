import 'package:flutter/material.dart';

enum DesignFormat {
  story,
  post,
}

extension DesignFormatX on DesignFormat {
  double get aspectRatio => switch (this) {
        DesignFormat.story => 9 / 16,
        DesignFormat.post => 1,
      };

  int get exportWidth => 1080;

  int get exportHeight => switch (this) {
        DesignFormat.story => 1920,
        DesignFormat.post => 1080,
      };

  String get labelTr => switch (this) {
        DesignFormat.story => 'Dikey hikaye (9:16)',
        DesignFormat.post => 'Kare post (1:1)',
      };
}

class DesignCopyPack {
  const DesignCopyPack({
    required this.headline,
    required this.cta,
    this.subline = '',
  });

  final String headline;
  final String cta;
  final String subline;
}

abstract final class DesignerBrand {
  static const brandRed = Color(0xFF9E0B1F);
  static const brandPrimary = Color(0xFFEA004B);
  static const brandNavy = Color(0xFF001F3F);
  static const mascotAsset = 'assets/sosyal/brand/mascot_logo.png';
  static const wordmarkAsset = 'assets/sosyal/brand/wordmark.svg';
  static const exampleAssets = [
    'assets/sosyal/examples/example_01.jpg',
    'assets/sosyal/examples/example_02.jpg',
    'assets/sosyal/examples/example_03.jpg',
    'assets/sosyal/examples/example_04.jpg',
    'assets/sosyal/examples/example_05.jpg',
    'assets/sosyal/examples/example_06.jpg',
  ];
  static const phones = '0242 515 06 57  ·  0532 512 03 49';
  static const defaultCta = 'HEMEN SİPARİŞ VER';
  static const badge =
      'TOST-U ŞAHANE  ·  MEŞHUR SANAYİ TOSTÇUSU  ·  SINCE 2006';
}

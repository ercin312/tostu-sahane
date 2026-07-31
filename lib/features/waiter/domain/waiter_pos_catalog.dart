import '../../../shared/domain/entities/product.dart';

/// Garson POS hiyerarşik menü düğümü (klasör veya sipariş satırı).
class WaiterPosNode {
  const WaiterPosNode({
    required this.id,
    required this.label,
    this.price,
    this.children = const [],
  });

  final String id;
  final String label;
  /// Yaprak ürün fiyatı. Klasörlerde null (alt seçim açılır).
  final double? price;
  final List<WaiterPosNode> children;

  bool get isFolder => children.isNotEmpty;
  bool get isLeaf => children.isEmpty && price != null;

  /// Sepete yazılacak sentetik ürün.
  Product toProduct(ProductCategory category) {
    final p = price ?? 0;
    return Product(
      id: id,
      nameKey: label,
      descriptionKey: label,
      price: p,
      category: category,
    );
  }
}

enum WaiterPosSection { tostlar, sahan, icecekler, yanUrunler }

/// VEGA tarzı garson menü — görsellerdeki yapı + fiyatlar.
abstract final class WaiterPosCatalog {
  static ProductCategory categoryFor(WaiterPosSection section) =>
      switch (section) {
        WaiterPosSection.tostlar => ProductCategory.tost,
        WaiterPosSection.sahan => ProductCategory.sahanda,
        WaiterPosSection.icecekler => ProductCategory.drink,
        WaiterPosSection.yanUrunler => ProductCategory.snack,
      };

  static List<WaiterPosNode> rootsFor(WaiterPosSection section) =>
      switch (section) {
        WaiterPosSection.tostlar => tostlar,
        WaiterPosSection.sahan => sahan,
        WaiterPosSection.icecekler => icecekler,
        WaiterPosSection.yanUrunler => yanUrunler,
      };

  static List<WaiterPosNode> _leaves(
    String prefix,
    Map<String, double> items,
  ) {
    return [
      for (final e in items.entries)
        WaiterPosNode(
          id: '${prefix}_${_slug(e.key)}',
          label: e.key,
          price: e.value,
        ),
    ];
  }

  static String _slug(String label) {
    const map = {
      'ç': 'c',
      'Ç': 'c',
      'ğ': 'g',
      'Ğ': 'g',
      'ı': 'i',
      'İ': 'i',
      'ö': 'o',
      'Ö': 'o',
      'ş': 's',
      'Ş': 's',
      'ü': 'u',
      'Ü': 'u',
      ' ': '_',
      '.': '',
    };
    final buf = StringBuffer();
    for (final ch in label.split('')) {
      buf.write(map[ch] ?? ch.toLowerCase());
    }
    return buf.toString().replaceAll(RegExp(r'[^a-z0-9_]+'), '');
  }

  // ── TOSTLAR ──────────────────────────────────────────────────────────────

  static final List<WaiterPosNode> tostlar = [
    const WaiterPosNode(id: 'w_tost', label: 'TOST', price: 180),
    const WaiterPosNode(id: 'w_akdeniz', label: 'AKDENİZ TOST', price: 220),
    WaiterPosNode(
      id: 'w_sandvic',
      label: 'SANDVİÇ',
      children: _leaves('w_sandvic', {
        'KAŞARLI': 180,
        'BEYAZ PEYNİRLİ': 180,
      }),
    ),
    const WaiterPosNode(id: 'w_patso', label: 'PATSO', price: 160),
    WaiterPosNode(
      id: 'w_karisik',
      label: 'KARISIK',
      children: _leaves('w_karisik', {
        'SADE': 200,
        'SALCALI': 200,
        'KETCAPLI': 200,
        'KETCAP MAYONEZ': 200,
        'MAYONEZ': 200,
        'DOMATES': 210,
        'DOM BİB': 210,
        'DOM BİB KET MAYO': 210,
        'BOL MALZ SADE': 300,
        'BOL MALZ SAL': 300,
        'BOL MAL KET': 300,
        'BOL MALZ KET MAY': 300,
        'BOL MALZ DOM': 300,
        'BOL MALZ DOM BİB': 310,
      }),
    ),
    WaiterPosNode(
      id: 'w_kasarli',
      label: 'KAŞARLI',
      children: _leaves('w_kasarli', {
        'SADE': 180,
        'SALCALI': 180,
        'KETCAPLI': 180,
        'KETCAP MAYONEZ': 180,
        'MAYONEZ': 180,
        'DOMATES': 190,
        'DOMATES YESIL BIBER': 190,
        'DOMATES YESIL BIBER KETCAP MAYONEZ': 190,
        'TURSU': 180,
        'BOL MALZ SADE': 270,
        'BOL MALZ SALÇALI': 270,
        'BOL MALZ KETÇAPLI': 270,
        'BOL MALZ KET MAY': 270,
        'BOL MALZ DOM.': 280,
      }),
    ),
    WaiterPosNode(
      id: 'w_beyaz',
      label: 'BEYAZ PEYNİRLİ',
      children: _leaves('w_beyaz', {
        'SADE': 180,
        'SALCALI': 180,
        'KETCAPLI': 180,
        'KETCAP MAYANEZ': 180,
        'MAYANEZ': 180,
        'DOMATES': 190,
        'DOMATES YESIL BIBER': 190,
        'SUCUKLU': 180,
        'KAŞARLI': 180,
        'BOL MALZ SADE': 270,
        'BOL MALZ SAL': 270,
        'BOL MALZ KET': 270,
        'BOL MALZ KET MAY': 270,
        'BOL MAL DOM': 280,
      }),
    ),
    WaiterPosNode(
      id: 'w_ispanakli',
      label: 'ISPANAKLI',
      children: _leaves('w_ispanakli', {
        'TULUMLU': 200,
        'KAŞARLI': 180,
        'YUMURTALI TULUMLU': 220,
        'YUMURTALI KAŞARLI': 200,
        'TULUMLU KAŞARLI': 220,
      }),
    ),
    const WaiterPosNode(
      id: 'w_beyaz_sucuklu',
      label: 'BEYAZ PEYNİR SUCUKLU',
      price: 200,
    ),
    const WaiterPosNode(id: 'w_fenomen', label: 'FENOMEN TOST', price: 250),
    WaiterPosNode(
      id: 'w_kavurmali_kasarli',
      label: 'KAVURMALI KASARLI',
      children: _leaves('w_kavurmali_kasarli', {
        'SADE': 280,
        'SALCALI': 280,
        'KETCAPLI': 280,
        'KETCAP MAYONEZ': 280,
        'MAYONEZ': 280,
        'DOMATES': 290,
        'DOMATES YESIL BIBER': 290,
        'DOMATES YESIL BIBER KETCAP MAYONEZ': 290,
        'SUCUKLU': 340,
        'ACILI': 280,
        'BOL MALZ SADE': 420,
        'BOL MALZ SALÇ': 420,
        'BOL MALZ KET': 420,
        'BOL MALZ KET MAY': 420,
      }),
    ),
    WaiterPosNode(
      id: 'w_aktoros',
      label: 'AKTOROS SUCUKLU',
      children: _leaves('w_aktoros', {
        'SADE': 200,
        'SALÇA': 200,
        'KETÇAP': 200,
        'KET MAYO': 200,
        'MAYO': 200,
        'DOM': 210,
        'DOM BİB': 210,
        'TURSU': 210,
        'ACILI': 200,
        'BOL MALZ': 300,
        'YUM': 220,
        'BOL MALZ YUM': 330,
      }),
    ),
    const WaiterPosNode(id: 'w_yumurtali', label: 'YUMURTALI', price: 160),
    WaiterPosNode(
      id: 'w_pastirmali',
      label: 'PASTIRMALI',
      children: _leaves('w_pastirmali', {
        'KAŞARLI': 300,
        'KAŞAR YUMURTA': 330,
        'SUCUK KAŞAR': 400,
        'SUCUK KAŞAR YUMURTA': 400,
        'PASTIRMA KAVURMA KAŞARLI': 450,
      }),
    ),
    WaiterPosNode(
      id: 'w_sucuklu',
      label: 'SUCUKLU',
      children: _leaves('w_sucuklu', {
        'SADE': 200,
        'SALÇALI': 200,
        'KET MAYO': 200,
        'KETÇAPLI': 200,
        'DOM BİB': 210,
        'DOMATESLİ': 210,
        'BOL MALZ': 280,
        'YUMURTALI': 220,
      }),
    ),
    const WaiterPosNode(
      id: 'w_protein',
      label: 'PROTEİN BOMBASI',
      price: 450,
    ),
    WaiterPosNode(
      id: 'w_kasap_sucuk',
      label: 'KASAP SUCUK',
      children: _leaves('w_kasap_sucuk', {
        'MAYONEZ': 180,
        'YUMURTA': 200,
        'KET MAYO': 180,
        'DOM BİB': 190,
        'DOM': 190,
        'KETÇAP': 180,
        'SALÇA': 180,
        'YUMURTA DOM BİB': 210,
      }),
    ),
  ];

  // ── SAHAN (görsel yok; klasik sahanda — doğrudan ekle) ───────────────────

  static const List<WaiterPosNode> sahan = [
    WaiterPosNode(id: 'w_menemen', label: 'MENEMEN', price: 170),
    WaiterPosNode(id: 'w_sahanda_yumurta', label: 'SAHANDA YUMURTA', price: 140),
    WaiterPosNode(
      id: 'w_sahanda_sucuklu',
      label: 'SAHANDA SUCUKLU YUMURTA',
      price: 250,
    ),
    WaiterPosNode(
      id: 'w_sahanda_kavurmali',
      label: 'SAHANDA KAVURMALI YUMURTA',
      price: 330,
    ),
  ];

  // ── İÇECEKLER ────────────────────────────────────────────────────────────

  static const List<WaiterPosNode> icecekler = [
    WaiterPosNode(id: 'w_portakal', label: 'PORTAKAL SUYU', price: 100),
    WaiterPosNode(id: 'w_limonata', label: 'LİMONATA', price: 50),
    WaiterPosNode(id: 'w_cola_25', label: '2.5 LİTRE KOLA', price: 100),
    WaiterPosNode(id: 'w_nescafe', label: 'NESCAFE', price: 70),
    WaiterPosNode(id: 'w_turk_kahve', label: 'TÜRK KAHVESİ', price: 70),
    WaiterPosNode(id: 'w_acik_ayran', label: 'AÇIK AYRAN', price: 40),
    WaiterPosNode(id: 'w_cay', label: 'CAY', price: 25),
    WaiterPosNode(id: 'w_ayran', label: 'AYRAN', price: 40),
    WaiterPosNode(id: 'w_sise_cola', label: 'SİŞE COLA', price: 80),
    WaiterPosNode(id: 'w_kutu_cola', label: 'KUTU COLA', price: 80),
    WaiterPosNode(id: 'w_fanta', label: 'FANTA', price: 80),
    WaiterPosNode(id: 'w_ice_tea', label: 'ICE TEA', price: 80),
    WaiterPosNode(id: 'w_cappy', label: 'CAPPY MEYVE SUYU', price: 50),
    WaiterPosNode(id: 'w_aroma', label: 'AROMA MEYVE SUYU', price: 50),
    WaiterPosNode(id: 'w_nigde', label: 'NİĞDE GAZOZU', price: 40),
    WaiterPosNode(id: 'w_sade_soda', label: 'SADE SODA', price: 30),
    WaiterPosNode(id: 'w_meyveli_soda', label: 'MEYVELİ SODA', price: 35),
    WaiterPosNode(id: 'w_zero', label: 'ZERO COLA', price: 80),
    WaiterPosNode(id: 'w_kucuk_su', label: 'KUCUK SU', price: 25),
    WaiterPosNode(id: 'w_litre_cola', label: 'LİTRELİK KOLA', price: 100),
    WaiterPosNode(id: 'w_buyuk_su', label: 'BUYUK SU', price: 30),
  ];

  // ── YAN ÜRÜNLER ──────────────────────────────────────────────────────────

  static const List<WaiterPosNode> yanUrunler = [
    WaiterPosNode(id: 'w_tursu', label: 'TURŞU', price: 10),
    WaiterPosNode(id: 'w_yesillik', label: 'YEŞİLLİK SÖĞÜŞ', price: 20),
    WaiterPosNode(id: 'w_patates', label: 'PATATES CİPSİ', price: 160),
    WaiterPosNode(id: 'w_sos', label: 'SOS', price: 10),
  ];
}

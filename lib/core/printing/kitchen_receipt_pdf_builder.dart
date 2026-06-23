import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/data/mock/mock_data.dart';
import '../../shared/domain/entities/order.dart';
import '../utils/cart_item_display_utils.dart';
import '../utils/order_modifiers_utils.dart';
import '../utils/waiter_order_notes.dart';
import '../utils/waiter_utils.dart';

/// 80 mm termal mutfak fişi — siyah/beyaz, yazıcı kesim alanına göre daraltılmış.
abstract final class KitchenReceiptPdfBuilder {
  static const _ink = PdfColors.black;
  static const _brandPhones = '0242 515 06 57 - 0532 512 03 49';
  static const _logoAsset = 'assets/images/kitchen_receipt_logo.png';

  static pw.MemoryImage? _logoImage;

  static Future<Uint8List> build(Order order) async {
    final (font, fontBold) = await _loadPdfFonts();
    final logo = await _loadLogo();
    final doc = pw.Document();

    final dateStr = DateFormat('dd.MM.yyyy - HH:mm').format(order.createdAt);
    final orderCode = 'A${order.orderNumber}';
    final mapsUrl = _mapsUrl(order);

    // 72 mm yazdırılabilir alan (80 mm ruloda sağ kesim payı).
    final pageFormat = PdfPageFormat(
      72 * PdfPageFormat.mm,
      double.infinity,
      marginLeft: 4 * PdfPageFormat.mm,
      marginRight: 6 * PdfPageFormat.mm,
      marginTop: 3 * PdfPageFormat.mm,
      marginBottom: 4 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          if (order.isDineIn) {
            return _buildDineInContent(
              order: order,
              logo: logo,
              font: font,
              fontBold: fontBold,
              dateStr: dateStr,
              orderCode: orderCode,
            );
          }
          return _buildDeliveryContent(
            order: order,
            logo: logo,
            font: font,
            fontBold: fontBold,
            dateStr: dateStr,
            orderCode: orderCode,
            mapsUrl: mapsUrl,
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildDineInContent({
    required Order order,
    required pw.MemoryImage? logo,
    required pw.Font font,
    required pw.Font fontBold,
    required String dateStr,
    required String orderCode,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _header(logo, font, fontBold),
        pw.SizedBox(height: 6),
        _section(
          title: 'İÇ SİPARİŞ',
          font: font,
          fontBold: fontBold,
          children: [
            pw.Text(
              'MASA ${order.tableNumber ?? '-'}',
              style: pw.TextStyle(font: fontBold, fontSize: 16, color: _ink),
            ),
            pw.SizedBox(height: 4),
            _labelValue(
              font,
              fontBold,
              'Garson:',
              order.waiterCode ??
                  waiterReceiptCode(name: order.waiterName),
            ),
          ],
        ),
        _section(
          title: 'SİPARİŞ BİLGİLERİ',
          font: font,
          fontBold: fontBold,
          children: [
            _labelValue(font, fontBold, 'Sipariş No:', orderCode),
            _labelValue(font, fontBold, 'Tarih:', dateStr),
          ],
        ),
        if (_hasOrderNote(order))
          _section(
            title: 'SİPARİŞ NOTU',
            font: font,
            fontBold: fontBold,
            children: [
              pw.Text(
                WaiterOrderNotes.display(order)!.trim(),
                style: pw.TextStyle(font: fontBold, fontSize: 10, color: _ink),
              ),
            ],
          ),
        if (_hasModifiers(order))
          _modifiersSection(order, font, fontBold),
        _itemsTable(order, font, fontBold),
        pw.SizedBox(height: 5),
        _paymentFooter(order, font, fontBold, showPayment: false),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'Afiyet Olsun!',
            style: pw.TextStyle(font: fontBold, fontSize: 11, color: _ink),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Mobil uygulama yazılım : alanyaproje.com',
            style: pw.TextStyle(font: fontBold, fontSize: 8, color: _ink),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDeliveryContent({
    required Order order,
    required pw.MemoryImage? logo,
    required pw.Font font,
    required pw.Font fontBold,
    required String dateStr,
    required String orderCode,
    required String? mapsUrl,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _header(logo, font, fontBold),
        pw.SizedBox(height: 6),
        _section(
          title: 'MÜŞTERİ BİLGİLERİ',
          font: font,
          fontBold: fontBold,
          children: [
            _labelValue(font, fontBold, 'Müşteri:', order.customerName),
            pw.SizedBox(height: 4),
            _phoneLine(fontBold, _formatPhone(order.customerPhone)),
          ],
        ),
        _section(
          title: 'TESLİMAT ADRESİ',
          font: font,
          fontBold: fontBold,
          children: [
            pw.Text(
              order.address,
              style: pw.TextStyle(font: fontBold, fontSize: 9, color: _ink),
            ),
            if (_hasDeliveryDirections(order)) ...[
              pw.SizedBox(height: 5),
              _infoBox(
                title: 'YOL TARİFİ',
                text: order.deliveryDirections!.trim(),
                font: font,
                fontBold: fontBold,
                fontSize: 8,
              ),
            ],
          ],
        ),
        if (_hasOrderNote(order))
          _section(
            title: 'SİPARİŞ NOTU',
            font: font,
            fontBold: fontBold,
            children: [
              pw.Text(
                WaiterOrderNotes.display(order)!.trim(),
                style: pw.TextStyle(font: fontBold, fontSize: 10, color: _ink),
              ),
            ],
          ),
        if (_hasModifiers(order))
          _modifiersSection(order, font, fontBold),
        _section(
          title: 'SİPARİŞ BİLGİLERİ',
          font: font,
          fontBold: fontBold,
          children: [
            _labelValue(font, fontBold, 'Sipariş No:', orderCode),
            _labelValue(font, fontBold, 'Tarih:', dateStr),
          ],
        ),
        _itemsTable(order, font, fontBold),
        pw.SizedBox(height: 5),
        _paymentFooter(order, font, fontBold),
        pw.SizedBox(height: 8),
        if (mapsUrl != null) ...[
          pw.Center(child: _qrCode(mapsUrl)),
          pw.SizedBox(height: 6),
        ],
        pw.Center(
          child: pw.Text(
            'Afiyet Olsun!',
            style: pw.TextStyle(font: fontBold, fontSize: 11, color: _ink),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Mobil uygulama yazılım : alanyaproje.com',
            style: pw.TextStyle(font: fontBold, fontSize: 8, color: _ink),
          ),
        ),
      ],
    );
  }

  static String? _mapsUrl(Order order) {
    final lat = order.deliveryLatitude;
    final lng = order.deliveryLongitude;
    if (lat == null || lng == null) return null;
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  static bool _hasDeliveryDirections(Order order) {
    final d = order.deliveryDirections?.trim();
    return d != null && d.isNotEmpty;
  }

  static bool _hasOrderNote(Order order) => WaiterOrderNotes.hasNote(order);

  static bool _hasModifiers(Order order) =>
      OrderModifiersUtils.hasModifiers(order);

  static pw.Widget _modifiersSection(
    Order order,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final lines = OrderModifiersUtils.receiptModifierLines(
      order,
      MockData.catalogExtras,
    );
    return _section(
      title: 'EKLER VE TERCİHLER',
      font: font,
      fontBold: fontBold,
      children: [
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              line,
              style: pw.TextStyle(font: fontBold, fontSize: 10, color: _ink),
            ),
          ),
      ],
    );
  }

  static String _formatPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '—';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('0')) return digits;
    if (digits.length == 10) return '0$digits';
    return phone;
  }

  static String _paymentLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.onlineCard => 'ÖDENDİ',
      PaymentMethod.cashOnDelivery => 'KAPIDA NAKİT',
      PaymentMethod.cardOnDelivery => 'KAPIDA KART',
    };
  }

  static Future<(pw.Font, pw.Font)> _loadPdfFonts() async {
    try {
      final regular = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();
      return (regular, bold);
    } catch (e) {
      debugPrint('PDF font download failed, using built-in: $e');
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    if (_logoImage != null) return _logoImage;
    try {
      final png = await rootBundle.load(_logoAsset);
      _logoImage = pw.MemoryImage(png.buffer.asUint8List());
      return _logoImage;
    } catch (e) {
      debugPrint('Receipt logo load failed: $e');
      return null;
    }
  }

  static pw.Widget _header(
    pw.MemoryImage? logo,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      children: [
        if (logo != null)
          pw.Center(
            child: pw.Image(logo, width: 120, fit: pw.BoxFit.contain),
          )
        else
          pw.Center(
            child: pw.Text(
              "TOST'U ŞAHANE",
              style: pw.TextStyle(font: fontBold, fontSize: 14, color: _ink),
            ),
          ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            'Tel: $_brandPhones',
            style: pw.TextStyle(font: font, fontSize: 7, color: _ink),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Container(height: 1.5, color: _ink),
      ],
    );
  }

  static pw.Widget _section({
    required String title,
    required pw.Font font,
    required pw.Font fontBold,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _ink, width: 1.2),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: fontBold, fontSize: 8, color: _ink),
          ),
          pw.SizedBox(height: 4),
          pw.Container(height: 0.8, color: _ink),
          pw.SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _labelValue(
    pw.Font font,
    pw.Font fontBold,
    String label,
    String value,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: _ink),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(font: font, fontSize: 7.5, color: _ink),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _phoneLine(pw.Font fontBold, String phone) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TELEFON',
          style: pw.TextStyle(font: fontBold, fontSize: 8, color: _ink),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          phone,
          style: pw.TextStyle(font: fontBold, fontSize: 14, color: _ink),
        ),
      ],
    );
  }

  static pw.Widget _infoBox({
    required String title,
    required String text,
    required pw.Font font,
    required pw.Font fontBold,
    required double fontSize,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _ink, width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: fontBold, fontSize: 8, color: _ink),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            text,
            style: pw.TextStyle(font: font, fontSize: fontSize, color: _ink),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemsTable(Order order, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _ink, width: 1.2),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: _ink, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2.2),
          1: const pw.FlexColumnWidth(0.55),
          2: const pw.FlexColumnWidth(1.1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _tableCell('ÜRÜN', fontBold, align: pw.TextAlign.left, fontSize: 9),
              _tableCell('ADET', fontBold, align: pw.TextAlign.center, fontSize: 9),
              _tableCell('TUTAR', fontBold, align: pw.TextAlign.right, fontSize: 9),
            ],
          ),
          ...order.items.map(
            (item) => pw.TableRow(
              children: [
                _tableCell(
                  CartItemDisplayUtils.receiptProductLine(
                    item,
                    MockData.catalogExtras,
                  ),
                  fontBold,
                  align: pw.TextAlign.left,
                  maxLines: 6,
                  fontSize: 10,
                ),
                _tableCell(
                  'x${item.quantity}',
                  fontBold,
                  align: pw.TextAlign.center,
                  fontSize: 12,
                ),
                _tableCell(
                  _formatMoney(item.totalPrice),
                  font,
                  align: pw.TextAlign.right,
                  fontSize: 9,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    int maxLines = 2,
    double fontSize = 7,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        maxLines: maxLines,
        style: pw.TextStyle(font: font, fontSize: fontSize, color: _ink),
      ),
    );
  }

  static String _formatMoney(double amount) {
    final formatted = NumberFormat('#,##0.00', 'tr_TR').format(amount);
    return '$formatted';
  }

  static pw.Widget _paymentFooter(
    Order order,
    pw.Font font,
    pw.Font fontBold, {
    bool showPayment = true,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _ink, width: 1.2),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          if (showPayment) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Ödeme:',
                  style: pw.TextStyle(font: fontBold, fontSize: 8, color: _ink),
                ),
                pw.Flexible(
                  child: pw.Text(
                    _paymentLabel(order.paymentMethod),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: _ink),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
          ],
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOPLAM:',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: _ink),
              ),
              pw.Text(
                '${_formatMoney(order.totalAmount)} TL',
                style: pw.TextStyle(font: fontBold, fontSize: 10, color: _ink),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _qrCode(String data) {
    return pw.BarcodeWidget(
      barcode: Barcode.qrCode(),
      data: data,
      width: 72,
      height: 72,
      drawText: false,
      color: _ink,
    );
  }
}

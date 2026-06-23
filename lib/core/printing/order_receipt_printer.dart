import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/data/mock/mock_data.dart';
import '../../shared/domain/entities/order.dart';
import '../localization/locale_keys.dart';
import '../utils/cart_item_display_utils.dart';
import '../utils/order_modifiers_utils.dart';
import '../utils/waiter_order_notes.dart';
import 'kitchen_receipt_pdf_builder.dart';
import 'kitchen_printer_settings.dart';
import '../utils/format_utils.dart';
import '../utils/order_status_utils.dart';

/// Sipariş fişini PDF olarak yazdırır veya metin olarak paylaşır.
abstract final class OrderReceiptPrinter {
  static const _kitchenPrinterKeywords = [
    'pos',
    'receipt',
    'thermal',
    'esc',
    'kitchen',
    'mutfak',
    'fiş',
    'fis',
    'xprinter',
    'epson',
  ];

  /// Yeni sipariş geldiğinde mutfak fişini otomatik yazdırır.
  /// Dialog açmadan kayıtlı/termal yazıcıya doğrudan gönderir.
  static Future<bool> autoPrintKitchenReceipt(
    Order order, {
    String? savedPrinterName,
  }) async {
    if (kIsWeb) return false;

    const format = PdfPageFormat.roll80;
    final docName = 'siparis_${order.orderNumber}';
    final savedName = savedPrinterName ?? await KitchenPrinterSettings.load();

    Uint8List? bytes;
  for (var attempt = 0; attempt < 3; attempt++) {
      try {
        bytes ??= await _buildPdf(order);

        final printers = await Printing.listPrinters();
        final printer = _pickKitchenPrinter(printers, savedName: savedName);
        if (printer == null) {
          debugPrint('autoPrintKitchenReceipt: yazıcı bulunamadı');
        } else {
          final direct = await Printing.directPrintPdf(
            printer: printer,
            onLayout: (_) async => bytes!,
            format: format,
            name: docName,
            dynamicLayout: false,
            usePrinterSettings:
                defaultTargetPlatform == TargetPlatform.windows,
          );
          if (direct == true) return true;
          debugPrint(
            'autoPrintKitchenReceipt: directPrintPdf false (${printer.name})',
          );
        }
      } catch (e, st) {
        debugPrint('autoPrintKitchenReceipt failed: $e\n$st');
      }

      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }
    return false;
  }

  static Printer? _pickKitchenPrinter(
    List<Printer> printers, {
    String? savedName,
  }) {
    if (printers.isEmpty) return null;

    final available = printers.where((p) => p.isAvailable).toList();
    final candidates = available.isNotEmpty ? available : printers;

    if (savedName != null && savedName.isNotEmpty) {
      for (final printer in candidates) {
        if (printer.name == savedName) return printer;
      }
    }
    for (final keyword in _kitchenPrinterKeywords) {
      for (final printer in candidates) {
        if (printer.name.toLowerCase().contains(keyword)) {
          return printer;
        }
      }
    }
    for (final printer in candidates) {
      if (printer.isDefault) return printer;
    }
    return candidates.first;
  }

  static Future<void> printReceipt(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        LocaleKeys.receiptPreviewTitle.tr(),
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PdfPreview(
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  allowPrinting: false,
                  allowSharing: false,
                  pdfFileName: 'siparis_${order.orderNumber}.pdf',
                  build: (_) => _buildPdf(order),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(LocaleKeys.receiptPreviewPrint.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final bytes = await _buildPdf(order);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      format: PdfPageFormat.roll80,
      name: 'siparis_${order.orderNumber}',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.receiptPrintSent.tr())),
      );
    }
  }

  static Future<void> shareReceipt(Order order) async {
    await SharePlus.instance.share(ShareParams(text: _buildPlainText(order)));
  }

  static Future<Uint8List> _buildPdf(Order order) async {
    return KitchenReceiptPdfBuilder.build(order);
  }

  static String _buildPlainText(Order order) {
    final buffer = StringBuffer()
      ..writeln('=== Tostu Sahane ===')
      ..writeln(
        LocaleKeys.orderNumber.tr(
          namedArgs: {'number': '${order.orderNumber}'},
        ),
      )
      ..writeln(DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt))
      ..writeln(order.customerName)
      ..writeln(order.address);
    final note = WaiterOrderNotes.display(order);
    if (note != null) {
      buffer
        ..writeln('--- SİPARİŞ NOTU ---')
        ..writeln(note);
    }
    if (OrderModifiersUtils.hasModifiers(order)) {
      buffer.writeln('--- EKLER VE TERCİHLER ---');
      for (final line in OrderModifiersUtils.receiptModifierLines(
        order,
        MockData.catalogExtras,
      )) {
        buffer.writeln(line);
      }
    }
    buffer
      ..writeln('---');
    for (final item in order.items) {
      buffer.writeln(
        '${CartItemDisplayUtils.quantityLine(item, MockData.catalogExtras)} '
        '${FormatUtils.currency(item.totalPrice)}',
      );
    }
    buffer
      ..writeln('---')
      ..writeln(
        '${LocaleKeys.customerTotal.tr()}: ${FormatUtils.currency(order.totalAmount)}',
      )
      ..writeln(OrderStatusUtils.label(order.status));
    return buffer.toString();
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/printing/cashier_printer_provider.dart';
import '../../../../core/printing/kitchen_printer_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/platform_layout_utils.dart';

/// Windows şube PC'sinde mutfak ve kasa yazıcısı seçimi.
class BranchPrinterSettingsPanel extends ConsumerStatefulWidget {
  const BranchPrinterSettingsPanel({super.key});

  @override
  ConsumerState<BranchPrinterSettingsPanel> createState() =>
      _BranchPrinterSettingsPanelState();
}

class _BranchPrinterSettingsPanelState
    extends ConsumerState<BranchPrinterSettingsPanel> {
  List<Printer> _printers = [];
  var _loadingPrinters = false;
  var _loadedPrefs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(kitchenPrinterProvider.notifier).load();
      await ref.read(cashierPrinterProvider.notifier).load();
      if (mounted) setState(() => _loadedPrefs = true);
      await _refreshPrinters();
    });
  }

  Future<void> _refreshPrinters() async {
    if (kIsWeb) return;
    setState(() => _loadingPrinters = true);
    try {
      final printers = await Printing.listPrinters();
      if (mounted) setState(() => _printers = printers);
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Widget _printerDropdown({
    required String label,
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      value: selected != null && _printers.any((p) => p.name == selected)
          ? selected
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(LocaleKeys.branchPrinterDefault.tr()),
        ),
        ..._printers.map(
          (p) => DropdownMenuItem<String?>(
            value: p.name,
            child: Text(p.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformLayout.isOpsDesktop) {
      return const SizedBox.shrink();
    }

    final kitchenPrinter = ref.watch(kitchenPrinterProvider);
    final cashierPrinter = ref.watch(cashierPrinterProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.print, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    LocaleKeys.branchPrinterSettingsTitle.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: _loadingPrinters ? null : _refreshPrinters,
                  icon: _loadingPrinters
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: LocaleKeys.commonRetry.tr(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              LocaleKeys.branchPrinterStationHint.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_loadedPrefs)
              const LinearProgressIndicator(minHeight: 2)
            else if (_printers.isEmpty)
              Text(LocaleKeys.branchPrinterNone.tr())
            else ...[
              _printerDropdown(
                label: LocaleKeys.branchPrinterKitchenSelect.tr(),
                selected: kitchenPrinter,
                onChanged: (value) =>
                    ref.read(kitchenPrinterProvider.notifier).save(value),
              ),
              const SizedBox(height: AppSpacing.md),
              _printerDropdown(
                label: LocaleKeys.branchPrinterCashierSelect.tr(),
                selected: cashierPrinter,
                onChanged: (value) =>
                    ref.read(cashierPrinterProvider.notifier).save(value),
              ),
            ],
            if (kitchenPrinter != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                LocaleKeys.branchPrinterKitchenSaved.tr(
                  namedArgs: {'name': kitchenPrinter},
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            if (cashierPrinter != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                LocaleKeys.branchPrinterCashierSaved.tr(
                  namedArgs: {'name': cashierPrinter},
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

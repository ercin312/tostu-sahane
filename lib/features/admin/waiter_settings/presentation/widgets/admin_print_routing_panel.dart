import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/print_routing_settings.dart';

class AdminPrintRoutingPanel extends StatefulWidget {
  const AdminPrintRoutingPanel({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final PrintRoutingSettings settings;
  final ValueChanged<PrintRoutingSettings> onChanged;

  @override
  State<AdminPrintRoutingPanel> createState() => _AdminPrintRoutingPanelState();
}

class _AdminPrintRoutingPanelState extends State<AdminPrintRoutingPanel> {
  late final TextEditingController _kitchenPrinterController;
  late final TextEditingController _cashierPrinterController;

  @override
  void initState() {
    super.initState();
    _kitchenPrinterController =
        TextEditingController(text: widget.settings.kitchenPrinterName);
    _cashierPrinterController =
        TextEditingController(text: widget.settings.cashierPrinterName);
  }

  @override
  void didUpdateWidget(covariant AdminPrintRoutingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.kitchenPrinterName !=
        widget.settings.kitchenPrinterName) {
      _kitchenPrinterController.text = widget.settings.kitchenPrinterName;
    }
    if (oldWidget.settings.cashierPrinterName !=
        widget.settings.cashierPrinterName) {
      _cashierPrinterController.text = widget.settings.cashierPrinterName;
    }
  }

  @override
  void dispose() {
    _kitchenPrinterController.dispose();
    _cashierPrinterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.print_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    LocaleKeys.adminPrintRoutingTitle.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              LocaleKeys.adminPrintRoutingSubtitle.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              LocaleKeys.adminPrintRoutingDineInSection.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    secondary: const Icon(
                      Icons.soup_kitchen_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      LocaleKeys.adminPrintRoutingDineInKitchen.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      LocaleKeys.adminPrintRoutingDineInKitchenHint.tr(),
                    ),
                    value: settings.dineInAtKitchen,
                    onChanged: (value) => widget.onChanged(
                      settings.copyWith(dineInAtKitchen: value),
                    ),
                  ),
                  if (settings.dineInAtKitchen) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: TextField(
                        controller: _kitchenPrinterController,
                        decoration: InputDecoration(
                          labelText:
                              LocaleKeys.adminPrintRoutingKitchenPrinter.tr(),
                          hintText:
                              LocaleKeys.adminPrintRoutingPrinterHint.tr(),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) => widget.onChanged(
                          settings.copyWith(kitchenPrinterName: value),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(LocaleKeys.adminPrintRoutingDineInCashier.tr()),
              subtitle: Text(LocaleKeys.adminPrintRoutingDineInCashierHint.tr()),
              value: settings.dineInAtCashier,
              onChanged: (value) =>
                  widget.onChanged(settings.copyWith(dineInAtCashier: value)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              LocaleKeys.adminPrintRoutingDeliverySection.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(LocaleKeys.adminPrintRoutingDeliveryKitchen.tr()),
              subtitle:
                  Text(LocaleKeys.adminPrintRoutingDeliveryKitchenHint.tr()),
              value: settings.deliveryAtKitchen,
              onChanged: (value) =>
                  widget.onChanged(settings.copyWith(deliveryAtKitchen: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(LocaleKeys.adminPrintRoutingDeliveryCashier.tr()),
              subtitle:
                  Text(LocaleKeys.adminPrintRoutingDeliveryCashierHint.tr()),
              value: settings.deliveryAtCashier,
              onChanged: (value) =>
                  widget.onChanged(settings.copyWith(deliveryAtCashier: value)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              LocaleKeys.adminPrintRoutingPhoneSection.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              LocaleKeys.adminPrintRoutingPhoneHint.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<PhoneOrderPrinterTarget>(
              segments: [
                ButtonSegment(
                  value: PhoneOrderPrinterTarget.kitchen,
                  label: Text(LocaleKeys.adminPrintRoutingPhoneKitchen.tr()),
                  icon: const Icon(Icons.soup_kitchen_outlined),
                ),
                ButtonSegment(
                  value: PhoneOrderPrinterTarget.cashier,
                  label: Text(LocaleKeys.adminPrintRoutingPhoneCashier.tr()),
                  icon: const Icon(Icons.point_of_sale_outlined),
                ),
              ],
              selected: {settings.phoneOrderPrinter},
              onSelectionChanged: (selected) {
                if (selected.isEmpty) return;
                widget.onChanged(
                  settings.copyWith(phoneOrderPrinter: selected.first),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              LocaleKeys.adminPrintRoutingPrintersSection.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (!settings.dineInAtKitchen) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _kitchenPrinterController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPrintRoutingKitchenPrinter.tr(),
                  hintText: LocaleKeys.adminPrintRoutingPrinterHint.tr(),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => widget.onChanged(
                  settings.copyWith(kitchenPrinterName: value),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _cashierPrinterController,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminPrintRoutingCashierPrinter.tr(),
                hintText: LocaleKeys.adminPrintRoutingPrinterHint.tr(),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => widget.onChanged(
                settings.copyWith(cashierPrinterName: value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

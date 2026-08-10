import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/delivery_address.dart';
import '../providers/address_provider.dart';
import '../widgets/address_editor_sheet.dart';

class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressProvider);

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.profileAddresses.tr())),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (addresses) => addresses.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        LocaleKeys.addressEmpty.tr(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: () => showAddressEditorSheet(
                          context: context,
                          ref: ref,
                          defaultSaveAsDefault: true,
                        ),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: Text(LocaleKeys.addressAddNew.tr()),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: addresses.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  return _AddressTile(
                    address: address,
                    onEdit: () => showAddressEditorSheet(
                      context: context,
                      ref: ref,
                      existing: address,
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddressEditorSheet(
          context: context,
          ref: ref,
          defaultSaveAsDefault: false,
        ),
        icon: const Icon(Icons.add),
        label: Text(LocaleKeys.addressAddNew.tr()),
      ),
    );
  }
}

class _AddressTile extends ConsumerWidget {
  const _AddressTile({required this.address, required this.onEdit});

  final DeliveryAddress address;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = address.title.startsWith('address_')
        ? address.title.tr()
        : address.title;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: address.isDefault
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
              if (address.isDefault)
                Chip(
                  label: Text(
                    LocaleKeys.addressDefaultBadge.tr(),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                ),
            ],
          ),
          Text(address.fullAddress),
          if (address.latitude != null && address.longitude != null)
            Text(
              '${address.latitude!.toStringAsFixed(4)}, ${address.longitude!.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton(
                onPressed: onEdit,
                child: Text(LocaleKeys.addressEdit.tr()),
              ),
              if (!address.isDefault)
                TextButton(
                  onPressed: () =>
                      ref.read(addressProvider.notifier).setDefault(address.id),
                  child: Text(LocaleKeys.addressSetDefault.tr()),
                ),
              TextButton(
                onPressed: () =>
                    ref.read(addressProvider.notifier).removeAddress(address.id),
                child: Text(
                  LocaleKeys.commonRemove.tr(),
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

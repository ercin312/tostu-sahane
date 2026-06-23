import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/delivery_address.dart';
import '../providers/address_provider.dart';
import 'address_map_picker_page.dart';

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
            ? Center(child: Text(LocaleKeys.addressEmpty.tr()))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: addresses.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  return _AddressTile(
                    address: address,
                    onEdit: () => _showAddressDialog(context, ref, address),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text(LocaleKeys.addressAddNew.tr()),
      ),
    );
  }

  Future<void> _showAddressDialog(
    BuildContext context,
    WidgetRef ref,
    DeliveryAddress? existing,
  ) async {
    final titleController = TextEditingController(
      text: existing != null && !existing.title.startsWith('address_')
          ? existing.title
          : '',
    );
    final addressController =
        TextEditingController(text: existing?.fullAddress ?? '');
    var setDefault = existing?.isDefault ?? false;
    var saving = false;
    double? pickedLat = existing?.latitude;
    double? pickedLng = existing?.longitude;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? LocaleKeys.addressAddNew.tr()
                    : LocaleKeys.addressEdit.tr(),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.addressTitleLabel.tr(),
                      hintText: LocaleKeys.addressTitleHome.tr(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: addressController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.addressFullLabel.tr(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final result = await Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddressMapPickerPage(
                                  initialLat: pickedLat,
                                  initialLng: pickedLng,
                                ),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                pickedLat = result['latitude'] as double;
                                pickedLng = result['longitude'] as double;
                                addressController.text =
                                    result['address'] as String;
                              });
                            }
                          },
                    icon: const Icon(Icons.map_outlined),
                    label: Text(LocaleKeys.addressPickOnMap.tr()),
                  ),
                  CheckboxListTile(
                    value: setDefault,
                    onChanged: (v) => setState(() => setDefault = v ?? false),
                    title: Text(LocaleKeys.addressSetDefault.tr()),
                    activeColor: AppColors.primary,
                  ),
                  if (saving)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(LocaleKeys.addressGeocoding.tr()),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: Text(LocaleKeys.commonCancel.tr()),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (addressController.text.trim().isEmpty) return;
                          setState(() => saving = true);
                          final title = titleController.text.trim().isEmpty
                              ? LocaleKeys.addressTitleHome
                              : titleController.text.trim();
                          if (existing == null) {
                            await ref.read(addressProvider.notifier).addAddress(
                                  title: title,
                                  fullAddress: addressController.text.trim(),
                                  setDefault: setDefault,
                                  latitude: pickedLat,
                                  longitude: pickedLng,
                                );
                          } else {
                            await ref
                                .read(addressProvider.notifier)
                                .updateAddress(
                                  id: existing.id,
                                  title: title,
                                  fullAddress: addressController.text.trim(),
                                  latitude: pickedLat,
                                  longitude: pickedLng,
                                );
                            if (setDefault && !existing.isDefault) {
                              await ref
                                  .read(addressProvider.notifier)
                                  .setDefault(existing.id);
                            }
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: Text(LocaleKeys.commonSave.tr()),
                ),
              ],
            );
          },
        );
      },
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
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (address.isDefault) ...[
                const SizedBox(width: AppSpacing.sm),
                Chip(
                  label: Text(
                    LocaleKeys.addressDefaultBadge.tr(),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                ),
              ],
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

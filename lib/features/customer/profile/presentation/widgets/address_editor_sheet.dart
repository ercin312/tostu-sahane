import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/delivery_address.dart';
import '../pages/address_map_picker_page.dart';
import '../providers/address_provider.dart';

/// Ortak adres ekleme/düzenleme diyaloğu.
/// Kaydedilen adresi döner (çoklu adres + checkout seçimi için).
Future<DeliveryAddress?> showAddressEditorSheet({
  required BuildContext context,
  required WidgetRef ref,
  DeliveryAddress? existing,
  bool defaultSaveAsDefault = false,
  String? saveHint,
}) async {
  final titleController = TextEditingController(
    text: existing != null && !existing.title.startsWith('address_')
        ? existing.title
        : '',
  );
  final addressController =
      TextEditingController(text: existing?.fullAddress ?? '');
  var setDefault = existing?.isDefault ?? defaultSaveAsDefault;
  var saving = false;
  double? pickedLat = existing?.latitude;
  double? pickedLng = existing?.longitude;
  DeliveryAddress? result;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md + bottomInset,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? LocaleKeys.addressAddNew.tr()
                        : LocaleKeys.addressEdit.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (saveHint != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      saveHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.addressTitleLabel.tr(),
                      hintText: LocaleKeys.addressTitleHome.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: addressController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.addressFullLabel.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final picked =
                                await Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddressMapPickerPage(
                                  initialLat: pickedLat,
                                  initialLng: pickedLng,
                                ),
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                pickedLat = picked['latitude'] as double?;
                                pickedLng = picked['longitude'] as double?;
                                addressController.text =
                                    (picked['address'] as String?) ??
                                        addressController.text;
                              });
                            }
                          },
                    icon: const Icon(Icons.map_outlined),
                    label: Text(LocaleKeys.addressPickOnMap.tr()),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: setDefault,
                    onChanged: (v) => setState(() => setDefault = v ?? false),
                    title: Text(LocaleKeys.addressSetDefault.tr()),
                    activeColor: AppColors.primary,
                  ),
                  if (saving)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(sheetContext),
                          child: Text(LocaleKeys.commonCancel.tr()),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final full =
                                      addressController.text.trim();
                                  if (full.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          LocaleKeys.addressFullLabel.tr(),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => saving = true);
                                  try {
                                    final title =
                                        titleController.text.trim().isEmpty
                                            ? LocaleKeys.addressTitleHome.tr()
                                            : titleController.text.trim();
                                    if (existing == null) {
                                      result = await ref
                                          .read(addressProvider.notifier)
                                          .createAddress(
                                            title: title,
                                            fullAddress: full,
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
                                            fullAddress: full,
                                            latitude: pickedLat,
                                            longitude: pickedLng,
                                          );
                                      if (setDefault && !existing.isDefault) {
                                        await ref
                                            .read(addressProvider.notifier)
                                            .setDefault(existing.id);
                                      }
                                      final list =
                                          ref.read(addressProvider).value ?? [];
                                      result = list.firstWhere(
                                        (a) => a.id == existing.id,
                                        orElse: () => existing,
                                      );
                                    }
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            LocaleKeys.commonError.tr(),
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setState(() => saving = false);
                                    }
                                  }
                                },
                          child: Text(LocaleKeys.commonSave.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  addressController.dispose();
  return result;
}

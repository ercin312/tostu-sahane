import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/media/app_image.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/domain/entities/product_extra.dart';
import '../../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../../../presentation/widgets/admin_image_picker_field.dart';

Future<void> showAdminCatalogExtraEditor(
  BuildContext context,
  WidgetRef ref, {
  ProductExtra? extra,
  bool separateWaiterPrice = false,
  ProductExtraKind defaultKind = ProductExtraKind.ingredient,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AdminCatalogExtraEditorSheet(
      extra: extra,
      separateWaiterPrice: separateWaiterPrice,
      defaultKind: defaultKind,
    ),
  );
}

class _AdminCatalogExtraEditorSheet extends ConsumerStatefulWidget {
  const _AdminCatalogExtraEditorSheet({
    this.extra,
    this.separateWaiterPrice = false,
    this.defaultKind = ProductExtraKind.ingredient,
  });

  final ProductExtra? extra;
  final bool separateWaiterPrice;
  final ProductExtraKind defaultKind;

  @override
  ConsumerState<_AdminCatalogExtraEditorSheet> createState() =>
      _AdminCatalogExtraEditorSheetState();
}

class _AdminCatalogExtraEditorSheetState
    extends ConsumerState<_AdminCatalogExtraEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _waiterPriceController;
  String? _imageSource;
  late ProductExtraKind _kind;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.extra?.name ?? '');
    _priceController = TextEditingController(
      text: widget.extra != null && widget.extra!.price > 0
          ? widget.extra!.price.toString()
          : '',
    );
    final settings = ref.read(waiterModeSettingsProvider).valueOrNull;
    final waiterOverride = widget.extra == null
        ? null
        : settings?.catalogExtraPrices[widget.extra!.id];
    _waiterPriceController = TextEditingController(
      text: (waiterOverride ?? widget.extra?.price ?? 0) > 0
          ? (waiterOverride ?? widget.extra?.price ?? 0).toString()
          : '',
    );
    _imageSource = widget.extra?.imageUrl;
    _kind = widget.extra?.kind ?? widget.defaultKind;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _waiterPriceController.dispose();
    super.dispose();
  }

  Future<void> _saveWaiterPrice(String extraId, double waiterPrice) async {
    final current = ref.read(waiterModeSettingsProvider).valueOrNull ??
        WaiterModeSettings.defaults;
    final prices = Map<String, double>.from(current.catalogExtraPrices)
      ..[extraId] = waiterPrice;
    await saveWaiterModeSettings(
      ref,
      current.copyWith(catalogExtraPrices: prices),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    final waiterPrice = widget.separateWaiterPrice
        ? double.tryParse(_waiterPriceController.text.replaceAll(',', '.'))
        : price;
    if (name.isEmpty || price == null || waiterPrice == null) return;

    setState(() => _saving = true);
    try {
      ProductExtra saved;
      if (widget.extra == null) {
        saved = await ref.read(adminCatalogExtrasProvider.notifier).createExtra(
              name: name,
              price: price,
              imageUrl: _imageSource,
              kind: _kind,
            );
      } else {
        saved = await ref.read(adminCatalogExtrasProvider.notifier).updateExtra(
              widget.extra!.copyWith(
                name: name,
                price: price,
                imageUrl: _imageSource,
                kind: _kind,
              ),
            );
      }
      if (widget.separateWaiterPrice) {
        await _saveWaiterPrice(saved.id, waiterPrice);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.commonError.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.extra != null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing
                  ? LocaleKeys.adminEditExtra.tr()
                  : LocaleKeys.adminAddExtra.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminImagePickerField(
              value: _imageSource,
              urlLabelKey: LocaleKeys.adminExtraImageUrl,
              previewHeight: 72,
              previewWidth: 72,
              onChanged: (value) => setState(() => _imageSource = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminExtraName.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<ProductExtraKind>(
              // ignore: deprecated_member_use
              value: _kind,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminExtraKind.tr(),
                helperText: LocaleKeys.adminExtraKindHint.tr(),
                helperMaxLines: 3,
              ),
              items: [
                DropdownMenuItem(
                  value: ProductExtraKind.ingredient,
                  child: Text(LocaleKeys.adminExtraKindIngredient.tr()),
                ),
                DropdownMenuItem(
                  value: ProductExtraKind.addon,
                  child: Text(LocaleKeys.adminExtraKindAddon.tr()),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _kind = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            if (widget.separateWaiterPrice) ...[
              TextField(
                controller: _waiterPriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminWaiterPrice.tr(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: widget.separateWaiterPrice
                    ? LocaleKeys.adminOnlinePrice.tr()
                    : LocaleKeys.adminExtraPrice.tr(),
                helperText: widget.separateWaiterPrice
                    ? LocaleKeys.adminPriceChannelsHint.tr()
                    : LocaleKeys.adminOnlinePriceHint.tr(),
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(LocaleKeys.commonSave.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminCatalogExtrasTab extends ConsumerWidget {
  const AdminCatalogExtrasTab({
    super.key,
    this.showInlineAddButton = false,
    this.separateWaiterPrice = false,
    this.kinds = const [],
    this.defaultKind = ProductExtraKind.ingredient,
  });

  /// Menü sayfasında FAB varken false; Garson Ayarları sekmesinde true.
  final bool showInlineAddButton;
  final bool separateWaiterPrice;
  final List<ProductExtraKind> kinds;
  final ProductExtraKind defaultKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extrasAsync = ref.watch(adminCatalogExtrasProvider);

    return extrasAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
      data: (allExtras) {
        final filtered = kinds.isEmpty
            ? allExtras
            : allExtras.where((extra) => kinds.contains(extra.kind)).toList();
        final extras = [...filtered]..sort((a, b) {
            if (a.isToastIngredient != b.isToastIngredient) {
              return a.isToastIngredient ? -1 : 1;
            }
            return a.name.compareTo(b.name);
          });
        if (extras.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LocaleKeys.adminNoCatalogExtras.tr(),
                    textAlign: TextAlign.center,
                  ),
                  if (kinds.isEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      LocaleKeys.adminExtraKindHint.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                  if (showInlineAddButton) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => showAdminCatalogExtraEditor(
                        context,
                        ref,
                        separateWaiterPrice: separateWaiterPrice,
                        defaultKind: defaultKind,
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(LocaleKeys.adminAddExtra.tr()),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: extras.length + (showInlineAddButton ? 1 : 0) +
              (kinds.isEmpty ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            var cursor = 0;
            if (kinds.isEmpty) {
              if (index == cursor) {
                return Text(
                  LocaleKeys.adminExtraKindHint.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                );
              }
              cursor++;
            }
            if (showInlineAddButton && index == cursor) {
              return Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => showAdminCatalogExtraEditor(
                    context,
                    ref,
                    separateWaiterPrice: separateWaiterPrice,
                    defaultKind: defaultKind,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(LocaleKeys.adminAddExtra.tr()),
                ),
              );
            }
            final extraIndex = index - cursor - (showInlineAddButton ? 1 : 0);
            final extra = extras[extraIndex];
            return _CatalogExtraListTile(
              extra: extra,
              waiterPrice: separateWaiterPrice
                  ? (ref
                          .watch(waiterModeSettingsProvider)
                          .valueOrNull
                          ?.catalogExtraPrices[extra.id] ??
                      extra.price)
                  : null,
              onEdit: () => showAdminCatalogExtraEditor(
                context,
                ref,
                extra: extra,
                separateWaiterPrice: separateWaiterPrice,
                defaultKind: defaultKind,
              ),
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(LocaleKeys.commonRemove.tr()),
                    content: Text(LocaleKeys.adminDeleteExtraConfirm.tr()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(LocaleKeys.commonCancel.tr()),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          LocaleKeys.commonRemove.tr(),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(adminCatalogExtrasProvider.notifier)
                      .deleteExtra(extra.id);
                }
              },
            );
          },
        );
      },
    );
  }
}

class _CatalogExtraListTile extends StatelessWidget {
  const _CatalogExtraListTile({
    required this.extra,
    required this.onEdit,
    required this.onDelete,
    this.waiterPrice,
  });

  final ProductExtra extra;
  final double? waiterPrice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = localizedOrRaw(extra.name);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: extra.imageUrl != null && extra.imageUrl!.isNotEmpty
                      ? AppImage(source: extra.imageUrl, fit: BoxFit.cover)
                      : ColoredBox(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: Icon(
                            Icons.fastfood_outlined,
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      waiterPrice == null
                          ? '${extra.isToastIngredient ? LocaleKeys.adminExtraKindIngredient.tr() : LocaleKeys.adminExtraKindAddon.tr()} · ${FormatUtils.currency(extra.price)}'
                          : '${extra.isToastIngredient ? LocaleKeys.adminExtraKindIngredient.tr() : LocaleKeys.adminExtraKindAddon.tr()}\n'
                              '${LocaleKeys.adminWaiterPrice.tr()}: ${FormatUtils.currency(waiterPrice!)}\n'
                              '${LocaleKeys.adminOnlinePrice.tr()}: ${FormatUtils.currency(extra.price)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
